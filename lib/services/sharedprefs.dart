import 'package:shared_preferences/shared_preferences.dart';

import '../settings/constants.dart';

class SharedPrefsService {
  // SharedPrefsService._private();

  // static final SharedPrefsService _instance = SharedPrefsService._private();

  // factory SharedPrefsService() {
  //   return _instance;
  // }

  static late final SharedPreferences _prefs;

  static int get dataRetentionPeriod =>
      _prefs.getInt(spKeyDataRetentionPeriod) ?? defaultDataRetentionPeriod;
  static int get maxSearchResults =>
      _prefs.getInt(spKeyMaxSearchResults) ?? defaultMaxSearchResults;
  static String get searchEngine =>
      _prefs.getString(spKeySearchEngine) ?? defaultSearchEngine;

  static set dataRetentionPeriod(int value) => setDataRetentionPeriod(value);
  static set maxSearchResults(int value) => setMaxSearchResults(value);
  static set searchEngine(String value) => setSearchEngine(value);

  static String getSeachEngineUrl(String query) {
    final searchEngine =
        _prefs.getString(spKeySearchEngine) ?? defaultSearchEngine;
    // logDebug('searchEngine:$searchEngine');
    switch (searchEngine) {
      case 'Google':
        return 'https://google.com/search?q=$query+podcast+rss';
      case 'Bing':
        return 'https://bing.com/search?q=$query+podcast+rss';
      default:
        return 'https://duckduckgo.com/?q=$query+podcast+rss';
    }
  }

  static Future init() async {
    _prefs = await SharedPreferences.getInstance();
  }

  static List<String>? getPlaylist() {
    return _prefs.getStringList(spKeyPlayListIds);
  }

  static int? getDataRetentionPeriod() {
    return _prefs.getInt(spKeyDataRetentionPeriod);
  }

  static Future savePlaylist(List<String> playlist) async {
    await _prefs.setStringList(spKeyPlayListIds, playlist);
  }

  static Future setDataRetentionPeriod(int value) async {
    await _prefs.setInt(spKeyDataRetentionPeriod, value);
  }

  static Future setMaxSearchResults(int value) async {
    await _prefs.setInt(spKeyMaxSearchResults, value);
  }

  static Future setSearchEngine(String value) async {
    await _prefs.setString(spKeySearchEngine, value);
  }
}
