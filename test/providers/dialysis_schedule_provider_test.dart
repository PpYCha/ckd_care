import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:ckd_care/db/app_database.dart';
import 'package:ckd_care/models/dialysis_schedule.dart';
import 'package:ckd_care/providers/dialysis_schedule_provider.dart';
import 'package:ckd_care/repositories/settings_repository.dart';

void main() {
  sqfliteFfiInit();

  test('load defaults to unset; save then load round-trips; clear unsets',
      () async {
    final repo = SettingsRepository(
        AppDatabase(databaseFactoryFfi, path: inMemoryDatabasePath));
    final p = DialysisScheduleProvider(repo);

    await p.load();
    expect(p.schedule.isSet, isFalse);

    const s = DialysisSchedule(
      weekdays: {2, 4, 6},
      timeOfDay: '07:30',
      durationHours: 3,
      clinicName: 'Clinic A',
      clinicAddress: '',
    );
    await p.save(s);
    expect(p.schedule, s);

    await p.clear();
    expect(p.schedule.isSet, isFalse);
  });
}
