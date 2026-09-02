import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:ckd_care/db/app_database.dart';

void main() {
  sqfliteFfiInit();

  AppDatabase newDb() =>
      AppDatabase(databaseFactoryFfi, path: inMemoryDatabasePath);

  test('opens at schema v1 with all tables and indexes', () async {
    final db = newDb();
    final database = await db.database;

    expect(await database.getVersion(), 1);

    final tables = (await database.query('sqlite_master',
            columns: ['name'], where: "type = 'table'"))
        .map((r) => r['name'])
        .toSet();
    expect(tables, containsAll(
        ['fluid_entry', 'medicine', 'medicine_time', 'dose_log', 'setting']));

    final indexes = (await database.query('sqlite_master',
            columns: ['name'], where: "type = 'index'"))
        .map((r) => r['name'])
        .toSet();
    expect(indexes, containsAll(
        ['idx_fluid_day', 'idx_time_med', 'idx_dose_med_time']));

    await db.close();
  });
}
