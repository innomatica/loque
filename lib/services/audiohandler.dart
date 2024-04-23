import 'dart:async';
import 'dart:developer';

import 'package:audio_service/audio_service.dart';
import 'package:just_audio/just_audio.dart';

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
  // final _sequence = <IndexedAudioSource>[];
  StreamSubscription? _subDuration;
  StreamSubscription? _subSeqState;
  StreamSubscription? _subPlyState;

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
    _handleSeqStateChange();
    _handlePlyStateChange();
  }

  Future<void> dispose() async {
    await _subDuration?.cancel();
    await _subSeqState?.cancel();
    await _subPlyState?.cancel();
    await _player.stop();
    await _player.dispose();
  }

  void _handleDurationChange() {
    // subscribe to the duration change
    _subDuration = _player.durationStream.listen((Duration? duration) {
      final index = _player.currentIndex;
      final qval = queue.value;
      if (index != null && index >= 0 && index < qval.length) {
        final item = qval[index];
        // broadcast updated mediaItem
        mediaItem.add(item.copyWith(duration: duration));
        // FIXME: probably unnecessary but not certain
        // broadcast updated queue
        // qval[index] = updated;
        // queue.add(qval);
      }
    });
  }

  void _handleSeqStateChange() {
    // subscribe to the sequence state change
    _subSeqState = _player.sequenceStateStream.listen((seqState) {
      if (seqState != null) {
        // NOTE we are handling with sequence not queue
        final index = seqState.currentIndex;
        final sequence = seqState.effectiveSequence;
        log('sequenceState: $index, $sequence');
        // required to validate the index
        if (index >= 0 && index < sequence.length) {
          // broadcast new mediaItem
          final item = sequence[index].tag;
          mediaItem.add(item);
          // mark previous mediaItems as played
          for (int prevIdx = 0; prevIdx < index; prevIdx += 1) {
            sequence[prevIdx].tag.extras['played'] = true;
          }
          // broadcast updated sequence
          queue.add(sequence.map((s) => s.tag as MediaItem).toList());
        }
      }
    });
  }

  void _handlePlyStateChange() {
    _subPlyState = _player.playerStateStream.listen((PlayerState state) async {
      // log('handlePlyStateChange: $state');
      if (state.processingState == ProcessingState.ready) {
        if (state.playing == false) {
          // about to start playing or paused
          final item = mediaItem.value;
          if (item != null) {
            // keep the current position
            item.extras!['seekPos'] = _player.position.inSeconds;
            // report change
            mediaItem.add(item);
          }
        }
      } else if (state.processingState == ProcessingState.completed) {
        // NOTE (playing, completed) may or MAY NOT be followed by (not playing, complted)
        if (state.playing) {
          // end of playing queue: be sure not to use (state.playing==false)
          await pause();
          // clear queue
          if (queue.value.isNotEmpty) {
            await clearQueue();
          }
        }
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
  AudioSource? get audioSource => _player.audioSource;
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
  Future<void> playMediaItem(MediaItem mediaItem) async {
    // log('playMediaItem: $mediaItem');
    final audioSource = _player.audioSource as ConcatenatingAudioSource;
    final index = audioSource.children
        .indexWhere((c) => (c as UriAudioSource).tag.id == mediaItem.id);
    final targetIdx = _player.currentIndex ?? 0;
    if (index >= 0 && index < audioSource.length) {
      // we remove existing one to reflect potential changes
      log('removing the item from $index');
      await audioSource.removeAt(index);
    }
    // log('inserting the item into ${_player.currentIndex ?? 0}');
    await audioSource.insert(targetIdx, _mediaItemToAudioSource(mediaItem));
    // update queue
    queue.add(queueFromAudioSource);
    // log('queue: ${queue.value}');
    await skipToQueueItem(targetIdx);
    _player.play();
  }

  // SeekHandler implements fastForward, rewind, seekForward, seekBackward
  @override
  Future<void> seek(Duration position) => _player.seek(position);

  // QueueHandler implements skipToNext, skipToPrevious
  @override
  Future<void> skipToQueueItem(int index) async {
    final qval = queue.value;
    log('skipToQueueItem: $index');
    if (index >= 0 && index < qval.length) {
      // start at the last position
      await _player.seek(Duration(seconds: qval[index].extras?['seekPos'] ?? 0),
          index: index);
    } else if (index == qval.length) {
      if (_player.playing) {
        await stop();
      }
      await clearQueue();
    }
  }

  @override
  Future<void> skipToNext() async {
    log('handler.skipToNext: $_player.currentIndex');
    if (_player.currentIndex != null) {
      skipToQueueItem(_player.currentIndex! + 1);
    }
  }

  UriAudioSource _mediaItemToAudioSource(MediaItem mediaItem) =>
      AudioSource.uri(Uri.parse(mediaItem.id), tag: mediaItem);

  List<MediaItem> get queueFromAudioSource =>
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
    final qval = queue.value;
    final index = qval.indexWhere((e) => e.id == mediaItem.id);
    if (index != -1) {
      await removeQueueItemAt(index);
    }
  }

  @override
  Future<void> removeQueueItemAt(int index) async {
    final audioSource = _player.audioSource as ConcatenatingAudioSource;
    if (index >= 0 && index < audioSource.length) {
      audioSource.removeAt(index);
      final qval = queue.value..removeAt(index);
      queue.add(qval);
      if (qval.isEmpty) {
        mediaItem.add(null);
      }
    }
  }

  Future<void> clearQueue() async {
    // log('handler.clearQueue');
    final qval = queue.value;
    final audioSource = _player.audioSource as ConcatenatingAudioSource;
    // need to report played for all the items in the queue
    if (qval.isNotEmpty) {
      // set all remaining mediaItem as played
      for (int index = 0; index < qval.length; index += 1) {
        qval[index].extras!['played'] = true;
      }
      queue.add(qval);
    }
    // then clear the queue
    await audioSource.clear();
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
      // handle queue
      final item = qval.removeAt(oldIndex);
      qval.insert(newIndex, item);
      queue.add(qval);
    }
  }
}
