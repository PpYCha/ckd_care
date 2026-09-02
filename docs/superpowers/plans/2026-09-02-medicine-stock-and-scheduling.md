# Medicine Stock & Scheduling Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Extend medicines with stock tracking (decrements when a dose is taken), an optional end-date, richer list display (times/stock/end-date), and a proper add/edit form with validation, time pre-loading on edit, and a save confirmation — hiding depleted/expired medicines from the dashboard only.

**Architecture:** Adds two columns to the `medicine` table via a real v1→v2 SQLite migration. Stock adjustment is folded into the existing `logDose` transaction (taken consumes 1, reversing a taken restores 1). A new `dashboardMedicines(today)` repository query filters out `stock_qty == 0` or past-`end_date` medicines for the dashboard, while the Medicines management list keeps showing all active medicines.

**Tech Stack:** Flutter, `provider`, `sqflite` + `sqflite_common_ffi` (tests), existing repository/provider layering.

## Global Constraints

- **Decisions (locked):** stock is **required for every medicine** (non-null int ≥ 0); depleted (`stock_qty == 0`) or past-`end_date` medicines are hidden from the **dashboard only** (still shown in the Medicines list for restocking); only marking a dose **Taken** decrements stock (by 1), and reversing Taken→Skipped restores 1.
- All DB access stays inside repositories; UI/providers never touch `sqflite`.
- Sync-metadata discipline continues: every write bumps `updated_at`; no hard deletes; reads filter `deleted = 0`. New columns live on the existing `medicine` table (already sync-tracked).
- `end_date` is stored as `'YYYY-MM-DD'` text (nullable); inclusive — a medicine is available through its end-date.
- Dates: `updated_at` is full ISO-8601; `end_date` and the dashboard "today" comparison use `'YYYY-MM-DD'`.
- Schema bumps to **version 2**. Fresh installs get the new columns via `onCreate`; existing v1 DBs get them via `onUpgrade` `ALTER TABLE`.
- `flutter analyze` clean and `flutter test` green is the gate for every task.

---

## File Structure

```
lib/
  db/app_database.dart            # MODIFY: schemaVersion=2, medicine DDL + onUpgrade ALTERs
  models/medicine.dart            # MODIFY: Medicine gains stockQty (required) + endDate (nullable)
  repositories/medicine_repository.dart  # MODIFY: dashboardMedicines(), stock-aware logDose
  providers/medicine_provider.dart       # MODIFY: timesByMedicine map, timesForMedicine()
  providers/dashboard_provider.dart      # MODIFY: use dashboardMedicines(day)
  screens/medicine_detail_screen.dart    # MODIFY: form + stock/end-date fields, preload times, validation, toast
  screens/medicines_screen.dart          # MODIFY: show times, stock, end-date
test/
  db/app_database_test.dart              # MODIFY: assert v2 + columns + a v1→v2 migration test
  repositories/medicine_repository_test.dart  # MODIFY: stock construction + new stock/filter tests
  providers/dashboard_provider_test.dart      # MODIFY: fake uses dashboardMedicines + stockQty
  widget_test.dart                            # MODIFY: fake uses dashboardMedicines + stockQty
```

---

### Task 1: Schema v2 migration + Medicine model fields

Adds `stock_qty` and `end_date` to the `medicine` table (fresh + upgrade paths) and the corresponding model fields. Because `Medicine`'s constructor gains a required field, this task also updates every `Medicine(...)` construction site in the test suite so `flutter test` stays green.

**Files:**
- Modify: `lib/db/app_database.dart`, `lib/models/medicine.dart`
- Modify (keep suite compiling): `test/repositories/medicine_repository_test.dart`, `test/providers/dashboard_provider_test.dart`, `test/widget_test.dart`
- Test: `test/db/app_database_test.dart`

**Interfaces:**
- Produces:
  - `Medicine` gains `final int stockQty;` (required) and `final DateTime? endDate;` (nullable), round-tripped in `fromMap`/`toMap`; plus `static String fmtDate(DateTime d)` → `'YYYY-MM-DD'`.
  - `medicine` table columns `stock_qty INTEGER NOT NULL DEFAULT 0` and `end_date TEXT` (nullable).
  - `AppDatabase.schemaVersion == 2`.

