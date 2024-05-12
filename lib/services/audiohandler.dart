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
  }

  Future<void> dispose() async {
    await _subDuration?.cancel();
    await _subPlyState?.cancel();
    await _subCurIndex?.cancel();

    await _player.stop();
    await _player.dispose();
  }

  //
  // Note that this will fire twice
  // - at the beginning: playing && buffering (valid data)
  // - at the end: not playing && idle (should be ignored)
  //
  void _handleDurationChange() {
    // subscribe to the duration change
    _subDuration = _player.durationStream.listen((Duration? duration) {
      // logDebug('handler.durationChange: $duration, ${_player.playerState}');
      if (duration != null && _player.playing) {
        // broadcast duration change
        if (currentMediaItem != null) {
          mediaItem.add(currentMediaItem!.copyWith(duration: duration));
        }
        // surprisingly this is a good spot to set the played flag
        // set played flag for the previous item
        if (sequence != null &&
            currentIndex != null &&
            currentIndex! > 0 &&
            currentIndex! < sequence!.length) {
          // logDebug(
          //     'handler.CurIndexChange.set played for ${currentIndex! - 1})');
          sequence![currentIndex! - 1].tag?.extras['played'] = true;
          queue.add(_queueFromSequence);
        }
      }
    });
  }

  void _handlePlyStateChange() {
    // subscribe to playerStateStream
    _subPlyState = _player.playerStateStream.listen((PlayerState state) async {
      // logDebug('handler.plyStateChange: $state');
      if (state.processingState == ProcessingState.ready) {
        if (state.playing == false) {
          // paused or loading done
          _updateSeekPos();
        }
      } else if (state.processingState == ProcessingState.buffering) {
        // probably unnecessary
        // _updateSeekPos();
      } else if (state.processingState == ProcessingState.completed) {
        // (playing, completed) => (not playing, completed) => (not playing, idle)
        if (state.playing) {
          logDebug('end of queue');
          // set played for the last mediaItem otherwise left unchecked
          if (currentMediaItem != null) {
            mediaItem.add(currentMediaItem!.copyWith(
                extras: currentMediaItem!.extras
                  ?..update('played', (value) => true)));
          }
          // need to call stop to ensure firing below state
          await stop();
        } else {
          // this is invoked when stop() is called
          // logDebug('cleaning up audioSource, queue, mediaItem');
          queue.add([]);
          mediaItem.add(null);
        }
      }
    });
  }

  //
  // When playMedia with existing mediaItem called, it invokes this function
  // twice, first when sequence is reordered then seek is called
  //
  void _handleCurIndexChange() {
    _subCurIndex = _player.currentIndexStream.listen((int? index) {
      // logDebug('handler.CurIndexChange.index: $index, ${_player.playerState}');
      // broadcast current media item
      mediaItem.add(currentMediaItem);
      // do not set the played flag here
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
      androidCompactActionIndices: const [0, 1, 2],
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

  // expose player properties to logic
  bool get playing => _player.playing;
  // Duration get position => _player.position;
  double get speed => _player.speed;
  Duration get duration => _player.duration ?? Duration.zero;
  Stream<Duration> get positionStream => _player.positionStream;

  // convenient shortcuts for internal use
  int? get currentIndex => _player.currentIndex;
  List<IndexedAudioSource>? get sequence => _player.sequence;
  IndexedAudioSource? get currentSource => currentIndex != null &&
          sequence != null &&
          currentIndex! < sequence!.length
      ? sequence?.elementAt(currentIndex!)
      : null;
  MediaItem? get currentMediaItem => currentSource?.tag as MediaItem?;

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
    // logDebug('playMediaItem: ${mediaItem.title}');
    final audioSource = _player.audioSource as ConcatenatingAudioSource;
    // first we need to save current position if currently playing
    if (_player.playing) {
      _updateSeekPos();
    }
    // check if the media is in the queue
    final mediaIndex = audioSource.children
        .indexWhere((c) => (c as UriAudioSource).tag.id == mediaItem.id);
    if (mediaIndex == -1) {
      // logDebug('new media => set up a new audio source');
      await _player.setAudioSource(ConcatenatingAudioSource(
          children: [_mediaItemToAudioSource(mediaItem)]));
      await _player.seek(Duration(seconds: mediaItem.extras!['seekPos']));
    } else if (mediaIndex < audioSource.length && mediaIndex != currentIndex) {
      // logDebug('existing media at $mediaIndex is selected');
      final targetIndex = _player.currentIndex ?? 0;
      await audioSource.move(mediaIndex, targetIndex);
      await _player.seek(Duration(seconds: mediaItem.extras!['seekPos']),
          index: targetIndex);
      // logDebug('seek to index $targetIndex');
    }
    // update queue
    queue.add(_queueFromSequence);
    // logDebug('queue: ${queue.value.map((m) => m.title).toList()}');
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
      // logDebug('... ${qval[index].title}');
    }
  }

  // QueueHandler skipToNext() seems to have bugs
  @override
  Future<void> skipToNext() async {
    // logDebug('skipToNext');
    final qval = queue.value;
    if (currentIndex != null && currentIndex! < (qval.length - 1)) {
      skipToQueueItem(currentIndex! + 1);
    }
  }

  UriAudioSource _mediaItemToAudioSource(MediaItem mediaItem) =>
      AudioSource.uri(Uri.parse(mediaItem.id), tag: mediaItem);

  List<MediaItem> get _queueFromSequence => sequence != null
      ? sequence!.map((s) => s.tag as MediaItem).toList()
      : <MediaItem>[];

  @override
  Future<void> addQueueItem(MediaItem mediaItem) async {
    // logDebug('addQueueItem: $mediaItem');
    await (_player.audioSource as ConcatenatingAudioSource)
        .add(_mediaItemToAudioSource(mediaItem));
    // broadcast change
    queue.add(_queueFromSequence);
  }

  @override
  Future<void> addQueueItems(List<MediaItem> mediaItems) async {
    await (_player.audioSource as ConcatenatingAudioSource)
        .addAll(mediaItems.map((m) => _mediaItemToAudioSource(m)).toList());
    // broadcast change
    queue.add(_queueFromSequence);
  }

  @override
  Future<void> insertQueueItem(int index, MediaItem mediaItem) async {
    (_player.audioSource as ConcatenatingAudioSource)
        .insert(index, _mediaItemToAudioSource(mediaItem));
    // broadcast change
    queue.add(_queueFromSequence);
  }

  @override
  Future<void> removeQueueItem(MediaItem mediaItem) async {
    // logDebug('removeQueueItem:${mediaItem.title}');
    final qval = queue.value;
    final index = qval.indexWhere((e) => e.id == mediaItem.id);
    if (index != -1) {
      await removeQueueItemAt(index);
    }
  }

  @override
  Future<void> removeQueueItemAt(int index) async {
    // logDebug('removeQueuItemAt: $index');
    final audioSource = _player.audioSource as ConcatenatingAudioSource?;
    if (index >= 0 && audioSource != null && index < audioSource.length) {
      audioSource.removeAt(index);
      // broadcast change
      queue.add(_queueFromSequence);
      // source list is empty
      if (audioSource.length == 0) {
        mediaItem.add(null);
      }
    }
  }

  Future<void> reorderQueue(int oldIndex, int newIndex) async {
    // logDebug('reorderQueue: $oldIndex, $newIndex');
    final audioSource = _player.audioSource as ConcatenatingAudioSource;
    if (oldIndex >= 0 &&
        oldIndex < audioSource.length &&
        newIndex >= 0 &&
        newIndex <= audioSource.length) {
      // handle audiosource
      await audioSource.move(oldIndex, newIndex);
      // broadcast queue
      queue.add(_queueFromSequence);
    }
  }

  void _updateSeekPos() {
    if (currentMediaItem != null) {
      mediaItem.add(currentMediaItem!.copyWith(
          extras: currentMediaItem!.extras
            ?..update('seekPos', (value) => _player.position.inSeconds)));
    }
  }
}
