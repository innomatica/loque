import 'dart:convert';

import 'package:feed_parser/feed_parser.dart';

// import 'package:uuid/uuid.dart';
// const uuid = Uuid();

enum PodcastSource { pcidx, rss }

// https://github.com/Podcastindex-org/podcast-namespace/blob/main/categories.json
const podcastCategories = <String>[
  // "After-Shows",
  // "Alternative",
  "Animals",
  // "Animation",
  "Arts",
  // "Automotive",
  "Astronomy",
  // "Aviation",
  "Beauty",
  "Books",
  "Business",
  "Careers",
  "Chemistry",
  // "Commentary",
  // "Courses",
  // "Climate",
  // "Crafts",
  "Culture",
  "Comedy",
  // "Daily",
  // "Design",
  "Documentary",
  "Drama",
  "Earth",
  "Education",
  "Entertainment",
  // "Entrepreneurship",
  "Family",
  "Fashion",
  "Fantasy",
  "Fiction",
  "Film",
  // "Fitness",
  "Food",
  // "Games",
  "Garden",
  "Government",
  "Health",
  "History",
  "Hobbies",
  "Home",
  // "How-To",
  // "Improv",
  "Interviews",
  // "Investing",
  "Journals",
  "Kids",
  "Language",
  "Learning",
  "Leisure",
  "Life",
  "Management",
  // "Manga",
  "Marketing",
  "Mathematics",
  // "Medicine",
  "Mental",
  "Music",
  "Nutrition",
  // "Natural",
  "Nature",
  "News",
  "Non-Profit",
  "Parenting",
  // "Performing",
  "Personal",
  "Pets",
  "Philosophy",
  "Physics",
  // "Places",
  "Politics",
  // "Religion",
  "Relationships",
  "Reviews",
  "Science",
  // "Self-Improvement",
  "Sexuality",
  "Social",
  "Society",
  // "Spirituality",
  // "Sports",
  "Stand-up",
  "Stories",
  // "Tabletop",
  "Technology",
  "Travel",
  "True Crime",
  // "Video-Games",
  "Visual",
  // "Weather",
  // "Wilderness",
];

// https://www.rssboard.org/rss-language-codes
// https://en.wikipedia.org/wiki/List_of_language_names
const podcastLanguage = {
  "All languages": "",
  "akkadû": "af", // Afrikaans
  "Shqiptar": "q", // Albanian
  // "Euskara": "eu", // Basque
  "Беларуская": "be", // Belarusian
  "български език": "bg", // Bulgarian
  "Català": "ca", // Catalan
  "简体字": "zh-cn", // Chinese (Simplified)
  "正體字": "zh-tw", // Chinese (Traditional)
  "Hrvatski": "hr", // Croatian
  "Čeština": "cs", // Czech
  "Dansk": "da", // Danish
  "Nederlands": "nl", // Dutch
  "English": "en",
  "Eesti": "et", // Estonian
  // "Føroyskt": "fo", // Faroese
  "Suomi": "fi", // Finnish
  "Français": "fr", // French
  "Galego": "gl", // Galician
  // "Gaelic": "gd",
  // "Deutsch": "de", // German
  "Ελληνικά": "el", // Greek
  // "ʻŌlelo Hawaiʻi": "haw", // Hawaiian
  "Magyar": "hu", // Hungarian
  "Íslenska": "is", // Icelandic
  "Indonesian": "in", // Indonesian
  "Gaeilge": "ga", // Irish
  "Italiano": "it", // Italian
  "日本語": "ja",
  "한국어": "ko",
  "Mакедонски": "mk", // Macedonian
  "Norsk": "no", // Norgean
  "Język polski": "pl", // Polish
  "Português": "pt", // Portuguese
  "Română": "ro", // Romanian
  "Русский": "ru", // Rusian
  "Српски": "sr", // Serbian
  "Slovenčina": "sk", // Slovak
  "Slovenščina": "sl", // Slovene
  "Español": "es", // Spanish
  "Svenska": "sv", // Swedish
  "Türkçe": "tr", // Turkish
  "Українська": "uk", // Ukranian
};

