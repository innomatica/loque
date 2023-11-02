import 'package:audio_service/audio_service.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../services/audiohandler.dart';

class PlayListView extends StatefulWidget {
  const PlayListView({super.key});

  @override
  State<PlayListView> createState() => _PlayListViewState();
}

class _PlayListViewState extends State<PlayListView> {
  @override
  Widget build(BuildContext context) {
    final handler = context.read<LoqueAudioHandler>();
    return StreamBuilder<List<MediaItem>>(
        // stream: handler.playbackState.map((e) => e.queueIndex).distinct(),
        stream: handler.queue.stream,
        builder: (context, snapshot) {
          if (snapshot.hasData) {
            // final queue = handler.getQueue();
            final queue = snapshot.data!;
            // final currentIndex = snapshot.data!;
            // debugPrint('snapshot has data: ${queue.length}');
            return ReorderableListView(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              children: <Widget>[
                for (int index = 0; index < queue.length; index += 1)
                  ListTile(
                    visualDensity: VisualDensity.compact,
                    enabled:
                        index > (handler.playbackState.value.queueIndex ?? 0),
                    key: Key('$index'),
                    title: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          queue[index].album ?? '',
                          style: const TextStyle(
                              fontSize: 14.0,
                              letterSpacing: 0.0,
                              fontWeight: FontWeight.w600),
                        ),
                        Text(
                          queue[index].title,
                          maxLines: 2,
                          style: const TextStyle(
                            letterSpacing: 0.0,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    //
                    // Delete Episode from the Playlist
                    //
                    // FIXME: enabled flag not working here
                    //
                    trailing: InkWell(
                      child: const Icon(
                        Icons.playlist_remove_rounded,
                        // color: Theme.of(context).colorScheme.primary,
                      ),
                      onTap: () {
                        handler.removeQueueItemAt(index);
                        setState(() {});
                      },
                    ),
                  ),
              ],
              //
              // Reorder Playlist
              //
              onReorder: (int oldIndex, int newIndex) {
                debugPrint('oldIndex:$oldIndex, newIndex:$newIndex');
                // if (oldIndex <= currentIndex || newIndex <= currentIndex) {
                //   debugPrint('not allowed to change already played items');
                //   return;
                // }
                setState(() {
                  if (oldIndex < newIndex) {
                    newIndex -= 1;
                  }
                  debugPrint('oldIndex:$oldIndex, newIndex:$newIndex');
                  handler.reorderQueue(oldIndex, newIndex);
                });
              },
            );
          }
          return Container();
        });
  }
}
