import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:ckd_care/db/app_database.dart';
import 'package:ckd_care/db/ids.dart';
import 'package:ckd_care/models/fluid_entry.dart';
import 'package:ckd_care/repositories/fluid_repository.dart';

void main() {
  sqfliteFfiInit();
  late AppDatabase db;
  late FluidRepository repo;

  setUp(() {
    db = AppDatabase(databaseFactoryFfi, path: inMemoryDatabasePath);
    repo = FluidRepository(db);
  });
  tearDown(() => db.close());

  FluidEntry entry(FluidType t, int ml, DateTime at) => FluidEntry(
        uuid: newUuid(),
        type: t,
        amountMl: ml,
        loggedAt: at,
        day: FluidEntry.dayOf(at),
        updatedAt: at,
      );

  test('totals sum intake and output per day and compute net', () async {
    final today = DateTime(2026, 9, 2, 8);
    await repo.add(entry(FluidType.intake, 300, today));
    await repo.add(entry(FluidType.intake, 350, today));
    await repo.add(entry(FluidType.output, 200, today));
    // different day, must be excluded
    await repo.add(entry(FluidType.intake, 999, DateTime(2026, 9, 1, 8)));

    final totals = await repo.totalsForDay(FluidEntry.dayOf(today));
    expect(totals.intakeMl, 650);
    expect(totals.outputMl, 200);
    expect(totals.netMl, 450);
  });

  test('entriesForDay round-trips and delete removes', () async {
    final at = DateTime(2026, 9, 2, 9);
    final id = await repo.add(entry(FluidType.intake, 250, at));
    var list = await repo.entriesForDay(FluidEntry.dayOf(at));
    expect(list.single.amountMl, 250);

    await repo.delete(id);
    list = await repo.entriesForDay(FluidEntry.dayOf(at));
    expect(list, isEmpty);
  });

  test('empty day returns zero totals', () async {
    final totals = await repo.totalsForDay('2026-01-01');
    expect(totals.intakeMl, 0);
    expect(totals.outputMl, 0);
    expect(totals.netMl, 0);
  });
}
