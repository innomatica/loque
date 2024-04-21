import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';

import '../models/channel.dart';
import '../models/episode.dart';
import '../settings/constants.dart';

const tableChannels = 'channels';
const tableEpisodes = 'episodes';
const tablePlaylist = 'playlist';
const tableSettings = 'settings';

//
// Table for SUBSCRIBED channels
//
const sqlCreateChannels = """
  CREATE TABLE $tableChannels (
    id TEXT PRIMARY KEY,
    title TEXT NOT NULL,
    url TEXT NOT NULL,
    source TEXT NOT NULL,
    info TEXT NOT NULL,
    link TEXT,
    description TEXT,
    author TEXT,
    imageUrl TEXT,
    lastUpdate INTEGER,
    language TEXT,
    categories TEXT
  )
""";

//
// Table for LISTENING episodes
//
const sqlCreateEpisodes = """
  CREATE TABLE $tableEpisodes (
    id TEXT PRIMARY KEY,
    title TEXT NOT NULL,
    mediaUrl TEXT NOT NULL,
    channelId TEXT NOT NULL,
    channelTitle TEXT NOT NULL,
    source TEXT NOT NULL,
    info TEXT NOT NULL,
    played INTEGER NOT NULL,
    liked INTEGER NOT NULL,
    link TEXT,
    description TEXT,
    guid TEXT,
    published INTEGER,
    mediaType TEXT,
    mediaBytes INTEGER,
    mediaDuration INTEGER,
    mediaSeekPos INTEGER,
    mediaDownload INTEGER,
    imageUrl TEXT,
    channelImageUrl TEXT,
    language TEXT
  );
""";

const sqlCreateSettings = """
  CREATE TABLE $tableSettings (
    id TEXT PRIMARY KEY,
  );
""";

const sqlCreateTables = [
  sqlCreateChannels,
  sqlCreateEpisodes,
  // sqlCreateSettings,
];

Database? _db;
const dbVersion = 1;

Future<Database> _open() async {
  return _db ??
      await openDatabase(
        '$appName.database',
        version: dbVersion,
        onCreate: (db, version) async {
          debugPrint('creating database');
          for (final statement in sqlCreateTables) {
            await db.execute(statement);
          }
        },
        onUpgrade: (db, oldVersion, newVersion) async {
          debugPrint('upgrade version from $oldVersion to $newVersion');
        },
      );
}

void close() async {
  if (_db != null) {
    await _db!.close();
  }
}

//
// Channel
//
Future saveChannel(Channel channel) async {
  final db = await _open();
  // debugPrint('database:saveChannel: $channel');
  await db.insert(
    tableChannels,
    channel.toDbMap(),
    conflictAlgorithm: ConflictAlgorithm.replace,
  );
}

Future<List<Channel>> readChannels({Map<String, dynamic>? params}) async {
  // debugPrint('database:readChannels');
  final db = await _open();
  final records = await db.query(
    tableChannels,
    distinct: params?['distict'],
    columns: params?['columns'],
    where: params?['where'],
    whereArgs: params?['whereArgs'],
    groupBy: params?['groupBy'],
    having: params?['having'],
    orderBy: params?['orderBy'],
    limit: params?['limit'],
    offset: params?['offset'],
  );
  return records.map((e) => Channel.fromDbMap(e)).toList();
}

// Future updateChannel(Channel channel) async {
//   final db = await _open();
//   debugPrint('database:updateChannel: $channel');
//   await db.update(
//     tableChannels,
//     channel.toDbMap(),
//     where: 'id=?',
//     whereArgs: [channel.id],
//   );
// }

Future deleteChannelById(String channelId) async {
  final db = await _open();
  // debugPrint('database:deleteChannel: $channel');
  await db.delete(
    tableChannels,
    where: 'id=?',
    whereArgs: [channelId],
  );
}

//
// Episode
//

// C
Future saveEpisode(Episode episode) async {
  final db = await _open();
  // debugPrint('database:createEpisode: $episode');
  await db.insert(
    tableEpisodes,
    episode.toDbMap(),
    conflictAlgorithm: ConflictAlgorithm.replace,
  );
}

// R
Future<List<Episode>> readEpisodes({Map<String, dynamic>? params}) async {
  // debugPrint('database:readEpisodes');
  final db = await _open();
  final records = await db.query(
    tableEpisodes,
    distinct: params?['distict'],
    columns: params?['columns'],
    where: params?['where'],
    whereArgs: params?['whereArgs'],
    groupBy: params?['groupBy'],
    having: params?['having'],
    orderBy: params?['orderBy'],
    limit: params?['limit'],
    offset: params?['offset'],
  );
  return records.map((e) => Episode.fromDbMap(e)).toList();
}

// U
Future updateEpisode({
  required Map<String, Object?> values,
  Map<String, dynamic>? params,
}) async {
  final db = await _open();
  debugPrint('database:updateEpisode: $values, $params');
  await db.update(
    tableEpisodes,
    values,
    where: params?['where'],
    whereArgs: params?['whereArgs'],
    conflictAlgorithm: ConflictAlgorithm.replace,
  );
}

// D
Future deleteEpisodeById(String episodeId) async {
  final db = await _open();
  // debugPrint('database:deleteEpisode: $episodeId');
  await db.delete(
    tableEpisodes,
    where: 'id=?',
    whereArgs: [episodeId],
  );
}

Future deleteEpisodesByChannelId(String channelId) async {
  final db = await _open();
  // debugPrint('database:deleteEpisode: $episode');
  await db.delete(
    tableEpisodes,
    where: 'channelId=?',
    whereArgs: [channelId],
  );
}
