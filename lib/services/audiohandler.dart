import 'dart:async';

import 'package:audio_service/audio_service.dart';
import 'package:just_audio/just_audio.dart';

import '../helpers/logger.dart';

const fastForwardInterval = Duration(seconds: 30);
const rewindInterval = Duration(seconds: 30);

Future<LoqueAudioHandler> initAudioService() async {
  return await AudioService.init<LoqueAudioHandler>(
    builder: () => LoqueAudioHandler(),
    config: const AudioServiceConfig(
      androidNotificationChannelId: 'com.innomatic.loque.channel.audio',
      androidNotificationChannelName: 'Loque playback',
      androidNotificationOngoing: true,
      // this will keep the foreground on during pause
      // check: https://pub.dev/packages/audio_service
      // androidStopForegroundOnPause: false,
      androidStopForegroundOnPause: true,
      androidNotificationIcon: 'drawable/app_icon',
      fastForwardInterval: fastForwardInterval,
      rewindInterval: rewindInterval,
    ),
  );
}

// https://pub.dev/packages/audio_service
class LoqueAudioHandler extends BaseAudioHandler
    with QueueHandler, SeekHandler {
  final _player = AudioPlayer();
  StreamSubscription? _subDuration;
  StreamSubscription? _subPlyState;
  StreamSubscription? _subCurIndex;
  StreamSubscription? _subBuffered;

  // String? _episodeId;

  LoqueAudioHandler() {
    _init();
  }

  Future _init() async {
    // expose _player.playbackEvent stream as plabackState stream
    _player.playbackEventStream.map(_transformEvent).pipe(playbackState);
    // start with empty list of audio source
    await _player.setAudioSource(ConcatenatingAudioSource(children: []));
    queue.add([]);
    // stream subscriptions
    _handleDurationChange();
    _handlePlyStateChange();
    _handleCurIndexChange();
    _handleBufferedChange();
  }

  Future<void> dispose() async {
    await _subDuration?.cancel();
    await _subPlyState?.cancel();
    await _subCurIndex?.cancel();
    await _subBuffered?.cancel();
    await _player.stop();
    await _player.dispose();
  }

  void _handleDurationChange() {
    // subscribe to the duration change
    _subDuration = _player.durationStream.listen((Duration? duration) {
      final index = _player.currentIndex;
      final sequence = _player.sequence;
      if (index != null && sequence != null && index < sequence.length) {
        final item = sequence[index].tag as MediaItem;
        // broadcast mediaItem with updated duration
        mediaItem.add(item.copyWith(duration: duration));
      }
      /* AVOID USING queue and mediaItem
      final qval = queue.value;
      if (index != null && index >= 0 && index < qval.length) {
        final item = qval[index];
        // broadcast mediaItem with updated duration
        mediaItem.add(item.copyWith(duration: duration));
      }
      */
    });
  }

  void _handlePlyStateChange() {
    _subPlyState = _player.playerStateStream.listen((PlayerState state) async {
      logDebug('handlePlyStateChange: $state');
      if (state.processingState == ProcessingState.ready) {
        if (state.playing == false) {
          // about to start playing or paused
          // final item = mediaItem.value;
          // if (item != null) {
          //   // keep the current position
          //   item.extras!['seekPos'] = _player.position.inSeconds;
          //   // report change
          //   mediaItem.add(item);
          // }
          _updateSeekPos();
        }
      } else if (state.processingState == ProcessingState.completed) {
        // NOTE (playing, completed) may or MAY NOT be followed by (not playing, complted)
        if (state.playing) {
          // end of playing queue: be sure not to use (state.playing==false)
          await stop();
          // clear queue
          if (queue.value.isNotEmpty) {
            await clearQueue();
          }
        }
      }
    });
  }

  void _handleCurIndexChange() {
    _subCurIndex = _player.currentIndexStream.listen((int? index) {
      logDebug('handleCurIndex.index: $index');
      final sequence = _player.sequence;
      if (sequence != null) {
        // update the queue with the sequence
        queue.add(sequence.map((s) => s.tag as MediaItem).toList());
      }
    });
  }

  void _handleBufferedChange() {
    _subBuffered = _player.bufferedPositionStream.listen((Duration position) {
      logDebug('handleBuffered.pos: ${position.inSeconds}');
      // buffered position sufficiently reaches to the end (duration)
      if (_player.duration != null &&
          (_player.duration!.inSeconds - 10) < position.inSeconds) {
        // update the audio source so that it will be broadcasted later
        _updatePlayed(_player.currentIndex, true);
      }
    });
  }

  // Transform a just_audio event into an audio_service state.
  // https://pub.dev/documentation/audio_service/latest/audio_service/PlaybackState-class.html
  // https://github.com/ryanheise/audio_service/blob/minor/audio_service/example/lib/main.dart
  PlaybackState _transformEvent(PlaybackEvent event) {
    return PlaybackState(
      // buttons to appear in the notification
      controls: [
        MediaControl.rewind,
        if (_player.playing) MediaControl.pause else MediaControl.play,
        // MediaControl.stop,
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

  // expose player properties: used by logic
  bool get playing => _player.playing;
  // Duration get position => _player.position;
  Duration get duration => _player.duration ?? Duration.zero;
  Stream<Duration> get positionStream => _player.positionStream;

  // implement basic features
  @override
  Future<void> play() => _player.play();
  @override
  Future<void> pause() => _player.pause();
  @override
  Future<void> stop() => _player.stop();

  @override
  Future<void> setSpeed(double speed) => _player.setSpeed(speed);

  @override
  // ignore: avoid_renaming_method_parameters
  Future<void> playMediaItem(MediaItem newItem) async {
    // logDebug('playMediaItem: $newItem');
    final audioSource = _player.audioSource as ConcatenatingAudioSource;
    // first we need to save current position if currently playing
    if (_player.playing) {
      _updateSeekPos();
    }
    // then reorder audioSource if requred
    final index = audioSource.children
        .indexWhere((c) => (c as UriAudioSource).tag.id == newItem.id);
    // current index: Warning do not completely trust this value
    final targetIdx = _player.currentIndex ?? 0;
    // if the mediaItem is in the queue remove it from the queue
    if (index >= 0 && index < audioSource.length) {
      // we remove the media from its original position
      // logDebug('remove the item from $index');
      await audioSource.removeAt(index);
    }
    // insert the mediaItem into the current position
    // logDebug('insert the item into ${_player.currentIndex ?? 0}');
    await audioSource.insert(targetIdx < audioSource.length ? targetIdx : 0,
        _mediaItemToAudioSource(newItem));
    // update queue
    queue.add(_queueFromAudioSource);
    // update mediaItem
    // play it: need this to apply seek position of the mediaItem
    await skipToQueueItem(targetIdx);
    _player.play();
  }

  // SeekHandler implements fastForward, rewind, seekForward, seekBackward
  @override
  Future<void> seek(Duration position) => _player.seek(position);

  // QueueHandler implements skipToNext, skipToPrevious
  @override
  Future<void> skipToQueueItem(int index) async {
    // logDebug('skipToQueueItem: $index');
    final qval = queue.value;
    if (index >= 0 && index < qval.length) {
      // start at the last position
      await _player.seek(Duration(seconds: qval[index].extras?['seekPos'] ?? 0),
          index: index);
      mediaItem.add(qval[index]);
    } else if (index == qval.length) {
      // if all done
      if (_player.playing) {
        await stop();
      }
      // clear queue
      await clearQueue();
    }
  }

  // FIXME: this can be deleted?
  @override
  Future<void> skipToNext() async {
    if (_player.currentIndex != null) {
      skipToQueueItem(_player.currentIndex! + 1);
    }
  }

  UriAudioSource _mediaItemToAudioSource(MediaItem mediaItem) =>
      AudioSource.uri(Uri.parse(mediaItem.id), tag: mediaItem);

  List<MediaItem> get _queueFromAudioSource =>
      _player.audioSource is ConcatenatingAudioSource
          ? (_player.audioSource as ConcatenatingAudioSource)
              .children
              .map((s) => (s as UriAudioSource).tag as MediaItem)
              .toList()
          : <MediaItem>[];

  @override
  Future<void> addQueueItem(MediaItem mediaItem) async {
    (_player.audioSource as ConcatenatingAudioSource)
        .add(_mediaItemToAudioSource(mediaItem));
    // broadcast change
    final qval = queue.value..add(mediaItem);
    queue.add(qval);
  }

  @override
  Future<void> addQueueItems(List<MediaItem> mediaItems) async {
    (_player.audioSource as ConcatenatingAudioSource)
        .addAll(mediaItems.map((m) => _mediaItemToAudioSource(m)).toList());
    // broadcast change
    final qval = queue.value..addAll(mediaItems);
    queue.add(qval);
  }

  @override
  Future<void> insertQueueItem(int index, MediaItem mediaItem) async {
    (_player.audioSource as ConcatenatingAudioSource)
        .insert(index, _mediaItemToAudioSource(mediaItem));
    // broadcast change
    final qval = queue.value..insert(index, mediaItem);
    queue.add(qval);
  }

  @override
  Future<void> removeQueueItem(MediaItem mediaItem) async {
    // logDebug('removeQueueItem:$mediaItem');
    final qval = queue.value;
    final index = qval.indexWhere((e) => e.id == mediaItem.id);
    if (index != -1) {
      await removeQueueItemAt(index);
    }
  }

  @override
  Future<void> removeQueueItemAt(int index) async {
    // logDebug('removeQueuItemAt: $index');
    final audioSource = _player.audioSource as ConcatenatingAudioSource;
    if (index >= 0 && index < audioSource.length) {
      audioSource.removeAt(index);
      final qval = queue.value..removeAt(index);
      queue.add(qval);
      // queue is empty
      if (qval.isEmpty) {
        // so no mediaItem
        mediaItem.add(null);
      }
    }
  }

  Future<void> clearQueue() async {
    // logDebug('handler.clearQueue');
    final qval = queue.value;
    if (qval.isNotEmpty) {
      // report played for all remaining items in the queue
      for (int index = 0; index < qval.length; index += 1) {
        qval[index].extras!['played'] = true;
      }
      queue.add(qval);
    }
    // then clear the queue
    // this does not set the currentIndex to null or zero
    // await (_player.audioSource as ConcatenatingAudioSource).clear();
    // this does set the currentIndex to zero
    await _player.setAudioSource(ConcatenatingAudioSource(children: []));
    queue.add([]);
    mediaItem.add(null);
  }

  Future<void> reorderQueue(int oldIndex, int newIndex) async {
    final qval = queue.value;
    if (oldIndex >= 0 &&
        oldIndex < qval.length &&
        newIndex >= 0 &&
        newIndex <= qval.length) {
      // handle audiosource
      final audioSource = (_player.audioSource as ConcatenatingAudioSource);
      final targetChild = audioSource.children[oldIndex];
      await audioSource.removeAt(oldIndex);
      await audioSource.insert(newIndex, targetChild);
      // broadcast queue
      final item = qval.removeAt(oldIndex);
      qval.insert(newIndex, item);
      queue.add(qval);
    }
  }

  void _updateSeekPos() {
    final index = _player.currentIndex;
    final seekPos = _player.position.inSeconds;
    if (index != null && _player.audioSource != null) {
      final sources =
          (_player.audioSource as ConcatenatingAudioSource).children;
      if (index < sources.length) {
        final mItem = (sources[index] as IndexedAudioSource).tag;
        mItem.extras['seekPos'] = seekPos;
        // broadcast the change
        mediaItem.add(mItem);
      }
    }
  }

  void _updatePlayed(int? index, bool flag) {
    if (index != null && _player.audioSource != null) {
      logDebug('updatePlayed: $index, $flag');
      final sources =
          (_player.audioSource as ConcatenatingAudioSource).children;
      if (index >= 0 && index < sources.length) {
        (sources[index] as IndexedAudioSource).tag.extras['played'] = flag;
        // we do not broadcast it here
        // instead it will be broadcasted at the next queue update
      }
    }
  }
}
