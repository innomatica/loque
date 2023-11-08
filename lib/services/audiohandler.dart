//
// IMPORTANT NOTICE:
// 1. Do not call any time consuming routines here
// 2. Distinguish usage of player.sequence vs logic.playlist
//
import 'dart:async';
import 'dart:developer';

import 'package:audio_service/audio_service.dart';
import 'package:just_audio/just_audio.dart';

import '../logic/loque.dart';
import '../models/channel.dart';
import '../models/episode.dart';

const fastForwardInterval = Duration(seconds: 30);
const rewindInterval = Duration(seconds: 30);

Future<LoqueAudioHandler> initAudioService() async {
  return await AudioService.init<LoqueAudioHandler>(
    builder: () => LoqueAudioHandler(),
    config: const AudioServiceConfig(
      androidNotificationChannelId: 'com.innomatic.loque.channel.audio',
      androidNotificationChannelName: 'Loque playback',
      androidNotificationOngoing: true,
      androidNotificationIcon: 'drawable/app_icon',
      fastForwardInterval: fastForwardInterval,
      rewindInterval: rewindInterval,
    ),
  );
}

// https://github.com/ryanheise/audio_service/blob/minor/audio_service/example/lib/main.dart
class LoqueAudioHandler extends BaseAudioHandler
    with QueueHandler, SeekHandler {
  final _player = AudioPlayer();
  late final LoqueLogic _logic;
  late final StreamSubscription _subPlayerState;
  late final StreamSubscription _subCurrentIndex;

  LoqueAudioHandler() {
    _player.playbackEventStream.map(_transformEvent).pipe(playbackState);
    // listen to playerStateStream
    _subPlayerState =
        _player.playerStateStream.listen((PlayerState state) async {
      // log('playerState: ${state.playing}  ${state.processingState}');
      if (state.processingState == ProcessingState.loading &&
          _player.currentIndex == 0) {
        // log('start of the queue');
        // broadcast initial mediaItem
        mediaItem.add(_player.sequence?[0].tag);
      } else if (state.processingState == ProcessingState.ready &&
          _player.playing) {
        _updateSeekPos(tagOnly: true);
      } else if (state.processingState == ProcessingState.completed &&
          state.playing == true) {
        // log('end of the queue');
        await stop();
        await _setPlayed(_player.currentIndex);
      }
    });
    // listen to currentIndexStream
    _subCurrentIndex = _player.currentIndexStream.listen((int? index) async {
      // log('currentIndexState: $index');
      // detecting change of media
      if (index != null &&
          index > 0 &&
          _player.processingState != ProcessingState.idle &&
          _player.processingState != ProcessingState.completed) {
        // broadcast subsequent mediaItems
        // log('new media loaded.index:$index, state:${_player.processingState}');
        // broadcast mediaItem
        mediaItem.add(_player.sequence?[index].tag);
        // set as played
        await _setPlayed(index - 1);
        // broadcast queue
        if (_player.sequence?.isNotEmpty == true) {
          queue.add(_player.sequence!.map((s) => s.tag as MediaItem).toList());
        }
      }
    });
  }

  void setLogic(LoqueLogic logic) {
    _logic = logic;
  }

  Future<void> dispose() async {
    // log('handler.dispose');
    await _subPlayerState.cancel();
    await _subCurrentIndex.cancel();
    await _player.dispose();
  }

  // Transform a just_audio event into an audio_service state.
  // https://github.com/ryanheise/audio_service/blob/minor/audio_service/example/lib/main.dart
  PlaybackState _transformEvent(PlaybackEvent event) {
    return PlaybackState(
      // buttons to appear in the notification
      controls: [
        MediaControl.rewind,
        if (_player.playing) MediaControl.pause else MediaControl.play,
        MediaControl.stop,
        MediaControl.fastForward,
      ],
      // additional actions enabled in the notification
      systemActions: const {
        MediaAction.seek,
        MediaAction.seekForward,
        MediaAction.seekBackward,
      },
      // controls to show in compact view
      androidCompactActionIndices: const [0, 1, 3],
      processingState: const {
        ProcessingState.idle: AudioProcessingState.idle,
        ProcessingState.loading: AudioProcessingState.loading,
        ProcessingState.buffering: AudioProcessingState.buffering,
        ProcessingState.ready: AudioProcessingState.ready,
        ProcessingState.completed: AudioProcessingState.completed,
      }[_player.processingState]!,
      playing: _player.playing,
      updatePosition: _player.position,
      bufferedPosition: _player.bufferedPosition,
      speed: _player.speed,
      queueIndex: event.currentIndex,
    );
  }

  @override
  Future<void> pause() async {
    // log('handler.pause');
    await _updateSeekPos();
    await _player.pause();
  }

  @override
  Future<void> play() => _player.play();

  // SeekHandler implements fastForward, rewind, seekForward, seekBackward
  @override
  Future<void> seek(Duration position) => _player.seek(position);

  @override
  Future<void> setSpeed(double speed) => _player.setSpeed(speed);

  // QueueHandler implements skipToNext, skipToPrevious
  @override
  Future<void> skipToQueueItem(int index) async {
    final currentIdx = _player.currentIndex;
    final sequence = _player.sequence;
    // validate index
    if (sequence != null &&
        index >= 0 &&
        index < (sequence.length) &&
        index != currentIdx) {
      final tag = sequence[index].tag;
      await _player.seek(Duration(seconds: tag.extras?['seekPos'] ?? 0),
          index: index);
    }
  }

  @override
  Future<void> stop() async {
    // log('handler.stop');
    await _updateSeekPos();
    await _player.stop();
  }

  @override
  Future<void> addQueueItem(MediaItem mediaItem) async {
    // log('handler.addQueueItem: ${mediaItem.title}');
    _logic.playlistAdd(mediaItem);
    await _updateSeekPos();
    // no changes in the currentIndex
    await _updateAudioSource(initialIndex: _player.currentIndex ?? 0);
  }

  @override
  Future<void> insertQueueItem(int index, MediaItem mediaItem) async {
    // log('handler.insertQueueItem: $index, ${mediaItem.id}');
    _logic.playlistInsert(index, mediaItem);
    await _updateSeekPos();
    int currentIdx = _player.currentIndex ?? 0;
    if (index < currentIdx) {
      // inserted above => episode at the next index (current episode) will be played
      await _updateAudioSource(initialIndex: currentIdx + 1);
    } else {
      // inserted below => episode at the current index will be played
      await _updateAudioSource(initialIndex: currentIdx);
    }
  }

  @override
  Future<void> removeQueueItem(MediaItem mediaItem) async {
    // log('handler.removeQueueItem: ${mediaItem.id}');
    final playlist = _logic.playlist;
    final index = playlist.indexWhere(
        (m) => m.extras?['episodeId'] == mediaItem.extras?['episodeId']);
    if (index != -1) {
      await removeQueueItemAt(index);
    }
  }

  @override
  Future<void> removeQueueItemAt(int index) async {
    // log('handler.removeQueueItemAt: $index');
    // remove item from the playlist
    if (_logic.playlistRemoveAt(index) != null) {
      // save current seek position
      await _updateSeekPos();
      int currentIdx = _player.currentIndex ?? 0;
      int initialIdx = 0;
      if (index >= currentIdx) {
        // future episode deleted => current episode isn't affected
        initialIdx = currentIdx < _logic.playlist.length
            ? currentIdx
            : _logic.playlist.length - 1;
      } else {
        // previous episode deleted => current episode was moved up
        initialIdx = currentIdx > 0 ? currentIdx - 1 : 0;
      }
      await _updateAudioSource(initialIndex: initialIdx);
    }
  }

  @override
  Future playMediaItem(MediaItem mediaItem) async {
    // log('handler.playMediaItem: ${mediaItem.extras?["episodeId"]}');
    final currentEpisodeId = getCurrentEpisodeId();
    if (currentEpisodeId == mediaItem.extras?["episodeId"]) {
      // asking the same episode as current one
      if (!_player.playing) {
        // presumably paused episode => resume play
        // log('play: restarting paused audio or first start');
        // report episode to the logic => NO NEED
        await play();
      } else {
        // currently playing => pause
        await pause();
      }
    } else {
      // new episode
      await stop();
      _logic.playlistPurge();
      _logic.playlistInsert(0, mediaItem);
      await _updateAudioSource(start: true);
    }
  }

  // media size in seconds
  Duration get duration => _player.duration ?? Duration.zero;
  Stream<Duration> get positionStream => _player.positionStream;
  Stream<bool> get playingStream => _player.playingStream;

  Future<void> _updateAudioSource({
    int initialIndex = 0,
    Duration? initialPosition,
    bool start = false,
  }) async {
    final playlist = _logic.playlist;
    // validate initialIndex
    initialIndex =
        initialIndex < 0 || initialIndex >= playlist.length ? 0 : initialIndex;
    // TODO: played check should be done somewhere else
    if (playlist.isEmpty || playlist[initialIndex].extras?['played'] == true) {
      // log('playlist is empty or current episode is played');
      // update queue
      queue.add([]);
      // stop player unconditionally
      await stop();
    } else {
      // set audio source with the playlist
      await _player.setAudioSource(
        ConcatenatingAudioSource(
            children: playlist
                .map((m) => AudioSource.uri(Uri.parse(m.id), tag: m))
                .toList()),
        preload: false,
        initialIndex: initialIndex,
        initialPosition: initialPosition ??
            Duration(seconds: playlist[initialIndex].extras?['seekPos'] ?? 0),
      );
      // update queue
      queue.add(playlist);
      // start player if required
      if (start && !_player.playing) {
        await _player.play();
      }
    }
  }

  //
  // Update seek position
  //
  Future _updateSeekPos({bool tagOnly = false}) async {
    // log('handler._updateSeekPos');
    final tag = getCurrentTag();
    if (tag != null) {
      // this is for internal use
      tag.extras?['seekPos'] = _player.position.inSeconds;
      // TODO: utlize tag for seekPos
      if (!tagOnly) {
        // this is for to database
        final episodeId = tag.extras?['episodeId'];
        if (episodeId is String) {
          await _logic.updateSeekPos(episodeId, _player.position.inSeconds);
        }
      }
    }
  }

  //
  // Get current media tag from the player sequence
  //
  MediaItem? getCurrentTag() {
    if (_player.sequence?.isNotEmpty == true &&
        _player.currentIndex != null &&
        _player.currentIndex! >= 0 &&
        _player.currentIndex! < _player.sequence!.length) {
      return _player.sequence![_player.currentIndex!].tag as MediaItem;
    }
    return null;
  }

  //
  // Get current epsisode id
  //
  String? getCurrentEpisodeId() {
    final tag = getCurrentTag();
    return tag?.extras?['episodeId'];
  }

  //
  // Get current episode
  //
  Episode? getCurrentEpisode() {
    final episodeId = getCurrentEpisodeId();
    if (episodeId is String) {
      try {
        return _logic.getEpisodeById(episodeId);
      } catch (e) {
        log(e.toString());
        return null;
      }
    }
    return null;
  }

  //
  // Get queue as a list of MediaItems
  //
  List<MediaItem> getQueue() {
    final res = <MediaItem>[];
    if (_player.sequence?.isNotEmpty == true) {
      res.addAll(_player.sequence!.map((e) => e.tag as MediaItem).toList());
    }
    return res;
  }

  //
  // Subscribe to a channel
  //
  Future subscribe(Channel channel) async {
    await _logic.subscribe(channel);
  }

  //
  // Unsubscribe from a channel
  //
  Future unsubscribe(Channel channel) async {
    await _logic.unsubscribe(channel);

    await _updateSeekPos();
    // find unaffected episode from remaining playlist
    List<MediaItem> playlist = _logic.playlist;
    final currentIdx = _player.currentIndex ?? 0;
    String? episodeId;
    final nextIdx = playlist
        .sublist(currentIdx)
        .indexWhere((m) => m.extras?['channelId'] != channel.id);
    if (nextIdx != -1) {
      episodeId = playlist[nextIdx].extras?['episodeId'];
    }
    // remove all affected episodes
    playlist = _logic.playlistRemoveByChannelId(channel.id);
    // find index of the media to play
    final initialIndex =
        playlist.indexWhere((m) => m.extras?['episodeId'] == episodeId);
    await _updateAudioSource(initialIndex: initialIndex);
  }

  //
  // Reorder playlist
  //
  Future reorderQueue(int oldIndex, int newIndex) async {
    final currentIndex = _player.currentIndex ?? 0;
    // log('handler.reorderPlaylist: $oldIndex, $newIndex, $currentIndex');
    // do not allow reorder if current media is to be affected
    if (oldIndex > currentIndex && newIndex > currentIndex) {
      await _updateSeekPos();
      _logic.playlistReorder(oldIndex, newIndex);
      await _updateAudioSource(initialIndex: currentIndex);
    }
  }

  //
  // Mark episode played: User interaction
  //
  Future markPlayed(String episodeId) async {
    final currentIndex = _player.currentIndex ?? 0;
    final sequence = _player.sequence ?? <IndexedAudioSource>[];
    final index =
        sequence.indexWhere((e) => e.tag.extras?['episodeId'] == episodeId);
    // log('handler.markPlayed: $currentIndex, $index');
    if (index == -1) {
      // not in the sequence
      await _logic.setPlayed(episodeId);
    } else {
      // in the sequence
      // FIXME: this does not work unless it is skipped automatically
      // when actually played
      // use removeMediaItemAt instead
      await _setPlayed(index);
      if (currentIndex == index) {
        if (sequence.length > (index + 1)) {
          await skipToNext();
        } else {
          await _player.stop();
        }
      }
    }
  }

  Future _setPlayed(int? index) async {
    final sequence = _player.sequence ?? <IndexedAudioSource>[];
    if (index != null && index >= 0 && index < sequence.length) {
      // this is for internal use
      final tag = sequence[index].tag;
      tag.extras?['played'] = true;
      // this is for database
      await _logic.setPlayed(tag.extras?['episodeId']);
    }
  }

  //
  // Clear played marker
  //
  Future markUnplayed(String episodeId) async {
    final currentId = getCurrentEpisodeId();
    // if it is the current one
    if (currentId == episodeId) {
      // assume that user does not want to play current episode
      await _player.pause();
      // rewind to the beginning
      await _player.seek(Duration.zero);
    }
    await _logic.setUnplayed(episodeId);
  }

  //
  // Toggle liked flag
  //
  Future<void> toggleLiked(String episodeId) => _logic.toggleLiked(episodeId);
}
