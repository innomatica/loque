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
  StreamSubscription? _subCurIndex;
  StreamSubscription? _subSeqState;
  // MediaItem? _currentMediaItem;

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
    // subscriptions
    _handleDurationChange();
    _handleCurIndexChange();
    _handleSeqStateChange();
  }

  void _handleDurationChange() {
    // subscribe to the duration change
    _subDuration = _player.durationStream.listen((duration) {
      final index = _player.currentIndex;
      final qval = queue.value;
      if (index != null && index >= 0 && index < qval.length) {
        final item = qval[index];
        final updated = item.copyWith(duration: duration);
        // broadcast new mediaItem
        mediaItem.add(updated);
        // broadcast new queue
        qval[index] = updated;
        queue.add(qval);
      }
    });
  }

  void _handleCurIndexChange() {
    // // subrcribe to the current index change
    // _subCurIndex = _player.currentIndexStream.listen((index) {
    //   final qval = queue.value;
    //   log('indexChange: $index, $qval');
    //   if (index != null && index >= 0 && index < qval.length) {
    //     final item = qval[index];
    //     // broadcast new mediaItem
    //     mediaItem.add(item);
    //   }
    // });
  }

  void _handleSeqStateChange() {
    // subscribe to the sequence state change
    _subSeqState = _player.sequenceStateStream.listen((seqState) {
      if (seqState != null) {
        final index = seqState.currentIndex;
        final sequence = seqState.effectiveSequence;
        if (index >= 0 && index < sequence.length) {
          final item = sequence[index].tag;
          // broadcast new mediaItem
          mediaItem.add(item);
          // broadcast new queue
          queue.add(sequence.map((s) => s.tag as MediaItem).toList());
        }
      }
    });
  }

  Future<void> dispose() async {
    await _subDuration?.cancel();
    await _subCurIndex?.cancel();
    await _subSeqState?.cancel();
    await _player.stop();
    await _player.dispose();
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
    log('playMediaItem: $mediaItem');
    final audioSource = _player.audioSource as ConcatenatingAudioSource;
    final index = audioSource.children
        .indexWhere((c) => (c as UriAudioSource).tag.id == mediaItem.id);
    final targetIdx = currentIndex ?? 0;
    if (index >= 0 && index < audioSource.length) {
      // we remove existing one to reflect potential changes
      log('removing the item from $index');
      await audioSource.removeAt(index);
    }
    log('inserting the item into ${currentIndex ?? 0}');
    await audioSource.insert(targetIdx, _mediaItemToAudioSource(mediaItem));
    // update queue
    queue.add(queueFromAudioSource);
    // log('queue: ${queue.value}');
    await skipToQueueItem(targetIdx);
    _player.play();
  }

  MediaItem? get currentMediaItem => mediaItem.value;
  String? get currentEpisodeId => mediaItem.value?.extras?['episodeId'];

  // expose player properties
  AudioPlayer get player => _player;
  Duration get duration => _player.duration ?? Duration.zero;
  bool get playing => _player.playing;
  Duration get position => _player.position;
  AudioSource? get audioSource => _player.audioSource;
  int? get currentIndex => _player.currentIndex;

  // expose player streams
  ProcessingState get processingState => _player.processingState;
  Stream<bool> get playingStream => _player.playingStream;
  Stream<int?> get currentIndexStream => _player.currentIndexStream;
  Stream<Duration> get positionStream => _player.positionStream;
  Stream<PlayerState> get playerStateStream => _player.playerStateStream;
  Stream<PlaybackEvent> get playbackEventStream => _player.playbackEventStream;

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
    (_player.audioSource as ConcatenatingAudioSource).removeAt(index);
    final qval = queue.value..removeAt(index);
    queue.add(qval);
    if (qval.isEmpty) {
      mediaItem.add(null);
    }
  }

  Future<void> clearQueue() async {
    // log('handler.clearQueue');
    (_player.audioSource as ConcatenatingAudioSource).clear();
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

  void setPlayed(String episodeId, {int delay = 0}) {
    // log('handler.setPlayed: $episodeId, $delay');
    final qval = queue.value;
    final index = qval.indexWhere((m) => m.extras!['episodeId'] == episodeId);
    if (index != -1) {
      Timer(Duration(seconds: delay), () {
        qval[index].extras!['played'] = true;
        // TODO: if this is located in the later part of the queue,
        // you may want it to be removed from the queue
        queue.add(qval);
      });
    }
  }

  void clearPlayed(String episodeId) {
    final qval = queue.value;
    final index = qval.indexWhere((m) => m.extras!['episodeId'] == episodeId);
    if (index != -1) {
      qval[index].extras!['played'] = false;
      queue.add(qval);
    }
  }
}
