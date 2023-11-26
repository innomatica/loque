import 'package:flutter/material.dart';
import 'package:flutter_widget_from_html_core/flutter_widget_from_html_core.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../helpers/widgets.dart';
import '../../models/episode.dart';

class EpisodePage extends StatefulWidget {
  final Episode episode;
  const EpisodePage(this.episode, {super.key});

  @override
  State<EpisodePage> createState() => _EpisodePageState();
}

class _EpisodePageState extends State<EpisodePage> {
  Widget _buildBody(BuildContext context) {
    // debugPrint('episode:${widget.episode.toString()}');
    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Column(
          children: [
            // title block
            Row(
              children: [
                // episode image
                LoqueImage(
                  widget.episode.imageUrl,
                  width: 90.0,
                  height: 90.0,
                ),
                const SizedBox(width: 8.0),
                // title, published, ...
                Expanded(
                  child: SizedBox(
                    height: 90.0,
                    child: Stack(
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          // mainAxisAlignment: MainAxisAlignment.spaceAround,
                          children: [
                            // title
                            Text(
                              widget.episode.title,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 16.0,
                                fontWeight: FontWeight.w500,
                                letterSpacing: 0.0,
                                color: Theme.of(context).colorScheme.tertiary,
                              ),
                            ),
                            // published
                            Text(
                              widget.episode.published.toString().split('.')[0],
                              style: const TextStyle(fontSize: 14.0),
                            ),
                            // media  duration
                            Text(
                              widget.episode.getDurationString(),
                              style: const TextStyle(fontSize: 14.0),
                            ),
                          ],
                        ),
                        Positioned(
                          right: 0,
                          bottom: 0,
                          child: IconButton(
                            icon: const Icon(Icons.link_rounded),
                            onPressed: widget.episode.link?.isEmpty == true
                                ? null
                                : () =>
                                    launchUrl(Uri.parse(widget.episode.link!)),
                          ),
                        )
                      ],
                    ),
                  ),
                ),
              ],
            ),
            const Divider(),
            // content
            HtmlWidget(
              widget.episode.description ?? '',
              onTapUrl: (url) => launchUrl(Uri.parse(url)),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // debugPrint(widget.episode.toString());
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
                widget.episode.channelTitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w500,
                  // letterSpacing: 0.0,
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
            onPressed: () => Share.share(widget.episode.mediaUrl),
          )
        ],
      ),
      body: _buildBody(context),
    );
  }
}
