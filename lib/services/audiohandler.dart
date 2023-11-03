//
// IMPORTANT NOTICE:
// 1. Do not call any time consuming routines here
// 2. Call _updateSeekPos() before any changes in the _player.sequence
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
    _subPlayerState = _player.playerStateStream.listen((PlayerState state) {
      // log('playerState: ${state.playing}  ${state.processingState}');
      if (state.processingState == ProcessingState.loading &&
          _player.currentIndex == 0) {
        // broadcast initial mediaItem
        mediaItem.add(_player.sequence?[0].tag);
      } else if (state.processingState == ProcessingState.completed) {
        // end of the queue
        stop();
      }
    });
    // listen to currentIndexStream
    _subCurrentIndex = _player.currentIndexStream.listen((int? index) async {
      // log('currentIndexState: $index');
      // detecting change of media
      if (index != null &&
          index >= 0 &&
          _player.processingState != ProcessingState.idle &&
          _player.processingState != ProcessingState.completed) {
        // broadcast subsequent mediaItems
        // log('new media loaded');
        mediaItem.add(_player.sequence?[index].tag);
        // set as played
        _setPlayed(index - 1);
      }
    });
  }

  Future<void> dispose() async {
    log('handler.dispose');
    _subPlayerState.cancel();
    _subCurrentIndex.cancel();
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
  Future<void> play() => _player.play();

  @override
  Future<void> pause() async {
    log('handler.pause');
    await _updateSeekPos();
    await _player.pause();
  }

  @override
  Future<void> setSpeed(double speed) => _player.setSpeed(speed);

  @override
  Future<void> stop() async {
    log('handler.stop');
    await _updateSeekPos();
    await _player.stop();
    // clear queue for playlist
    // queue.add([]);
  }

  //
  // SeekHandler
  // default implementations: fastForward, rewind, seekForward, seekBackward
  //
  @override
  Future<void> seek(Duration position) => _player.seek(position);

  // TODO: save before seek: is this unnecessary?
  /*
  // Future<void> seek(Duration position) async {
  //   log('handler.seek');
  //   await _updateSeekPos();
  //   await _player.seek(position);
  // }

  @override
  Future<void> rewind() async {
    log('handler.rewind');
    await _updateSeekPos();
    if (rewindInterval < _player.position) {
      await _player.seek(_player.position - rewindInterval);
    } else {
      await _player.seek(Duration.zero);
    }
  }

  @override
  Future<void> fastForward() async {
    log('handler.fastForward');
    await _updateSeekPos();
    if (_player.duration != null &&
        (_player.position + fastForwardInterval) > _player.duration!) {
      await _player.seek(_player.duration);
    } else {
      await _player.seek(_player.position + fastForwardInterval);
    }
  }
  */

  //
  // QueueHandler
  // default implementations: skipToNext, skipToPrevious
  //
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

  // @override
  // Future<void> skipToNext() async {}

  // @override
  // Future<void> skipToPrevious() async {}

  @override
  Future<void> addQueueItem(MediaItem mediaItem) async {
    log('handler.addQueueItem: ${mediaItem.id}');
    // take current sequence
    final sequence = _player.sequence ?? <IndexedAudioSource>[];
    // check if the item is in the sequence
    final found = sequence.indexWhere((s) => s.tag.id == mediaItem.id);
    if (found == -1) {
      // save current seek position
      await _updateSeekPos();
      // append item to the sequence
      sequence.add(AudioSource.uri(Uri.parse(mediaItem.id), tag: mediaItem));
      // reset audio source
      await _setAudioSource(sequence,
          initialIndex: _player.currentIndex ?? 0,
          initialPosition: _player.position);
    }
  }

  @override
  Future<void> insertQueueItem(int index, MediaItem mediaItem) async {
    log('handler.insertQueueItem: $index, ${mediaItem.id}');
    // current sequence
    final sequence = _player.sequence ?? <IndexedAudioSource>[];
    // check if the item is already in the sequence
    final found = sequence.indexWhere((s) => s.tag.id == mediaItem.id);
    if (found == -1) {
      // insert item to the sequence if necessary
      sequence.insert(
          index, AudioSource.uri(Uri.parse(mediaItem.id), tag: mediaItem));
      // save current seek position
      await _updateSeekPos();
      int currentIdx = _player.currentIndex ?? 0;
      if (index < currentIdx) {
        // inserted above => episode at the next index (current episode) will be played
        await _setAudioSource(sequence, initialIndex: currentIdx + 1);
      } else {
        // inserted below => episode at the current index will be played
        await _setAudioSource(sequence, initialIndex: currentIdx);
      }
    }
  }

  @override
  Future<void> removeQueueItemAt(int index) async {
    log('handler.removeQueueItemAt: $index');
    // save current seek position
    await _updateSeekPos();
    // take current sequence
    final sequence = _player.sequence ?? <IndexedAudioSource>[];
    // index must be in the valid range
    if (index >= 0 && index < sequence.length) {
      // remove the item from the sequence
      sequence.removeAt(index);
      // save current seek position
      await _updateSeekPos();
      int currentIdx = _player.currentIndex ?? 0;
      if (index > currentIdx) {
        // future episode deleted => episode at the current index will be played
        await _setAudioSource(sequence, initialIndex: currentIdx);
      } else {
        // episode at the previous index (current episode) will be played
        await _setAudioSource(sequence, initialIndex: currentIdx - 1);
      }
    }
  }

  // media size in seconds
  Duration get duration => _player.duration ?? Duration.zero;
  Stream<Duration> get positionStream => _player.positionStream;

  void setLogic(LoqueLogic logic) {
    _logic = logic;
  }

  Future<void> _setAudioSource(
    List<IndexedAudioSource> sequence, {
    int? initialIndex,
    Duration? initialPosition,
    bool start = false,
  }) async {
    bool wasPlaying = _player.playing;
    // log('_setAudioSource ------>');
    // sequence.forEach((s) => log(s.tag.title));
    // log('<----');
    // be sure to stop player before setAudioSource call
    _player.stop();
    if (sequence.isEmpty) {
      // empty sequence should not be used for _player.setAudioSource
      queue.add([]);
    } else {
      await _player.setAudioSource(
        ConcatenatingAudioSource(children: sequence),
        preload: false,
        initialIndex: initialIndex ?? 0,
        initialPosition: initialPosition ??
            Duration(
              seconds: sequence[initialIndex ?? 0].tag.extras?['seekPos'] ?? 0,
            ),
      );
      // update queue
      queue.add(sequence.map((s) => s.tag as MediaItem).toList());
      // previously playing or force to start?
      if (wasPlaying || start) {
        // then back to playing
        _player.play();
      }
    }
  }

  //
  // Update seek position
  //
  Future _updateSeekPos() async {
    log('handler._updateSeekPos');
    final tag = getCurrentTag();
    if (tag != null) {
      // this is for internal use
      tag.extras?['seekPos'] = _player.position.inSeconds;
      // this is for to database
      final episodeId = tag.extras?['episodeId'];
      if (episodeId is String) {
        await _logic.updateSeekPos(episodeId, _player.position.inSeconds);
      }
    }
  }

  //
  // Get current media tag from the player sequence
  //
  MediaItem? getCurrentTag() {
    if (_player.sequence != null &&
        _player.currentIndex != null &&
        _player.currentIndex! > -1 &&
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
  // Play episode: user deliverately chose an episode to play
  //
  Future playEpisode(Episode episode, {bool dryRun = false}) async {
    log('handler.playEpisode: ${episode.id}');
    final currentEpisodeId = getCurrentEpisodeId();
    if (currentEpisodeId == episode.id) {
      // asking the same episode as current one
      if (!_player.playing) {
        // presumably paused episode => resume play
        log('play: restarting paused audio or first start');
        // report episode to the logic => NO NEED
        await _player.play();
      }
    } else {
      // new episode
      await _updateSeekPos();
      final sequence = _player.sequence ?? <IndexedAudioSource>[];
      // remove all previous dryRun
      sequence.removeWhere((s) => s.tag.extras?['dryRun'] == true);
      // remove all played episode
      sequence.removeWhere((s) => s.tag.extras?['played'] == true);
      // check if the episode is in the sequence
      final index =
          sequence.indexWhere((s) => s.tag.extras?['episodeId'] == episode.id);
      // int seekPos;
      if (index == -1) {
        // episode is not in the sequence => prepend
        sequence.insert(0, episode.getAudioSource());
      } else {
        // episode is in the sequence => reorder
        final target = sequence.removeAt(index);
        sequence.insert(0, target);
      }
      // tag dryRun to the current item
      if (dryRun) {
        sequence[0].tag.extras?['dryRun'] = true;
      }
      await _setAudioSource(sequence, start: true);
    }
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
    final tag = getCurrentTag();
    await _logic.unsubscribe(channel);
    // check if current episode is affected
    if (_player.playing && tag?.extras?['channelId'] == channel.id) {
      // pause first so the player remains paused
      await _player.pause();
    }
    final sequence = _player.sequence;
    // check if affected episodes are on the sequence
    if (sequence?.isNotEmpty == true &&
        sequence!.any((s) => s.tag.extras['channelId'] == channel.id)) {
      // save current seek position
      await _updateSeekPos();
      // remove them from the sequence
      sequence.removeWhere((s) => s.tag.extras['channelId'] == channel.id);
      // FIXME: do something
      _setAudioSource(sequence);
    }
  }

  //
  // Reorder playlist
  //
  Future reorderQueue(int oldIndex, int newIndex) async {
    log('handler.reorderPlaylist: $oldIndex, $newIndex');
    // take current sequence
    final sequence = _player.sequence ?? <IndexedAudioSource>[];
    // index must be in the valid range
    if (oldIndex >= 0 &&
        newIndex >= 0 &&
        oldIndex < sequence.length &&
        newIndex < sequence.length) {
      // save current seek
      await _updateSeekPos();
      // reorder sequence
      final target = sequence.removeAt(oldIndex);
      sequence.insert(newIndex, target);
      // FIXME: do something
      await _setAudioSource(sequence);
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
    log('handler.markPlayed: $currentIndex, $index');
    await _setPlayed(index);
    if (currentIndex == index) {
      if (sequence.length > (index + 1)) {
        await skipToNext();
      } else {
        await _player.stop();
      }
    }
    // remove it from the queue ? => don't do this: it will confuse the logic
    // await removeQueueItemAt(index);
  }

  Future _setPlayed(int index) async {
    final sequence = _player.sequence ?? <IndexedAudioSource>[];
    if (index >= 0 && index < sequence.length) {
      // this is for internal use
      final tag = sequence[index].tag;
      tag.extras?['played'] = true;
      // this is for database
      _logic.setPlayed(tag.extras?['episodeId']);
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

  void _printSequence() {
    log('_printSequence-------------->');
    _player.sequence?.forEach((s) => log(s.tag.title));
    log('<----------------------');
  }
}