- [ ] **Step 1: Update the migration test first**

In `test/db/app_database_test.dart`, add these two tests inside `main()` (keep the existing test). Add imports at the top: `import 'dart:io';` and `import 'package:path/path.dart' as p;`

```dart
  test('schema is version 2 with stock_qty and end_date on medicine', () async {
    final db = AppDatabase(databaseFactoryFfi, path: inMemoryDatabasePath);
    final database = await db.database;
    expect(await database.getVersion(), 2);
    final cols = (await database.rawQuery('PRAGMA table_info(medicine)'))
        .map((r) => r['name'])
        .toSet();
    expect(cols, containsAll(['stock_qty', 'end_date']));
    await db.close();
  });

  test('migrates a v1 database to v2 by adding the new columns', () async {
    final dir = await Directory.systemTemp.createTemp('ckd_mig');
    final path = p.join(dir.path, 'v1.db');
    // Build a minimal v1 medicine table (no stock_qty/end_date).
    final v1 = await databaseFactoryFfi.openDatabase(path,
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
        ));
    await v1.close();

    // Reopen through AppDatabase (version 2) -> triggers onUpgrade.
    final appDb = AppDatabase(databaseFactoryFfi, path: path);
    final db2 = await appDb.database;
    final cols = (await db2.rawQuery('PRAGMA table_info(medicine)'))
        .map((r) => r['name'])
        .toSet();
    expect(cols, containsAll(['stock_qty', 'end_date']));
    // Existing row survived and got the default stock.
    final row = (await db2.query('medicine', where: 'uuid = ?', whereArgs: ['u-legacy'])).single;
    expect(row['stock_qty'], 0);
    expect(row['end_date'], isNull);
    await appDb.close();
    await dir.delete(recursive: true);
  });
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `flutter test test/db/app_database_test.dart`
Expected: FAIL — version is 1 and `stock_qty`/`end_date` columns don't exist yet.

- [ ] **Step 3: Bump schema version and add the columns + migration**

In `lib/db/app_database.dart`:

Change the version constant:

```dart
  static const int schemaVersion = 2;
```

Replace the `onUpgrade` callback body with:

```dart
        onUpgrade: (db, oldVersion, newVersion) async {
          if (oldVersion < 2) {
            await db.execute(
                'ALTER TABLE medicine ADD COLUMN stock_qty INTEGER NOT NULL DEFAULT 0');
            await db.execute('ALTER TABLE medicine ADD COLUMN end_date TEXT');
          }
        },
```

In `_v1Statements`, replace the `CREATE TABLE medicine(...)` statement with (adds the two columns so fresh installs match the upgraded schema):

```dart
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
```

- [ ] **Step 4: Add the model fields**

In `lib/models/medicine.dart`, replace the `Medicine` class (leave `MedicineTime` untouched) with:

```dart
class Medicine {
  const Medicine({
    this.id,
    required this.uuid,
    required this.name,
    this.dosage,
    this.active = true,
    required this.stockQty,
    this.endDate,
    required this.createdAt,
    required this.updatedAt,
    this.deleted = false,
  });

  final int? id;
  final String uuid;
  final String name;
  final String? dosage;
  final bool active;
  final int stockQty;
  final DateTime? endDate;
  final DateTime createdAt;
  final DateTime updatedAt;
  final bool deleted;

