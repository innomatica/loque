import 'dart:async';

import 'package:audio_service/audio_service.dart';
import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:loqueapp/services/audiohandler.dart';
import 'package:loqueapp/services/sharedprefs.dart';
import 'package:loqueapp/settings/constants.dart';
import 'package:rxdart/rxdart.dart';

import '../models/channel.dart';
import '../models/episode.dart';
import '../services/database.dart' as db;
import '../services/pcidx.dart';
import '../services/rss.dart';

enum EpisodeFilter { unplayed, all, liked }

class LoqueLogic extends ChangeNotifier {
  EpisodeFilter _filter = EpisodeFilter.unplayed;
  final _channels = <Channel>[];
  final _episodes = <Episode>[];

  late final LoqueAudioHandler _handler;
  StreamSubscription? _subQueue;

  LoqueLogic(LoqueAudioHandler handler) {
    _handler = handler;
    _init();
  }

  void _init() async {
    _handleQueueChange();
    await _loadChannels();
    await refreshEpisodes();
  }

  @override
  void dispose() async {
    db.close();
    _subQueue?.cancel();
    _handler.dispose();
    super.dispose();
  }

  // getters
  List<Channel> get channels => _channels;
  List<Episode> get episodes => _filter == EpisodeFilter.unplayed
      ? _episodes.where((e) => e.played == false).toList()
      : _filter == EpisodeFilter.liked
          ? _episodes.where((e) => e.liked == true).toList()
          : _episodes;
  EpisodeFilter get filter => _filter;
  Episode? get currentEpisode => _episodes
      .cast<Episode?>()
      .firstWhere((e) => e!.id == currentEpisodeId, orElse: () => null);

  // from handler
  // LoqueAudioHandler get handler => _handler;
  String? get currentEpisodeId => _handler.currentEpisodeId;
  MediaItem? get currentTag => _handler.currentMediaItem;
  BehaviorSubject<List<MediaItem>> get queue => _handler.queue;
  BehaviorSubject<MediaItem?> get mediaItem => _handler.mediaItem;
  BehaviorSubject<PlaybackState> get playbackState => _handler.playbackState;

  // from handler._player
  Duration get duration => _handler.duration;
  AudioSource? get audioSource => _handler.audioSource;
  Stream<Duration> get positionStream => _handler.positionStream;

  void _handleQueueChange() {
    _subQueue = _handler.queue.listen((List<MediaItem> queue) async {
      for (final mediaItem in queue) {
        if (mediaItem.extras!['played'] == true) {
          // debugPrint('${mediaItem.extras!['episodeId']} reported as played');
          final episodeId = mediaItem.extras!['episodeId'];
          final episode = _getEpisodeById(episodeId);
          if (episode != null && episode.played == false) {
            // mark played and set seekPos to zero
            episode.played = true;
            episode.mediaSeekPos = 0;
            // update database
            await db.updateEpisode(
              values: {'played': 1, 'mediaSeekPos': 0},
              params: {
                'where': 'id = ?',
                'whereArgs': [episodeId]
              },
            );
          }
        }
      }
      notifyListeners();
    });
  }

  //
  // Load channel data from database
  //
  Future _loadChannels() async {
    _channels.clear();
    // read all channels from database
    final res = await db.readChannels();
    _channels.addAll(res);
    sortChannels(false);
    notifyListeners();
  }

  //
  // get Episode data from the episode list
  //
  Episode? _getEpisodeById(String episodeId) =>
      _episodes.cast<Episode?>().firstWhere((e) => e!.id == episodeId);

  //
  // Fetch episodes for the channel
  //
  Future<List<Episode>> _fetchEpisodes(Channel channel) async {
    final daysSince =
        // _prefs.getInt(spKeyDataRetentionPeriod) ?? defaultDataRetentionPeriod;
        SharedPrefsService.getDataRetentionPeriod() ??
            defaultDataRetentionPeriod;
    List<Episode> res = [];
    try {
      if (channel.source == PodcastSource.pcidx) {
        // get episodes from pcidx
        res = await getEpisodesFromPcIdx(channel, daysSince: daysSince);
      } else if (channel.source == PodcastSource.rss && channel.link != null) {
        // get episodes from rss doc
        res = await getEpisodesFromRssChannel(channel, daysSince: daysSince);
      }
    } catch (e) {
      debugPrint(e.toString());
    }
    return res;
  }

