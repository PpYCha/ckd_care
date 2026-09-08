import 'package:sqflite/sqflite.dart';
import 'package:ckd_care/db/app_database.dart';
import 'package:ckd_care/models/dialysis_session_log.dart';

class DialysisSessionLogRepository {
  DialysisSessionLogRepository(this._db);
  final AppDatabase _db;

  Future<DialysisSessionLog?> logForSession(DateTime sessionStart) async {
    final db = await _db.database;
    final rows = await db.query(
      'dialysis_session_log',
      where: 'session_key = ?',
      whereArgs: [sessionKeyFor(sessionStart)],
      limit: 1,
    );
    return rows.isEmpty ? null : DialysisSessionLog.fromMap(rows.single);
  }

  Future<Map<String, DialysisSessionLog>> logsForSessions(
    Iterable<DateTime> sessionStarts,
  ) async {
    final keys = sessionStarts.map(sessionKeyFor).toSet();
    if (keys.isEmpty) return const {};

    final db = await _db.database;
    final placeholders = List.filled(keys.length, '?').join(',');
    final rows = await db.query(
      'dialysis_session_log',
      where: 'session_key IN ($placeholders)',
      whereArgs: keys.toList(),
      orderBy: 'session_start ASC',
    );
    return {
      for (final log in rows.map(DialysisSessionLog.fromMap))
        log.sessionKey: log,
    };
  }

  Future<void> saveWeights({
    required DateTime sessionStart,
    Object? preWeightKg = kDialysisWeightUnchanged,
    Object? postWeightKg = kDialysisWeightUnchanged,
  }) async {
    final key = sessionKeyFor(sessionStart);
    final db = await _db.database;
    final existing = await logForSession(sessionStart);
    final nextPre = preWeightKg == kDialysisWeightUnchanged
        ? existing?.preWeightKg
        : (preWeightKg as num?)?.toDouble();
    final nextPost = postWeightKg == kDialysisWeightUnchanged
        ? existing?.postWeightKg
        : (postWeightKg as num?)?.toDouble();

    if (nextPre == null && nextPost == null) {
      await db.delete(
        'dialysis_session_log',
        where: 'session_key = ?',
        whereArgs: [key],
      );
      return;
    }

    final log = DialysisSessionLog(
      sessionKey: key,
      sessionStart: normalizedSessionStart(sessionStart),
      preWeightKg: nextPre,
      postWeightKg: nextPost,
      updatedAt: DateTime.now(),
    );
    await db.insert(
      'dialysis_session_log',
      log.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }
}

const Object kDialysisWeightUnchanged = Object();