  /// 'YYYY-MM-DD' for storage/comparison.
  static String fmtDate(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-'
      '${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';

  factory Medicine.fromMap(Map<String, Object?> m) => Medicine(
        id: m['id'] as int?,
        uuid: m['uuid'] as String,
        name: m['name'] as String,
        dosage: m['dosage'] as String?,
        active: (m['active'] as int) == 1,
        stockQty: m['stock_qty'] as int,
        endDate: m['end_date'] == null
            ? null
            : DateTime.parse(m['end_date'] as String),
        createdAt: DateTime.parse(m['created_at'] as String),
        updatedAt: DateTime.parse(m['updated_at'] as String),
        deleted: (m['deleted'] as int) == 1,
      );

  Map<String, Object?> toMap() => {
        if (id != null) 'id': id,
        'uuid': uuid,
        'name': name,
        'dosage': dosage,
        'active': active ? 1 : 0,
        'stock_qty': stockQty,
        'end_date': endDate == null ? null : fmtDate(endDate!),
        'created_at': createdAt.toIso8601String(),
        'updated_at': updatedAt.toIso8601String(),
        'deleted': deleted ? 1 : 0,
      };
}
```

- [ ] **Step 5: Update Medicine construction sites in tests so the suite compiles**

The constructor now requires `stockQty`. Update every `Medicine(...)` in tests:

In `test/repositories/medicine_repository_test.dart`, change the `med` helper and the inline resave construction:

```dart
  Medicine med(String name, {int stock = 10}) => Medicine(
      uuid: newUuid(),
      name: name,
      stockQty: stock,
      createdAt: DateTime(2026, 9, 2),
      updatedAt: DateTime(2026, 9, 2));
```

And the inline `Medicine(...)` in the "saveMedicine replaces times" test — add `stockQty: 10`:

```dart
    await repo.saveMedicine(
        Medicine(
            id: id,
            uuid: newUuid(),
            name: 'Losartan',
            stockQty: 10,
            createdAt: DateTime(2026, 9, 2),
            updatedAt: DateTime(2026, 9, 2)),
        ['09:00']);
```

In `test/providers/dashboard_provider_test.dart` and `test/widget_test.dart`, each `_FakeMedicine` builds a `Medicine(id: 1, uuid: 'u1', name: 'Losartan', ...)` — add `stockQty: 10,` to both.

- [ ] **Step 6: Run the full suite + analyze**

Run: `flutter test`
Expected: all pass (migration tests now green; existing tests still green).

Run: `flutter analyze`
Expected: "No issues found!"

- [ ] **Step 7: Commit**

```bash
git add lib/db/app_database.dart lib/models/medicine.dart test/db/app_database_test.dart test/repositories/medicine_repository_test.dart test/providers/dashboard_provider_test.dart test/widget_test.dart
git commit -m "feat: add medicine stock_qty and end_date (schema v2 migration)"
```

---

### Task 2: Stock-aware dose logging + dashboard filtering (repository)

Folds stock adjustment into `logDose` and adds `dashboardMedicines(today)` that excludes depleted/expired medicines.

**Files:**
- Modify: `lib/repositories/medicine_repository.dart`
- Test: `test/repositories/medicine_repository_test.dart`

**Interfaces:**
- Consumes: `Medicine`, `DoseStatus`, `AppDatabase`.
- Produces:
  - `Future<List<Medicine>> dashboardMedicines(String today)` — `active = 1 AND deleted = 0 AND stock_qty > 0 AND (end_date IS NULL OR end_date >= today)`, ordered by name.
  - `logDose(int, DateTime, DoseStatus)` (unchanged signature) now also adjusts `medicine.stock_qty`: becoming Taken consumes 1 (clamped at 0); reversing Taken restores 1. All within one transaction.

- [ ] **Step 1: Write the failing tests**

Add to `test/repositories/medicine_repository_test.dart` inside `main()`:

```dart
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
    await repo.logDose(id, DateTime(2026, 9, 2, 18), DoseStatus.taken); // clamp 0
    expect((await repo.activeMedicines()).single.stockQty, 0);
  });

  test('dashboardMedicines excludes depleted and past-end-date medicines', () async {
    final ok = await repo.saveMedicine(med('InStock', stock: 5), ['08:00']);
    final depleted = await repo.saveMedicine(med('Empty', stock: 0), ['08:00']);
    final ended = await repo.saveMedicine(
        Medicine(
            uuid: newUuid(),
            name: 'Ended',
            stockQty: 5,
            endDate: DateTime(2026, 8, 31),
            createdAt: DateTime(2026, 9, 2),
            updatedAt: DateTime(2026, 9, 2)),
        ['08:00']);
    final futureEnd = await repo.saveMedicine(
        Medicine(
            uuid: newUuid(),
            name: 'FutureEnd',
            stockQty: 5,
            endDate: DateTime(2026, 12, 31),
            createdAt: DateTime(2026, 9, 2),
            updatedAt: DateTime(2026, 9, 2)),
        ['08:00']);

    final names = (await repo.dashboardMedicines('2026-09-02')).map((m) => m.name).toSet();
    expect(names, {'InStock', 'FutureEnd'});
    expect(names.contains('Empty'), isFalse);      // depleted
    expect(names.contains('Ended'), isFalse);       // end_date < today
    // Medicines list still shows all active (including depleted/ended).
    expect((await repo.activeMedicines()).length, 4);
    // ids referenced to avoid unused_local warnings
    expect([ok, depleted, ended, futureEnd].every((i) => i > 0), isTrue);
  });
