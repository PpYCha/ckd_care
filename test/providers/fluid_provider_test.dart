import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:ckd_care/db/app_database.dart';
import 'package:ckd_care/db/ids.dart';
import 'package:ckd_care/models/fluid_entry.dart';
import 'package:ckd_care/providers/fluid_provider.dart';
import 'package:ckd_care/repositories/fluid_repository.dart';

void main() {
  sqfliteFfiInit();
  late AppDatabase db;
  late FluidRepository repo;
  late FluidProvider provider;

  setUp(() {
    db = AppDatabase(databaseFactoryFfi, path: inMemoryDatabasePath);
    repo = FluidRepository(db);
    provider = FluidProvider(repo);
  });

  tearDown(() => db.close());

  FluidEntry entry(FluidType type, int ml, DateTime at) => FluidEntry(
    uuid: newUuid(),
    type: type,
    amountMl: ml,
    loggedAt: at,
    day: FluidEntry.dayOf(at),
    updatedAt: at,
  );

  test('selectDate and day navigation load history for that date', () async {
    final sep2 = DateTime(2026, 9, 2, 9);
    final sep3 = DateTime(2026, 9, 3, 10);
    await repo.add(entry(FluidType.intake, 300, sep2));
    await repo.add(entry(FluidType.output, 125, sep3));

    await provider.selectDate(sep2);
    expect(provider.day, '2026-09-02');
    expect(provider.entries.single.amountMl, 300);

    await provider.nextDay();
    expect(provider.day, '2026-09-03');
    expect(provider.entries.single.amountMl, 125);

    await provider.previousDay();
    expect(provider.day, '2026-09-02');
    expect(provider.entries.single.amountMl, 300);
  });

  test('isToday reflects whether the selected day is today', () async {
    await provider.selectDate(DateTime.now());
    expect(provider.isToday, isTrue);

    await provider.previousDay();
    expect(provider.isToday, isFalse);
  });
}
