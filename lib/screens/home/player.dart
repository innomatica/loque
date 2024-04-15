import 'package:async/async.dart';
import 'package:audio_service/audio_service.dart';
import 'package:audio_video_progress_bar/audio_video_progress_bar.dart';

import 'package:flutter/material.dart';
import 'package:loqueapp/services/audiohandler.dart';
import 'package:provider/provider.dart';

import '../../helpers/widgets.dart';
import '../../logic/loque.dart';

const speeds = <double>[0.5, 0.8, 1.0, 1.2, 1.5];

class PlayerView extends StatefulWidget {
  const PlayerView({super.key});

  @override
  State<PlayerView> createState() => _PlayerViewState();
}

class _PlayerViewState extends State<PlayerView> {
  RestartableTimer? _timer;

  @override
  void initState() {
    super.initState();
    // automatically dismiss the screen after a while
    _timer = RestartableTimer(
      const Duration(seconds: 30),
      () {
        if (mounted) {
          Navigator.of(context).pop();
        }
      },
    );
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final logic = context.read<LoqueLogic>();

    return StreamBuilder<PlaybackState?>(
      stream: logic.handler.playbackState,
      builder: (context, snapshot) {
        if (snapshot.hasData) {
          final state = snapshot.data!;
          final tag = logic.handler.getTagFromQueue(state.queueIndex);
          debugPrint('playerview.state: $state, tag: $tag');
          return Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // title block
                Row(
                  children: [
                    LoqueImage(tag?.artUri.toString(), width: 60, height: 60),
                    const SizedBox(width: 8.0),
                    Flexible(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            tag?.album ?? '',
                            style: TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 16,
                                color: Theme.of(context).colorScheme.tertiary),
                          ),
                          Text(
                            tag?.title ?? '',
                            maxLines: 2,
                            style: const TextStyle(
                                fontWeight: FontWeight.w500,
                                overflow: TextOverflow.ellipsis),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                //
                // progress bar
                //
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 24.0),
                  child: buildProgressBar(logic.handler),
                ),
                //
                // other player widgets
                //
                Container(
                  color: Theme.of(context).colorScheme.secondaryContainer,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      //
                      // speed selector
                      //
                      DropdownButton<double>(
                        value: state.speed,
                        iconSize: 0,
                        isDense: true,
                        onChanged: (double? value) {
                          logic.handler.setSpeed(value ?? 1.0);
                        },
                        items: speeds
                            .map<DropdownMenuItem<double>>(
                              (double value) => DropdownMenuItem<double>(
                                value: value,
                                child: Text('$value x'),
                              ),
                            )
                            .toList(),
                      ),
                      //
                      // rewind button
                      //
                      IconButton(
                        icon: const Icon(Icons.replay_30_rounded, size: 32),
                        onPressed: () async => await logic.handler.rewind(),
                      ),
                      //
                      // play / pause button
                      //
                      state.playing
                          ? IconButton(
                              icon: const Icon(Icons.pause_rounded, size: 32),
                              onPressed: () => logic.handler.pause(),
                            )
                          : IconButton(
                              icon: const Icon(Icons.play_arrow_rounded,
                                  size: 32),
                              onPressed: () => logic.handler.play(),
                            ),
                      //
                      // fast forward
                      //
                      IconButton(
                        icon: const Icon(Icons.forward_30_rounded, size: 32),
                        onPressed: () async =>
                            await logic.handler.fastForward(),
                      )
                    ],
                  ),
                ),
              ],
            ),
          );
        } else {
          return const SizedBox(height: 0.0);
        }
      },
    );
  }
}

//
// Progress Bar
// NOTE: PlaybackState.updatePosition is not updating frequently. So we need
// separate streambuilder here.
//
StreamBuilder<Duration> buildProgressBar(LoqueAudioHandler handler) {
  return StreamBuilder<Duration>(
    stream: handler.positionStream.distinct(),
    builder: (context, snapshot) {
      final total = handler.duration;
      final progress = snapshot.data ?? Duration.zero;
      return ProgressBar(
        progress: progress,
        total: total,
        onSeek: (duration) async => await handler.seek(duration),
      );
    },
  );
}
