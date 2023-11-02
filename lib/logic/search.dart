import 'package:flutter/material.dart';
import 'package:loqueapp/services/pcidx.dart';
import 'package:loqueapp/services/rss.dart';

import '../models/channel.dart';
import '../services/sharedprefs.dart';

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
}
