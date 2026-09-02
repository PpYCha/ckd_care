# CKD Care — Daily Tracking Loop (Group A) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build the daily tracking loop of the CKD care app — fluid intake/output against a daily limit, fixed-time medicine reminders with an adherence log, and a dashboard tying them together — all local via SQLite.

**Architecture:** `Widget → Provider (ChangeNotifier) → Repository → SQLite`. Repositories are the only code touching the DB and return typed models, so providers and UI test against fakes. A local notification service schedules medicine reminders with stable, idempotent IDs. Schema is versioned from v1 so Group B/C are later migrations.

**Tech Stack:** Flutter, `provider`, `sqflite` + `path`, `flutter_local_notifications`, `sqflite_common_ffi` (test-only), `timezone` (required by flutter_local_notifications for zoned scheduling).

## Global Constraints

- Dart SDK: `^3.13.2` (existing `pubspec.yaml`).
- Local-only: no network, no accounts, no sync. Never add a cloud/HTTP dependency.
- All DB access goes through repositories; UI/providers never touch `sqflite` directly.
- Repository methods return typed models, never raw `Map` rows.
- Dates: `logged_at` / `acted_at` / `scheduled_time` = full ISO-8601 (`DateTime.toIso8601String()`); `day` = `'YYYY-MM-DD'`.
- Fluid amounts are whole `int` milliliters.
- `flutter analyze` clean and `flutter test` green is the gate before any task is "done".
- Follow `package:flutter_lints` (already active). Prefer `const` constructors where the linter asks.

---

## File Structure

```
lib/
  main.dart                       # app entry: init DB + notifications, reschedule-on-boot, provide providers
  db/app_database.dart            # open DB, schema v1, onUpgrade migrations
  models/
    fluid_entry.dart
    medicine.dart                 # Medicine + MedicineTime
    dose_log.dart
  repositories/
    fluid_repository.dart
    medicine_repository.dart
    settings_repository.dart
  services/notification_service.dart
  providers/
    settings_provider.dart
    fluid_provider.dart
    medicine_provider.dart
    dashboard_provider.dart
  screens/
    dashboard_screen.dart
    fluid_screen.dart
    medicines_screen.dart
    medicine_detail_screen.dart
    settings_screen.dart
  widgets/
    fluid_gauge.dart
    dose_tile.dart
test/
  db/app_database_test.dart
  repositories/fluid_repository_test.dart
  repositories/medicine_repository_test.dart
  repositories/settings_repository_test.dart
  providers/dashboard_provider_test.dart
  services/notification_service_test.dart
  widget_test.dart                # dashboard smoke test (replaces scaffold test)
```

---

### Task 1: Dependencies & database foundation

Adds packages and the versioned SQLite opener with schema v1. Establishes the in-memory test harness every later repository test reuses.

**Files:**
- Modify: `pubspec.yaml` (dependencies)
- Create: `lib/db/app_database.dart`
- Test: `test/db/app_database_test.dart`

**Interfaces:**
- Consumes: nothing.
- Produces:
  - `class AppDatabase` with `AppDatabase(this._factory, {this.path = 'ckd_care.db'})`, `Future<Database> get database` (lazy-opens), `Future<void> close()`, static `const int schemaVersion = 1`, and `static const List<String> _v1Statements` (table + index DDL).
  - Constructor takes a `DatabaseFactory` so tests inject `databaseFactoryFfi` and production injects the default `databaseFactory`.

- [ ] **Step 1: Add dependencies**

Edit `pubspec.yaml`. Under `dependencies:` (after `cupertino_icons`):

```yaml
  sqflite: ^2.3.3
  path: ^1.9.0
  provider: ^6.1.2
  flutter_local_notifications: ^17.2.3
  timezone: ^0.9.4
```

Under `dev_dependencies:` (after `flutter_lints`):

```yaml
  sqflite_common_ffi: ^2.3.3
```

- [ ] **Step 2: Install and verify**

Run: `flutter pub get`
Expected: "Got dependencies!" with no version-solve errors.

- [ ] **Step 3: Write the failing test**

Create `test/db/app_database_test.dart`:

```dart
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
```

- [ ] **Step 4: Run test to verify it fails**

Run: `flutter test test/db/app_database_test.dart`
Expected: FAIL — `app_database.dart` / `AppDatabase` not found.

- [ ] **Step 5: Implement `AppDatabase`**

Create `lib/db/app_database.dart`:

```dart
import 'package:sqflite/sqflite.dart';

/// Opens and owns the local SQLite database. The only place schema DDL lives.
/// Inject a [DatabaseFactory] so tests can use the in-memory FFI factory.
class AppDatabase {
  AppDatabase(this._factory, {this.path = 'ckd_care.db'});

  static const int schemaVersion = 1;

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
          // Group B/C migrations land here as: if (oldVersion < 2) { ... }
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
      type TEXT NOT NULL,
      amount_ml INTEGER NOT NULL,
      logged_at TEXT NOT NULL,
      day TEXT NOT NULL,
      note TEXT
    )''',
    'CREATE INDEX idx_fluid_day ON fluid_entry(day, type)',
    '''
    CREATE TABLE medicine(
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      name TEXT NOT NULL,
      dosage TEXT,
      active INTEGER NOT NULL DEFAULT 1,
      created_at TEXT NOT NULL
    )''',
    '''
    CREATE TABLE medicine_time(
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      medicine_id INTEGER NOT NULL REFERENCES medicine(id),
      time_of_day TEXT NOT NULL
    )''',
    'CREATE INDEX idx_time_med ON medicine_time(medicine_id)',
    '''
    CREATE TABLE dose_log(
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      medicine_id INTEGER NOT NULL REFERENCES medicine(id),
      scheduled_time TEXT NOT NULL,
      status TEXT NOT NULL,
      acted_at TEXT NOT NULL
    )''',
    'CREATE INDEX idx_dose_med_time ON dose_log(medicine_id, scheduled_time)',
    'CREATE TABLE setting(key TEXT PRIMARY KEY, value TEXT NOT NULL)',
  ];
}
```

- [ ] **Step 6: Run test to verify it passes**

Run: `flutter test test/db/app_database_test.dart`
Expected: PASS.

- [ ] **Step 7: Commit**

```bash
git add pubspec.yaml pubspec.lock lib/db/app_database.dart test/db/app_database_test.dart
git commit -m "feat: add deps and versioned SQLite schema v1"
```

---

### Task 2: Domain models

Plain immutable Dart classes with `fromMap`/`toMap`. No DB access. Kept in one task since they are trivial and interdependent.

**Files:**
- Create: `lib/models/fluid_entry.dart`, `lib/models/medicine.dart`, `lib/models/dose_log.dart`
- Test: none dedicated (exercised via repository tests in Tasks 3–5).

**Interfaces:**
- Produces:
  - `enum FluidType { intake, output }` (in `fluid_entry.dart`).
  - `class FluidEntry { final int? id; final FluidType type; final int amountMl; final DateTime loggedAt; final String day; final String? note; }` with `FluidEntry.fromMap(Map<String,Object?>)`, `Map<String,Object?> toMap()`, and `static String dayOf(DateTime dt)` returning `'YYYY-MM-DD'`.
  - `class Medicine { final int? id; final String name; final String? dosage; final bool active; final DateTime createdAt; }` + `fromMap`/`toMap`.
  - `class MedicineTime { final int? id; final int? medicineId; final String timeOfDay; }` (`timeOfDay` = `'HH:mm'`) + `fromMap`/`toMap`.
  - `enum DoseStatus { taken, skipped }` and `class DoseLog { final int? id; final int medicineId; final DateTime scheduledTime; final DoseStatus status; final DateTime actedAt; }` + `fromMap`/`toMap`.