class Channel {
  String id;
  String title;
  String url;
  PodcastSource source;
  Map<String, dynamic> info;

  String? link;
  String? description;
  String? author;
  String? imageUrl;
  DateTime? lastUpdate;
  String? language;
  List<String>? categories;

  Channel({
    required this.id,
    required this.title,
    required this.url,
    required this.source,
    required this.info,
    this.link,
    this.description,
    this.imageUrl,
    this.author,
    this.language,
    this.lastUpdate,
    this.categories,
  });

  factory Channel.fromPcIdx(Map<String, dynamic> feed) {
    final lastUpdate = feed['lastUpdateTime'] ?? feed['newestItemPublishTime'];

    if (feed['url'] is String && feed['url'].isNotEmpty) {
      return Channel(
        id: base64.encode(utf8.encode(feed['url'])),
        title: feed['title'] ?? "<Title Unknown>",
        url: feed['url'],
        link: feed['link'],
        description: feed['description'],
        author: feed['author'],
        imageUrl: feed['image'],
        lastUpdate: lastUpdate != null && lastUpdate is int
            ? DateTime.fromMillisecondsSinceEpoch(lastUpdate * 1000,
                isUtc: true)
            : null,
        language: feed['language'],
        // casting of List is no loger allowed
        categories: feed['categories']?.values.cast<String>().toList(),
        source: PodcastSource.pcidx,
        info: {
          "id": feed['id'],
          "itunesId": feed['itunesId'],
          // 'guid': feed['podcastGuid']
          "explicit": feed['explicit'],
          "feedType": feed['type'],
          "episodeCount": feed['episodeCount'],
        },
      );
    }
    throw Exception({
      "message": "invalid data from PodcastIndex: no url",
    });
  }

  factory Channel.fromRssFeed(FeedData feedData, String url) {
    return Channel(
      id: base64.encode(utf8.encode(url)),
      title: feedData.title ?? 'unknown',
      url: url,
      source: PodcastSource.rss,
      info: {},
      link: feedData.link,
      description: feedData.description,
      imageUrl: feedData.icon ?? feedData.image,
      author: feedData.authors,
      language: feedData.language,
      lastUpdate: feedData.updated,
      categories: feedData.categories?.split(','),
    );
  }

  factory Channel.fromDbMap(Map<String, dynamic> map) {
    return Channel(
      id: map['id'],
      title: map['title'],
      url: map['url'],
      source: PodcastSource.values.firstWhere((e) => e.name == map['source']),
      info: jsonDecode(map['info']) ?? {},
      link: map['link'],
      description: map['description'],
      author: map['author'],
      imageUrl: map['imageUrl'],
      lastUpdate: DateTime.tryParse(map['lastUpdate']),
      language: map['language'],
      categories: map['categories']?.split(','),
    );
  }

  // https://github.com/tekartik/sqflite/blob/master/sqflite/doc/supported_types.md
  Map<String, dynamic> toDbMap() {
    return {
      "id": id,
      "title": title,
      "url": url,
      'source': source.name,
      "info": jsonEncode(info),
      "link": link,
      "description": description,
      "author": author,
      "imageUrl": imageUrl,
      "lastUpdate": lastUpdate?.toString(),
      "language": language,
      "categories": categories?.join(','),
    };
  }

  String getDescription() {
    return (description ?? "")
        .replaceAll(RegExp(r'<[^>]*>|&[^;]+;'), '')
        .trim();
  }

  @override
  String toString() {
    return {
      "id": id,
      "title": title,
      "url": url,
      'source': source,
      "info": info,
      "link": link,
      // "description": description,
      "author": author,
      "imageUrl": imageUrl,
      "lastUpdate": lastUpdate,
      "language": language,
      "categories": categories,
    }.toString();
  }
}