  //
  // Handler proxies
  //
  Future<void> stop() => _handler.stop();
  Future<void> rewind() => _handler.rewind();
  Future<void> fastForward() => _handler.fastForward();
  Future<void> setSpeed(double speed) => _handler.setSpeed(speed);
  Future<void> seek(Duration position) => _handler.seek(position);
  Future<void> resume() async {
    if (_handler.audioSource != null) {
      _handler.play();
    }
  }

  Future<void> play(Episode? episode, {bool dryRun = false}) async {
    debugPrint('logic.play ${episode?.id} vs $currentEpisodeId: $dryRun');
    if (dryRun) {
      // TODO: implement this
    } else {
      if (episode == null) {
        // resume paused episode
        resume();
      } else {
        if (currentEpisodeId == episode.id) {
          // currently playing or paused
          _handler.playing ? pause() : resume();
        } else {
          if (_handler.playing && currentEpisode != null) {
            // save position before move on to play new episode
            _updateEpisodePosition(currentEpisode!);
          }
          _handler.playMediaItem(episode.toMediaItem());
        }
      }
    }
  }

  Future<void> _updateEpisodePosition(Episode episode) async {
    episode.mediaSeekPos = _handler.position.inSeconds;
    await db.saveEpisode(episode);
    // update duration only if it is nonzero and we do not save it honoring
    // the original data
    if (_handler.duration.inSeconds > 0) {
      episode.mediaDuration = _handler.duration.inSeconds;
    }
    notifyListeners();
  }

  // Future<void> pause() => _handler.pause();
  Future<void> pause() async {
    await _handler.pause();
    // update episode info
    // final index = _episodes.indexWhere((e) => e.id == currentEpisodeId);
    // if (index != -1) {
    if (currentEpisode != null) {
      // update position
      _updateEpisodePosition(currentEpisode!);
    }
  }

  //
  // 1. load episode data from the database
  // 2. fetch episode data from the podcast channels
  // 3. merge data
  //
  Future refreshEpisodes() async {
    bool dirty = false;
    _episodes.clear();

    // load eposides from DB
    final records = await db.readEpisodes();
    final expiryDate =
        DateTime.now().subtract(const Duration(days: maxDataRetentionPeriod));
    final displayDate = DateTime.now()
        .subtract(Duration(days: SharedPrefsService.dataRetentionPeriod));

    for (final episode in records) {
      // remove expired episodes
      if (episode.published == null ||
          episode.published!.isBefore(expiryDate)) {
        // except liked
        if (!episode.liked) {
          // debugPrint('refreshEpisode: expired ${episode.published}');
          await db.deleteEpisodeById(episode.id);
        }
      } else if (episode.published!.isAfter(displayDate)) {
        _episodes.add(episode);
      }
    }

    // debugPrint('refreshEpisode: load episodes from db');
    sortEpisodes();

    // fetch episodes from internet
    for (final channel in _channels) {
      final results = await _fetchEpisodes(channel);

      // merge records with episodes
      for (final episode in results) {
        // only if it is not expired
        if (episode.published != null &&
            episode.published!.isAfter(expiryDate)) {
          final index = _episodes.indexWhere((e) => e.id == episode.id);
          if (index == -1) {
            dirty = true;
            _episodes.add(episode);
          }
        }
      }
      // debugPrint('refreshEpisode: fetch episodes from internet');
    }

    if (dirty) {
      // debugPrint('refreshEpisode: dirty detected');
      sortEpisodes();

      for (final episode in _episodes) {
        await db.saveEpisode(episode);
      }
    }
  }

  //
  // Sort channels by the names
  //
  void sortChannels(bool notify) {
    // sort by title
    _channels.sort((a, b) => a.title.compareTo(b.title));
    if (notify) {
      notifyListeners();
    }
  }

//
// Sort episodes by the published date but with priority on the items
// that have been played (nonzero mediaSeekPos)
//
  void sortEpisodes({bool notify = true}) {
    _episodes.sort((a, b) =>
        (b.published?.millisecondsSinceEpoch ?? 0) -
        (a.published?.millisecondsSinceEpoch ?? 0));
    if (notify) {
      // debugPrint('sortEpisodes: $_episodes');
      notifyListeners();
    }
  }

