import 'dart:async';

import 'package:audio_service/audio_service.dart';
import 'package:flutter/material.dart';
import 'package:rxdart/rxdart.dart';

import '../helpers/logger.dart';
import '../models/channel.dart';
import '../models/episode.dart';
import '../services/audiohandler.dart';
import '../settings/constants.dart';
import '../services/database.dart' as db;
import '../services/pcidx.dart';
import '../services/rss.dart';
import '../services/sharedprefs.dart';

enum EpisodeFilter { unplayed, all, liked }

class LoqueLogic extends ChangeNotifier {
  EpisodeFilter _filter = EpisodeFilter.unplayed;
  final _channels = <Channel>[];
  final _episodes = <Episode>[];

  late final LoqueAudioHandler _handler;
  StreamSubscription? _subQueue;
  StreamSubscription? _subMediaItem;

  LoqueLogic(LoqueAudioHandler handler) {
    _handler = handler;
    _init();
  }

  void _init() async {
    _handleQueueChange();
    _handleMediaItemChange();
    await _loadChannels();
    await refreshEpisodes();
  }

  @override
  void dispose() async {
    db.close();
    _subQueue?.cancel();
    _subMediaItem?.cancel();
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
  double get speed => _handler.speed;
  bool get playing => _handler.playing;
  MediaItem? get currentMedia => _handler.mediaItem.value;
  String? get currentEpisodeId =>
      _handler.mediaItem.value?.extras?['episodeId'];
  BehaviorSubject<List<MediaItem>> get queue => _handler.queue;
  BehaviorSubject<MediaItem?> get mediaItem => _handler.mediaItem;
  BehaviorSubject<PlaybackState> get playbackState => _handler.playbackState;

  // from handler._player
  Duration get duration => _handler.duration;
  Stream<Duration> get positionStream => _handler.positionStream;

  //
  // Queue Change Handler: called when
  //
  // - generic changes in the queue (add, remove, reorder)
  // - sequence state has been changed => mediaItem set played
  //
  void _handleQueueChange() {
    _subQueue = _handler.queue.listen((List<MediaItem> items) async {
      for (final mediaItem in items) {
        // logDebug('logic.queueChange.mediaItem: $mediaItem');
        // check played flag
        if (mediaItem.extras!['played'] == true) {
          // logDebug('${mediaItem.extras!['episodeId']} reported as played');
          final episodeId = mediaItem.extras!['episodeId'];
          final episode = _getEpisodeById(episodeId);
          // update database only if necessary
          if (episode != null && episode.played == false) {
            // mark played and set seekPos to zero: required to update UI
            episode.played = true;
            episode.mediaSeekPos = 0;
            // update database
            await db.saveEpisode(episode);
            // await db.updateEpisodes(
            //   values: {'played': 1, 'mediaSeekPos': 0},
            //   params: {
            //     'where': 'id = ?',
            //     'whereArgs': [episodeId]
            //   },
            // );
          }
        }
      }
      // required to notify
      notifyListeners();
    });
  }

  //
  // MediaItemChange handler: called when
  //
  // - before playing new episode => mediaItem seekPos updated
  // - new episode is loaded => mediaItem duration updated
  //
  void _handleMediaItemChange() {
    _subMediaItem = _handler.mediaItem.listen((MediaItem? mediaItem) async {
      // logDebug('logic.mediaItemChange: ${mediaItem?.title}');
      if (mediaItem != null) {
        final episodeId = mediaItem.extras!['episodeId'];
        final played = mediaItem.extras!['played'];
        final seekPos = mediaItem.extras!['seekPos'];
        final duration = mediaItem.duration;

        final episode = _getEpisodeById(episodeId);

        if (episode != null) {
          // update database
          if (played == true) {
            episode.played = true;
            episode.mediaSeekPos = 0;
            // } else if (seekPos != null || duration != null) {
            //   episode.mediaSeekPos = seekPos;
            //   episode.mediaDuration = duration?.inSeconds;
          } else {
            if (seekPos != null && seekPos > 5) {
              episode.mediaSeekPos = seekPos;
            }
            if (duration != null) {
              episode.mediaDuration = duration.inSeconds;
            }
          }
          await db.saveEpisode(episode);
          notifyListeners();
        }
      }
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
      logError(e.toString());
    }
    return res;
  }

  //
  // Handler proxies
  //
  Future<void> stop() => _handler.stop();
  Future<void> pause() => _handler.pause();
  Future<void> rewind() => _handler.rewind();
  Future<void> fastForward() => _handler.fastForward();
  Future<void> seek(Duration position) => _handler.seek(position);
  Future<void> setSpeed(double speed) async {
    await _handler.setSpeed(speed);
    notifyListeners();
  }

  Future<void> resume() async {
    if (_handler.queue.value.isNotEmpty) {
      _handler.play();
    }
  }

  Future<void> play(Episode? episode, {bool dryRun = false}) async {
    // logDebug('logic.play ${episode?.id} vs $currentEpisodeId: $dryRun');
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
          _handler.playMediaItem(episode.toMediaItem());
        }
      }
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
        DateTime.now().subtract(Duration(days: maxDataRetentionPeriod));
    final displayDate = DateTime.now()
        .subtract(Duration(days: SharedPrefsService.dataRetentionPeriod));

    for (final episode in records) {
      // remove expired episodes
      if (episode.published == null ||
          episode.published!.isBefore(expiryDate)) {
        // except liked
        if (!episode.liked) {
          // logDebug('refreshEpisode: expired ${episode.published}');
          await db.deleteEpisodeById(episode.id);
        }
      } else if (episode.published!.isAfter(displayDate)) {
        _episodes.add(episode);
      }
    }

    // logDebug('refreshEpisode: load episodes from db');
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
      // logDebug('refreshEpisode: fetch episodes from internet');
    }

