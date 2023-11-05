import 'dart:convert';

import 'package:audio_service/audio_service.dart';
import 'package:feed_parser/feed_parser.dart';
import 'package:just_audio/just_audio.dart';

import 'channel.dart';

class Episode {
  String id;
  String title;
  String mediaUrl;
  String channelId;
  String channelTitle;
  PodcastSource source;
  Map<String, dynamic> info;
  bool played;
  bool liked;

  String? link;
  String? description;
  String? guid;
  DateTime? published;
  String? mediaType;
  int? mediaBytes;
  int? mediaDuration;
  int? mediaSeekPos;
  bool? mediaDownload;
  String? imageUrl;
  String? channelImageUrl;
  String? language;

  Episode(
      {required this.id,
      required this.title,
      required this.mediaUrl,
      required this.channelId,
      required this.channelTitle,
      required this.source,
      required this.info,
      required this.played,
      required this.liked,
      this.link,
      this.description,
      this.guid,
      this.published,
      this.mediaType,
      this.mediaBytes,
      this.mediaDuration,
      this.mediaSeekPos,
      this.mediaDownload,
      this.imageUrl,
      this.channelImageUrl,
      this.language});

  factory Episode.fromPcIdx(Map<String, dynamic> episode, Channel channel) {
    // by definition, each episode requires non trivial mediaUrl
    if (episode['enclosureUrl'] is String &&
        episode['enclosureUrl'].isNotEmpty) {
      return Episode(
        id: episode['guid'] ??
            base64.encode(utf8.encode(episode['enclosureUrl'])),
        title: episode['title'] ?? '<Unknown Title>',
        link: episode['link'],
        description: episode['description'],
        guid: episode['guid'],
        published: episode['datePublished'] is int
            ? DateTime.fromMillisecondsSinceEpoch(
                episode['datePublished'] * 1000,
                isUtc: true)
            : null,
        mediaUrl: episode['enclosureUrl'],
        mediaType: episode['enclosureType'],
        mediaBytes: episode['enclosureLength'],
        mediaDuration: episode['duration'],
        mediaSeekPos: 0,
        mediaDownload: false,
        imageUrl: episode['image'],
        channelId: channel.id,
        channelTitle: channel.title,
        channelImageUrl: channel.imageUrl,
        language: episode['feedLanguage'],
        source: PodcastSource.pcidx,
        info: {
          "id": episode['id'],
          "explicit": episode['explicit'],
          // feed means channel in PodcastIndex term
          "feedImage": episode['feedImage'],
          "feedId": episode['feedId'],
          "feedTitle": episode['feedTitle'],
        },
        played: false,
        liked: false,
      );
    }
    throw Exception({"message": "invalid enclosureUrl from PodcastIndex"});
  }

  factory Episode.fromRssData(FeedItem item, Channel channel) {
    if (item.media != null && item.media![0].url != null) {
      return Episode(
        id: item.id,
        title: item.title ?? 'unknown episode',
        mediaUrl: item.media![0].url!,
        channelId: channel.id,
        channelTitle: channel.title,
        source: channel.source,
        info: {},
        played: false,
        liked: false,
        link: item.link,
        description: item.description,
        guid: item.id,
        published: item.updated,
        mediaType: item.media![0].type,
        mediaBytes: item.media![0].bytes,
        // duration is not part of standard RSS but from xmlns:itunes
        mediaDuration: item.media!
            .firstWhere((e) => e.duration != null, orElse: () => item.media![0])
            .duration,
        mediaSeekPos: 0,
        mediaDownload: false,
        imageUrl: channel.imageUrl,
        channelImageUrl: channel.imageUrl,
        language: channel.language,
      );
    }
    throw Exception({"message": "invalid FeedItem from Rss Data"});
  }

