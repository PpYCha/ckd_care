import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:ckd_care/db/app_database.dart';
import 'package:ckd_care/db/ids.dart';
import 'package:ckd_care/models/dose_log.dart';
import 'package:ckd_care/models/medicine.dart';
import 'package:ckd_care/repositories/medicine_repository.dart';

void main() {
  sqfliteFfiInit();
  late AppDatabase db;
  late MedicineRepository repo;

  setUp(() {
    db = AppDatabase(databaseFactoryFfi, path: inMemoryDatabasePath);
    repo = MedicineRepository(db);
  });
  tearDown(() => db.close());

  Medicine med(String name) => Medicine(
      uuid: newUuid(),
      name: name,
      createdAt: DateTime(2026, 9, 2),
      updatedAt: DateTime(2026, 9, 2));

  test('saveMedicine replaces times; active list excludes deactivated', () async {
    final id = await repo.saveMedicine(med('Losartan'), ['08:00', '20:00']);
    expect((await repo.timesFor(id)).map((t) => t.timeOfDay), ['08:00', '20:00']);

    // resave with different times -> replaced, not appended
    await repo.saveMedicine(
        Medicine(
            id: id,
            uuid: newUuid(),
            name: 'Losartan',
            createdAt: DateTime(2026, 9, 2),
            updatedAt: DateTime(2026, 9, 2)),
        ['09:00']);
    expect((await repo.timesFor(id)).map((t) => t.timeOfDay), ['09:00']);

    await repo.deactivate(id);
    expect(await repo.activeMedicines(), isEmpty);
  });

  test('logDose is idempotent per (medicine, scheduledTime); last status wins', () async {
    final id = await repo.saveMedicine(med('Calcitriol'), ['08:00']);
    final due = DateTime(2026, 9, 2, 8);

    await repo.logDose(id, due, DoseStatus.taken);
    await repo.logDose(id, due, DoseStatus.skipped); // same slot again

    final doses = await repo.dosesForMedicine(id);
    expect(doses.length, 1);
    expect(doses.single.status, DoseStatus.skipped);
    expect(await repo.statusFor(id, due), DoseStatus.skipped);
    expect(await repo.statusFor(id, DateTime(2026, 9, 2, 20)), isNull);
  });
}