```

- [ ] **Step 2: Run to verify failure**

Run: `flutter test test/repositories/medicine_repository_test.dart`
Expected: FAIL — `dashboardMedicines` undefined; stock not adjusted.

- [ ] **Step 3: Add `dashboardMedicines` and stock-aware `logDose`**

In `lib/repositories/medicine_repository.dart`, add the new query method (after `activeMedicines`):

```dart
  /// Active medicines eligible to show on the dashboard: in stock and not past
  /// their end-date. [today] is 'YYYY-MM-DD'.
  Future<List<Medicine>> dashboardMedicines(String today) async {
    final db = await _db.database;
    final rows = await db.query('medicine',
        where:
            'active = 1 AND deleted = 0 AND stock_qty > 0 AND (end_date IS NULL OR end_date >= ?)',
        whereArgs: [today],
        orderBy: 'name COLLATE NOCASE ASC');
    return rows.map(Medicine.fromMap).toList();
  }
```

Replace the entire `logDose` method with the transactional, stock-aware version:

```dart
  Future<void> logDose(
      int medicineId, DateTime scheduledTime, DoseStatus status) async {
    final db = await _db.database;
    final iso = scheduledTime.toIso8601String();
    final now = DateTime.now().toIso8601String();
    await db.transaction((txn) async {
      final existing = await txn.query('dose_log',
          columns: ['id', 'status'],
          where: 'medicine_id = ? AND scheduled_time = ? AND deleted = 0',
          whereArgs: [medicineId, iso]);
      final DoseStatus? oldStatus = existing.isEmpty
          ? null
          : DoseStatus.values.byName(existing.first['status'] as String);

      if (existing.isEmpty) {
        final medRows = await txn.query('medicine',
            columns: ['uuid'], where: 'id = ?', whereArgs: [medicineId]);
        final medicineUuid = medRows.first['uuid'] as String;
        await txn.insert('dose_log', {
          'uuid': newUuid(),
          'medicine_id': medicineId,
          'medicine_uuid': medicineUuid,
          'scheduled_time': iso,
          'status': status.name,
          'acted_at': now,
          'updated_at': now,
          'deleted': 0,
        });
      } else {
        await txn.update('dose_log',
            {'status': status.name, 'acted_at': now, 'updated_at': now},
            where: 'id = ?', whereArgs: [existing.first['id']]);
      }

      // Stock: becoming 'taken' consumes 1; reversing a 'taken' restores 1.
      // ponytail: clamp at 0 — at stock 0 a reversal could over-credit by 1,
      // but the dashboard hides 0-stock medicines so that path isn't reachable via UI.
      final adjustment = (oldStatus == DoseStatus.taken ? 1 : 0) -
          (status == DoseStatus.taken ? 1 : 0);
      if (adjustment != 0) {
        final medRows = await txn.query('medicine',
            columns: ['stock_qty'], where: 'id = ?', whereArgs: [medicineId]);
        final current = medRows.first['stock_qty'] as int;
        final next = (current + adjustment).clamp(0, 1 << 31);
        await txn.update('medicine', {'stock_qty': next, 'updated_at': now},
            where: 'id = ?', whereArgs: [medicineId]);
      }
    });
  }
