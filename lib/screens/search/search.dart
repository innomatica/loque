import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../helpers/logger.dart';
import '../../helpers/widgets.dart';
import '../../logic/search.dart';
import '../../models/channel.dart';
import 'browser.dart';

class SearchPage extends StatefulWidget {
  const SearchPage({super.key});

  @override
  State<SearchPage> createState() => _SearchPageState();
}

enum InputBox { keyword, rssfeed, websrch, none }

class _SearchPageState extends State<SearchPage> {
  final _keywordController = TextEditingController();
  final _rssfeedController = TextEditingController();
  final _scrollController = ScrollController();
  String _keywords = '';
  bool _loading = false;
  InputBox _showInputBox = InputBox.none;

  @override
  void dispose() {
    _keywordController.dispose();
    _rssfeedController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  //
  // Trending Dialog
  //
  Future _searchTrending() async {
    String? language = "en";
    // do not support all categories option: takes too long
    // bool allCategorise = false;
    final categories = podcastCategories
        .map<Map<String, dynamic>>((e) => {"value": false, "title": e})
        .toList();
    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(builder: (context, setState) {
          return AlertDialog(
            // titlePadding: const EdgeInsets.only(top: 12.0, left: 8.0),
            contentPadding:
                const EdgeInsets.only(left: 8.0, top: 16.0, bottom: 8.0),
            actionsPadding: const EdgeInsets.only(
                left: 8.0, right: 12.0, top: 4.0, bottom: 16.0),
            content: SizedBox(
              width: double.maxFinite,
              //
              // Category Checkboxes
              //
              child: ListView(
                // shrinkWrap: true,
                children: categories
                    .map(
                      (e) => CheckboxListTile(
                        visualDensity: VisualDensity.compact,
                        title: Text(e['title'] as String),
                        value: e['value'],
                        onChanged: (value) {
                          setState(() {
                            e["value"] = value ?? false;
                          });
                        },
                      ),
                    )
                    .toList(),
              ),
            ),
            actions: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  //
                  // languages
                  //
                  DropdownButton<String>(
                    value: language,
                    isDense: true,
                    items: podcastLanguage.keys
                        .map<DropdownMenuItem<String>>(
                          (e) => DropdownMenuItem(
                            value: podcastLanguage[e],
                            child: Text(
                              e,
                              style: const TextStyle(fontSize: 13.0),
                            ),
                          ),
                        )
                        .toList(),
                    onChanged: (value) {
                      language = value;
                      setState(() {});
                      // logDebug(language);
                    },
                  ),
                  // search button
                  FilledButton(
                    onPressed: () {
                      Navigator.of(context).pop({
                        "categories": categories
                            .where((e) => e['value'] == true)
                            .map((e) => e['title'])
                            .join(','),
                        "language": language,
                      });
                      // Navigator.of(context).pop(allCategorise
                      //     ? {"language": language}
                      //     : {
                      //         "categories": categories
                      //             .where((e) => e['value'] == true)
                      //             .map((e) => e['title'])
                      //             .join(','),
                      //         "language": language,
                      //       });
                    },
                    child: const Text('search'),
                  )
                ],
              ),
            ],
          );
        });
      },
    ).then((value) async {
      // logDebug('value: $value');
      if (value != null &&
          value['categories'] is String &&
          value['categories'].isNotEmpty) {
        setState(() => _loading = true);
        final search = context.read<SearchLogic>();
        await search.trendingPodcastsByLangCat(
          value['language'],
          value['categories'],
        );
        _scrollController.jumpTo(0);
        setState(() => _loading = false);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final channels = context.watch<SearchLogic>().channels;
    final iconColor = Theme.of(context).colorScheme.secondary;
    final accentColor = Theme.of(context).colorScheme.primary;
    return Scaffold(
      appBar: AppBar(title: const Text('Search Podcasts')),
      body: Column(
        children: [
          //
          // keyword search
          //
          ListTile(
            onTap: () => setState(() {
              _showInputBox = _showInputBox == InputBox.keyword
                  ? InputBox.none
                  : InputBox.keyword;
            }),
            visualDensity: VisualDensity.compact,
            iconColor: iconColor,
            leading: const Icon(Icons.search_rounded),
            title: Row(
              children: [
                const Text('PodcastIndex'),
                Text(' Keyword ', style: TextStyle(color: accentColor)),
                const Text('Search'),
              ],
            ),
            subtitle: _showInputBox == InputBox.keyword
                ? TextField(
                    controller: _keywordController,
                    decoration: InputDecoration(
                      isDense: true,
                      hintText: "technology, business, ...",
                      suffixIcon: InkWell(
                        child: Icon(Icons.check, size: 28.0, color: iconColor),
                        onTap: () async {
                          if (_keywordController.text.isNotEmpty) {
                            setState(() {
                              _loading = true;
                              _showInputBox = InputBox.none;
                            });
                            final logic = context.read<SearchLogic>();
                            await logic.searchPodcastsByKeyword(
                                _keywordController.text);
                            _scrollController.jumpTo(0);
                            setState(() => _loading = false);
                          }
                          _keywordController.clear();
                          FocusManager.instance.primaryFocus?.unfocus();
                        },
                      ),
                    ),
                  )
                : null,
          ),
          //
          // Trending
          //
          ListTile(
            onTap: () => setState(() {
              _showInputBox = InputBox.none;
              _searchTrending();
            }),
            visualDensity: VisualDensity.compact,
            iconColor: iconColor,
            leading: const Icon(Icons.trending_up_rounded),
            title: Row(
              children: [
                const Text('On'),
                Text(' Trending ', style: TextStyle(color: accentColor)),
                const Text('in PodcastIndex'),
              ],
            ),
          ),
          //
          // Curated
          //
          ListTile(
            onTap: () async {
              setState(() {
                _showInputBox = InputBox.none;
                _loading = true;
              });
              final search = context.read<SearchLogic>();
              await search.getCuratedList();
              setState(() => _loading = false);
            },
            visualDensity: VisualDensity.compact,
            iconColor: iconColor,
            leading: const Icon(Icons.favorite_border_rounded),
            title: Row(
              children: [
                const Text('Try Loque'),
                Text(' Favorites', style: TextStyle(color: accentColor)),
              ],
            ),
          ),
          //
          // RSS URL
          //
          ListTile(
            onTap: () => setState(() {
              _showInputBox = _showInputBox == InputBox.rssfeed
                  ? InputBox.none
                  : InputBox.rssfeed;
            }),
            visualDensity: VisualDensity.compact,
            iconColor: iconColor,
            leading: const Icon(Icons.rss_feed_rounded),
            title: Row(
              children: [
                const Text('I know the'),
                Text(' Feed URL', style: TextStyle(color: accentColor)),
              ],
            ),
            subtitle: _showInputBox == InputBox.rssfeed
                ? TextField(
                    controller: _rssfeedController,
                    decoration: InputDecoration(
                      isDense: true,
                      hintText: "https://example.com/rss",
                      suffixIcon: InkWell(
                        child: Icon(Icons.check, size: 28.0, color: iconColor),
                        onTap: () async {
                          if (_rssfeedController.text.isNotEmpty) {
                            logDebug("url: ${_rssfeedController.text}");
                            setState(() => _loading = true);
                            final logic = context.read<SearchLogic>();
                            final flag = await logic
                                .getChannelDataFromRss(_rssfeedController.text);
                            if (flag == false) {
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    backgroundColor: Theme.of(context)
                                        .colorScheme
                                        .primaryContainer,
                                    content: Text(
                                      'Failed to find podcast... Check the URL',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: Theme.of(context)
                                            .colorScheme
                                            .onPrimaryContainer,
                                      ),
                                    ),
                                  ),
                                );
                              }
                            } else {
                              setState(() {
                                _showInputBox = InputBox.none;
                              });
                            }
                            setState(() => _loading = false);
                          }
                          _rssfeedController.clear();
                          FocusManager.instance.primaryFocus?.unfocus();
                        },
                      ),
                    ),
                  )
                : null,
          ),
          //
          // Browse and Find
          //
          ListTile(
            onTap: () => setState(() {
              _showInputBox = _showInputBox == InputBox.websrch
                  ? InputBox.none
                  : InputBox.websrch;
            }),
            visualDensity: VisualDensity.compact,
            iconColor: iconColor,
            leading: const Icon(Icons.public_rounded),
            title: Row(
              children: [
                Text('Browse and Find ', style: TextStyle(color: accentColor)),
                const Text('the Feed'),
              ],
            ),
            subtitle: _showInputBox == InputBox.websrch
                ? TextField(
                    onChanged: (value) => _keywords = value,
                    decoration: InputDecoration(
                      isDense: true,
                      hintText: "leadership, culture, ...",
                      suffixIcon: InkWell(
                        child: Icon(Icons.check, size: 28.0, color: iconColor),
                        onTap: () async {
                          FocusManager.instance.primaryFocus?.unfocus();
                          if (_keywords.isNotEmpty) {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                  builder: (context) => Browser(_keywords)),
                            );
                          }
                        },
                      ),
                    ),
                  )
                : null,
          ),
          //
          // Import Google OPML
          //
          ListTile(
            onTap: () async {
              _showInputBox = InputBox.none;
              FilePickerResult? result = await FilePicker.platform.pickFiles();
              if (result != null) {
                setState(() => _loading = true);
                File file = File(result.files.single.path!);
                logDebug('file: $file');
                if (context.mounted) {
                  final search = context.read<SearchLogic>();
                  await search.importFromGooglePodcast(file);
                }
                setState(() => _loading = false);
              }
            },
            visualDensity: VisualDensity.compact,
            iconColor: iconColor,
            leading: const Icon(Icons.podcasts_rounded),
            title: Row(
              children: [
                Text('Import ', style: TextStyle(color: accentColor)),
                const Text('data from Google Podcast'),
              ],
            ),
          ),

          //
          // search results
          //
          Expanded(
            child: Stack(
              children: [
                ListView.builder(
                  controller: _scrollController,
                  // shrinkWrap: true,
                  itemCount: channels.length,
                  itemBuilder: (context, index) => ChannelTile(channels[index]),
                ),
                _loading
                    ? const Center(
                        child: SizedBox(
                          width: 20.0,
                          height: 20.0,
                          child: CircularProgressIndicator(),
                        ),
                      )
                    : Container(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
