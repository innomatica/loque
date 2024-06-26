import 'package:audio_service/audio_service.dart';
import 'package:flutter/material.dart';

import 'package:provider/provider.dart';

import '../../helpers/widgets.dart';
import '../../logic/loque.dart';
import '../../models/episode.dart';
import '../episode/episode.dart';

const chipWidth = 100.0;

class EpisodesView extends StatefulWidget {
  const EpisodesView({super.key});

  @override
  State<EpisodesView> createState() => _EpisodesViewState();
}

class _EpisodesViewState extends State<EpisodesView> {
  Widget _buildEpisodeTile(BuildContext context, Episode episode) {
    // logDebug('episode: $episode');
    final logic = context.read<LoqueLogic>();
    final styleColor0 = episode.played ? Theme.of(context).disabledColor : null;
    final styleColor2 = episode.played
        ? Theme.of(context).disabledColor
        : Theme.of(context).colorScheme.tertiary;
    // : Colors.amber;
    const chipVisualDensity = VisualDensity(horizontal: -4, vertical: -4);
    //
    // Episode Tile
    //
    return Padding(
      padding: const EdgeInsets.only(
          top: 16.0, left: 12.0, right: 12.0, bottom: 4.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            onTap: () {
              Navigator.of(context).push(MaterialPageRoute(
                  builder: (context) => EpisodePage(episode)));
            },
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                //
                // channel block
                //
                Row(
                  children: [
                    LoqueImage(episode.channelImageUrl,
                        width: 40, height: 40, disabled: episode.played),
                    const SizedBox(width: 8.0),
                    Flexible(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // channel title
                          Text(
                            episode.channelTitle,
                            style: TextStyle(
                              // fontSize: 14.0,
                              letterSpacing: 0.0,
                              fontWeight: FontWeight.w500,
                              color: styleColor2,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          // last update
                          Text(
                            episode.published.toString().split(' ')[0],
                            style: TextStyle(
                              // fontSize: 14.0,
                              letterSpacing: 0.0,
                              // fontWeight: FontWeight.w500,
                              color: styleColor0,
                            ),
                          )
                        ],
                      ),
                    ),
                  ],
                ),
                //
                const SizedBox(height: 4.0),
                //
                // episode title
                //
                Text(
                  episode.title,
                  style: TextStyle(
                    fontSize: 16.0,
                    letterSpacing: 0.0,
                    fontWeight: FontWeight.w500,
                    color: styleColor0,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          //
          // Buttons
          //
          StreamBuilder<PlaybackState>(
              stream: logic.playbackState,
              builder: (context, snapshot) {
                final state = snapshot.data;
                final tag = logic.currentMedia;
                return Row(
                  children: [
                    //
                    // play button chip
                    //
                    episode.id == tag?.extras?['episodeId'] &&
                            state?.playing == true
                        // currently playing
                        ? ActionChip(
                            visualDensity: chipVisualDensity,
                            avatar: Icon(
                              Icons.pause_rounded,
                              color: Theme.of(context).colorScheme.onPrimary,
                            ),
                            label: SizedBox(
                              width: chipWidth,
                              child: Text(
                                'now playing',
                                style: TextStyle(
                                  fontWeight: FontWeight.w500,
                                  fontSize: 14.0,
                                  color:
                                      Theme.of(context).colorScheme.onPrimary,
                                ),
                              ),
                            ),
                            side: BorderSide.none,
                            backgroundColor:
                                Theme.of(context).colorScheme.primary,
                            onPressed: () async => await logic.pause(),
                          )
                        // not playing => start playing
                        : (episode.mediaSeekPos ?? 0) > 0
                            // played before but paused
                            ? ActionChip(
                                visualDensity: chipVisualDensity,
                                avatar:
                                    const Icon(Icons.slow_motion_video_rounded),
                                label: SizedBox(
                                    width: chipWidth,
                                    child: Text(episode.getDurationString())),
                                // side: BorderSide.none,
                                onPressed: episode.played
                                    ? null
                                    : () => logic.play(episode),
                              )
                            // hasn't been played yet
                            : ActionChip(
                                visualDensity: chipVisualDensity,
                                avatar: const Icon(Icons.play_circle_rounded),
                                label: SizedBox(
                                    width: chipWidth,
                                    child: Text(episode.getDurationString())),
                                // side: BorderSide.none,
                                onPressed: episode.played
                                    ? null
                                    : () async => logic.play(episode),
                              ),
                    const Expanded(child: SizedBox()),
                    //
                    // liked
                    //
                    IconButton(
                      icon: episode.liked
                          ? const Icon(Icons.thumb_up_alt)
                          : const Icon(Icons.thumb_up_alt_outlined),
                      onPressed: () async =>
                          await logic.toggleLiked(episode.id),
                    ),
                    //
                    // playlist add
                    //
                    IconButton(
                      icon: const Icon(Icons.playlist_add_rounded),
                      onPressed: logic.isInPlaylist(episode.id)
                          ? null
                          : () async =>
                              await logic.addEpisodeToPlaylist(episode),
                    ),
                    //
                    // played
                    //
                    IconButton(
                      onPressed: episode.played
                          ? () async => await logic.clearPlayed(episode.id)
                          : () async {
                              await logic.setPlayed(episode.id);
                              if (episode.id == logic.currentEpisodeId) {
                                // currently playing => DON'T do anything
                              } else {
                                // if it is on the playlist remove it
                                await logic
                                    .removePlaylistItemByEpisodeId(episode.id);
                              }
                            },
                      icon: episode.played
                          ? const Icon(Icons.unpublished_outlined)
                          : const Icon(Icons.check_circle_outline),
                    ),
                  ],
                );
              }),
        ],
      ),
    );
  }

  Widget _buildLogo(BuildContext context) {
    return Center(
      child: IconButton(
        onPressed: () => context.read<LoqueLogic>().refreshEpisodes(),
        icon: Image.asset(
          'assets/images/podcast-512.png',
          width: 100,
          height: 100,
          fit: BoxFit.cover,
          color: Colors.grey.withOpacity(0.7),
          colorBlendMode: BlendMode.dstIn,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final episodes = context.watch<LoqueLogic>().episodes;
    // logDebug('episodes: $episodes');
    return episodes.isNotEmpty
        ? RefreshIndicator(
            onRefresh: () => context.read<LoqueLogic>().refreshEpisodes(),
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: 4.0),
              itemCount: episodes.length,
              itemBuilder: (context, index) =>
                  _buildEpisodeTile(context, episodes[index]),
              separatorBuilder: (context, index) => Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20.0),
                child: Divider(
                  height: 0,
                  thickness: 0,
                  color:
                      Theme.of(context).colorScheme.secondary.withOpacity(0.3),
                ),
              ),
            ),
          )
        : _buildLogo(context);
  }
}
