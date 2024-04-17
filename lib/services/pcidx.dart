import 'dart:convert';
// import 'dart:developer';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../models/channel.dart';
import '../models/episode.dart';
import '../settings/constants.dart';
import '../settings/secrets.dart';

enum PcIdxSearchType { term, title, person, music }

Future<String?> _fetchData(Uri url) async {
  String apiHeaderTime =
      (DateTime.now().millisecondsSinceEpoch ~/ 1000).toString();
  String authHash =
      sha1.convert(utf8.encode("$apiKey$apiSecret$apiHeaderTime")).toString();

  try {
    final res = await http.get(url, headers: {
      "User-Agent": "$appId/$appVersion",
      "X-Auth-Key": apiKey,
      "X-Auth-Date": apiHeaderTime,
      "Authorization": authHash,
    });
    // debugPrint('fetchData: ${res.body}');

    if (res.statusCode == 200) {
      return (res.body);
    }
  } catch (e) {
    debugPrint(e.toString());
  }
  return null;
}

Future<List<Channel>> searchPodcasts(
  String keyword, {
  int max = defaultMaxSearchResults,
  bool similar = true,
  PcIdxSearchType searchType = PcIdxSearchType.term,
}) async {
  String? apiPath;

  switch (searchType) {
    case PcIdxSearchType.title:
      apiPath = '/api/1.0/search/bytitle';
    case PcIdxSearchType.person:
      apiPath = '/api/1.0/search/byperson';
    case PcIdxSearchType.music:
      apiPath = '/api/1.0/search/music/byterm';
    default:
      apiPath = '/api/1.0/search/byterm';
  }

  final url = Uri(
    scheme: "https",
    host: apiHost,
    path: apiPath,
    queryParameters: {
      'q': keyword,
      'max': max.toString(),
      'similar': similar ? 'true' : 'false',
    },
  );
  // debugPrint(url.toString());

  final res = await _fetchData(url);
  if (res != null) {
    final decoded = jsonDecode(res);
    // note that it returns "true" / "false" instead of true / false
    if (decoded?['status'] == "true" && decoded?['feeds'] is List) {
      return decoded!['feeds']
          .map<Channel>((e) => Channel.fromPcIdx(e))
          .toList();
    }
  }
  return [];
}

Future<List<Channel>> getTrendingPodcasts({
  int daysSince = defaultTrendingDaysSince,
  int maxResults = defaultMaxSearchResults,
  String? language,
  String? categories,
}) async {
  String since = (DateTime.now()
              .subtract(Duration(days: daysSince))
              .millisecondsSinceEpoch ~/
          1000)
      .toString();
  final params = {'since': since, 'max': maxResults.toString()};

  if (categories != null && categories != "") {
    params["cat"] = categories.trim();
  }
  if (language != null && language != "") {
    params['lang'] = language;
  }
  // debugPrint('params: $params');

  final url = Uri(
    scheme: "https",
    host: apiHost,
    path: '/api/1.0/podcasts/trending',
    queryParameters: params,
  );

  final res = await _fetchData(url);
  // debugPrint('getTrendingPodcasts: ${url.toString()}, $res');
  if (res != null) {
    final decoded = jsonDecode(res);
    // note that it returns "true" / "false" instead of true / false
    if (decoded?['status'] == "true" && decoded?['feeds'] is List) {
      return decoded!['feeds']
          .map<Channel>((e) => Channel.fromPcIdx(e))
          .toList();
    }
  }
  return <Channel>[];
}

Future<List<Channel>> getPodcastByFeedId(int feedId) async {
  final url = Uri(
    scheme: "https",
    host: apiHost,
    path: '/api/1.0/podcasts/byfeedid',
    query: 'id=$feedId',
  );

  // debugPrint(url.toString());

  final res = await _fetchData(url);
  if (res != null) {
    final decoded = jsonDecode(res);
    // note that it returns "true" / "false" instead of true / false
    if (decoded?['status'] == "true" && decoded?['feeds'] is List) {
      return decoded!['feeds']
          .map<Channel>((e) => Channel.fromPcIdx(e))
          .toList();
    }
  }
  return <Channel>[];
}

Future<Channel?> getPodcastByFeedUrl(String feedUrl) async {
  final url = Uri(
    scheme: "https",
    host: apiHost,
    path: '/api/1.0/podcasts/byfeedurl',
    query: 'url=$feedUrl',
  );
  // debugPrint(url.toString());

  final res = await _fetchData(url);
  // debugPrint(res.toString());
  if (res != null) {
    final decoded = jsonDecode(res);
    // note that it returns "true" / "false" instead of true / false
    if (decoded?['status'] == "true" &&
        decoded?['feed'] is Map<String, dynamic>) {
      return Channel.fromPcIdx(decoded['feed']);
    }
  }
  return null;
}

Future<List<Episode>> getEpisodesFromPcIdx(
  Channel channel, {
  int daysSince = defaultDataRetentionPeriod,
  // int max = defaultMaxSearchResults,
  // bool fulltext = true,
}) async {
  if (channel.source != PodcastSource.pcidx) {
    throw Exception('getEpisodesFromPcIdx: invalid channel type');
  }
  String since = (DateTime.now()
              .subtract(Duration(days: daysSince))
              .millisecondsSinceEpoch ~/
          1000)
      .toString();
  final url = Uri(
    scheme: "https",
    host: apiHost,
    path: '/api/1.0/episodes/byfeedid',
    query: 'id=${channel.info["id"]}&since=$since&fulltext',
    // NOTE: max parameter has no meaning where since parameter exists
    // query: 'id=${channel.info["id"]}&since=$since&max=$max&fulltext',
    // queryParameters: {
    //   'id': channel.info["id"].toString(),
    //   'since': since,
    //   'max': max.toString(),
    //   // 'fulltext': fulltext,
    // },
  );
  // debugPrint(url.toString());

  final res = await _fetchData(url);
  if (res != null) {
    final decoded = jsonDecode(res);

    // log('decoded: $decoded');
    // note that it returns "true" / "false" instead of true / false
    if (decoded?['status'] == "true" && decoded?['items'] is List) {
      return decoded!['items']
          .map<Episode>((e) => Episode.fromPcIdx(e, channel))
          .toList();
    }
  }
  return <Episode>[];
}