- [ ] **Step 1: Implement `fluid_entry.dart`**

Create `lib/models/fluid_entry.dart`:

```dart
enum FluidType { intake, output }

class FluidEntry {
  const FluidEntry({
    this.id,
    required this.type,
    required this.amountMl,
    required this.loggedAt,
    required this.day,
    this.note,
  });

  final int? id;
  final FluidType type;
  final int amountMl;
  final DateTime loggedAt;
  final String day;
  final String? note;

  static String dayOf(DateTime dt) =>
      '${dt.year.toString().padLeft(4, '0')}-'
      '${dt.month.toString().padLeft(2, '0')}-'
      '${dt.day.toString().padLeft(2, '0')}';

  factory FluidEntry.fromMap(Map<String, Object?> m) => FluidEntry(
        id: m['id'] as int?,
        type: FluidType.values.byName(m['type'] as String),
        amountMl: m['amount_ml'] as int,
        loggedAt: DateTime.parse(m['logged_at'] as String),
        day: m['day'] as String,
        note: m['note'] as String?,
      );

  Map<String, Object?> toMap() => {
        if (id != null) 'id': id,
        'type': type.name,
        'amount_ml': amountMl,
        'logged_at': loggedAt.toIso8601String(),
        'day': day,
        'note': note,
      };
}
```

- [ ] **Step 2: Implement `medicine.dart`**

Create `lib/models/medicine.dart`:

```dart
class Medicine {
  const Medicine({
    this.id,
    required this.name,
    this.dosage,
    this.active = true,
    required this.createdAt,
  });

  final int? id;
  final String name;
  final String? dosage;
  final bool active;
  final DateTime createdAt;

  factory Medicine.fromMap(Map<String, Object?> m) => Medicine(
        id: m['id'] as int?,
        name: m['name'] as String,
        dosage: m['dosage'] as String?,
        active: (m['active'] as int) == 1,
        createdAt: DateTime.parse(m['created_at'] as String),
      );

  Map<String, Object?> toMap() => {
        if (id != null) 'id': id,
        'name': name,
        'dosage': dosage,
        'active': active ? 1 : 0,
        'created_at': createdAt.toIso8601String(),
      };
}

class MedicineTime {
  const MedicineTime({this.id, this.medicineId, required this.timeOfDay});

  final int? id;
  final int? medicineId;
  final String timeOfDay; // 'HH:mm'

  factory MedicineTime.fromMap(Map<String, Object?> m) => MedicineTime(
        id: m['id'] as int?,
        medicineId: m['medicine_id'] as int?,
        timeOfDay: m['time_of_day'] as String,
      );

  Map<String, Object?> toMap() => {
        if (id != null) 'id': id,
        if (medicineId != null) 'medicine_id': medicineId,
        'time_of_day': timeOfDay,
      };
}
```

- [ ] **Step 3: Implement `dose_log.dart`**

Create `lib/models/dose_log.dart`:

```dart
enum DoseStatus { taken, skipped }

class DoseLog {
  const DoseLog({
    this.id,
    required this.medicineId,
    required this.scheduledTime,
    required this.status,
    required this.actedAt,
  });

  final int? id;
  final int medicineId;
  final DateTime scheduledTime;
  final DoseStatus status;
  final DateTime actedAt;

  factory DoseLog.fromMap(Map<String, Object?> m) => DoseLog(
        id: m['id'] as int?,
        medicineId: m['medicine_id'] as int,
        scheduledTime: DateTime.parse(m['scheduled_time'] as String),
        status: DoseStatus.values.byName(m['status'] as String),
        actedAt: DateTime.parse(m['acted_at'] as String),
      );

  Map<String, Object?> toMap() => {
        if (id != null) 'id': id,
        'medicine_id': medicineId,
        'scheduled_time': scheduledTime.toIso8601String(),
        'status': status.name,
        'acted_at': actedAt.toIso8601String(),
      };
}
```

- [ ] **Step 4: Verify it compiles**

Run: `flutter analyze lib/models`
Expected: "No issues found!"

- [ ] **Step 5: Commit**

```bash
git add lib/models
git commit -m "feat: add domain models"
```

---

### Task 3: Fluid repository

CRUD for fluid entries plus the daily rollup the dashboard needs.

**Files:**
- Create: `lib/repositories/fluid_repository.dart`
- Test: `test/repositories/fluid_repository_test.dart`

**Interfaces:**
- Consumes: `AppDatabase`, `FluidEntry`, `FluidType`.
- Produces `class FluidRepository`:
  - `FluidRepository(this._db)` where `_db` is `AppDatabase`.
  - `Future<int> add(FluidEntry entry)` → new row id.
  - `Future<void> delete(int id)`.
  - `Future<List<FluidEntry>> entriesForDay(String day)` ordered by `logged_at`.
  - `Future<DailyFluidTotals> totalsForDay(String day)`.
  - `class DailyFluidTotals { final int intakeMl; final int outputMl; int get netMl => intakeMl - outputMl; }`.

- [ ] **Step 1: Write the failing test**

Create `test/repositories/fluid_repository_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:ckd_care/db/app_database.dart';
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

  FluidEntry entry(FluidType t, int ml, DateTime at) =>
      FluidEntry(type: t, amountMl: ml, loggedAt: at, day: FluidEntry.dayOf(at));

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
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/repositories/fluid_repository_test.dart`
Expected: FAIL — `FluidRepository` not found.

- [ ] **Step 3: Implement the repository**

Create `lib/repositories/fluid_repository.dart`:

```dart
import 'package:ckd_care/db/app_database.dart';
import 'package:ckd_care/models/fluid_entry.dart';

class DailyFluidTotals {
  const DailyFluidTotals({required this.intakeMl, required this.outputMl});
  final int intakeMl;
  final int outputMl;
  int get netMl => intakeMl - outputMl;
}

class FluidRepository {
  FluidRepository(this._db);
  final AppDatabase _db;

  Future<int> add(FluidEntry entry) async {
    final db = await _db.database;
    return db.insert('fluid_entry', entry.toMap());
  }

  Future<void> delete(int id) async {
    final db = await _db.database;
    await db.delete('fluid_entry', where: 'id = ?', whereArgs: [id]);
  }

  Future<List<FluidEntry>> entriesForDay(String day) async {
    final db = await _db.database;
    final rows = await db.query('fluid_entry',
        where: 'day = ?', whereArgs: [day], orderBy: 'logged_at ASC');
    return rows.map(FluidEntry.fromMap).toList();
  }

  Future<DailyFluidTotals> totalsForDay(String day) async {
    final db = await _db.database;
    final rows = await db.rawQuery(
      "SELECT type, COALESCE(SUM(amount_ml), 0) AS total "
      "FROM fluid_entry WHERE day = ? GROUP BY type",
      [day],
    );
    var intake = 0, output = 0;
    for (final r in rows) {
      final total = (r['total'] as num).toInt();
      if (r['type'] == FluidType.intake.name) intake = total;
      if (r['type'] == FluidType.output.name) output = total;
    }
    return DailyFluidTotals(intakeMl: intake, outputMl: output);
  }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/repositories/fluid_repository_test.dart`
Expected: PASS (3 tests).

- [ ] **Step 5: Commit**

```bash
git add lib/repositories/fluid_repository.dart test/repositories/fluid_repository_test.dart
git commit -m "feat: add fluid repository with daily rollups"
```

---

### Task 4: Settings repository

