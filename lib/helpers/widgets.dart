import 'package:audio_service/audio_service.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../logic/loque.dart';
import '../models/channel.dart';
import '../screens/channel/channel.dart';
import '../screens/home/player.dart';

//
// ClipRRect Image with disabled coloring
//
class LoqueImage extends StatelessWidget {
  final String? imageUrl;
  final double width;
  final double height;
  final bool disabled;
  const LoqueImage(
    this.imageUrl, {
    this.width = 40.0,
    this.height = 40.0,
    this.disabled = false,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return ColorFiltered(
      colorFilter: disabled
          ? const ColorFilter.matrix(<double>[
              0.2126, 0.7152, 0.0722, 0, //
              0, 0.2126, 0.7152, 0.0722,
              0, 0, 0.2126, 0.7152,
              0.0722, 0, 0, 0,
              0, 0, 1, 0
            ])
          : const ColorFilter.matrix(
              <double>[
                1, 0, 0, 0, //
                0, 0, 1, 0,
                0, 0, 0, 0,
                1, 0, 0, 0,
                0, 0, 1, 0
              ],
            ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(4.0),
        child: imageUrl?.isNotEmpty == true
            ? Image(
                image: CachedNetworkImageProvider(imageUrl!),
                width: width,
                height: height,
                fit: BoxFit.cover,
              )
            : Image(
                image: const AssetImage('assets/images/podcast-512.png'),
                width: width,
                height: height,
                fit: BoxFit.cover,
              ),
      ),
    );
  }
}

//
// Channel Tile
//
class ChannelTile extends StatelessWidget {
  final Channel channel;
  const ChannelTile(this.channel, {super.key});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => ChannelPage(channel),
          ),
        );
      },
      //
      // Image and Title
      //
      title: Row(
        children: [
          LoqueImage(channel.imageUrl, width: 60, height: 60),
          Flexible(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    channel.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    softWrap: false,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.tertiary,
                      fontWeight: FontWeight.w500,
                      fontSize: 17,
                      letterSpacing: 0.0,
                    ),
                  ),
                  channel.lastUpdate != null
                      ? Text(
                          channel.lastUpdate.toString().split(' ')[0],
                          style: const TextStyle(
                            fontWeight: FontWeight.w500,
                            fontSize: 14.0,
                          ),
                        )
                      : const SizedBox()
                ],
              ),
            ),
          ),
        ],
      ),
      //
      // Description
      //
      subtitle: Padding(
        padding: const EdgeInsets.only(top: 4.0),
        child: Text(
          channel.getDescription(),
          overflow: TextOverflow.ellipsis,
          maxLines: 2,
        ),
      ),
    );
  }
}

//
// Channel Card
//
class ChannelCard extends StatelessWidget {
  final Channel channel;
  const ChannelCard(this.channel, {super.key});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => ChannelPage(channel),
          ),
        );
      },
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          LoqueImage(channel.imageUrl, width: 100, height: 100),
          SizedBox(
            width: 100,
            height: 20,
            child: Padding(
              padding: const EdgeInsets.only(top: 2.0),
              child: Text(
                channel.title,
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.primary,
                  fontWeight: FontWeight.w600,
                  fontSize: 13.0,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

//
// Mini Player for Scaffold BottomSheet
//
StreamBuilder buildMiniPlayer(BuildContext context) {
  final logic = context.read<LoqueLogic>();
  return StreamBuilder<PlaybackState?>(
    stream: logic.playbackState,
    builder: (context, snapshot) {
      if (snapshot.hasData) {
        final state = snapshot.data!;
        final tag = logic.currentTag;
        // logDebug('miniplayer.state: $state, tag: $tag');
        if ([
          AudioProcessingState.loading,
          AudioProcessingState.buffering,
          AudioProcessingState.ready
        ].contains(state.processingState)) {
          return Container(
            padding: const EdgeInsets.only(left: 8.0),
            decoration: BoxDecoration(
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(10.0),
                topRight: Radius.circular(10.0),
              ),
              color: Theme.of(context)
                  .colorScheme
                  .secondaryContainer
                  .withOpacity(0.35),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: TextButton(
                    onPressed: () {
                      showModalBottomSheet(
                        context: context,
                        builder: (context) => const PlayerView(),
                      );
                    },
                    child: Center(
                      child: Text(
                        tag?.title ?? "... media loading ...",
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontWeight: FontWeight.w500,
                          color: Theme.of(context)
                              .colorScheme
                              .onSecondaryContainer,
                        ),
                      ),
                    ),
                  ),
                ),
                /*
                Expanded(
                  child: GestureDetector(
                    onTap: () {
                      showModalBottomSheet(
                        context: context,
                        builder: (context) => const PlayerView(),
                      );
                    },
                    //
                    // title
                    //
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Expanded(
                          child: Text(
                            tag?.title ?? "... media loading ...",
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontWeight: FontWeight.w500,
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSecondaryContainer,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                */
                //
                // play button
                //
                state.playing
                    ? IconButton(
                        icon: const Icon(Icons.pause_rounded),
                        onPressed: () => logic.pause(),
                      )
                    : IconButton(
                        icon: const Icon(Icons.play_arrow_rounded),
                        onPressed: () => logic.play(null),
                      ),
              ],
            ),
          );
        }
      }
      // show nothing when the player is idle, completed, or error state
      return const SizedBox(height: 0.0);
    },
  );
}
