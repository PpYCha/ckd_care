import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:ckd_care/db/app_database.dart';
import 'package:ckd_care/repositories/settings_repository.dart';
import 'package:ckd_care/models/health_profile.dart';
import 'package:ckd_care/models/dialysis_schedule.dart';

void main() {
  sqfliteFfiInit();
  late AppDatabase db;
  late SettingsRepository repo;

  setUp(() {
    db = AppDatabase(databaseFactoryFfi, path: inMemoryDatabasePath);
    repo = SettingsRepository(db);
  });
  tearDown(() => db.close());

  test('fluid limit is null until set, then persists', () async {
    expect(await repo.getFluidLimitMl(), isNull);
    await repo.setFluidLimitMl(1000);
    expect(await repo.getFluidLimitMl(), 1000);
    await repo.setFluidLimitMl(1200); // overwrite, not duplicate
    expect(await repo.getFluidLimitMl(), 1200);
  });

  test('notifications default true and toggle', () async {
    expect(await repo.getNotificationsEnabled(), isTrue);
    await repo.setNotificationsEnabled(false);
    expect(await repo.getNotificationsEnabled(), isFalse);
  });

  test('food disclaimer ack version round-trips; null until set', () async {
    expect(await repo.getFoodDisclaimerAckVersion(), isNull);
    await repo.setFoodDisclaimerAck('1.0');
    expect(await repo.getFoodDisclaimerAckVersion(), '1.0');
  });

  test('health profile round-trips; defaults when unset', () async {
    final empty = await repo.getHealthProfile();
    expect(empty, const HealthProfile()); // unset stage, none, all false

    const p = HealthProfile(
      ckdStage: CkdStage.stage4,
      dialysisStatus: DialysisStatus.hemodialysis,
      diabetes: true,
      elevatedPotassium: true,
    );
    await repo.saveHealthProfile(p);
    expect(await repo.getHealthProfile(), p);
  });

  test('dialysis schedule is unset until saved, then round-trips; clear removes it',
      () async {
    final repo = SettingsRepository(
        AppDatabase(databaseFactoryFfi, path: inMemoryDatabasePath));

    final initial = await repo.getDialysisSchedule();
    expect(initial.isSet, isFalse);

    const s = DialysisSchedule(
      weekdays: {1, 3, 5},
      timeOfDay: '09:00',
      durationHours: 4,
      clinicName: 'Healthy Kidney Center',
      clinicAddress: '123 Main St',
    );
    await repo.saveDialysisSchedule(s);
    expect(await repo.getDialysisSchedule(), s);

    await repo.clearDialysisSchedule();
    expect((await repo.getDialysisSchedule()).isSet, isFalse);
  });
}
