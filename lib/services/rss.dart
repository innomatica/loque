import 'dart:convert';

import 'package:feed_parser/feed_parser.dart';
import 'package:http/http.dart' as http;

import '../helpers/logger.dart';
import '../models/channel.dart';
import '../models/episode.dart';
import '../settings/constants.dart';

final feedSignatures = <String>['<rss', '<feed'];

Future<Channel?> getChannelFromRssUrl(String url) async {
  if (url.startsWith('http://')) {
    // reject if no TLS
    return null;
  } else if (!url.startsWith('https://')) {
    // add https:// if none provided
    url = 'https://$url';
  }

  try {
    final res = await http.get(Uri.parse(url));
    // logDebug('res.body: ${res.body}');
    if (res.statusCode < 400 &&
        feedSignatures.any((element) => res.body.contains(element))) {
      try {
        final utf8String = utf8.decode(res.bodyBytes, allowMalformed: true);
        final feedData = FeedData.parse(utf8String);

        return Channel.fromRssFeed(feedData, url);
      } catch (e) {
        logError(e.toString());
      }
    }
  } catch (e) {
    logError(e.toString());
  }
  return null;
}

Future<List<Episode>> getEpisodesFromRssChannel(
  Channel channel, {
  int daysSince = defaultDataRetentionPeriod,
}) async {
  if (channel.source != PodcastSource.rss) {
    throw Exception('getEpisodesFromRssChannel: invalid channel type');
  }

  List<Episode> episodes = [];

  try {
    final res = await http.get(Uri.parse(channel.url));
    if (res.statusCode < 400) {
      // logDebug(res.body);
      try {
        final utf8String = utf8.decode(res.bodyBytes, allowMalformed: true);
        final feedData = FeedData.parse(utf8String);
        if (feedData.items != null) {
          for (final item in feedData.items!) {
            if (item.updated != null &&
                item.updated!.isAfter(
                    DateTime.now().subtract(Duration(days: daysSince)))) {
              episodes.add(Episode.fromRssData(item, channel));
            }
          }
        }
      } catch (e) {
        logError(e.toString());
      }
    }
  } catch (e) {
    logError(e.toString());
  }
  return episodes;
}
