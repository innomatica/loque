import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../helpers/widgets.dart';
import '../../logic/loque.dart';
import '../../services/audiohandler.dart';

class PlayListView extends StatefulWidget {
  const PlayListView({super.key});

  @override
  State<PlayListView> createState() => _PlayListViewState();
}

class _PlayListViewState extends State<PlayListView> {
  Widget _buildPlaylist(playlist) {
    final handler = context.read<LoqueAudioHandler>();
    return StreamBuilder<bool>(
      stream: handler.playbackState.stream.map((s) => s.playing).distinct(),
      builder: (context, snapshot) {
        return IgnorePointer(
          // prevent reorder during playing
          ignoring: snapshot.data == true,
          child: ReorderableListView(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            onReorder: (int oldIndex, int newIndex) {
              debugPrint('oldIndex:$oldIndex, newIndex:$newIndex');
              setState(() {
                if (oldIndex < newIndex) {
                  newIndex -= 1;
                }
                handler.reorderQueue(oldIndex, newIndex);
              });
            },
            children: <Widget>[
              for (int index = 0; index < playlist.length; index += 1)
                ListTile(
                  visualDensity: VisualDensity.compact,
                  enabled: playlist[index].extras?['played'] != true,
                  shape: index == handler.playbackState.value.queueIndex
                      ? RoundedRectangleBorder(
                          side: BorderSide(
                              color: Theme.of(context).colorScheme.primary),
                          borderRadius: BorderRadius.circular(10),
                        )
                      : null,
                  key: Key('$index'),
                  // title: channel name
                  title: Text(
                    playlist[index].album ?? '',
                    maxLines: 1,
                    style: const TextStyle(
                      fontSize: 14.0,
                      letterSpacing: 0.0,
                      overflow: TextOverflow.ellipsis,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  // subtitle: episode name
                  subtitle: Text(
                    playlist[index].title,
                    maxLines: 1,
                    style: const TextStyle(
                      letterSpacing: 0.0,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  //
                  // Delete Episode from the Playlist
                  //
                  trailing: buildPlaylistRemoveButton(handler, playlist[index]),
                  onTap: () => handler.playMediaItem(playlist[index]),
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildBackground() {
    return Center(
      child: Icon(Icons.playlist_play_rounded,
          size: 100, color: Theme.of(context).colorScheme.surfaceVariant),
    );
  }

  @override
  Widget build(BuildContext context) {
    final logic = context.watch<LoqueLogic>();
    final playlist = logic.playlist;
    return playlist.isNotEmpty ? _buildPlaylist(playlist) : _buildBackground();
  }
}
