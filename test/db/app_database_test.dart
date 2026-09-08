import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:ckd_care/db/app_database.dart';

void main() {
  sqfliteFfiInit();

  AppDatabase newDb() =>
      AppDatabase(databaseFactoryFfi, path: inMemoryDatabasePath);

  test('opens at current schema with all tables and indexes', () async {
    final db = newDb();
    final database = await db.database;

    expect(await database.getVersion(), 4);

    final tables = (await database.query(
      'sqlite_master',
      columns: ['name'],
      where: "type = 'table'",
    )).map((r) => r['name']).toSet();
    expect(
      tables,
      containsAll([
        'fluid_entry',
        'medicine',
        'medicine_time',
        'dose_log',
        'setting',
        'dialysis_session_log',
      ]),
    );

    final indexes = (await database.query(
      'sqlite_master',
      columns: ['name'],
      where: "type = 'index'",
    )).map((r) => r['name']).toSet();
    expect(
      indexes,
      containsAll([
        'idx_fluid_day',
        'idx_time_med',
        'idx_dose_med_time',
        'idx_dialysis_session_start',
      ]),
    );

    await db.close();
  });

  test('schema is current with stock_qty, end_date, consume_until_empty on medicine', () async {
    final db = AppDatabase(databaseFactoryFfi, path: inMemoryDatabasePath);
    final database = await db.database;
    expect(await database.getVersion(), 4);
    final cols = (await database.rawQuery('PRAGMA table_info(medicine)'))
        .map((r) => r['name'])
        .toSet();
    expect(cols, containsAll(['stock_qty', 'end_date', 'consume_until_empty']));
    await db.close();
  });

  test('migrates a v1 database to v2 by adding the new columns', () async {
    final dir = await Directory.systemTemp.createTemp('ckd_mig');
    final path = p.join(dir.path, 'v1.db');
    // Build a minimal v1 medicine table (no stock_qty/end_date).
    final v1 = await databaseFactoryFfi.openDatabase(
      path,
      options: OpenDatabaseOptions(
        version: 1,
        onCreate: (db, v) async {
          await db.execute('''
              CREATE TABLE medicine(
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                uuid TEXT NOT NULL UNIQUE,
                name TEXT NOT NULL,
                dosage TEXT,
                active INTEGER NOT NULL DEFAULT 1,
                created_at TEXT NOT NULL,
                updated_at TEXT NOT NULL,
                deleted INTEGER NOT NULL DEFAULT 0
              )''');
          await db.insert('medicine', {
            'uuid': 'u-legacy',
            'name': 'Legacy',
            'active': 1,
            'created_at': '2026-01-01T00:00:00.000',
            'updated_at': '2026-01-01T00:00:00.000',
            'deleted': 0,
          });
        },
      ),
    );
    await v1.close();

    // Reopen through AppDatabase (version 2) -> triggers onUpgrade.
    final appDb = AppDatabase(databaseFactoryFfi, path: path);
    final db2 = await appDb.database;
    final cols = (await db2.rawQuery('PRAGMA table_info(medicine)'))
        .map((r) => r['name'])
        .toSet();
    expect(cols, containsAll(['stock_qty', 'end_date']));
    // Existing row survived and got the default stock.
    final row = (await db2.query(
      'medicine',
      where: 'uuid = ?',
      whereArgs: ['u-legacy'],
    )).single;
    expect(row['stock_qty'], 0);
    expect(row['end_date'], isNull);
    await appDb.close();
    await dir.delete(recursive: true);
  });

  test(
    'migrates a v3 database to v4 by adding dialysis session logs',
    () async {
      final dir = await Directory.systemTemp.createTemp('ckd_mig_v3');
      final path = p.join(dir.path, 'v3.db');
      final v3 = await databaseFactoryFfi.openDatabase(
        path,
        options: OpenDatabaseOptions(
          version: 3,
          onCreate: (db, v) async {
            await db.execute(
              'CREATE TABLE setting(key TEXT PRIMARY KEY, value TEXT NOT NULL)',
            );
          },
        ),
      );
      await v3.close();

      final appDb = AppDatabase(databaseFactoryFfi, path: path);
      final migrated = await appDb.database;
      expect(await migrated.getVersion(), 4);
      final tables = (await migrated.query(
        'sqlite_master',
        columns: ['name'],
        where: "type = 'table'",
      )).map((r) => r['name']).toSet();
      expect(tables, contains('dialysis_session_log'));
      final cols = (await migrated.rawQuery(
        'PRAGMA table_info(dialysis_session_log)',
      )).map((r) => r['name']).toSet();
      expect(
        cols,
        containsAll([
          'session_key',
          'session_start',
          'pre_weight_kg',
          'post_weight_kg',
          'updated_at',
        ]),
      );
      await appDb.close();
      await dir.delete(recursive: true);
    },
  );
}