Key/value store for the daily fluid limit and the notifications-enabled flag.

**Files:**
- Create: `lib/repositories/settings_repository.dart`
- Test: `test/repositories/settings_repository_test.dart`

**Interfaces:**
- Consumes: `AppDatabase`.
- Produces `class SettingsRepository`:
  - `SettingsRepository(this._db)`.
  - `Future<int?> getFluidLimitMl()` → null when unset.
  - `Future<void> setFluidLimitMl(int ml)`.
  - `Future<bool> getNotificationsEnabled()` → default `true`.
  - `Future<void> setNotificationsEnabled(bool enabled)`.
  - Keys: `const String kFluidLimit = 'fluid_limit_ml';`, `const String kNotifications = 'notifications_enabled';`.

- [ ] **Step 1: Write the failing test**

Create `test/repositories/settings_repository_test.dart`:

```dart
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
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/repositories/settings_repository_test.dart`
Expected: FAIL — `SettingsRepository` not found.

- [ ] **Step 3: Implement the repository**

Create `lib/repositories/settings_repository.dart`:

```dart
import 'package:ckd_care/db/app_database.dart';

const String kFluidLimit = 'fluid_limit_ml';
const String kNotifications = 'notifications_enabled';

class SettingsRepository {
  SettingsRepository(this._db);
  final AppDatabase _db;

  Future<String?> _get(String key) async {
    final db = await _db.database;
    final rows = await db.query('setting',
        columns: ['value'], where: 'key = ?', whereArgs: [key]);
    return rows.isEmpty ? null : rows.first['value'] as String;
  }

  Future<void> _set(String key, String value) async {
    final db = await _db.database;
    await db.insert('setting', {'key': key, 'value': value},
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<int?> getFluidLimitMl() async {
    final v = await _get(kFluidLimit);
    return v == null ? null : int.tryParse(v);
  }

  Future<void> setFluidLimitMl(int ml) => _set(kFluidLimit, ml.toString());

  Future<bool> getNotificationsEnabled() async =>
      (await _get(kNotifications) ?? 'true') == 'true';

  Future<void> setNotificationsEnabled(bool enabled) =>
      _set(kNotifications, enabled.toString());
}
```

