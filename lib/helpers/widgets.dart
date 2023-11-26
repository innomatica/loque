import 'package:audio_service/audio_service.dart';
import 'package:audio_video_progress_bar/audio_video_progress_bar.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:loqueapp/services/audiohandler.dart';
import 'package:provider/provider.dart';

import '../models/channel.dart';
import '../models/episode.dart';
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
// Play Button
//
StreamBuilder<bool> buildPlayButton(LoqueAudioHandler handler,
    {double? size, Color? color}) {
  return StreamBuilder<bool>(
    stream: handler.playbackState.map((s) => s.playing).distinct(),
    builder: (context, snapshot) => snapshot.hasData && snapshot.data == true
        ? IconButton(
            icon: Icon(Icons.pause_rounded, size: size, color: color),
            onPressed: () async => await handler.pause(),
          )
        : IconButton(
            icon: Icon(Icons.play_arrow_rounded, size: size, color: color),
            onPressed: () async => await handler.play(),
          ),
  );
}

//
// Forward 30 sec
//
IconButton buildForwardButton(LoqueAudioHandler handler, {double? size}) {
  return IconButton(
    icon: Icon(Icons.forward_30_rounded, size: size),
    onPressed: () async => await handler.fastForward(),
  );
}

//
// Rewind 30 sec
//
IconButton buildRewindButton(LoqueAudioHandler handler, {double? size}) {
  return IconButton(
    icon: Icon(Icons.replay_30_rounded, size: size),
    onPressed: () async => await handler.rewind(),
  );
}

//
// Playback Speed Button
//
const speeds = <double>[0.5, 0.8, 1.0, 1.2, 1.5];

StreamBuilder<double> buildSpeedSelector(LoqueAudioHandler handler) {
  return StreamBuilder<double>(
    stream: handler.playbackState.map((s) => s.speed).distinct(),
    builder: (context, snapshot) {
      return DropdownButton<double>(
        value: snapshot.data ?? 1.0,
        iconSize: 0,
        isDense: true,
        onChanged: (double? value) {
          handler.setSpeed(value ?? 1.0);
        },
        items: speeds
            .map<DropdownMenuItem<double>>(
              (double value) => DropdownMenuItem<double>(
                value: value,
                child: Text('$value x'),
              ),
            )
            .toList(),
      );
    },
  );
}

//
// Progress Bar
//
StreamBuilder<Duration> buildProgressBar(LoqueAudioHandler handler) {
  return StreamBuilder<Duration>(
    // for some reason this does not work
    // stream: handler.playbackState.map((s) => s.updatePosition).distinct(),
    // but this does
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

//
// Playlist Add Button
//
StreamBuilder<bool> buildPlaylistAddButton(
        LoqueAudioHandler handler, Episode episode) =>
    StreamBuilder<bool>(
      stream: handler.playbackState.map((s) => s.playing).distinct(),
      builder: (context, snapshot) {
        return IconButton(
          icon: const Icon(Icons.playlist_add_rounded),
          onPressed: episode.played ||
                  (snapshot.hasData && snapshot.data == true)
              ? null
              : () async => await handler.addQueueItem(episode.toMediaItem()),
        );
      },
    );

//
// Playlist Remove Button
//
StreamBuilder<bool> buildPlaylistRemoveButton(
        LoqueAudioHandler handler, MediaItem mediaItem) =>
    StreamBuilder<bool>(
        // stream: handler.playbackState.map((s) => s.playing).distinct(),
        stream: handler.playingStream,
        builder: (context, snapshot) {
          return SizedBox(
            width: 32,
            child: IconButton(
              icon: const Icon(Icons.playlist_remove_rounded),
              onPressed: (snapshot.hasData && snapshot.data != true) ||
                      mediaItem.extras?['played'] != true
                  ? () async => await handler.removeQueueItem(mediaItem)
                  : null,
            ),
          );
        });

//
// Check/Uncheck Played Button
//
Widget buildCheckPlayedButton(LoqueAudioHandler handler, Episode episode) =>
    IconButton(
      onPressed: () async => await handler.togglePlayed(episode),
      icon: episode.played
          ? const Icon(Icons.unpublished_outlined)
          : const Icon(Icons.check_circle_outline),
    );

//
// Mini Player for Scaffold BottomSheet
//
StreamBuilder<AudioProcessingState?> buildMiniPlayer(BuildContext context) {
  final handler = context.read<LoqueAudioHandler>();
  return StreamBuilder<AudioProcessingState?>(
    stream: handler.playbackState.map((s) => s.processingState).distinct(),
    builder: (context, snapshot) {
      if (snapshot.hasData &&
          [
            AudioProcessingState.loading,
            AudioProcessingState.buffering,
            AudioProcessingState.ready
          ].contains(snapshot.data)) {
        // debugPrint('miniplayer.processingState: ${snapshot.data}');
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
                child: GestureDetector(
                  onTap: () {
                    showModalBottomSheet(
                      context: context,
                      builder: (context) => const PlayerView(),
                    );
                  },
                  child: StreamBuilder<int?>(
                      stream: handler.playbackState
                          .map((e) => e.queueIndex)
                          .distinct(),
                      builder: (context, snapshot) {
                        final tag = handler.getCurrentTag();
                        // debugPrint('tag: $tag');
                        return Text(
                          tag?.title ?? "",
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontWeight: FontWeight.w500,
                            color: Theme.of(context)
                                .colorScheme
                                .onSecondaryContainer,
                          ),
                        );
                      }),
                ),
              ),
              // const PlayButton(),
              buildPlayButton(handler),
            ],
          ),
        );
      } else {
        return const SizedBox(height: 0.0);
      } // show nothing when no sequence is on stage
    },
  );
}
