import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:http/http.dart' as http;

import '../../helpers/widgets.dart';
import '../../logic/search.dart';
import '../../models/channel.dart';
import '../../settings/constants.dart';
import 'browser.dart';

class SearchPage extends StatefulWidget {
  const SearchPage({super.key});

  @override
  State<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends State<SearchPage> {
  final _keywordController = TextEditingController();
  final _scrollController = ScrollController();
  bool loading = false;

  @override
  void dispose() {
    _keywordController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  //
  // Trending Dialog
  //
  Future searchTrending() async {
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
                      // debugPrint(language);
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
      // debugPrint('value: $value');
      if (value != null &&
          value['categories'] is String &&
          value['categories'].isNotEmpty) {
        setState(() {
          loading = true;
        });
        final search = context.read<SearchLogic>();
        await search.trendingPodcastsByLangCat(
          value['language'],
          value['categories'],
        );
        _scrollController.jumpTo(0);
        setState(() {
          loading = false;
        });
      }
    });
  }

  //
  // Show Curated List
  Future showCurated() async {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Loque Favorites'),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 4.0, vertical: 8.0),
        content: SizedBox(
          width: double.maxFinite,
          child: FutureBuilder(
              future: http.get(Uri.parse(urlCuratedData)),
              builder: (context, snapshot) {
                if (snapshot.hasData) {
                  final res = snapshot.data!;
                  if (res.statusCode == 200) {
                    final channels = jsonDecode(res.body);
                    final search = context.read<SearchLogic>();
                    return ListView.builder(
                      shrinkWrap: true,
                      itemCount: channels.length,
                      itemBuilder: (context, index) => Card(
                        child: ListTile(
                          title: Text(channels[index]["title"]),
                          subtitle: Text(
                            channels[index]["categories"],
                            style: TextStyle(
                                color: Theme.of(context).colorScheme.tertiary),
                          ),
                          onTap: () {
                            search.getPodcastByUrl(channels[index]['url']);
                          },
                        ),
                      ),
                    );
                  } else {
                    return const Text('Server failure');
                  }
                }
                return Container();
              }),
        ),
      ),
    );
  }

  //
  // Browser Dialog
  //
  Future browseAndFind() async {
    String keyword = '';
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        titlePadding: const EdgeInsets.all(0.0),
        contentPadding: const EdgeInsets.only(
          top: 0.0,
          left: 24,
          right: 24,
          bottom: 20,
        ),
        content: TextField(
          onChanged: (value) => keyword = value,
          decoration: InputDecoration(
            isDense: true,
            label: const Text('Enter keyword'),
            suffix: IconButton(
              onPressed: () {
                Navigator.of(context).pop({"keyword": keyword});
              },
              icon: const Icon(Icons.check_rounded),
            ),
          ),
        ),
      ),
    ).then((value) async {
      if (value != null) {
        Navigator.of(context).push(
          MaterialPageRoute(builder: (context) => Browser(value['keyword'])),
        );
      }
    });
  }

  //
  // RSS Dialog
  //
  Future enterRssUrl() async {
    String url = '';
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        titlePadding: const EdgeInsets.all(0.0),
        contentPadding: const EdgeInsets.only(
          top: 0.0,
          left: 24,
          right: 24,
          bottom: 20,
        ),
        content: TextField(
          onChanged: (value) => url = value,
          decoration: InputDecoration(
            isDense: true,
            label: const Text('Enter RSS URL'),
            suffix: IconButton(
              onPressed: () {
                if (url.isNotEmpty) {
                  // debugPrint('url: $url');
                  Navigator.of(context).pop({"url": url});
                }
              },
              icon: const Icon(Icons.check_rounded),
            ),
          ),
        ),
      ),
    ).then((value) async {
      // debugPrint('value: $value');
      if (value != null) {
        final logic = context.read<SearchLogic>();
        final flag = await logic.getChannelDataFromRss(value['url']);
        if (flag == false) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                backgroundColor: Theme.of(context).colorScheme.primaryContainer,
                content: Text(
                  'Failed to find podcast... Check URL',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.onPrimaryContainer,
                  ),
                ),
              ),
            );
          }
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final channels = context.watch<SearchLogic>().channels;
    return Scaffold(
      appBar: AppBar(title: const Text('Search Podcasts')),
      body: Column(
        children: [
          //
          // search text box
          //
          Padding(
            padding:
                const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
            child: TextField(
              controller: _keywordController,
              decoration: InputDecoration(
                isDense: true,
                border:
                    OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                prefixIcon: _keywordController.text.isEmpty
                    ? null
                    : InkWell(
                        child: Icon(
                          Icons.close,
                          size: 28.0,
                          color: Theme.of(context).colorScheme.error,
                        ),
                        onTap: () {
                          FocusManager.instance.primaryFocus?.unfocus();
                          _keywordController.text = '';
                          setState(() {});
                        },
                      ),
                suffixIcon: InkWell(
                  child: Icon(
                    Icons.search,
                    size: 28.0,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  onTap: () async {
                    if (_keywordController.text.isNotEmpty) {
                      setState(() {
                        loading = true;
                      });
                      final logic = context.read<SearchLogic>();
                      FocusManager.instance.primaryFocus?.unfocus();
                      await logic
                          .searchPodcastsByKeyword(_keywordController.text);
                      _scrollController.jumpTo(0);
                      setState(() {
                        loading = false;
                      });
                    }
                  },
                ),
              ),
            ),
          ),
          //
          // Button Bar
          //
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              //
              // Trending
              //
              FilledButton.tonal(
                onPressed: searchTrending,
                // child: const Text("Trending"),
                child: const Icon(Icons.trending_up_rounded),
              ),
              //
              // Trending
              //
              FilledButton.tonal(
                onPressed: showCurated,
                // child: const Text("Trending"),
                child: const Icon(Icons.favorite_border_outlined),
              ),
              //
              // RSS
              //
              FilledButton.tonal(
                onPressed: enterRssUrl,
                // child: const Text("Browse and Find"),
                child: const Icon(Icons.rss_feed_rounded),
              ),
              //
              // Search Web
              //
              FilledButton.tonal(
                onPressed: browseAndFind,
                // child: const Text("Browse and Find"),
                child: const Icon(Icons.public_rounded),
              ),
            ],
          ),
          const SizedBox(height: 8.0),
          //
          // search results
          //
          Expanded(
            child: Stack(
              children: [
                ListView.builder(
                  controller: _scrollController,
                  itemCount: channels.length,
                  itemBuilder: (context, index) => ChannelTile(channels[index]),
                ),
                loading
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
