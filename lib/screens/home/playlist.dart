import 'package:audio_service/audio_service.dart';
import 'package:flutter/material.dart';
import 'package:loqueapp/helpers/widgets.dart';
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
            final queue = snapshot.data!;
            return ReorderableListView(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              children: <Widget>[
                for (int index = 0; index < queue.length; index += 1)
                  ListTile(
                    visualDensity: VisualDensity.compact,
                    enabled: queue[index].extras?['played'] != true,
                    shape: index == handler.playbackState.value.queueIndex
                        ? RoundedRectangleBorder(
                            side: BorderSide(
                                color: Theme.of(context).colorScheme.primary),
                            borderRadius: BorderRadius.circular(10),
                          )
                        : null,
                    key: Key('$index'),
                    title: Text(
                      queue[index].album ?? '',
                      style: const TextStyle(
                        fontSize: 14.0,
                        letterSpacing: 0.0,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    subtitle: Text(
                      queue[index].title,
                      maxLines: 2,
                      style: const TextStyle(
                        letterSpacing: 0.0,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    //
                    // Delete Episode from the Playlist
                    //
                    trailing: buildPlaylistRemoveButton(handler, queue[index]),
                    onTap: () {
                      handler.playMediaItem(queue[index]);
                    },
                  ),
              ],
              //
              // Reorder Playlist
              //
              onReorder: (int oldIndex, int newIndex) {
                debugPrint('oldIndex:$oldIndex, newIndex:$newIndex');
                // setState(() {
                //   if (oldIndex < newIndex) {
                //     newIndex -= 1;
                //   }
                //   debugPrint('oldIndex:$oldIndex, newIndex:$newIndex');
                //   handler.reorderQueue(oldIndex, newIndex);
                // });
              },
            );
          }
          return Container();
        });
  }
}
