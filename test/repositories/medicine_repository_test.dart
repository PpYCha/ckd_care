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

  Medicine med(String name, {int stock = 10, bool consumeUntilEmpty = false}) =>
      Medicine(
        uuid: newUuid(),
        name: name,
        stockQty: stock,
        consumeUntilEmpty: consumeUntilEmpty,
        createdAt: DateTime(2026, 9, 2),
        updatedAt: DateTime(2026, 9, 2),
      );

  test(
    'saveMedicine replaces times; active list excludes deactivated',
    () async {
      final id = await repo.saveMedicine(med('Losartan'), ['08:00', '20:00']);
      expect((await repo.timesFor(id)).map((t) => t.timeOfDay), [
        '08:00',
        '20:00',
      ]);

      // resave with different times -> replaced, not appended
      await repo.saveMedicine(
        Medicine(
          id: id,
          uuid: newUuid(),
          name: 'Losartan',
          stockQty: 10,
          createdAt: DateTime(2026, 9, 2),
          updatedAt: DateTime(2026, 9, 2),
        ),
        ['09:00'],
      );
      expect((await repo.timesFor(id)).map((t) => t.timeOfDay), ['09:00']);

      await repo.deactivate(id);
      expect(await repo.activeMedicines(), isEmpty);
    },
  );

  test(
    'logDose is idempotent per (medicine, scheduledTime); last status wins',
    () async {
      final id = await repo.saveMedicine(med('Calcitriol'), ['08:00']);
      final due = DateTime(2026, 9, 2, 8);

      await repo.logDose(id, due, DoseStatus.taken);
      await repo.logDose(id, due, DoseStatus.skipped); // same slot again

      final doses = await repo.dosesForMedicine(id);
      expect(doses.length, 1);
      expect(doses.single.status, DoseStatus.skipped);
      expect(await repo.statusFor(id, due), DoseStatus.skipped);
      expect(await repo.statusFor(id, DateTime(2026, 9, 2, 20)), isNull);
    },
  );

  test('marking taken decrements stock; reversing restores it', () async {
    final id = await repo.saveMedicine(med('Aspirin', stock: 3), ['08:00']);
    final due = DateTime(2026, 9, 2, 8);

    await repo.logDose(id, due, DoseStatus.taken);
    expect((await repo.activeMedicines()).single.stockQty, 2);

    // same slot -> skipped: restores the consumed unit
    await repo.logDose(id, due, DoseStatus.skipped);
    expect((await repo.activeMedicines()).single.stockQty, 3);

    // skipped -> taken again: consumes again
    await repo.logDose(id, due, DoseStatus.taken);
    expect((await repo.activeMedicines()).single.stockQty, 2);

    // stock never goes below zero
    await repo.logDose(id, DateTime(2026, 9, 2, 12), DoseStatus.taken); // 1
    await repo.logDose(id, DateTime(2026, 9, 2, 16), DoseStatus.taken); // 0
    await repo.logDose(
      id,
      DateTime(2026, 9, 2, 18),
      DoseStatus.taken,
    ); // clamp 0
    expect((await repo.activeMedicines()).single.stockQty, 0);
  });

  test('saveMedicine persists a restocked medicine', () async {
    final id = await repo.saveMedicine(med('Losartan', stock: 0), ['08:00']);
    final original = (await repo.activeMedicines()).single;

    await repo.saveMedicine(
      Medicine(
        id: id,
        uuid: original.uuid,
        name: original.name,
        stockQty: 10,
        createdAt: original.createdAt,
        updatedAt: DateTime(2026, 9, 3),
      ),
      ['08:00'],
    );

    expect((await repo.activeMedicines()).single.stockQty, 10);
  });

  test(
    'dashboardMedicines keeps out-of-stock maintenance medicines visible',
    () async {
      final ok = await repo.saveMedicine(med('InStock', stock: 5), ['08:00']);
      final maintenance = await repo.saveMedicine(
        med('Maintenance', stock: 0),
        ['08:00'],
      );
      final finite = await repo.saveMedicine(
        med('FiniteCourse', stock: 0, consumeUntilEmpty: true),
        ['08:00'],
      );
      final ended = await repo.saveMedicine(
        Medicine(
          uuid: newUuid(),
          name: 'Ended',
          stockQty: 5,
          endDate: DateTime(2026, 8, 31),
          createdAt: DateTime(2026, 9, 2),
          updatedAt: DateTime(2026, 9, 2),
        ),
        ['08:00'],
      );
      final futureEnd = await repo.saveMedicine(
        Medicine(
          uuid: newUuid(),
          name: 'FutureEnd',
          stockQty: 5,
          endDate: DateTime(2026, 12, 31),
          createdAt: DateTime(2026, 9, 2),
          updatedAt: DateTime(2026, 9, 2),
        ),
        ['08:00'],
      );

      final names = (await repo.dashboardMedicines('2026-09-02'))
          .map((m) => m.name)
          .toSet();
      expect(names, {'InStock', 'Maintenance', 'FutureEnd'});
      expect(names.contains('FiniteCourse'), isFalse);
      expect(names.contains('Ended'), isFalse);
      // Medicines list still shows all active (including depleted/ended).
      expect((await repo.activeMedicines()).length, 5);
      // ids referenced to avoid unused_local warnings
      expect(
        [ok, maintenance, finite, ended, futureEnd].every((i) => i > 0),
        isTrue,
      );
    },
  );
}
