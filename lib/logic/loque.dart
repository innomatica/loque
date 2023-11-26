import 'package:audio_service/audio_service.dart';
import 'package:flutter/material.dart';
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

  LoqueLogic() {
    _initData();
  }

  @override
  void dispose() {
    db.close();
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

  void _initData() async {
    // _loadPlaylist();
    await _loadChannels();
    await refreshEpisodes();
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
// Sort episodes by the published date
//
  void sortEpisodes() {
    // sort by published
    _episodes.sort((a, b) =>
        (b.published?.millisecondsSinceEpoch ?? 0) -
        (a.published?.millisecondsSinceEpoch ?? 0));
  }

  int getEpisodeSeekPos(String? episodeId) {
    final index = _episodes.indexWhere((e) => e.id == episodeId);
    return index == -1 ? 0 : _episodes[index].mediaSeekPos ?? 0;
  }

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
      } else if (channel.source == PodcastSource.rss &&
          channel.link is String) {
        // get episodes from rss doc
        res = await getEpisodesFromRssChannel(channel, daysSince: daysSince);
      }
    } catch (e) {
      debugPrint(e.toString());
    }
    return res;
  }

  //
  // get Episode data from the episode list
  //
  Episode getEpisodeById(String episodeId) =>
      _episodes.firstWhere((e) => e.id == episodeId);

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
  // Update seek position
  //
  Future updateSeekPos(String episodeId, int seekPos) async {
    // ignore if seek postion is too close to the beginning
    if (seekPos > 5) {
      final index = _episodes.indexWhere((e) => e.id == episodeId);
      if (index != -1) {
        _episodes[index].mediaSeekPos = seekPos;
        await db.saveEpisode(_episodes[index]);
      }
      notifyListeners();
    }
  }

  //
  // Set episode played
  //
  Future setPlayed(String? episodeId) async {
    if (episodeId is String) {
      // debugPrint('logic.setPlayed: $episodeId');
      final episode = getEpisodeById(episodeId);
      // set played
      episode.played = true;
      // set seek pos to zero again
      episode.mediaSeekPos = 0;
      await db.saveEpisode(episode);

      // // remove id from the playlist
      // final flag = _plistids.remove(episodeId);
      // if (flag) {
      //   // save playlist if necessary
      //   await _savePlaylistIds();
      // }
      notifyListeners();
    }
  }

  //
  // Set episode unplayed
  //
  Future setUnplayed(String? episodeId) async {
    if (episodeId is String) {
      // debugPrint('logic.setUnplayed: $episodeId');
      final episode = getEpisodeById(episodeId);
      // set unplayed
      episode.played = false;
      // set seek pos to zero again
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
      // debugPrint('logic.markLiked: $episodeId');
      final episode = getEpisodeById(episodeId);
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
