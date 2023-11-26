import 'package:async/async.dart';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../helpers/widgets.dart';
import '../../services/audiohandler.dart';

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
    final handler = context.read<LoqueAudioHandler>();
    // final episode = handler.getCurrentEpisode();

    return StreamBuilder<int?>(
      // stream: handler.sequenceStateStream,
      stream: handler.playbackState.map((s) => s.queueIndex).distinct(),
      builder: (context, snapshot) {
        if (snapshot.hasData) {
          final tag = handler.getCurrentTag();
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
                const SizedBox(height: 16.0),
                // progress bar
                buildProgressBar(handler),
                const SizedBox(height: 16.0),
                // other player widgets
                Container(
                  color: Theme.of(context).colorScheme.secondaryContainer,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      buildSpeedSelector(handler),
                      buildRewindButton(handler, size: 32),
                      buildPlayButton(handler, size: 32),
                      buildForwardButton(handler, size: 32),
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
