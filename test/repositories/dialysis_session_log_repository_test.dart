import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:ckd_care/db/app_database.dart';
import 'package:ckd_care/models/dialysis_session_log.dart';
import 'package:ckd_care/repositories/dialysis_session_log_repository.dart';

void main() {
  sqfliteFfiInit();
  late AppDatabase db;
  late DialysisSessionLogRepository repo;

  setUp(() {
    db = AppDatabase(databaseFactoryFfi, path: inMemoryDatabasePath);
    repo = DialysisSessionLogRepository(db);
  });

  tearDown(() => db.close());

  test('empty session returns null', () async {
    expect(await repo.logForSession(DateTime(2026, 9, 2, 9)), isNull);
  });

  test('saving and updating weights round-trips by session key', () async {
    final start = DateTime(2026, 9, 2, 9, 0, 45);

    await repo.saveWeights(
      sessionStart: start,
      preWeightKg: 70.25,
      postWeightKg: 68.75,
    );
    var log = await repo.logForSession(start);
    expect(log, isNotNull);
    expect(log!.sessionKey, sessionKeyFor(start));
    expect(log.preWeightKg, 70.25);
    expect(log.postWeightKg, 68.75);

    await repo.saveWeights(sessionStart: start, preWeightKg: 69.5);
    log = await repo.logForSession(DateTime(2026, 9, 2, 9));
    expect(log!.preWeightKg, 69.5);
    expect(log.postWeightKg, 68.75);

    await repo.saveWeights(sessionStart: start, postWeightKg: null);
    log = await repo.logForSession(start);
    expect(log!.preWeightKg, 69.5);
    expect(log.postWeightKg, isNull);
  });

  test('blank weights clear the stored log', () async {
    final start = DateTime(2026, 9, 2, 9);
    await repo.saveWeights(sessionStart: start, preWeightKg: 70);
    expect(await repo.logForSession(start), isNotNull);

    await repo.saveWeights(
      sessionStart: start,
      preWeightKg: null,
      postWeightKg: null,
    );
    expect(await repo.logForSession(start), isNull);
  });

  test('logsForSessions returns only requested sessions', () async {
    final first = DateTime(2026, 9, 2, 9);
    final second = DateTime(2026, 9, 4, 9);
    await repo.saveWeights(sessionStart: first, preWeightKg: 70);
    await repo.saveWeights(sessionStart: second, postWeightKg: 68);

    final logs = await repo.logsForSessions([first]);
    expect(logs.keys, [sessionKeyFor(first)]);
    expect(logs[sessionKeyFor(first)]!.preWeightKg, 70);
  });
}