    if (dirty) {
      // logDebug('refreshEpisode: dirty detected');
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
      // logDebug('sortEpisodes: $_episodes');
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
      logDebug('loque.subscribe: duplicated channel');
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
    // logDebug('logic.setPlayed: $episodeId');
    final episode = _getEpisodeById(episodeId);
    if (episode != null) {
      // set played
      episode.played = true;
      // set seek pos back to zero
      episode.mediaSeekPos = 0;
      // update database
      await db.saveEpisode(episode);
      // remove item from the queue
      await _handler.removeQueueItem(episode.toMediaItem());
      notifyListeners();
    }
  }

  //
  // Clear episode played flag
  //
  Future clearPlayed(String episodeId) async {
    // logDebug('logic.clearPlayed: $episodeId');
    final episode = _getEpisodeById(episodeId);
    if (episode != null) {
      // set unplayed
      episode.played = false;
      // set seek pos to zero
      episode.mediaSeekPos = 0;
      await db.saveEpisode(episode);
      notifyListeners();
    }
  }

  //
  // Toggle liked flag
  //
  Future toggleLiked(String? episodeId) async {
    if (episodeId is String) {
      // logDebug('logic.markLiked: $episodeId');
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
    // logDebug(_filter.name);
    notifyListeners();
  }

  //
  // Playlist(Queue) related
  //

  bool isInPlaylist(String episodeId) =>
      queue.value.indexWhere((m) => m.extras?['episodeId'] == episodeId) != -1;
  // bool isInPlaylist(String episodeId) {
  //   final index =
  //       queue.value.indexWhere((m) => m.extras?['episodeId'] == episodeId);
  //   logDebug(
  //       'isInPlaylist: $episodeId, ${queue.value.map((e) => e.id).toList()}');
  //   return index != -1;
  // }

  Future<void> addEpisodeToPlaylist(Episode episode) =>
      _handler.addQueueItem(episode.toMediaItem());

  Future<void> skipToNext() async {
    // logDebug('logic.skipToNext');
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
    // logDebug('logic.removePlaylistItemByEpisodeId');
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