Note: `ConflictAlgorithm` comes from `sqflite`. Add `import 'package:sqflite/sqflite.dart';` at the top of the file.

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/repositories/settings_repository_test.dart`
Expected: PASS (2 tests).

- [ ] **Step 5: Commit**

```bash
git add lib/repositories/settings_repository.dart test/repositories/settings_repository_test.dart
git commit -m "feat: add settings repository (fluid limit, notifications flag)"
```

---

### Task 5: Medicine repository

Medicines + their times + the idempotent adherence log.

**Files:**
- Create: `lib/repositories/medicine_repository.dart`
- Test: `test/repositories/medicine_repository_test.dart`

**Interfaces:**
- Consumes: `AppDatabase`, `Medicine`, `MedicineTime`, `DoseLog`, `DoseStatus`.
- Produces `class MedicineRepository`:
  - `MedicineRepository(this._db)`.
  - `Future<int> saveMedicine(Medicine med, List<String> times)` — inserts or updates the medicine and **replaces** its `medicine_time` rows with `times` (`'HH:mm'`); returns the medicine id.
  - `Future<List<Medicine>> activeMedicines()` — `active = 1`, ordered by name.
  - `Future<List<MedicineTime>> timesFor(int medicineId)`.
  - `Future<void> deactivate(int medicineId)` — sets `active = 0`.
  - `Future<void> logDose(int medicineId, DateTime scheduledTime, DoseStatus status)` — idempotent per `(medicineId, scheduledTime)`: updates the existing row's status if present, else inserts.
  - `Future<List<DoseLog>> dosesForMedicine(int medicineId)` — newest first.
  - `Future<DoseStatus?> statusFor(int medicineId, DateTime scheduledTime)` — null when not acted on.

- [ ] **Step 1: Write the failing test**

Create `test/repositories/medicine_repository_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:ckd_care/db/app_database.dart';
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

  Medicine med(String name) => Medicine(name: name, createdAt: DateTime(2026, 9, 2));

  test('saveMedicine replaces times; active list excludes deactivated', () async {
    final id = await repo.saveMedicine(med('Losartan'), ['08:00', '20:00']);
    expect((await repo.timesFor(id)).map((t) => t.timeOfDay), ['08:00', '20:00']);

    // resave with different times -> replaced, not appended
    await repo.saveMedicine(
        Medicine(id: id, name: 'Losartan', createdAt: DateTime(2026, 9, 2)),
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
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/repositories/medicine_repository_test.dart`
Expected: FAIL — `MedicineRepository` not found.

- [ ] **Step 3: Implement the repository**

Create `lib/repositories/medicine_repository.dart`:

```dart
import 'package:sqflite/sqflite.dart';
import 'package:ckd_care/db/app_database.dart';
import 'package:ckd_care/models/dose_log.dart';
import 'package:ckd_care/models/medicine.dart';

class MedicineRepository {
  MedicineRepository(this._db);
  final AppDatabase _db;

  Future<int> saveMedicine(Medicine med, List<String> times) async {
    final db = await _db.database;
    return db.transaction((txn) async {
      final int id;
      if (med.id == null) {
        id = await txn.insert('medicine', med.toMap());
      } else {
        id = med.id!;
        await txn.update('medicine', med.toMap(),
            where: 'id = ?', whereArgs: [id]);
      }
      await txn.delete('medicine_time', where: 'medicine_id = ?', whereArgs: [id]);
      for (final t in times) {
        await txn.insert('medicine_time', {'medicine_id': id, 'time_of_day': t});
      }
      return id;
    });
  }

  Future<List<Medicine>> activeMedicines() async {
    final db = await _db.database;
    final rows = await db.query('medicine',
        where: 'active = 1', orderBy: 'name COLLATE NOCASE ASC');
    return rows.map(Medicine.fromMap).toList();
  }

  Future<List<MedicineTime>> timesFor(int medicineId) async {
    final db = await _db.database;
    final rows = await db.query('medicine_time',
        where: 'medicine_id = ?', whereArgs: [medicineId], orderBy: 'time_of_day ASC');
    return rows.map(MedicineTime.fromMap).toList();
  }

  Future<void> deactivate(int medicineId) async {
    final db = await _db.database;
    await db.update('medicine', {'active': 0},
        where: 'id = ?', whereArgs: [medicineId]);
  }

  Future<void> logDose(int medicineId, DateTime scheduledTime, DoseStatus status) async {
    final db = await _db.database;
    final iso = scheduledTime.toIso8601String();
    final now = DateTime.now().toIso8601String();
    final existing = await db.query('dose_log',
        columns: ['id'],
        where: 'medicine_id = ? AND scheduled_time = ?',
        whereArgs: [medicineId, iso]);
    if (existing.isEmpty) {
      await db.insert('dose_log', {
        'medicine_id': medicineId,
        'scheduled_time': iso,
        'status': status.name,
        'acted_at': now,
      });
    } else {
      await db.update('dose_log', {'status': status.name, 'acted_at': now},
          where: 'id = ?', whereArgs: [existing.first['id']]);
    }
  }

  Future<List<DoseLog>> dosesForMedicine(int medicineId) async {
    final db = await _db.database;
    final rows = await db.query('dose_log',
        where: 'medicine_id = ?', whereArgs: [medicineId],
        orderBy: 'scheduled_time DESC');
    return rows.map(DoseLog.fromMap).toList();
  }

  Future<DoseStatus?> statusFor(int medicineId, DateTime scheduledTime) async {
    final db = await _db.database;
    final rows = await db.query('dose_log',
        columns: ['status'],
        where: 'medicine_id = ? AND scheduled_time = ?',
        whereArgs: [medicineId, scheduledTime.toIso8601String()]);
    return rows.isEmpty ? null : DoseStatus.values.byName(rows.first['status'] as String);
  }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/repositories/medicine_repository_test.dart`
Expected: PASS (2 tests).

- [ ] **Step 5: Commit**

```bash
git add lib/repositories/medicine_repository.dart test/repositories/medicine_repository_test.dart
git commit -m "feat: add medicine repository with idempotent dose log"
```

---

### Task 6: Notification service

Wraps `flutter_local_notifications` with stable, idempotent per-dose IDs. Depends only on the plugin (injected) — no DB, no providers — so it unit-tests against a mock plugin.

**Files:**
- Create: `lib/services/notification_service.dart`
- Test: `test/services/notification_service_test.dart`

**Interfaces:**
- Consumes: `FlutterLocalNotificationsPlugin`, `MedicineTime`.
- Produces `class NotificationService`:
  - `NotificationService(this._plugin)`.
  - `static int notificationId(int medicineId, String timeOfDay)` — stable: `medicineId * 1440 + (hh*60+mm)`. Public + pure so tests and callers agree.
  - `Future<void> scheduleForMedicine(int medicineId, List<MedicineTime> times)` — cancels this medicine's slots then schedules a daily notification per time.
  - `Future<void> cancelForMedicine(int medicineId, List<MedicineTime> times)`.
  - `Future<void> cancelDose(int medicineId, String timeOfDay)` — cancels one slot (used when a dose is marked from the dashboard).

- [ ] **Step 1: Write the failing test**

Create `test/services/notification_service_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:ckd_care/models/medicine.dart';
import 'package:ckd_care/services/notification_service.dart';

void main() {
  test('notificationId is stable and unique per (medicine, time)', () {
    expect(NotificationService.notificationId(1, '08:00'),
        NotificationService.notificationId(1, '08:00'));
    expect(NotificationService.notificationId(1, '08:00'),
        isNot(NotificationService.notificationId(1, '20:00')));
    expect(NotificationService.notificationId(1, '08:00'),
        isNot(NotificationService.notificationId(2, '08:00')));
  });

  test('id encodes medicine and minute-of-day', () {
    // medicine 2 at 08:30 -> 2*1440 + 510
    expect(NotificationService.notificationId(2, '08:30'), 2 * 1440 + 510);
  });
}
```

(Scheduling itself hits the platform plugin and is covered by the manual device checklist; the pure ID contract is what the reschedule logic depends on, so that is what we assert.)

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/services/notification_service_test.dart`
Expected: FAIL — `NotificationService` not found.

- [ ] **Step 3: Implement the service**

Create `lib/services/notification_service.dart`:

```dart
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:ckd_care/models/medicine.dart';

class NotificationService {
  NotificationService(this._plugin);
  final FlutterLocalNotificationsPlugin _plugin;

  static const _details = NotificationDetails(
    android: AndroidNotificationDetails('meds', 'Medicine reminders',
        importance: Importance.max, priority: Priority.high),
    iOS: DarwinNotificationDetails(),
  );

  /// Stable id: medicine * 1440 + minute-of-day. Pure so callers and the
  /// scheduler always agree on which notification maps to which dose slot.
  static int notificationId(int medicineId, String timeOfDay) {
    final parts = timeOfDay.split(':');
    final minutes = int.parse(parts[0]) * 60 + int.parse(parts[1]);
    return medicineId * 1440 + minutes;
  }

  Future<void> scheduleForMedicine(int medicineId, List<MedicineTime> times) async {
    await cancelForMedicine(medicineId, times);
    for (final t in times) {
      await _plugin.zonedSchedule(
        notificationId(medicineId, t.timeOfDay),
        'Time for your medicine',
        'Tap to mark taken or skipped',
        _nextInstanceOf(t.timeOfDay),
        _details,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        matchDateTimeComponents: DateTimeComponents.time, // repeat daily
        payload: '$medicineId|${t.timeOfDay}',
      );
    }
  }

  Future<void> cancelForMedicine(int medicineId, List<MedicineTime> times) async {
    for (final t in times) {
      await _plugin.cancel(notificationId(medicineId, t.timeOfDay));
    }
  }

  Future<void> cancelDose(int medicineId, String timeOfDay) =>
      _plugin.cancel(notificationId(medicineId, timeOfDay));

  tz.TZDateTime _nextInstanceOf(String timeOfDay) {
    final parts = timeOfDay.split(':');
    final now = tz.TZDateTime.now(tz.local);
    var scheduled = tz.TZDateTime(tz.local, now.year, now.month, now.day,
        int.parse(parts[0]), int.parse(parts[1]));
    if (scheduled.isBefore(now)) {
      scheduled = scheduled.add(const Duration(days: 1));
    }
    return scheduled;
  }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/services/notification_service_test.dart`
Expected: PASS (2 tests).

- [ ] **Step 5: Commit**

```bash
git add lib/services/notification_service.dart test/services/notification_service_test.dart
git commit -m "feat: add notification service with stable dose ids"
```

---

### Task 7: Providers

`ChangeNotifier`s that hold UI state and call repositories/notification service. Grouped in one task; the dashboard provider is the one with real aggregation logic and gets a test against fake repos.

**Files:**
- Create: `lib/providers/settings_provider.dart`, `lib/providers/fluid_provider.dart`, `lib/providers/medicine_provider.dart`, `lib/providers/dashboard_provider.dart`
- Test: `test/providers/dashboard_provider_test.dart`

**Interfaces:**
- Consumes: `FluidRepository`, `SettingsRepository`, `MedicineRepository`, `NotificationService`, all models.
- Produces:
  - `class SettingsProvider extends ChangeNotifier` — `int? fluidLimitMl`, `bool notificationsEnabled`, `Future<void> load()`, `Future<void> setLimit(int ml)`, `Future<void> setNotifications(bool v)`.
  - `class FluidProvider extends ChangeNotifier` — holds `List<FluidEntry> entries` for a `String day`, `Future<void> loadDay(String day)`, `Future<void> add(FluidType type, int ml, {String? note})`, `Future<void> remove(int id)`.
  - `class MedicineProvider extends ChangeNotifier` — `List<Medicine> medicines`, `Future<void> load()`, `Future<void> save(Medicine med, List<String> times)` (also reschedules notifications), `Future<void> deactivate(Medicine med)` (cancels its notifications).
  - `class DashboardProvider extends ChangeNotifier` — computes today's view. `Future<void> refresh()` populates `DailyFluidTotals? fluidTotals`, `int? fluidLimitMl`, and `List<DueDose> dueToday`. `Future<void> markDose(DueDose dose, DoseStatus status)` logs the dose, cancels its notification, and refreshes.
  - `class DueDose { final int medicineId; final String medicineName; final String timeOfDay; final DateTime scheduledTime; final DoseStatus? status; }`.

- [ ] **Step 1: Write the failing test (dashboard aggregation + markDose side effects)**

Create `test/providers/dashboard_provider_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:ckd_care/models/dose_log.dart';
import 'package:ckd_care/models/fluid_entry.dart';
import 'package:ckd_care/models/medicine.dart';
import 'package:ckd_care/providers/dashboard_provider.dart';
import 'package:ckd_care/repositories/fluid_repository.dart';

// Minimal fakes implementing only what DashboardProvider calls.
class _FakeFluid implements FluidRepository {
  @override
  Future<DailyFluidTotals> totalsForDay(String day) async =>
      const DailyFluidTotals(intakeMl: 650, outputMl: 200);
  @override
  noSuchMethod(Invocation i) => super.noSuchMethod(i);
}

class _FakeSettings {
  Future<int?> getFluidLimitMl() async => 1000;
}

class _FakeMedicine {
  final logged = <String>[];
  Future<List<Medicine>> activeMedicines() async =>
      [Medicine(id: 1, name: 'Losartan', createdAt: DateTime(2026, 9, 2))];
  Future<List<MedicineTime>> timesFor(int id) async =>
      [const MedicineTime(timeOfDay: '08:00')];
  Future<DoseStatus?> statusFor(int id, DateTime t) async => null;
  Future<void> logDose(int id, DateTime t, DoseStatus s) async =>
      logged.add('$id|$s');
}

class _FakeNotifications {
  final cancelled = <String>[];
  Future<void> cancelDose(int medicineId, String timeOfDay) async =>
      cancelled.add('$medicineId|$timeOfDay');
}

void main() {
  test('refresh aggregates fluid + due doses for today', () async {
    final p = DashboardProvider(
      fluid: _FakeFluid(),
      settings: _FakeSettings(),
      medicine: _FakeMedicine(),
      notifications: _FakeNotifications(),
      now: () => DateTime(2026, 9, 2, 12),
    );
    await p.refresh();

    expect(p.fluidTotals!.intakeMl, 650);
    expect(p.fluidLimitMl, 1000);
    expect(p.dueToday.single.medicineName, 'Losartan');
    expect(p.dueToday.single.scheduledTime, DateTime(2026, 9, 2, 8));
  });

  test('markDose logs and cancels the notification', () async {
    final meds = _FakeMedicine();
    final notes = _FakeNotifications();
    final p = DashboardProvider(
      fluid: _FakeFluid(),
      settings: _FakeSettings(),
      medicine: meds,
      notifications: notes,
      now: () => DateTime(2026, 9, 2, 12),
    );
    await p.refresh();
    await p.markDose(p.dueToday.single, DoseStatus.taken);

    expect(meds.logged, ['1|DoseStatus.taken']);
    expect(notes.cancelled, ['1|08:00']);
  });
}
```

Note: `DashboardProvider`'s constructor takes its collaborators via named params typed as narrow interfaces (or `dynamic` structural fakes as above). Define the constructor to accept the concrete `FluidRepository`, `SettingsRepository`, `MedicineRepository`, `NotificationService` in production; for the test, the fakes are duck-typed via named params typed `dynamic`. Use named params typed `dynamic` in the constructor to keep the fakes lightweight:
`DashboardProvider({required dynamic fluid, required dynamic settings, required dynamic medicine, required dynamic notifications, DateTime Function()? now})`.

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/providers/dashboard_provider_test.dart`
Expected: FAIL — `DashboardProvider` not found.

- [ ] **Step 3: Implement `dashboard_provider.dart`**

Create `lib/providers/dashboard_provider.dart`:

```dart
import 'package:flutter/foundation.dart';
import 'package:ckd_care/models/dose_log.dart';
import 'package:ckd_care/models/fluid_entry.dart';
import 'package:ckd_care/repositories/fluid_repository.dart';

class DueDose {
  const DueDose({
    required this.medicineId,
    required this.medicineName,
    required this.timeOfDay,
    required this.scheduledTime,
    required this.status,
  });
  final int medicineId;
  final String medicineName;
  final String timeOfDay;
  final DateTime scheduledTime;
  final DoseStatus? status;
}

class DashboardProvider extends ChangeNotifier {
  DashboardProvider({
    required dynamic fluid,
    required dynamic settings,
    required dynamic medicine,
    required dynamic notifications,
    DateTime Function()? now,
  })  : _fluid = fluid,
        _settings = settings,
        _medicine = medicine,
        _notifications = notifications,
        _now = now ?? DateTime.now;

  final dynamic _fluid;
  final dynamic _settings;
  final dynamic _medicine;
  final dynamic _notifications;
  final DateTime Function() _now;

  DailyFluidTotals? fluidTotals;
  int? fluidLimitMl;
  List<DueDose> dueToday = const [];

  Future<void> refresh() async {
    final today = _now();
    final day = FluidEntry.dayOf(today);
    fluidTotals = await _fluid.totalsForDay(day);
    fluidLimitMl = await _settings.getFluidLimitMl();

    final meds = await _medicine.activeMedicines();
    final due = <DueDose>[];
    for (final m in meds) {
      final times = await _medicine.timesFor(m.id);
      for (final t in times) {
        final parts = (t.timeOfDay as String).split(':');
        final scheduled = DateTime(today.year, today.month, today.day,
            int.parse(parts[0]), int.parse(parts[1]));
        final status = await _medicine.statusFor(m.id, scheduled);
        due.add(DueDose(
          medicineId: m.id,
          medicineName: m.name,
          timeOfDay: t.timeOfDay,
          scheduledTime: scheduled,
          status: status,
        ));
      }
    }
    due.sort((a, b) => a.scheduledTime.compareTo(b.scheduledTime));
    dueToday = due;
    notifyListeners();
  }

  Future<void> markDose(DueDose dose, DoseStatus status) async {
    await _medicine.logDose(dose.medicineId, dose.scheduledTime, status);
    await _notifications.cancelDose(dose.medicineId, dose.timeOfDay);
    await refresh();
  }
}
```

- [ ] **Step 4: Run the dashboard test to verify it passes**

Run: `flutter test test/providers/dashboard_provider_test.dart`
Expected: PASS (2 tests).

- [ ] **Step 5: Implement the remaining providers**

Create `lib/providers/settings_provider.dart`:

```dart
import 'package:flutter/foundation.dart';
import 'package:ckd_care/repositories/settings_repository.dart';

class SettingsProvider extends ChangeNotifier {
  SettingsProvider(this._repo);
  final SettingsRepository _repo;

  int? fluidLimitMl;
  bool notificationsEnabled = true;

  Future<void> load() async {
    fluidLimitMl = await _repo.getFluidLimitMl();
    notificationsEnabled = await _repo.getNotificationsEnabled();
    notifyListeners();
  }

  Future<void> setLimit(int ml) async {
    await _repo.setFluidLimitMl(ml);
    fluidLimitMl = ml;
    notifyListeners();
  }

  Future<void> setNotifications(bool v) async {
    await _repo.setNotificationsEnabled(v);
    notificationsEnabled = v;
    notifyListeners();
  }
}
```

Create `lib/providers/fluid_provider.dart`:

```dart
import 'package:flutter/foundation.dart';
import 'package:ckd_care/models/fluid_entry.dart';
import 'package:ckd_care/repositories/fluid_repository.dart';

class FluidProvider extends ChangeNotifier {
  FluidProvider(this._repo);
  final FluidRepository _repo;

  String day = FluidEntry.dayOf(DateTime.now());
  List<FluidEntry> entries = const [];

  Future<void> loadDay(String d) async {
    day = d;
    entries = await _repo.entriesForDay(d);
    notifyListeners();
  }

  Future<void> add(FluidType type, int ml, {String? note}) async {
    final now = DateTime.now();
    await _repo.add(FluidEntry(
      type: type,
      amountMl: ml,
      loggedAt: now,
      day: FluidEntry.dayOf(now),
      note: note,
    ));
    await loadDay(day);
  }

  Future<void> remove(int id) async {
    await _repo.delete(id);
    await loadDay(day);
  }
}
```

Create `lib/providers/medicine_provider.dart`:

```dart
import 'package:flutter/foundation.dart';
import 'package:ckd_care/models/medicine.dart';
import 'package:ckd_care/repositories/medicine_repository.dart';
import 'package:ckd_care/services/notification_service.dart';

class MedicineProvider extends ChangeNotifier {
  MedicineProvider(this._repo, this._notifications);
  final MedicineRepository _repo;
  final NotificationService _notifications;

  List<Medicine> medicines = const [];

  Future<void> load() async {
    medicines = await _repo.activeMedicines();
    notifyListeners();
  }

  Future<void> save(Medicine med, List<String> times) async {
    final id = await _repo.saveMedicine(med, times);
    await _notifications.scheduleForMedicine(id, await _repo.timesFor(id));
    await load();
  }

  Future<void> deactivate(Medicine med) async {
    final times = await _repo.timesFor(med.id!);
    await _repo.deactivate(med.id!);
    await _notifications.cancelForMedicine(med.id!, times);
    await load();
  }
}
```

- [ ] **Step 6: Verify all providers compile and tests pass**

Run: `flutter test test/providers/dashboard_provider_test.dart && flutter analyze lib/providers`
Expected: test PASS; analyze "No issues found!"

- [ ] **Step 7: Commit**

```bash
git add lib/providers test/providers/dashboard_provider_test.dart
git commit -m "feat: add providers (settings, fluid, medicine, dashboard)"
```

---

### Task 8: UI screens, widgets, and app wiring

Builds the screens, the fluid gauge/dose tile widgets, and wires everything in `main.dart` (DB init, notification init + reschedule-on-boot, provider tree). Replaces the scaffold counter app.

**Files:**
- Create: `lib/widgets/fluid_gauge.dart`, `lib/widgets/dose_tile.dart`, `lib/screens/dashboard_screen.dart`, `lib/screens/fluid_screen.dart`, `lib/screens/medicines_screen.dart`, `lib/screens/medicine_detail_screen.dart`, `lib/screens/settings_screen.dart`
- Modify: `lib/main.dart` (full replace)
- Test: none new here (smoke test is Task 9).

**Interfaces:**
- Consumes: all providers, models, `AppDatabase`, `NotificationService`.
- Produces:
  - `FluidGauge({required int intakeMl, required int? limitMl})` — renders "X / Y mL" with a `LinearProgressIndicator`; color: green `< 0.8`, amber `0.8–1.0`, red `> 1.0` of limit; shows "Set a daily limit" when `limitMl == null`.
  - `DoseTile({required DueDose dose, required void Function(DoseStatus) onMark})`.
  - `CkdApp` root widget with a `MultiProvider` and bottom-nav to Dashboard / Fluid / Medicines / Settings.
  - `main()` initializes timezone, notifications, DB, providers, then reschedules all active medicines' notifications on boot.

- [ ] **Step 1: Implement `fluid_gauge.dart`**

Create `lib/widgets/fluid_gauge.dart`:

```dart
import 'package:flutter/material.dart';

class FluidGauge extends StatelessWidget {
  const FluidGauge({super.key, required this.intakeMl, required this.limitMl});
  final int intakeMl;
  final int? limitMl;

  @override
  Widget build(BuildContext context) {
    if (limitMl == null) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Text('Set a daily fluid limit in Settings'),
        ),
      );
    }
    final limit = limitMl!;
    final ratio = limit == 0 ? 0.0 : intakeMl / limit;
    final color = ratio > 1.0
        ? Colors.red
        : ratio >= 0.8
            ? Colors.amber
            : Colors.green;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('$intakeMl / $limit mL',
              style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 8),
          LinearProgressIndicator(
              value: ratio.clamp(0.0, 1.0), color: color, minHeight: 10),
        ]),
      ),
    );
  }
}
```

- [ ] **Step 2: Implement `dose_tile.dart`**

Create `lib/widgets/dose_tile.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:ckd_care/models/dose_log.dart';
import 'package:ckd_care/providers/dashboard_provider.dart';

