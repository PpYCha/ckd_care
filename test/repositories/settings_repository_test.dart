import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:ckd_care/db/app_database.dart';
import 'package:ckd_care/repositories/settings_repository.dart';

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
}
