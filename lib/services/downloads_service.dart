import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart' as p;
import '../models/models.dart';

/// downloads_service.dart — equivalente Dart de lib/downloads.ts.
/// No site usa IndexedDB (metadata + segmentos); aqui usamos:
///   - sqflite para metadata (equivalente à STORE_META)
///   - filesystem (ApplicationDocumentsDirectory/downloads/) para os
///     segmentos .bin já decriptados (equivalente à STORE_SEGS)
class DownloadsService {
  DownloadsService._();
  static final instance = DownloadsService._();

  Database? _db;

  Future<Database> get _database async {
    if (_db != null) return _db!;
    final dir = await getApplicationDocumentsDirectory();
    final path = p.join(dir.path, 'pixgo_downloads.db');
    _db = await openDatabase(
      path,
      version: 1,
      onCreate: (db, v) => db.execute('''
        CREATE TABLE downloads (
          contentId TEXT PRIMARY KEY,
          title TEXT,
          poster TEXT,
          quality TEXT,
          expiresAt TEXT,
          segCount INTEGER,
          downloadedAt TEXT
        )
      '''),
    );
    return _db!;
  }

  Future<Directory> _segmentsDir(String contentId) async {
    final dir = await getApplicationDocumentsDirectory();
    final d = Directory(p.join(dir.path, 'downloads', contentId));
    if (!await d.exists()) await d.create(recursive: true);
    return d;
  }

  Future<List<DownloadItem>> listDownloads() async {
    final db = await _database;
    final rows = await db.query('downloads');
    return rows
        .map((r) => DownloadItem(
              contentId: r['contentId'] as String,
              title: r['title'] as String? ?? '',
              poster: r['poster'] as String?,
              quality: r['quality'] as String? ?? '',
              expiresAt: DateTime.tryParse(r['expiresAt'] as String? ?? '') ?? DateTime.now(),
            ))
        .toList();
  }

  Future<void> deleteDownload(String contentId) async {
    final db = await _database;
    await db.delete('downloads', where: 'contentId = ?', whereArgs: [contentId]);
    final dir = await _segmentsDir(contentId);
    if (await dir.exists()) await dir.delete(recursive: true);
  }

  Future<void> saveMeta({
    required String contentId,
    required String title,
    String? poster,
    required String quality,
    required DateTime expiresAt,
    required int segCount,
  }) async {
    final db = await _database;
    await db.insert(
      'downloads',
      {
        'contentId': contentId,
        'title': title,
        'poster': poster,
        'quality': quality,
        'expiresAt': expiresAt.toIso8601String(),
        'segCount': segCount,
        'downloadedAt': DateTime.now().toIso8601String(),
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> saveSegment(String contentId, int index, List<int> plaintextBytes) async {
    final dir = await _segmentsDir(contentId);
    final f = File(p.join(dir.path, 'seg_$index.mp4'));
    await f.writeAsBytes(plaintextBytes, flush: true);
  }

  Future<File?> getSegmentFile(String contentId, int index) async {
    final dir = await _segmentsDir(contentId);
    final f = File(p.join(dir.path, 'seg_$index.mp4'));
    return await f.exists() ? f : null;
  }

  Future<void> purgeExpired() async {
    final all = await listDownloads();
    final now = DateTime.now();
    for (final d in all) {
      if (d.expiresAt.isBefore(now)) await deleteDownload(d.contentId);
    }
  }
}