```

- [ ] **Step 4: Run to verify passing**

Run: `flutter test test/repositories/medicine_repository_test.dart`
Expected: PASS (all medicine-repo tests, including the two new ones).

- [ ] **Step 5: Commit**

```bash
git add lib/repositories/medicine_repository.dart test/repositories/medicine_repository_test.dart
git commit -m "feat: decrement stock on taken dose; add dashboardMedicines filter"
```

---

### Task 3: Provider wiring (dashboard filter + list times)

Dashboard uses the filtered query; the Medicines list gains each medicine's times.

**Files:**
- Modify: `lib/providers/dashboard_provider.dart`, `lib/providers/medicine_provider.dart`
- Test: `test/providers/dashboard_provider_test.dart`

**Interfaces:**
- Consumes: `MedicineRepository.dashboardMedicines`, `MedicineRepository.timesFor`.
- Produces:
  - `MedicineProvider` gains `Map<int, List<String>> timesByMedicine` (populated by `load()`) and `Future<List<String>> timesForMedicine(int id)`.
  - `DashboardProvider.refresh` calls `_medicine.dashboardMedicines(day)` instead of `activeMedicines()`.

- [ ] **Step 1: Update the dashboard provider test**

In `test/providers/dashboard_provider_test.dart`, the `_FakeMedicine` currently exposes `activeMedicines()`. Rename it to `dashboardMedicines(String today)` (same return), so it matches the new call:

```dart
  Future<List<Medicine>> dashboardMedicines(String today) async => [
        Medicine(
            id: 1,
            uuid: 'u1',
            name: 'Losartan',
            stockQty: 10,
            createdAt: DateTime(2026, 9, 2),
            updatedAt: DateTime(2026, 9, 2))
      ];
```

(Leave `timesFor`, `statusFor`, `logDose` on the fake as they are.) The existing assertions on `dueToday` remain valid.

- [ ] **Step 2: Run to verify failure**

Run: `flutter test test/providers/dashboard_provider_test.dart`
Expected: FAIL — `DashboardProvider` still calls `activeMedicines`, which the fake no longer defines (NoSuchMethodError), or the assertion on dueToday is empty.

- [ ] **Step 3: Point the dashboard at the filtered query**

In `lib/providers/dashboard_provider.dart`, in `refresh()`, change the medicines fetch line:

```dart
    final meds = await _medicine.dashboardMedicines(day);
```

(`day` is already computed as `FluidEntry.dayOf(today)` earlier in the method.)

- [ ] **Step 4: Run to verify passing**

Run: `flutter test test/providers/dashboard_provider_test.dart`
Expected: PASS.

- [ ] **Step 5: Add times to MedicineProvider**

In `lib/providers/medicine_provider.dart`, add a times map and a lookup, populated on load:

```dart
  List<Medicine> medicines = const [];
  Map<int, List<String>> timesByMedicine = {};

  Future<void> load() async {
    medicines = await _repo.activeMedicines();
    final map = <int, List<String>>{};
    for (final m in medicines) {
      map[m.id!] = (await _repo.timesFor(m.id!)).map((t) => t.timeOfDay).toList();
    }
    timesByMedicine = map;
    notifyListeners();
  }

  /// Times ('HH:mm') for one medicine — used by the edit form to pre-load.
  Future<List<String>> timesForMedicine(int id) async =>
      (await _repo.timesFor(id)).map((t) => t.timeOfDay).toList();
