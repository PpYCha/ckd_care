import 'package:sqflite/sqflite.dart';

/// Opens and owns the local SQLite database. The only place schema DDL lives.
/// Inject a [DatabaseFactory] so tests can use the in-memory FFI factory.
class AppDatabase {
  AppDatabase(this._factory, {this.path = 'ckd_care.db'});

  static const int schemaVersion = 2;

  final DatabaseFactory _factory;
  final String path;
  Database? _db;

  Future<Database> get database async {
    return _db ??= await _factory.openDatabase(
      path,
      options: OpenDatabaseOptions(
        version: schemaVersion,
        onConfigure: (db) => db.execute('PRAGMA foreign_keys = ON'),
        onCreate: (db, version) async {
          for (final stmt in _v1Statements) {
            await db.execute(stmt);
          }
        },
        onUpgrade: (db, oldVersion, newVersion) async {
          if (oldVersion < 2) {
            await db.execute(
                'ALTER TABLE medicine ADD COLUMN stock_qty INTEGER NOT NULL DEFAULT 0');
            await db.execute('ALTER TABLE medicine ADD COLUMN end_date TEXT');
          }
        },
      ),
    );
  }

  Future<void> close() async {
    await _db?.close();
    _db = null;
  }

  static const List<String> _v1Statements = [
    '''
    CREATE TABLE fluid_entry(
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      uuid TEXT NOT NULL UNIQUE,
      type TEXT NOT NULL,
      amount_ml INTEGER NOT NULL,
      logged_at TEXT NOT NULL,
      day TEXT NOT NULL,
      note TEXT,
      updated_at TEXT NOT NULL,
      deleted INTEGER NOT NULL DEFAULT 0
    )''',
    'CREATE INDEX idx_fluid_day ON fluid_entry(day, type)',
    '''
    CREATE TABLE medicine(
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      uuid TEXT NOT NULL UNIQUE,
      name TEXT NOT NULL,
      dosage TEXT,
      active INTEGER NOT NULL DEFAULT 1,
      created_at TEXT NOT NULL,
      updated_at TEXT NOT NULL,
      deleted INTEGER NOT NULL DEFAULT 0,
      stock_qty INTEGER NOT NULL DEFAULT 0,
      end_date TEXT
    )''',
    '''
    CREATE TABLE medicine_time(
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      uuid TEXT NOT NULL UNIQUE,
      medicine_id INTEGER NOT NULL REFERENCES medicine(id),
      medicine_uuid TEXT NOT NULL,
      time_of_day TEXT NOT NULL,
      updated_at TEXT NOT NULL,
      deleted INTEGER NOT NULL DEFAULT 0
    )''',
    'CREATE INDEX idx_time_med ON medicine_time(medicine_id)',
    '''
    CREATE TABLE dose_log(
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      uuid TEXT NOT NULL UNIQUE,
      medicine_id INTEGER NOT NULL REFERENCES medicine(id),
      medicine_uuid TEXT NOT NULL,
      scheduled_time TEXT NOT NULL,
      status TEXT NOT NULL,
      acted_at TEXT NOT NULL,
      updated_at TEXT NOT NULL,
      deleted INTEGER NOT NULL DEFAULT 0
    )''',
    'CREATE INDEX idx_dose_med_time ON dose_log(medicine_id, scheduled_time)',
    'CREATE TABLE setting(key TEXT PRIMARY KEY, value TEXT NOT NULL)',
  ];
}