  // https://github.com/tekartik/sqflite/blob/master/sqflite/doc/supported_types.md
  factory Episode.fromDbMap(Map<String, dynamic> map) {
    return Episode(
      id: map['id'],
      title: map['title'],
      mediaUrl: map['mediaUrl'],
      channelId: map['channelId'],
      channelTitle: map['channelTitle'],
      source: PodcastSource.values.firstWhere((e) => e.name == map['source']),
      info: jsonDecode(map['info']) ?? {},
      link: map['link'],
      description: map['description'],
      guid: map['guid'],
      published: DateTime.tryParse(map['published']),
      mediaType: map['mediaType'],
      mediaBytes: map['mediaBytes'],
      mediaDuration: map['mediaDuration'],
      mediaSeekPos: map['mediaSeekPos'],
      mediaDownload: map['mediaDownload'] == 1,
      imageUrl: map['imageUrl'],
      channelImageUrl: map['channelImageUrl'],
      language: map['language'],
      played: map['played'] == 1,
      liked: map['liked'] == 1,
    );
  }

  String getDescription() {
    return (description ?? "")
        .replaceAll(RegExp(r'<[^>]*>|&[^;]+;'), '')
        .trim();
  }

  String getBytesString() {
    if ((mediaBytes ?? 0) == 0) {
      return ' * * * ';
    }

    if (mediaBytes! < 1000) {
      return '$mediaBytes bytes';
    } else if (mediaBytes! < 1000000) {
      return '${mediaBytes! * 10 ~/ 1000 / 10} kb';
    } else if (mediaBytes! < 1000000000) {
      return '${mediaBytes! * 10 ~/ 1000000 / 10} mb';
    } else {
      return '${mediaBytes! * 10 ~/ 1000000000 / 10} gb';
    }
  }

  String getDurationString() {
    if ((mediaDuration ?? 0) == 0) {
      return '?? min';
    }

    String suffix = (mediaSeekPos ?? 0) == 0 ? '' : 'left';
    final value = (mediaDuration ?? 0) - (mediaSeekPos ?? 0);

    if (value < 60) {
      return '$value secs $suffix';
    } else if (value < 3600) {
      return '${value ~/ 60} min $suffix';
    } else {
      return '${value ~/ 3600} hr ${(value % 3600) ~/ 60} min $suffix';
    }
  }

  Map<String, dynamic> toDbMap() {
    return {
      "id": id,
      "title": title,
      "mediaUrl": mediaUrl,
      "channelId": channelId,
      "channelTitle": channelTitle,
      "source": source.name,
      "info": jsonEncode(info),
      "link": link,
      "description": description,
      "guid": guid,
      "published": published?.toString(),
      "mediaType": mediaType,
      "mediaBytes": mediaBytes,
      "mediaDuration": mediaDuration,
      "mediaSeekPos": mediaSeekPos,
      "mediaDownload": mediaDownload == true ? 1 : 0,
      "imageUrl": imageUrl,
      "channelImageUrl": channelImageUrl,
      "language": language,
      "played": played == true ? 1 : 0,
      "liked": liked == true ? 1 : 0,
    };
  }

  UriAudioSource getAudioSource() {
    // return ProgressiveAudioSource(
    return AudioSource.uri(Uri.parse(mediaUrl), tag: toMediaItem());
  }

  MediaItem toMediaItem({Map<String, Object>? extras}) {
    return MediaItem(
      id: mediaUrl,
      title: title,
      album: channelTitle,
      artist: channelTitle,
      duration:
          mediaDuration != null ? Duration(seconds: mediaDuration!) : null,
      artUri: channelImageUrl != null ? Uri.tryParse(channelImageUrl!) : null,
      extras: extras == null
          ? {
              'channelId': channelId, // channel.id
              'episodeId': id,
              'link': link, //
              'source': source.name,
              'seekPos': mediaSeekPos,
              'played': played,
            }
          : {
              'channelId': channelId, // channel.id
              'episodeId': id,
              'link': link, //
              'source': source.name,
              'seekPos': mediaSeekPos,
              'played': played,
              ...extras,
            },
    );
  }

  @override
  String toString() {
    return {
      "id": id,
      "title": title,
      "mediaUrl": mediaUrl,
      "channelId": channelId,
      "source": source.name,
      "info": info,
      "played": played,
      "liked": liked,
      "link": link,
      // "description": description,
      "guid": guid,
      "published": published?.toString(),
      "mediaType": mediaType,
      "mediaBytes": mediaBytes,
      "mediaDuration": mediaDuration,
      "mediaSeekPos": mediaSeekPos,
      "mediaDownload": mediaDownload,
      "imageUrl": imageUrl,
      "channelImageUrl": channelImageUrl,
      "language": language,
    }.toString();
  }
}