class DoseTile extends StatelessWidget {
  const DoseTile({super.key, required this.dose, required this.onMark});
  final DueDose dose;
  final void Function(DoseStatus) onMark;

  @override
  Widget build(BuildContext context) {
    final subtitle = switch (dose.status) {
      DoseStatus.taken => 'Taken',
      DoseStatus.skipped => 'Skipped',
      null => 'Pending',
    };
    return ListTile(
      title: Text('${dose.medicineName} — ${dose.timeOfDay}'),
      subtitle: Text(subtitle),
      trailing: dose.status != null
          ? Icon(dose.status == DoseStatus.taken ? Icons.check_circle : Icons.cancel)
          : Row(mainAxisSize: MainAxisSize.min, children: [
              TextButton(onPressed: () => onMark(DoseStatus.taken), child: const Text('Taken')),
              TextButton(onPressed: () => onMark(DoseStatus.skipped), child: const Text('Skip')),
            ]),
    );
  }
}
```

- [ ] **Step 3: Implement the screens**

Create `lib/screens/dashboard_screen.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:ckd_care/providers/dashboard_provider.dart';
import 'package:ckd_care/widgets/dose_tile.dart';
import 'package:ckd_care/widgets/fluid_gauge.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});
  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback(
        (_) => context.read<DashboardProvider>().refresh());
  }

  @override
  Widget build(BuildContext context) {
    final d = context.watch<DashboardProvider>();
    return ListView(padding: const EdgeInsets.all(12), children: [
      FluidGauge(
          intakeMl: d.fluidTotals?.intakeMl ?? 0, limitMl: d.fluidLimitMl),
      if (d.fluidTotals != null)
        Padding(
          padding: const EdgeInsets.all(8),
          child: Text('Net balance: ${d.fluidTotals!.netMl} mL '
              '(out ${d.fluidTotals!.outputMl} mL)'),
        ),
      const Divider(),
      Text('Today\'s medicines', style: Theme.of(context).textTheme.titleMedium),
      ...d.dueToday.map((dose) => DoseTile(
            dose: dose,
            onMark: (s) => context.read<DashboardProvider>().markDose(dose, s),
          )),
      if (d.dueToday.isEmpty) const ListTile(title: Text('No medicines scheduled')),
    ]);
  }
}
```

Create `lib/screens/fluid_screen.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:ckd_care/models/fluid_entry.dart';
import 'package:ckd_care/providers/fluid_provider.dart';