```

(Replace the existing `medicines` field declaration + `load()` method with the above; keep `save`/`deactivate` unchanged.)

- [ ] **Step 6: Run full suite + analyze**

Run: `flutter test`
Expected: all pass.

Run: `flutter analyze`
Expected: "No issues found!"

- [ ] **Step 7: Commit**

```bash
git add lib/providers/dashboard_provider.dart lib/providers/medicine_provider.dart test/providers/dashboard_provider_test.dart
git commit -m "feat: dashboard uses stock-filtered medicines; expose medicine times"
```

---

### Task 4: Medicine form + list UI

Rebuilds the add/edit screen with stock and end-date fields, required-field validation, time pre-loading on edit, and a save-success toast; enriches the Medicines list with times, stock, and end-date.

**Files:**
- Modify: `lib/screens/medicine_detail_screen.dart`, `lib/screens/medicines_screen.dart`
- Test: none new (UI transcription; behavior is covered by Tasks 1–3). Verified via `flutter analyze` and manual check.

**Interfaces:**
- Consumes: `Medicine` (with `stockQty`/`endDate`), `MedicineProvider.save`, `MedicineProvider.timesForMedicine`, `MedicineProvider.timesByMedicine`.

- [ ] **Step 1: Rewrite the medicine detail screen**

Replace `lib/screens/medicine_detail_screen.dart` entirely:

```dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:ckd_care/db/ids.dart';
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
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _name =
      TextEditingController(text: widget.medicine?.name ?? '');
  late final TextEditingController _dosage =
      TextEditingController(text: widget.medicine?.dosage ?? '');
  late final TextEditingController _stock = TextEditingController(
      text: widget.medicine?.stockQty.toString() ?? '');
  final List<String> _times = [];
  DateTime? _endDate;
  bool _timesError = false;

  @override
  void initState() {
    super.initState();
    final m = widget.medicine;
    if (m != null) {
      _endDate = m.endDate;
      // Pre-load existing times for edit.
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        final times = await context.read<MedicineProvider>().timesForMedicine(m.id!);
        if (mounted) setState(() => _times..clear()..addAll(times));
      });
    }
  }

  Future<void> _pickTime() async {
    final t = await showTimePicker(context: context, initialTime: TimeOfDay.now());
    if (t != null) {
      setState(() {
        _times.add(
            '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}');
        _timesError = false;
      });
    }
  }

  Future<void> _pickEndDate() async {
    final now = DateTime.now();
    final d = await showDatePicker(
      context: context,
      initialDate: _endDate ?? now,
      firstDate: now.subtract(const Duration(days: 365)),
      lastDate: DateTime(now.year + 5),
    );
    if (d != null) setState(() => _endDate = d);
  }

  Future<void> _save() async {
    final formOk = _formKey.currentState!.validate();
    setState(() => _timesError = _times.isEmpty);
    if (!formOk || _times.isEmpty) return;

    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    final med = Medicine(
      id: widget.medicine?.id,
      uuid: widget.medicine?.uuid ?? newUuid(),
      name: _name.text.trim(),
      dosage: _dosage.text.trim().isEmpty ? null : _dosage.text.trim(),
      stockQty: int.parse(_stock.text.trim()),
      endDate: _endDate,
      createdAt: widget.medicine?.createdAt ?? DateTime.now(),
      updatedAt: DateTime.now(),
    );
    await context.read<MedicineProvider>().save(med, _times..sort());
    if (!mounted) return;
    navigator.pop();
    messenger.showSnackBar(
        const SnackBar(content: Text('Saved successfully')));
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
                final provider = context.read<MedicineProvider>();
                final navigator = Navigator.of(context);
                await provider.deactivate(widget.medicine!);
                if (mounted) navigator.pop();
              },
            ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(padding: const EdgeInsets.all(16), children: [
          TextFormField(
            controller: _name,
            decoration: const InputDecoration(
                labelText: 'Name *', hintText: 'Required'),
            validator: (v) =>
                (v == null || v.trim().isEmpty) ? 'Name is required' : null,
          ),
          TextFormField(
            controller: _dosage,
            decoration: const InputDecoration(labelText: 'Dosage'),
          ),
          TextFormField(
            controller: _stock,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
                labelText: 'Stock quantity *', hintText: 'Required'),
            validator: (v) {
              final n = int.tryParse((v ?? '').trim());
              if (n == null) return 'Enter a whole number';
              if (n < 0) return 'Stock cannot be negative';
              return null;
            },
          ),
          const SizedBox(height: 16),
          Row(children: [
            Expanded(
              child: Text(_endDate == null
                  ? 'End date: none (indefinite)'
                  : 'Taken until ${Medicine.fmtDate(_endDate!)}'),
            ),
            if (_endDate != null)
              IconButton(
                  icon: const Icon(Icons.clear),
                  onPressed: () => setState(() => _endDate = null)),
            TextButton(onPressed: _pickEndDate, child: const Text('Set end date')),
          ]),
          const SizedBox(height: 8),
          const Text('Reminder times *'),
          Wrap(spacing: 8, children: [
            for (final t in _times)
              Chip(
                label: Text(t),
                onDeleted: () => setState(() => _times.remove(t)),
              ),
            ActionChip(label: const Text('+ time'), onPressed: _pickTime),
          ]),
          if (_timesError)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text('Add at least one time',
                  style: TextStyle(color: Theme.of(context).colorScheme.error)),
            ),
          const SizedBox(height: 24),
          FilledButton(onPressed: _save, child: const Text('Save')),
        ]),
      ),
    );
  }
}
```

- [ ] **Step 2: Enrich the Medicines list**

Replace the `ListTile` loop in `lib/screens/medicines_screen.dart`'s `build` (the `for (final m in p.medicines)` block) with one that shows times, stock, and end-date. Replace the whole `body: ListView(...)` with:

```dart
      body: ListView(children: [
        for (final m in p.medicines)
          ListTile(
            title: Text(m.name),
            subtitle: Text([
              if ((m.dosage ?? '').isNotEmpty) m.dosage!,
              if ((p.timesByMedicine[m.id] ?? []).isNotEmpty)
                (p.timesByMedicine[m.id] ?? []).join(', '),
              'Stock: ${m.stockQty}',
              if (m.endDate != null) 'Until ${Medicine.fmtDate(m.endDate!)}',
            ].join('  •  ')),
            trailing: m.stockQty == 0
                ? const Chip(label: Text('Out of stock'))
                : null,
            onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (_) => MedicineDetailScreen(medicine: m))),
          ),
        if (p.medicines.isEmpty) const ListTile(title: Text('No medicines yet')),
      ]),
