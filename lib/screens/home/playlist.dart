import 'package:audio_service/audio_service.dart';
import 'package:flutter/material.dart';
import 'package:loqueapp/helpers/widgets.dart';
import 'package:provider/provider.dart';

import '../../logic/loque.dart';

class PlayListView extends StatefulWidget {
  const PlayListView({super.key});

  @override
  State<PlayListView> createState() => _PlayListViewState();
}

class _PlayListViewState extends State<PlayListView> {
  @override
  Widget build(BuildContext context) {
    final logic = context.read<LoqueLogic>();
    return StreamBuilder<List<MediaItem>>(
      stream: logic.queue,
      builder: (context, snapshot) {
        if (snapshot.hasData && snapshot.data!.isNotEmpty) {
          final playlist = snapshot.data!;
          return ReorderableListView(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            onReorder: (int oldIndex, int newIndex) {
              // debugPrint('oldIndex:$oldIndex, newIndex:$newIndex');
              // only future items are to be reordered
              // FIXME: avoid using playbackState directly
              final queueIndex = logic.playbackState.value.queueIndex;
              if (queueIndex != null &&
                  queueIndex < oldIndex &&
                  queueIndex < newIndex) {
                // debugPrint('allowed to reorder');
                setState(() {
                  if (oldIndex < newIndex) {
                    newIndex -= 1;
                  }
                  logic.reorderPlaylist(oldIndex, newIndex);
                });
              }
            },
            children: <Widget>[
              for (int index = 0; index < playlist.length; index += 1)
                ListTile(
                  visualDensity: VisualDensity.compact,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 8.0),
                  enabled: playlist[index].extras?['played'] != true,
                  // FIXME: avoid using playbackState directly
                  shape: index == logic.playbackState.value.queueIndex
                      ? RoundedRectangleBorder(
                          side: BorderSide(
                              color: Theme.of(context).colorScheme.primary),
                          borderRadius: BorderRadius.circular(10),
                        )
                      : null,
                  key: Key('$index'),
                  //
                  // Title
                  //
                  title: Row(
                    children: [
                      LoqueImage(
                        playlist[index].artUri.toString(),
                        width: 40.0,
                        height: 40.0,
                      ),
                      const SizedBox(width: 8.0),
                      Expanded(
                        child: Text(
                          playlist[index].title,
                          maxLines: 1,
                          style: const TextStyle(
                            // fontSize: 14.0,
                            // fontWeight: FontWeight.w300,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ),
                    ],
                  ),
                  //
                  // Delete Episode from the Playlist
                  //
                  trailing: SizedBox(
                    width: 32,
                    child: IconButton(
                      icon: const Icon(Icons.playlist_remove_rounded),
                      onPressed: () async =>
                          await logic.removePlaylistItem(playlist[index]),
                    ),
                  ),
                  onTap: () => logic.playMediaItem(playlist[index]),
                ),
            ],
          );
        } else {
          return Center(
            child: Icon(Icons.playlist_play_rounded,
                size: 100, color: Theme.of(context).colorScheme.surfaceVariant),
          );
        }
      },
    );
  }
}