class FluidScreen extends StatefulWidget {
  const FluidScreen({super.key});
  @override
  State<FluidScreen> createState() => _FluidScreenState();
}

class _FluidScreenState extends State<FluidScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) =>
        context.read<FluidProvider>().loadDay(FluidEntry.dayOf(DateTime.now())));
  }

  Future<void> _addDialog(FluidType type) async {
    final controller = TextEditingController();
    final ml = await showDialog<int>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Add ${type.name} (mL)'),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          autofocus: true,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          TextButton(
              onPressed: () => Navigator.pop(ctx, int.tryParse(controller.text)),
              child: const Text('Add')),
        ],
      ),
    );
    if (ml != null && ml > 0 && mounted) {
      await context.read<FluidProvider>().add(type, ml);
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = context.watch<FluidProvider>();
    return Scaffold(
      body: ListView(children: [
        for (final e in p.entries)
          Dismissible(
            key: ValueKey(e.id),
            onDismissed: (_) => context.read<FluidProvider>().remove(e.id!),
            child: ListTile(
              leading: Icon(e.type == FluidType.intake
                  ? Icons.water_drop
                  : Icons.opacity_outlined),
              title: Text('${e.amountMl} mL'),
              subtitle: Text('${e.type.name} • '
                  '${e.loggedAt.hour.toString().padLeft(2, '0')}:'
                  '${e.loggedAt.minute.toString().padLeft(2, '0')}'),
            ),
          ),
        if (p.entries.isEmpty) const ListTile(title: Text('No entries today')),
      ]),
      floatingActionButton: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          FloatingActionButton.extended(
              heroTag: 'in',
              onPressed: () => _addDialog(FluidType.intake),
              label: const Text('Intake')),
          const SizedBox(width: 12),
          FloatingActionButton.extended(
              heroTag: 'out',
              onPressed: () => _addDialog(FluidType.output),
              label: const Text('Output')),
        ],
      ),
    );
  }
}
```

Create `lib/screens/medicines_screen.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:ckd_care/models/medicine.dart';
import 'package:ckd_care/providers/medicine_provider.dart';
import 'package:ckd_care/screens/medicine_detail_screen.dart';

