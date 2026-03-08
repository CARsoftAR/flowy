import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'dart:async';

class AppDatabase {
  static final AppDatabase _instance = AppDatabase._internal();
  static Database? _database;

  AppDatabase._internal();

  factory AppDatabase() => _instance;

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'flowy.db');

    return await openDatabase(
      path,
      version: 1,
      onCreate: _onCreate,
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    // ── Table: Liked Songs ──────────────────────────────────────────
    await db.execute('''
      CREATE TABLE liked_songs (
        id TEXT PRIMARY KEY,
        title TEXT NOT NULL,
        artist TEXT NOT NULL,
        thumbnailUrl TEXT,
        highResThumbnailUrl TEXT,
        durationMs INTEGER,
        addedAt TIMESTAMP DEFAULT CURRENT_TIMESTAMP
      )
    ''');

    // ── Table: History ───────────────────────────────────────────────
    await db.execute('''
      CREATE TABLE history (
        id TEXT PRIMARY KEY,
        title TEXT NOT NULL,
        artist TEXT NOT NULL,
        thumbnailUrl TEXT,
        highResThumbnailUrl TEXT,
        durationMs INTEGER,
        lastPlayedAt TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        playCount INTEGER DEFAULT 1
      )
    ''');

    // ── Table: Bookmarks (Listening Memory) ──────────────────────────
    await db.execute('''
      CREATE TABLE bookmarks (
        songId TEXT PRIMARY KEY,
        positionSeconds INTEGER NOT NULL,
        updatedAt TIMESTAMP DEFAULT CURRENT_TIMESTAMP
      )
    ''');
  }

  // ── Helper methods for generic CRUD if needed ───────────────────────
}