  //
  // Subscribe to a new channel
  //
  Future subscribe(Channel channel) async {
    // add to channels only if it isn't there yet
    final index = _channels.indexWhere((e) => e.id == channel.id);
    if (index == -1) {
      _channels.add(channel);
      sortChannels(false);
      await db.saveChannel(channel);

      // add episodes from the channel to the existing one
      final res = await _fetchEpisodes(channel);
      _episodes.addAll(res);
      sortEpisodes();
    } else {
      debugPrint('loque.subscribe: duplicated channel');
    }
  }

  //
  // Unsubscrbe from the channel
  //
  Future<void> unsubscribe(Channel channel) async {
    // delete channel
    _channels.remove(channel);
    await db.deleteChannelById(channel.id);

    // remove episodes belongs to the channel
    _episodes.removeWhere((e) => e.channelId == channel.id);
    // _dbepsods.removeWhere((e) => e.channelId == channel.id);
    // delete corresponding episodes from the database
    await db.deleteEpisodesByChannelId(channel.id);

    // finally remove playlistitems
    await removePlaylistItemsByChannelId(channel.id);
    notifyListeners();
  }

  //
  // Set episode played flag
  //
  Future setPlayed(String episodeId) async {
    // debugPrint('logic.setPlayed: $episodeId, $delay');
    final episode = _getEpisodeById(episodeId);
    if (episode != null) {
      // set played
      episode.played = true;
      // set seek pos back to zero
      episode.mediaSeekPos = 0;
      // update database
      await db.updateEpisode(
        values: {'played': 1, 'mediaSeekPos': 0},
        params: {
          'where': 'id = ?',
          'whereArgs': [episodeId]
        },
      );
      // remove item from the queue
      _handler.removeQueueItem(episode.toMediaItem());
      notifyListeners();
    }
  }

  //
  // Clear episode played flag
  //
  Future clearPlayed(String episodeId) async {
    final episode = _getEpisodeById(episodeId);
    if (episode != null) {
      // set unplayed
      episode.played = false;
      // set seek pos to zero
      episode.mediaSeekPos = 0;
      await db.saveEpisode(episode);
      notifyListeners();
      // do the same thing to the mediaItem in the queue
      // DON'T DO THIS: this will confuse the user. They can re-add the
      // episode manually.
      // _handler.clearPlayed(episodeId);
    }
  }

  //
  // Toggle liked flag
  //
  Future toggleLiked(String? episodeId) async {
    if (episodeId is String) {
      // debugPrint('logic.markLiked: $episodeId');
      final episode = _getEpisodeById(episodeId);
      if (episode != null) {
        // toggle liked
        episode.liked = !episode.liked;
        await db.saveEpisode(episode);
        notifyListeners();
      }
    }
  }

  //
  // Rotate filter type
  //
  rotateEpisodeFilter() {
    _filter =
        EpisodeFilter.values[(_filter.index + 1) % EpisodeFilter.values.length];
    // debugPrint(_filter.name);
    notifyListeners();
  }

  //
  // Playlist(Queue) related
  //
  Future<void> addEpisodeToPlaylist(Episode episode) =>
      _handler.addQueueItem(episode.toMediaItem());

  Future<void> skipToNext() async {
    // debugPrint('logic.skipToNext');
    _handler.skipToNext();
  }

  Future<void> playMediaItem(MediaItem? mediaItem) async {
    if (mediaItem != null) {
      // find episode for the media
      final episodeId = mediaItem.extras!['episodeId'];
      final index = _episodes.indexWhere((e) => e.id == episodeId);
      if (index != -1) {
        play(_episodes[index]);
      }
    }
  }

  Future<void> removePlaylistItem(MediaItem mediaItem) async {
    _handler.removeQueueItem(mediaItem);
  }

  Future<void> removePlaylistItemByEpisodeId(String id) async {
    // debugPrint('logic.removePlaylistItemByEpisodeId');
    final qval = queue.value;
    final index = qval.indexWhere((m) => m.extras!['episodeId'] == id);
    if (index != -1) {
      _handler.removeQueueItemAt(index);
    }
  }

  Future<void> reorderPlaylist(int oldIndex, int newIndex) =>
      _handler.reorderQueue(oldIndex, newIndex);

  //
  // remove mediaItem from queue by channel id
  //
  Future<void> removePlaylistItemsByChannelId(String id) async {
    int index;
    do {
      var qval = queue.value;
      index = qval.indexWhere((m) => m.extras!['channelId'] == id);
      if (index != -1) {
        // NOTE: this should be done one by one since it modifies list size.
        await removePlaylistItem(qval[index]);
      }
    } while (index != -1);
  }
}