class MedicinesScreen extends StatefulWidget {
  const MedicinesScreen({super.key});
  @override
  State<MedicinesScreen> createState() => _MedicinesScreenState();
}

class _MedicinesScreenState extends State<MedicinesScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance
        .addPostFrameCallback((_) => context.read<MedicineProvider>().load());
  }

  @override
  Widget build(BuildContext context) {
    final p = context.watch<MedicineProvider>();
    return Scaffold(
      body: ListView(children: [
        for (final m in p.medicines)
          ListTile(
            title: Text(m.name),
            subtitle: Text(m.dosage ?? ''),
            onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (_) => MedicineDetailScreen(medicine: m))),
          ),
        if (p.medicines.isEmpty) const ListTile(title: Text('No medicines yet')),
      ]),
      floatingActionButton: FloatingActionButton(
        onPressed: () => Navigator.push(
            context,
            MaterialPageRoute(
                builder: (_) => const MedicineDetailScreen(medicine: null))),
        child: const Icon(Icons.add),
      ),
    );
  }
}
```

Create `lib/screens/medicine_detail_screen.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:ckd_care/models/medicine.dart';
import 'package:ckd_care/providers/medicine_provider.dart';

/// Add/edit a medicine. `medicine == null` means create.
class MedicineDetailScreen extends StatefulWidget {
  const MedicineDetailScreen({super.key, required this.medicine});
  final Medicine? medicine;
  @override
  State<MedicineDetailScreen> createState() => _MedicineDetailScreenState();
}

class _MedicineDetailScreenState extends State<MedicineDetailScreen> {
  late final TextEditingController _name =
      TextEditingController(text: widget.medicine?.name ?? '');
  late final TextEditingController _dosage =
      TextEditingController(text: widget.medicine?.dosage ?? '');
  final List<String> _times = [];

  Future<void> _pickTime() async {
    final t = await showTimePicker(context: context, initialTime: TimeOfDay.now());
    if (t != null) {
      setState(() => _times.add(
          '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}'));
    }
  }

  Future<void> _save() async {
    if (_name.text.trim().isEmpty || _times.isEmpty) return;
    final med = Medicine(
      id: widget.medicine?.id,
      name: _name.text.trim(),
      dosage: _dosage.text.trim().isEmpty ? null : _dosage.text.trim(),
      createdAt: widget.medicine?.createdAt ?? DateTime.now(),
    );
    await context.read<MedicineProvider>().save(med, _times..sort());
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.medicine == null ? 'Add medicine' : 'Edit medicine'),
        actions: [
          if (widget.medicine != null)
            IconButton(
              icon: const Icon(Icons.delete),
              onPressed: () async {
                await context.read<MedicineProvider>().deactivate(widget.medicine!);
                if (mounted) Navigator.pop(context);
              },
            ),
        ],
      ),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        TextField(controller: _name, decoration: const InputDecoration(labelText: 'Name')),
        TextField(controller: _dosage, decoration: const InputDecoration(labelText: 'Dosage')),
        const SizedBox(height: 16),
        Wrap(spacing: 8, children: [
          for (final t in _times) Chip(label: Text(t)),
          ActionChip(label: const Text('+ time'), onPressed: _pickTime),
        ]),
        const SizedBox(height: 24),
        FilledButton(onPressed: _save, child: const Text('Save')),
      ]),
    );
  }
}
```

Note: editing an existing medicine starts with an empty `_times` list and replaces its times on save (matches `saveMedicine`'s replace semantics). Pre-loading existing times is a later enhancement, not needed for the first version.

Create `lib/screens/settings_screen.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:ckd_care/providers/settings_provider.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});
  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance
        .addPostFrameCallback((_) => context.read<SettingsProvider>().load());
  }

  Future<void> _editLimit() async {
    final controller = TextEditingController(
        text: context.read<SettingsProvider>().fluidLimitMl?.toString() ?? '');
    final ml = await showDialog<int>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Daily fluid limit (mL)'),
        content: TextField(
            controller: controller,
            keyboardType: TextInputType.number,
            autofocus: true),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          TextButton(
              onPressed: () => Navigator.pop(ctx, int.tryParse(controller.text)),
              child: const Text('Save')),
        ],
      ),
    );
    if (ml != null && ml > 0 && mounted) {
      await context.read<SettingsProvider>().setLimit(ml);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = context.watch<SettingsProvider>();
    return ListView(children: [
      ListTile(
        title: const Text('Daily fluid limit'),
        subtitle: Text(s.fluidLimitMl == null ? 'Not set' : '${s.fluidLimitMl} mL'),
        trailing: const Icon(Icons.edit),
        onTap: _editLimit,
      ),
      SwitchListTile(
        title: const Text('Medicine reminders'),
        value: s.notificationsEnabled,
        onChanged: (v) => context.read<SettingsProvider>().setNotifications(v),
      ),
    ]);
  }
}
```

- [ ] **Step 4: Rewrite `main.dart` with init + provider tree**

Replace `lib/main.dart` entirely:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:provider/provider.dart';
import 'package:sqflite/sqflite.dart';
import 'package:timezone/data/latest.dart' as tzdata;

import 'package:ckd_care/db/app_database.dart';
import 'package:ckd_care/providers/dashboard_provider.dart';
import 'package:ckd_care/providers/fluid_provider.dart';
import 'package:ckd_care/providers/medicine_provider.dart';
import 'package:ckd_care/providers/settings_provider.dart';
import 'package:ckd_care/repositories/fluid_repository.dart';
import 'package:ckd_care/repositories/medicine_repository.dart';
import 'package:ckd_care/repositories/settings_repository.dart';
import 'package:ckd_care/screens/dashboard_screen.dart';
import 'package:ckd_care/screens/fluid_screen.dart';
import 'package:ckd_care/screens/medicines_screen.dart';
import 'package:ckd_care/screens/settings_screen.dart';
import 'package:ckd_care/services/notification_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  tzdata.initializeTimeZones();

  final plugin = FlutterLocalNotificationsPlugin();
  await plugin.initialize(const InitializationSettings(
    android: AndroidInitializationSettings('@mipmap/ic_launcher'),
    iOS: DarwinInitializationSettings(),
  ));

  final db = AppDatabase(databaseFactory);
  final fluidRepo = FluidRepository(db);
  final settingsRepo = SettingsRepository(db);
  final medicineRepo = MedicineRepository(db);
  final notifications = NotificationService(plugin);

  // Reschedule-on-boot: re-register reminders for every active medicine.
  for (final m in await medicineRepo.activeMedicines()) {
    await notifications.scheduleForMedicine(m.id!, await medicineRepo.timesFor(m.id!));
  }

  runApp(CkdApp(
    fluidRepo: fluidRepo,
    settingsRepo: settingsRepo,
    medicineRepo: medicineRepo,
    notifications: notifications,
  ));
}

class CkdApp extends StatelessWidget {
  const CkdApp({
    super.key,
    required this.fluidRepo,
    required this.settingsRepo,
    required this.medicineRepo,
    required this.notifications,
  });
  final FluidRepository fluidRepo;
  final SettingsRepository settingsRepo;
  final MedicineRepository medicineRepo;
  final NotificationService notifications;

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => SettingsProvider(settingsRepo)),
        ChangeNotifierProvider(create: (_) => FluidProvider(fluidRepo)),
        ChangeNotifierProvider(
            create: (_) => MedicineProvider(medicineRepo, notifications)),
        ChangeNotifierProvider(
            create: (_) => DashboardProvider(
                  fluid: fluidRepo,
                  settings: settingsRepo,
                  medicine: medicineRepo,
                  notifications: notifications,
                )),
      ],
      child: MaterialApp(
        title: 'CKD Care',
        theme: ThemeData(colorSchemeSeed: Colors.teal, useMaterial3: true),
        home: const HomeShell(),
      ),
    );
  }
}

class HomeShell extends StatefulWidget {
  const HomeShell({super.key});
  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _index = 0;
  static const _titles = ['Dashboard', 'Fluid', 'Medicines', 'Settings'];
  static const _screens = [
    DashboardScreen(),
    FluidScreen(),
    MedicinesScreen(),
    SettingsScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(_titles[_index])),
      body: _screens[_index],
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.dashboard), label: 'Home'),
          NavigationDestination(icon: Icon(Icons.water_drop), label: 'Fluid'),
          NavigationDestination(icon: Icon(Icons.medication), label: 'Meds'),
          NavigationDestination(icon: Icon(Icons.settings), label: 'Settings'),
        ],
      ),
    );
  }
}
```

