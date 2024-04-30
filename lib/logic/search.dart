import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../models/channel.dart';
import '../services/pcidx.dart';
import '../services/rss.dart';
import '../services/sharedprefs.dart';
import '../settings/constants.dart';

class SearchLogic extends ChangeNotifier {
  // SearchLogic() {
  //   _initData();
  // }
  SearchLogic();

  final _channels = <Channel>[];

  List<Channel> get channels => _channels;

  // https://podcastindex-org.github.io/docs-api/#get-/search/byterm
  Future searchPodcastsByKeyword(String keyword) async {
    final res = await searchPodcasts(keyword);
    _channels.clear();
    _channels.addAll(res);
    notifyListeners();
  }

  // https://podcastindex-org.github.io/docs-api/#get-/podcasts/trending
  Future trendingPodcastsByLangCat(
    String language,
    String categories,
  ) async {
    final res = await getTrendingPodcasts(
      language: language,
      categories: categories,
      daysSince: SharedPrefsService.dataRetentionPeriod,
      maxResults: SharedPrefsService.maxSearchResults,
    );
    // logDebug('trending:$language, $categories, $res');
    _channels.clear();
    _channels.addAll(res);
    notifyListeners();
  }

  //
  // Get channel data from RSS URL
  //
  Future<bool> getChannelDataFromRss(String url) async {
    final channel = await getChannelFromRssUrl(url);
    if (channel != null) {
      _channels.clear();
      _channels.add(channel);
      notifyListeners();
      return true;
    }
    return false;
  }

  //
  // Get channel(s) by Url
  //
  Future getPodcastByUrl(String url) async {
    final res = await getPodcastByFeedUrl(url);
    // logDebug('getPodcastByUrl: $res');
    if (res is Channel) {
      // check duplication
      final idx = _channels.indexWhere((c) => c.id == res.id);
      if (idx == -1) {
        _channels.insert(0, res);
        notifyListeners();
      }
    }
  }

  //
  // Get curated list
  //
  Future getCuratedList() async {
    final res = await http.get(Uri.parse(urlCuratedData));
    if (res.statusCode == 200) {
      final channels = jsonDecode(res.body);
      _channels.clear();
      for (final channel in channels.reversed.toList()) {
        final res = await getPodcastByFeedUrl(channel['url']);
        if (res is Channel) {
          _channels.insert(0, res);
          notifyListeners();
        }
      }
    } else {
      // fail to fetch
    }
  }
}
