import 'dart:async';

import 'package:audio_service/audio_service.dart';
import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:loqueapp/services/audiohandler.dart';
import 'package:loqueapp/services/sharedprefs.dart';
import 'package:loqueapp/settings/constants.dart';

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
  final _playlist = <MediaItem>[];

  late final LoqueAudioHandler _handler;
  late final StreamSubscription _subPlayerState;

  LoqueLogic(LoqueAudioHandler handler) {
    _handler = handler;
    _init();
  }

  @override
  void dispose() async {
    db.close();

    await _subPlayerState.cancel();
    _handler.dispose();
    super.dispose();
  }

  List<Channel> get channels => _channels;
  List<Episode> get episodes => _filter == EpisodeFilter.unplayed
      ? _episodes.where((e) => e.played == false).toList()
      : _filter == EpisodeFilter.liked
          ? _episodes.where((e) => e.liked == true).toList()
          : _episodes;
  List<MediaItem> get playlist => _playlist;
  EpisodeFilter get filter => _filter;

  // handler and its properties
  LoqueAudioHandler get handler => _handler;
  String? get currentEpisodeId => _handler.currentEpisodeId;
  AudioSource? get audioSource => _handler.audioSource;
  // other handler proxies
  Future<void> pause() => _handler.pause();
  Future<void> stop() => _handler.stop();

  void _init() async {
    //
    // DO NOT CALL _player functions here such as seek, which may throw
    // exceptions by creating events inside an event handler
    //
    // playing    processing   state
    // --------------------------------
    // false      idle         initialized, not playing, between media switching
    // false      loading      media loading: update index
    // false      ready        media loaded, paused: update position
    // true       ready        start to play: update duration
    // true       completed    completed: set completed
    // false      completed    has been completed
    //
    // start playing media
    // (false,idle) => (false,loading) => (false,ready) => (true,ready)
    //
    // stop at the end
    // (true,completed) => (false,completed)
    //
    // pause
    // (true,ready) => (false,ready)
    //
    // resume
    // (false,ready) => (true,ready)
    //
    // media switching
    // (true,ready) => (false,ready) => (false,idle) => (false,loading) => (false,ready) => (true,ready)
    //
    // seek
    // (true,ready) => (true,buffering) => (true,ready)

    // listen to playerStateStream
    _subPlayerState =
        _handler.playerStateStream.distinct().listen((PlayerState state) async {
      // debugPrint(
      //     '\n\t====> playerState: ${state.playing}  ${state.processingState}\n');
      if (state.processingState == ProcessingState.loading) {
        // media is being loaded: state.playing must be false
        // currentIndex becomes valid
      } else if (state.processingState == ProcessingState.ready) {
        // media is ready
        if (state.playing) {
          // play started
          // _onTrueAndReady();
        } else {
          // not started yet (so the duration may not be correct) or paused
          // _onFalseAndReady();
        }
      } else if (state.processingState == ProcessingState.completed) {
        // endo of playing note that occurs twice in succession, one with
        // playing=true then followed by playing=false: choose the former
        if (state.playing) {
          // _onTrueAndCompleted();
        }
      }
    });

    // _loadPlaylist();
    await _loadChannels();
    await refreshEpisodes();
  }

  //
  // player.playing = true && processingState = ready
  //
  // called when:
  //   - start a new episode
  //   - resume playing from pause or after seek
  //
  Future _onTrueAndReady() async {
    // FIXME: validate the timing of currentEpisodeId
    debugPrint('_onTrueAndReady: $currentEpisodeId, ${_handler.duration}');
    if (currentEpisodeId != null) {
      final index = _episodes.indexWhere((e) => e.id == currentEpisodeId);
      if (index != -1) {
        // update media duration
        _episodes[index].mediaDuration = _handler.duration.inSeconds;
        // update last played
        _episodes[index].lastPlayed = DateTime.now();
        await db.saveEpisode(_episodes[index]);
        // reorder episodes
        sortEpisodes();
        notifyListeners();
      }
    }
  }

  //
  // player.playing = false && processingState = ready
  //
  // called when:
  //   - after media loaded
  //   - paused
  //   - the first stage of media switching
  //
  Future _onFalseAndReady() async {
    // FIXME: validate the timing of currentEpisodeId
    debugPrint('_onFalseAndReady: $currentEpisodeId, ${_handler.position}');
    if (currentEpisodeId != null) {
      if (_handler.position.inSeconds > 5) {
        final index = _episodes.indexWhere((e) => e.id == currentEpisodeId);
        if (index != -1) {
          // update position
          _episodes[index].mediaSeekPos = _handler.position.inSeconds;
          await db.saveEpisode(_episodes[index]);
          notifyListeners();
        }
      }
    }
  }

  //
  // player.playing = true && processingState = completed
  //
  // called when:
  //   - right after media completed and before actually stopped
  //
  _onTrueAndCompleted() {
    // FIXME: validate the timing of currentEpisodeId
    debugPrint('_onTrueAndCompleted: $currentEpisodeId');
    if (currentEpisodeId != null) {
      markPlayed(currentEpisodeId!);
    }
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
  Episode _getEpisodeById(String episodeId) =>
      _episodes.firstWhere((e) => e.id == episodeId);

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

  Future<void> playEpisode(Episode episode) async {
    // FIXME: validate the timing of currentEpisodeId
    if (currentEpisodeId == episode.id) {
      // currently playing or paused
      _handler.playing ? _handler.pause() : _handler.play();
    } else {
      // new episode
      debugPrint('playing new episode');
      // await _handler.pause();
      _handler.playMediaItem(episode.toMediaItem());
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
    notifyListeners();

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
      notifyListeners();

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
  void sortEpisodes({bool notify = false}) {
    _episodes.sort((a, b) {
      if ((a.mediaSeekPos ?? 0) > 0) {
        if ((b.mediaSeekPos ?? 0) > 0) {
          // both have been played
          return (b.lastPlayed?.millisecondsSinceEpoch ?? 0) -
              (a.lastPlayed?.millisecondsSinceEpoch ?? 0);
        } else {
          return -1;
        }
      } else {
        if ((b.mediaSeekPos ?? 0) > 0) {
          return 1;
        } else {
          // both haven't been played
          return (b.published?.millisecondsSinceEpoch ?? 0) -
              (a.published?.millisecondsSinceEpoch ?? 0);
        }
      }
    });
    // _episodes.sort((a, b) =>
    //     (b.published?.millisecondsSinceEpoch ?? 0) -
    //     (a.published?.millisecondsSinceEpoch ?? 0));
    if (notify) {
      debugPrint('sortEpisodes: $_episodes');
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

      notifyListeners();
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
    notifyListeners();
  }

  //
  // Mark episode played: User interaction
  //
  Future markPlayed(String episodeId) async {
    // FIXME: validate the timing of currentEpisodeId
    // the episide is currently playing
    if (currentEpisodeId == episodeId && _handler.playing) {
      // assume that user is done
      await _handler.pause();
    }
    // debugPrint('logic.setPlayed: $episodeId');
    final episode = _getEpisodeById(episodeId);
    // set played
    episode.played = true;
    // set seek pos back to zero
    episode.mediaSeekPos = 0;
    await db.saveEpisode(episode);
    notifyListeners();
  }

  //
  // Clear played marker
  //
  Future markUnplayed(String episodeId) async {
    // FIXME: validate the timing of currentEpisodeId
    // if the episode is currently playing
    if (currentEpisodeId == episodeId) {
      // assume that user does not want to play current episode
      await _handler.pause();
      // rewind to the beginning
      await _handler.seek(Duration.zero);
    }

    final episode = _getEpisodeById(episodeId);
    // set unplayed
    episode.played = false;
    // set seek pos to zero
    episode.mediaSeekPos = 0;
    await db.saveEpisode(episode);
    notifyListeners();
  }

  //
  // Toggle played marker
  //
  Future togglePlayed(Episode episode) =>
      episode.played ? markUnplayed(episode.id) : markPlayed(episode.id);

  //
  // Toggle liked flag
  //
  Future toggleLiked(String? episodeId) async {
    if (episodeId is String) {
      // debugPrint('logic.markLiked: $episodeId');
      final episode = _getEpisodeById(episodeId);
      // toggle liked
      episode.liked = !episode.liked;
      await db.saveEpisode(episode);
      notifyListeners();
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

  void addToPlaylist(Episode episode) {}

  //
  // Playlist
  //
  void playlistAdd(MediaItem item) {
    if (!_playlist.any((m) => m.id == item.id)) {
      _playlist.add(item);
      notifyListeners();
    }
  }

  void playlistInsert(int index, MediaItem item) {
    MediaItem target = item;
    int index = _playlist.indexWhere((m) => m.id == item.id);
    // already in the list?
    if (index != -1) {
      // replace the item with existing one
      target = _playlist.removeAt(index);
    }
    _playlist.insert(0, target);
    notifyListeners();
  }

  MediaItem? playlistRemoveAt(int index) {
    MediaItem? target;
    if (index >= 0 && index < _playlist.length) {
      target = _playlist.removeAt(index);
      notifyListeners();
    }
    return target;
  }

  MediaItem? playlistRemove(MediaItem item) {
    MediaItem? target;
    final index = _playlist.indexWhere((m) => m.id == item.id);
    if (index != -1) {
      target = _playlist.removeAt(index);
      notifyListeners();
    }
    return target;
  }

  List<MediaItem> playlistRemoveByChannelId(String channelId) {
    _playlist.removeWhere((m) => m.extras?['channelId'] == channelId);
    notifyListeners();
    return _playlist;
  }

  bool playlistReorder(int oldIndex, int newIndex) {
    if (oldIndex >= 0 &&
        newIndex >= 0 &&
        oldIndex < _playlist.length &&
        newIndex < _playlist.length) {
      final target = _playlist.removeAt(oldIndex);
      _playlist.insert(newIndex, target);
      notifyListeners();
      return true;
    }
    return false;
  }

  void playlistPurge({bool silently = true}) {
    // move garbages
    playlist.removeWhere(
        (m) => m.extras?['played'] == true || m.extras?['dryRun'] == true);
    if (!silently) {
      notifyListeners();
    }
  }
}