- [ ] **Step 5: Analyze the whole app**

Run: `flutter analyze`
Expected: "No issues found!" (fix any lint/const issues it reports before committing).

- [ ] **Step 6: Commit**

```bash
git add lib/widgets lib/screens lib/main.dart
git commit -m "feat: add screens, widgets, and app wiring"
```

---

### Task 9: Dashboard smoke test & final gate

Replaces the scaffold `widget_test.dart` with a real smoke test that pumps the dashboard against seeded fakes, then runs the full suite + analyzer.

**Files:**
- Modify: `test/widget_test.dart` (full replace)

**Interfaces:**
- Consumes: `DashboardScreen`, `DashboardProvider`, fakes.

- [ ] **Step 1: Replace the scaffold widget test**

Replace `test/widget_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:ckd_care/models/medicine.dart';
import 'package:ckd_care/providers/dashboard_provider.dart';
import 'package:ckd_care/repositories/fluid_repository.dart';
import 'package:ckd_care/screens/dashboard_screen.dart';

class _FakeFluid {
  Future<DailyFluidTotals> totalsForDay(String day) async =>
      const DailyFluidTotals(intakeMl: 650, outputMl: 200);
}

class _FakeSettings {
  Future<int?> getFluidLimitMl() async => 1000;
}

class _FakeMedicine {
  Future<List<Medicine>> activeMedicines() async =>
      [Medicine(id: 1, name: 'Losartan', createdAt: DateTime(2026, 9, 2))];
  Future<List<MedicineTime>> timesFor(int id) async =>
      [const MedicineTime(timeOfDay: '08:00')];
  Future<dynamic> statusFor(int id, DateTime t) async => null;
}

class _FakeNotifications {
  Future<void> cancelDose(int id, String t) async {}
}

void main() {
  testWidgets('dashboard renders gauge and due dose', (tester) async {
    final provider = DashboardProvider(
      fluid: _FakeFluid(),
      settings: _FakeSettings(),
      medicine: _FakeMedicine(),
      notifications: _FakeNotifications(),
      now: () => DateTime(2026, 9, 2, 12),
    );
    await tester.pumpWidget(MaterialApp(
      home: ChangeNotifierProvider<DashboardProvider>.value(
        value: provider,
        child: const Scaffold(body: DashboardScreen()),
      ),
    ));
    await tester.pumpAndSettle();

    expect(find.text('650 / 1000 mL'), findsOneWidget);
    expect(find.textContaining('Losartan'), findsOneWidget);
  });
}
```

- [ ] **Step 2: Run the smoke test**

Run: `flutter test test/widget_test.dart`
Expected: PASS.

- [ ] **Step 3: Full gate — whole suite + analyzer**

Run: `flutter test`
Expected: all tests PASS (db, 3 repositories, notification service, dashboard provider, widget smoke).

Run: `flutter analyze`
Expected: "No issues found!"

- [ ] **Step 4: Commit**

```bash
git add test/widget_test.dart
git commit -m "test: add dashboard smoke test; green suite + clean analyze"
```

---

## Manual verification checklist (device / emulator)

Run after Task 9 on a real device or emulator (`flutter run`). Notifications cannot be fully proven in unit tests.

1. First launch → dashboard shows "Set a daily fluid limit".
2. Settings → set limit 1000 mL.
3. Fluid → add intake 700, then 350 → dashboard gauge turns **red** (1050 / 1000), net balance reflects output.
4. Medicines → add "Losartan", time set ~2 min in the future → wait → **notification fires**.
5. Tap dashboard **Taken** for the dose → tile shows "Taken", notification for that slot cancelled.
6. Reboot device → relaunch → medicine reminder is re-scheduled (fires next day at its time).
7. Toggle reminders off in Settings (flag persists across relaunch).

---

## Self-Review

**Spec coverage:**
- Fluid intake/output + daily limit + gauge + net balance → Tasks 3, 7, 8 (FluidGauge color thresholds, DailyFluidTotals.netMl). ✓
- Medicine fixed-time reminders + Taken/Skip + adherence log → Tasks 5, 6, 7, 8. ✓
- Idempotent dose log (`medicine_id + scheduled_time`) → Task 5 test. ✓
- Stable/idempotent notification IDs + reschedule-on-boot + cancel-on-dashboard-mark → Task 6, `main.dart` boot loop, `DashboardProvider.markDose`. ✓
- Soft-delete medicine → Task 5 `deactivate`. ✓
- Versioned schema + migration guard → Task 1 (`onUpgrade` stub, test asserts v1). ✓
- Settings (limit, notifications flag) → Task 4, SettingsProvider/Screen. ✓
- Edge cases (limit unset, permission denied, dose acted twice) → FluidGauge null-limit branch, dashboard is source of truth, Task 5 idempotency. ✓
- Testing plan (unit rollups/idempotency/migration, provider aggregation, notification IDs, smoke) → Tasks 1,3,4,5,6,7,9. ✓

**Placeholder scan:** No TBD/TODO; all code blocks complete; the `onUpgrade` empty body is an intentional v1 no-op (documented), not a placeholder.

**Type consistency:** `DailyFluidTotals`, `FluidEntry.dayOf`, `DueDose`, `NotificationService.notificationId`, `saveMedicine(Medicine, List<String>)`, `logDose(int, DateTime, DoseStatus)`, `statusFor` signatures match across producing and consuming tasks. Provider constructor uses `dynamic`-typed named params, so the same fakes work in provider tests, the widget smoke test, and real repos in `main.dart`.

**Deferred (Group B/C, not gaps):** lab results, medicine stock, dialysis schedule, food lists — future specs/migrations, per the design.