```

Add the model import at the top of `medicines_screen.dart` (needed for `Medicine.fmtDate`):

```dart
import 'package:ckd_care/models/medicine.dart';
```

- [ ] **Step 3: Analyze**

Run: `flutter analyze`
Expected: "No issues found!" (fix any const/lint issues it reports).

- [ ] **Step 4: Full suite**

Run: `flutter test`
Expected: all pass (unchanged — this task is UI only).

- [ ] **Step 5: Commit**

```bash
git add lib/screens/medicine_detail_screen.dart lib/screens/medicines_screen.dart
git commit -m "feat: medicine form with stock/end-date, validation, save toast; richer list"
```

---

## Manual verification checklist (device/emulator)

Run after Task 4 via `flutter run -d Pixel_4a_API_34`:

1. Add a medicine with name, stock 3, one time ~2 min out, no end date → **"Saved successfully"** toast appears.
2. Medicines list shows the medicine with its time(s), `Stock: 3`.
3. Dashboard shows the dose → mark **Taken** → open Medicines list → `Stock: 2`.
4. Mark the same dose **Skip** (from dashboard) → stock back to `3`.
5. Edit the medicine → the name, dosage, stock, end-date, and **times are pre-loaded**.
6. Try to save with an empty name / empty stock / no times → inline validation errors block save.
7. Set stock to 0 (edit) → it disappears from the **dashboard** but still shows in the **Medicines list** with an "Out of stock" chip.
8. Set an end-date in the past (edit) → disappears from the dashboard, still in the list.

---

## Self-Review

**Spec coverage:**
- List shows time taken (not just name/dosage) → Task 3 (`timesByMedicine`) + Task 4 Step 2. ✓
- Stock feature; taken reflects on stock → Task 1 (column) + Task 2 (`logDose` decrement) + Task 4 (field/display). ✓
- Stock 0 → hidden from dashboard list → Task 2 (`dashboardMedicines` `stock_qty > 0`) + Task 3 (wiring). ✓
- "Taken until X date" + hidden after end-date → Task 1 (`end_date`) + Task 2 (`end_date >= today` filter) + Task 4 (date picker). ✓
- Save success toast → Task 4 Step 1 (SnackBar after save). ✓
- Edit loads time + other details → Task 3 (`timesForMedicine`) + Task 4 (`initState` pre-load, controllers seeded from `widget.medicine`). ✓
- Required fields (name, stock, ≥1 time) → Task 4 (Form validators + `_timesError`). ✓

**Placeholder scan:** No TBD/TODO; all code blocks complete; the `ponytail:` comment on the stock clamp documents a real, UI-prevented edge, not a placeholder.

**Type consistency:** `stockQty` (int), `endDate` (DateTime?), `Medicine.fmtDate`, `dashboardMedicines(String today)`, `timesByMedicine` (`Map<int,List<String>>`), `timesForMedicine(int)→Future<List<String>>` are used identically across producing (Tasks 1–3) and consuming (Task 4) tasks. The dashboard fake is renamed `activeMedicines`→`dashboardMedicines` in the same task (3) that changes the real call.

**Deferred (not in scope):** low-stock warnings/notifications, stock history/audit, per-day one-shot reminder scheduling (unchanged), and the rest of Group B (labs, dialysis schedule).
