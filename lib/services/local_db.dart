import 'dart:convert';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

class LocalDb {
  static final LocalDb instance = LocalDb._();
  LocalDb._();

  Database? _db;

  Future<Database> get db async {
    if (_db != null) return _db!;
    _db = await openDatabase(
      join(await getDatabasesPath(), 'field_activity_v1.db'),
      version: 1,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE queued_activities (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            payload TEXT NOT NULL,
            created_at TEXT NOT NULL,
            synced INTEGER NOT NULL DEFAULT 0
          )
        ''');
      },
    );
    return _db!;
  }

  Future<int> queueActivity(Map<String, dynamic> payload) async {
    final d = await db;
    return d.insert('queued_activities', {
      'payload': jsonEncode(payload),
      'created_at': DateTime.now().toIso8601String(),
      'synced': 0,
    });
  }

  Future<List<Map<String, dynamic>>> pendingActivities() async {
    final d = await db;
    return d.query('queued_activities', where: 'synced = 0', orderBy: 'id ASC');
  }

  Future<void> markSynced(int id) async {
    final d = await db;
    await d.update('queued_activities', {'synced': 1},
        where: 'id = ?', whereArgs: [id]);
  }

  Future<int> todayVisitCount(String userId) async {
    final d = await db;

    final today = DateTime.now();
    final start = DateTime(today.year, today.month, today.day);
    final end = start.add(const Duration(days: 1));

    final result = await d.rawQuery(
      '''
    SELECT COUNT(*) as count
    FROM queued_activities
    WHERE json_extract(payload, '\$.User_ID') = ?
      AND created_at >= ?
      AND created_at < ?
    ''',
      [
        userId,
        start.toIso8601String(),
        end.toIso8601String(),
      ],
    );

    return (result.first['count'] as int?) ?? 0;
  }

  Future<int> monthVisitCount(String userId) async {
    final d = await db;
    final now = DateTime.now();
    final start =
        DateTime(now.year, now.month, 1).toIso8601String().substring(0, 10);
    final end =
        DateTime(now.year, now.month + 1, 1).toIso8601String().substring(0, 10);
    final r = await d.rawQuery(
        r"SELECT COUNT(*) AS count FROM queued_activities WHERE json_extract(payload, '$.User_ID') = ? AND json_extract(payload, '$.Activity_Date') >= ? AND json_extract(payload, '$.Activity_Date') < ?",
        [userId, start, end]);
    return (r.first['count'] as int?) ?? 0;
  }

  Future<int> entityMonthVisitCount(
      String userId, String entityType, String entityId) async {
    final d = await db;
    final now = DateTime.now();
    final start =
        DateTime(now.year, now.month, 1).toIso8601String().substring(0, 10);
    final end =
        DateTime(now.year, now.month + 1, 1).toIso8601String().substring(0, 10);
    final r = await d.rawQuery(
        r"SELECT COUNT(*) AS count FROM queued_activities WHERE json_extract(payload, '$.User_ID') = ? AND json_extract(payload, '$.Entity_Type') = ? AND json_extract(payload, '$.Entity_ID') = ? AND json_extract(payload, '$.Activity_Date') >= ? AND json_extract(payload, '$.Activity_Date') < ?",
        [userId, entityType, entityId, start, end]);
    return (r.first['count'] as int?) ?? 0;
  }

  Future<List<Map<String, dynamic>>> activityPayloads(
      String userId, String category) async {
    final d = await db;
    final rows = await d.query('queued_activities', orderBy: 'id DESC');
    final result = <Map<String, dynamic>>[];
    for (final row in rows) {
      try {
        final payload =
            Map<String, dynamic>.from(jsonDecode(row['payload'] as String));
        if ('${payload['User_ID'] ?? ''}' == userId &&
            '${payload['Activity_Category'] ?? ''}' == category)
          result.add(payload);
      } catch (_) {}
    }
    return result;
  }

  Future<List<Map<String, dynamic>>> recentActivities(String userId,
      {int limit = 5}) async {
    final d = await db;
    final rows = await d.query('queued_activities', orderBy: 'id DESC');
    final result = <Map<String, dynamic>>[];
    for (final row in rows) {
      try {
        final payload =
            Map<String, dynamic>.from(jsonDecode(row['payload'] as String));
        if ('${payload['User_ID'] ?? ''}' != userId) continue;
        payload['_synced'] = row['synced'] == 1;
        result.add(payload);
        if (result.length == limit) break;
      } catch (_) {}
    }
    return result;
  }
}
