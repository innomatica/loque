import 'package:audio_service/audio_service.dart';
import 'package:audio_video_progress_bar/audio_video_progress_bar.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:loqueapp/services/audiohandler.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

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
        child: imageUrl != null && imageUrl != ''
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
// Episode Popup Menu Button
//
class EpisodeMenu extends StatelessWidget {
  final Episode episode;
  const EpisodeMenu(this.episode, {super.key});

  @override
  Widget build(BuildContext context) {
    final handler = context.read<LoqueAudioHandler>();

    return PopupMenuButton<String>(
      child: Icon(
        Icons.more_horiz,
        color: Theme.of(context).colorScheme.primary,
      ),
      itemBuilder: (context) {
        return <PopupMenuEntry<String>>[
          const PopupMenuItem<String>(
            value: 'played',
            child: Text('Mark as played'),
          ),
          const PopupMenuItem<String>(
            value: 'unplayed',
            child: Text('Mark as unplayed'),
          ),
          const PopupMenuItem<String>(
            value: 'share',
            child: Text('Share this episode'),
          ),
          const PopupMenuItem<String>(
            value: 'webpage',
            child: Text('Visit web page'),
          ),
        ];
      },
      onSelected: (item) {
        if (item == 'played') {
          handler.markPlayed(episode.id);
        } else if (item == 'unplayed') {
          handler.markUnplayed(episode.id);
        } else if (item == 'share') {
          Share.share('${episode.link}');
        } else if (item == 'webpage') {
          if (episode.link is String) {
            launchUrl(Uri.parse(episode.link!));
          }
        }
      },
    );
  }
}

//
// Play Button
//
StreamBuilder<bool> buildPlayButton(LoqueAudioHandler handler,
        {double? size, Color? color}) =>
    StreamBuilder<bool>(
      // stream: handler.playingStream,
      stream: handler.playbackState.map((s) => s.playing).distinct(),
      builder: (context, snapshot) {
        // debugPrint('snapshot:${snapshot.data}');
        return snapshot.hasData && snapshot.data == true
            ? IconButton(
                icon: Icon(Icons.pause_rounded, size: size, color: color),
                onPressed: () {
                  handler.pause();
                },
              )
            : IconButton(
                icon: Icon(Icons.play_arrow_rounded, size: size, color: color),
                onPressed: () {
                  handler.play();
                },
              );
      },
    );

//
// Forward 30 sec
//
IconButton buildForwardButton(LoqueAudioHandler handler, {double? size}) =>
    IconButton(
      icon: Icon(Icons.forward_30_rounded, size: size),
      onPressed: () => handler.fastForward(),
    );

//
// Rewind 30 sec
//
IconButton buildRewindButton(LoqueAudioHandler handler, {double? size}) =>
    IconButton(
      icon: Icon(Icons.replay_30_rounded, size: size),
      onPressed: () => handler.rewind(),
    );

//
// Playback Speed Button
//
const speeds = <double>[0.5, 0.8, 1.0, 1.2, 1.5];

StreamBuilder<double> buildSpeedSelector(LoqueAudioHandler handler) =>
    StreamBuilder<double>(
      stream: handler.playbackState.map((s) => s.speed).distinct(),
      builder: (context, snapshot) {
        return DropdownButton<double>(
          value: snapshot.data ?? 1.0,
          iconSize: 0,
          isDense: true,
          onChanged: (double? value) {
            handler.setSpeed(value ?? 1.0);
          },
          items: speeds.map<DropdownMenuItem<double>>((double value) {
            return DropdownMenuItem<double>(
              value: value,
              child: Text('$value x'),
            );
          }).toList(),
        );
      },
    );

//
// Progress Bar
//
StreamBuilder<Duration> buildProgressBar(LoqueAudioHandler handler) =>
    StreamBuilder<Duration>(
      // TODO: for some reason this stream does not work
      // stream: handler.playbackState.map((s) => s.updatePosition).distinct(),
      // but this does
      stream: handler.positionStream.distinct(),
      builder: (context, snapshot) {
        final total = handler.duration;
        final progress = snapshot.data ?? Duration.zero;
        return ProgressBar(
          progress: progress,
          buffered: progress,
          total: total,
          onSeek: (duration) => handler.seek(duration),
        );
      },
    );

String toTimeString(int? secs) {
  String timeStr = '';
  if (secs is int) {
    if (secs < 0) {
      timeStr = '00:00';
    } else if (secs < 10) {
      timeStr = '00:0$secs';
    } else if (secs < 60) {
      timeStr = '00:$secs';
    } else if (secs < 3600) {
      final mins = secs ~/ 60;
      final rems = secs % 60;
      if (mins < 10) {
        timeStr = '0$mins:';
      } else {
        timeStr = '$mins:';
      }
      if (rems < 10) {
        timeStr = '${timeStr}0$rems';
      } else {
        timeStr = '$timeStr$rems';
      }
    } else {
      final hrs = secs ~/ 3600;
      final mins = (secs % 3600) ~/ 60;
      final rems = secs % 60;
      if (mins < 10) {
        timeStr = '$hrs:0$mins:';
      } else {
        timeStr = '$hrs:$mins:';
      }
      if (rems < 10) {
        timeStr = '${timeStr}0$rems';
      } else {
        timeStr = '$timeStr$rems';
      }
    }
  }
  return timeStr;

  /*
    return secs is int
        ? secs < 60
            ? '$secs'
            : secs < 3600
                ? '${secs ~/ 60}:${secs % 60}'
                : '${secs ~/ 3600}:${(secs % 3600) ~/ 60}:${secs % 60}'
        : '';
    */
}

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
        // debugPrint('miniplayer.queueIndex: ${snapshot.data}');

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
