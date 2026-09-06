import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:ckd_care/db/app_database.dart';
import 'package:ckd_care/models/dialysis_session_log.dart';
import 'package:ckd_care/providers/dialysis_session_log_provider.dart';
import 'package:ckd_care/repositories/dialysis_session_log_repository.dart';

void main() {
  sqfliteFfiInit();

  test('loads and saves weights for sessions', () async {
    final db = AppDatabase(databaseFactoryFfi, path: inMemoryDatabasePath);
    final provider = DialysisSessionLogProvider(
      DialysisSessionLogRepository(db),
    );
    final start = DateTime(2026, 9, 2, 9);

    await provider.loadForSessions([start]);
    expect(provider.logFor(start), isNull);

    await provider.saveWeights(
      sessionStart: start,
      preWeightKg: 70.5,
      postWeightKg: 69.25,
    );

    final log = provider.logFor(start);
    expect(log, isNotNull);
    expect(log!.sessionKey, sessionKeyFor(start));
    expect(log.preWeightKg, 70.5);
    expect(log.postWeightKg, 69.25);

    await db.close();
  });
}
