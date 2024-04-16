import 'package:flutter/material.dart';
import 'package:loqueapp/services/pcidx.dart';
import 'package:loqueapp/services/rss.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../helpers/widgets.dart';
import '../../logic/loque.dart';
import '../../models/channel.dart';
import '../../models/episode.dart';
import '../../services/sharedprefs.dart';
import '../episode/episode.dart';

class ChannelPage extends StatefulWidget {
  final Channel channel;

  const ChannelPage(this.channel, {super.key});

  @override
  State<ChannelPage> createState() => _ChannelPageState();
}

class _ChannelPageState extends State<ChannelPage> {
  late final Future<List<Episode>> _episodes;

  @override
  void initState() {
    super.initState();
    _episodes = widget.channel.source == PodcastSource.pcidx
        ? getEpisodesFromPcIdx(widget.channel,
            daysSince: SharedPrefsService.dataRetentionPeriod)
        : getEpisodesFromRssChannel(widget.channel,
            daysSince: SharedPrefsService.dataRetentionPeriod);
    // debugPrint(widget.channel.toString());
  }

//
// Episode Tile for Searched Channels
//
  Widget _buildEpisodeTile(
    BuildContext context,
    Episode episode,
    bool isSubscribed,
  ) {
    // debugPrint('episode: $episode');
    const infoTextStyle = TextStyle(
      fontSize: 13.0,
      fontWeight: FontWeight.w600,
      letterSpacing: 0.0,
    );

    return ListTile(
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // info line
          Row(
            children: [
              // published
              Text(
                episode.published.toString().split(' ')[0],
                style: infoTextStyle,
              ),
              const SizedBox(width: 10),
              // media size
              // Text(episode.getBytesString(), style: infoTextStyle),
              // const SizedBox(width: 10),
              // media duration
              Text(episode.getDurationString(), style: infoTextStyle),
              const Expanded(child: SizedBox()),
              // play (dry run)
              InkWell(
                child: const Padding(
                  padding: EdgeInsets.symmetric(vertical: 0, horizontal: 0),
                  child: Icon(Icons.play_arrow_outlined),
                ),
                onTap: () {
                  final logic = context.read<LoqueLogic>();
                  // FIXME: dryRun has to be handled.
                  logic.play(episode);
                },
              ),
            ],
          ),
          // title
          Text(
            episode.title,
            style: TextStyle(
              // fontSize: 15.0,
              fontWeight: FontWeight.w500,
              letterSpacing: 0.0,
              color: Theme.of(context).colorScheme.primary,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
      subtitle: // description
          Text(
        episode.getDescription(),
        maxLines: 3,
        overflow: TextOverflow.ellipsis,
      ),
      onTap: () async {
        Navigator.of(context).push(
            MaterialPageRoute(builder: (context) => EpisodePage(episode)));
        // if (episode.link is String && episode.link!.isNotEmpty) {
        //   launchUrl(Uri.parse(episode.link!));
        // }
      },
    );
  }

  Widget _buildBody(BuildContext context) {
    bool isSubscribed = context
        .watch<LoqueLogic>()
        .channels
        .any((e) => e.id == widget.channel.id);
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: Column(
        children: [
          Row(
            children: [
              //
              // image
              //
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: LoqueImage(
                  widget.channel.imageUrl,
                  width: 100,
                  height: 100,
                ),
              ),
              //
              // Author and Categories
              //
              Flexible(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // author
                    Text(
                      widget.channel.author ?? "",
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.tertiary,
                        letterSpacing: 0.0,
                        fontSize: 18.0,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    // categories
                    Text(
                      widget.channel.categories?.join(',') ?? "",
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    // last update
                    Text(
                      widget.channel.lastUpdate.toString().split(' ')[0],
                      style: const TextStyle(fontWeight: FontWeight.w500),
                    ),
                    // number of episodes: almost always null
                    // Text(
                    //   widget.item.episodeCount.toString(),
                    //   style: sublabelTextStyle,
                    // ),
                    Row(
                      children: [
                        //
                        // subscription button
                        //
                        InputChip(
                          selected: isSubscribed,
                          onSelected: (value) {
                            final logic = context.read<LoqueLogic>();
                            if (value) {
                              logic.subscribe(widget.channel);
                            } else {
                              logic.unsubscribe(widget.channel);
                            }
                          },
                          visualDensity: VisualDensity.compact,
                          label: Text(
                            isSubscribed ? 'subscribed' : 'subscribe',
                            // style: const TextStyle(fontSize: 12.0),
                          ),
                        ),
                        // const SizedBox(width: 16.0),
                        // IconButton(
                        //   visualDensity: VisualDensity.compact,
                        //   icon: const Icon(Icons.home),
                        //   onPressed: widget.channel.link is String
                        //       ? () => launchUrl(Uri.parse(widget.channel.url))
                        //       : null,
                        // ),
                        // IconButton(
                        //   visualDensity: VisualDensity.compact,
                        //   icon: const Icon(Icons.share),
                        //   onPressed: () => Share.share(widget.channel.url),
                        // ),
                      ],
                    ),
                  ],
                ),
              )
            ],
          ),
          //
          // Description and Episodes
          //
          FutureBuilder(
            future: _episodes,
            builder: (context, snapshot) {
              return Flexible(
                child: snapshot.hasData
                    ? ListView(
                        children: [
                          // Description
                          Padding(
                            padding: const EdgeInsets.all(8.0),
                            child: Text(
                              widget.channel.getDescription(),
                              style: const TextStyle(fontSize: 15.0),
                            ),
                          ),
                          const Divider(),
                          // Episodes
                          ...snapshot.data!.map((e) =>
                              _buildEpisodeTile(context, e, isSubscribed)),
                        ],
                      )
                    : const Center(
                        child: SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(),
                        ),
                      ),
              );
            },
          )
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leadingWidth: 40,
        titleSpacing: 0,
        title: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.max,
          children: [
            Flexible(
              child: Text(
                widget.channel.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w500,
                  shadows: <Shadow>[
                    Shadow(
                      offset: Offset(0.5, 0.5),
                      blurRadius: 2.0,
                    )
                  ],
                ),
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.share_rounded),
            onPressed: () => Share.share(widget.channel.link?.isNotEmpty == true
                ? widget.channel.link!
                : widget.channel.url),
          )
        ],
      ),
      body: _buildBody(context),
      // https://github.com/flutter/flutter/issues/50314
      bottomNavigationBar: buildMiniPlayer(context),
    );
  }
}
