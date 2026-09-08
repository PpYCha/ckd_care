# Personal Dialysis Schedule Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Let the user record their recurring weekly dialysis schedule (which weekdays, time, duration, clinic) and see their next session and upcoming sessions — a "Next session" card + an upcoming list, matching the reference design, plus a compact next-session card on the dashboard.

**Architecture:** A recurring weekly pattern (`DialysisSchedule`) is stored as config in the existing `setting` key/value table under `dialysis_sched_*` keys — the same pattern the health profile uses, so no new SQL table or migration. Concrete upcoming sessions are **computed** (never stored) by pure functions from the pattern + the current time. A `DialysisScheduleProvider` (mirroring `HealthProfileProvider`) exposes the pattern to the UI; screens render the computed next/upcoming sessions and an edit form. The feature is reached from Settings, with a compact next-session card surfaced on the dashboard.

**Tech Stack:** Flutter, `provider` (already used), `sqflite` via the existing `SettingsRepository`, the app theme (`AppColors.dialysis` purple). No new dependencies.

## Global Constraints

- **Offline-first, no new dependency, no new SQL table.** Store the schedule in the existing `setting` table via `SettingsRepository`, exactly like `HealthProfile` (`profile_*` keys). Sessions are derived, not persisted.
- **Recurring weekly pattern only** for v1. One-off overrides (a single moved/cancelled session), attendance logging, and pre-session reminder notifications are explicitly **out of scope** (deferred) — do not add them.
- **This is scheduling, not clinical advice.** No medical claims, no disclaimers needed beyond plain scheduling copy.
- **Weekday convention:** `DateTime.weekday`, i.e. **1 = Monday … 7 = Sunday**, everywhere (model, storage, UI). Never use 0-based.
- **Time is stored as `'HH:mm'`** (24-hour, zero-padded) and displayed as 12-hour (`'9:00 AM'`).
- **Purple accent** (`AppColors.dialysis`) for this module, consistent with the existing "Dialysis centers" styling.
- Follow existing patterns: value object with `==`/`hashCode` (like `HealthProfile`), provider with `load()`/`save()` (like `HealthProfileProvider`), screens using `Theme.of(context)` `colorScheme`/`textTheme`.
- `flutter analyze` clean and `flutter test` green is the gate for every task.

---

## File Structure

```
lib/models/
  dialysis_schedule.dart              # CREATE: DialysisSchedule + DialysisSession value objects,
                                      #   pure nextSession/upcomingSessions, format + weekday helpers
lib/repositories/
  settings_repository.dart            # MODIFY: dialysis_sched_* keys + get/save/clear schedule
lib/providers/
  dialysis_schedule_provider.dart     # CREATE: ChangeNotifier wrapping SettingsRepository
lib/widgets/
  next_dialysis_card.dart             # CREATE: the purple "Next session" card (shared by screen + dashboard)
lib/screens/
  dialysis_schedule_screen.dart       # CREATE: next-session card + upcoming list + empty/setup state
  dialysis_schedule_edit_screen.dart  # CREATE: weekday/time/duration/clinic form
lib/main.dart                         # MODIFY: register DialysisScheduleProvider
lib/screens/settings_screen.dart      # MODIFY: "Dialysis schedule" entry
lib/screens/dashboard_screen.dart     # MODIFY: compact next-session card when a schedule is set
test/models/
  dialysis_schedule_test.dart         # CREATE
test/repositories/
  settings_repository_test.dart       # MODIFY: schedule round-trip test
test/providers/
  dialysis_schedule_provider_test.dart # CREATE
```

---

### Task 1: DialysisSchedule model + session computation (pure)

The testable core: the value objects, the recurring-to-concrete session computation, and display helpers.

**Files:**
- Create: `lib/models/dialysis_schedule.dart`
- Test: `test/models/dialysis_schedule_test.dart`

**Interfaces:**
- Produces:
  - `class DialysisSchedule` — `const DialysisSchedule({required Set<int> weekdays, required String timeOfDay, required int durationHours, required String clinicName, required String clinicAddress})`; `bool get isSet => weekdays.isNotEmpty`; value equality.
  - `class DialysisSession` — `const DialysisSession({required DateTime start, required int durationHours, required String clinicName, required String clinicAddress})`; `DateTime get end`.
  - `List<DialysisSession> upcomingSessions(DialysisSchedule schedule, {required DateTime now, int count = 6})`
  - `DialysisSession? nextSession(DialysisSchedule schedule, {required DateTime now})`
  - `String encodeWeekdays(Set<int> weekdays)` → CSV like `'1,3,5'` (sorted); `Set<int> decodeWeekdays(String? csv)`
  - `const List<String> kWeekdayAbbr` (index 0 = Mon … 6 = Sun); `const List<String> kMonthAbbr`
  - `String formatTime12(DateTime t)` → `'9:00 AM'`; `String weekdayAbbr(DateTime t)`; `String monthAbbr(DateTime t)`

- [ ] **Step 1: Write the failing tests**

```dart
// test/models/dialysis_schedule_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:ckd_care/models/dialysis_schedule.dart';

void main() {
  // Mon/Wed/Fri, 09:00, 4h. Weekdays: Mon=1, Wed=3, Fri=5.
  const mwf = DialysisSchedule(
    weekdays: {1, 3, 5},
    timeOfDay: '09:00',
    durationHours: 4,
    clinicName: 'Healthy Kidney Center',
    clinicAddress: '123 Main St',
  );

  test('isSet reflects whether any weekday is chosen', () {
    expect(mwf.isSet, isTrue);
    expect(
      const DialysisSchedule(
              weekdays: {},
              timeOfDay: '09:00',
              durationHours: 4,
              clinicName: '',
              clinicAddress: '')
          .isSet,
      isFalse,
    );
  });

  test('nextSession is the soonest future occurrence', () {
    // Tuesday 2026-09-01 10:00 -> next is Wednesday 2026-09-02 09:00.
    final next = nextSession(mwf, now: DateTime(2026, 9, 1, 10));
    expect(next, isNotNull);
    expect(next!.start, DateTime(2026, 9, 2, 9, 0));
    expect(next.durationHours, 4);
    expect(next.clinicName, 'Healthy Kidney Center');
    expect(next.end, DateTime(2026, 9, 2, 13, 0));
  });

  test("a session earlier today is excluded; later today is included", () {
    // Wednesday 2026-09-02 at 08:00 (before 09:00) -> today's 09:00 counts.
    final before = nextSession(mwf, now: DateTime(2026, 9, 2, 8));
    expect(before!.start, DateTime(2026, 9, 2, 9, 0));
    // Wednesday 2026-09-02 at 09:30 (after start) -> today's is past, next is Friday.
    final after = nextSession(mwf, now: DateTime(2026, 9, 2, 9, 30));
    expect(after!.start, DateTime(2026, 9, 4, 9, 0));
  });

  test('upcomingSessions returns the next N in order', () {
    // From Tuesday 2026-09-01 10:00: Wed 09-02, Fri 09-04, Mon 09-07.
    final list = upcomingSessions(mwf, now: DateTime(2026, 9, 1, 10), count: 3);
    expect(list.map((s) => s.start).toList(), [
      DateTime(2026, 9, 2, 9, 0),
      DateTime(2026, 9, 4, 9, 0),
      DateTime(2026, 9, 7, 9, 0),
    ]);
  });

  test('an unset schedule yields no sessions', () {
    const empty = DialysisSchedule(
        weekdays: {},
        timeOfDay: '09:00',
        durationHours: 4,
        clinicName: '',
        clinicAddress: '');
    expect(nextSession(empty, now: DateTime(2026, 9, 1)), isNull);
    expect(upcomingSessions(empty, now: DateTime(2026, 9, 1)), isEmpty);
  });

  test('encode/decode weekdays round-trips and sorts', () {
    expect(encodeWeekdays({5, 1, 3}), '1,3,5');
    expect(decodeWeekdays('1,3,5'), {1, 3, 5});
    expect(decodeWeekdays(''), <int>{});
    expect(decodeWeekdays(null), <int>{});
  });

  test('formatTime12 renders 12-hour clock', () {
    expect(formatTime12(DateTime(2026, 1, 1, 9, 0)), '9:00 AM');
    expect(formatTime12(DateTime(2026, 1, 1, 13, 5)), '1:05 PM');
    expect(formatTime12(DateTime(2026, 1, 1, 0, 0)), '12:00 AM');
    expect(formatTime12(DateTime(2026, 1, 1, 12, 0)), '12:00 PM');
  });

  test('equality is by value', () {
    expect(
      mwf,
      const DialysisSchedule(
        weekdays: {1, 3, 5},
        timeOfDay: '09:00',
        durationHours: 4,
        clinicName: 'Healthy Kidney Center',
        clinicAddress: '123 Main St',
      ),
    );
  });
}
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `flutter test test/models/dialysis_schedule_test.dart`
Expected: FAIL — `dialysis_schedule.dart` / the symbols are not defined.

- [ ] **Step 3: Implement the model + pure functions**

```dart
// lib/models/dialysis_schedule.dart
import 'package:flutter/foundation.dart';

/// A recurring weekly dialysis pattern. Weekdays use [DateTime.weekday] values
/// (1 = Monday … 7 = Sunday). Concrete sessions are computed, never stored.
@immutable
class DialysisSchedule {
  const DialysisSchedule({
    required this.weekdays,
    required this.timeOfDay,
    required this.durationHours,
    required this.clinicName,
    required this.clinicAddress,
  });

  final Set<int> weekdays; // 1..7 (Mon..Sun)
  final String timeOfDay; // 'HH:mm'
  final int durationHours;
  final String clinicName;
  final String clinicAddress;

  bool get isSet => weekdays.isNotEmpty;

  DialysisSchedule copyWith({
    Set<int>? weekdays,
    String? timeOfDay,
    int? durationHours,
    String? clinicName,
    String? clinicAddress,
  }) =>
      DialysisSchedule(
        weekdays: weekdays ?? this.weekdays,
        timeOfDay: timeOfDay ?? this.timeOfDay,
        durationHours: durationHours ?? this.durationHours,
        clinicName: clinicName ?? this.clinicName,
        clinicAddress: clinicAddress ?? this.clinicAddress,
      );

  @override
  bool operator ==(Object other) =>
      other is DialysisSchedule &&
      setEquals(other.weekdays, weekdays) &&
      other.timeOfDay == timeOfDay &&
      other.durationHours == durationHours &&
      other.clinicName == clinicName &&
      other.clinicAddress == clinicAddress;

  @override
  int get hashCode => Object.hash(
        Object.hashAllUnordered(weekdays),
        timeOfDay,
        durationHours,
        clinicName,
        clinicAddress,
      );
}

/// A concrete, dated occurrence derived from a [DialysisSchedule].
@immutable
class DialysisSession {
  const DialysisSession({
    required this.start,
    required this.durationHours,
    required this.clinicName,
    required this.clinicAddress,
  });

  final DateTime start;
  final int durationHours;
  final String clinicName;
  final String clinicAddress;

  DateTime get end => start.add(Duration(hours: durationHours));
}

/// The next [count] sessions with a start strictly after [now], soonest first.
List<DialysisSession> upcomingSessions(DialysisSchedule schedule,
    {required DateTime now, int count = 6}) {
  if (!schedule.isSet) return const [];
  final parts = schedule.timeOfDay.split(':');
  final hour = int.parse(parts[0]);
  final minute = int.parse(parts[1]);

  final result = <DialysisSession>[];
  var day = DateTime(now.year, now.month, now.day);
  final maxDays = count * 7 + 7; // weekly pattern: this always finds `count`
  for (var i = 0; i < maxDays && result.length < count; i++) {
    if (schedule.weekdays.contains(day.weekday)) {
      final start = DateTime(day.year, day.month, day.day, hour, minute);
      if (start.isAfter(now)) {
        result.add(DialysisSession(
          start: start,
          durationHours: schedule.durationHours,
          clinicName: schedule.clinicName,
          clinicAddress: schedule.clinicAddress,
        ));
      }
    }
    day = day.add(const Duration(days: 1));
  }
  return result;
}

DialysisSession? nextSession(DialysisSchedule schedule, {required DateTime now}) {
  final list = upcomingSessions(schedule, now: now, count: 1);
  return list.isEmpty ? null : list.first;
}

String encodeWeekdays(Set<int> weekdays) =>
    (weekdays.toList()..sort()).join(',');

Set<int> decodeWeekdays(String? csv) {
  final s = (csv ?? '').trim();
  if (s.isEmpty) return <int>{};
  return s.split(',').map((e) => int.parse(e.trim())).toSet();
}

const List<String> kWeekdayAbbr = [
  'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'
];
const List<String> kMonthAbbr = [
  'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
  'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
];

String weekdayAbbr(DateTime t) => kWeekdayAbbr[t.weekday - 1];
String monthAbbr(DateTime t) => kMonthAbbr[t.month - 1];

String formatTime12(DateTime t) {
  final h = t.hour % 12 == 0 ? 12 : t.hour % 12;
  final ampm = t.hour < 12 ? 'AM' : 'PM';
  return '$h:${t.minute.toString().padLeft(2, '0')} $ampm';
}
```

- [ ] **Step 4: Run the tests to verify they pass**

Run: `flutter test test/models/dialysis_schedule_test.dart`
Expected: PASS (8 tests).

- [ ] **Step 5: Commit**

```bash
git add lib/models/dialysis_schedule.dart test/models/dialysis_schedule_test.dart
git commit -m "feat: dialysis schedule model + session computation"
```

---

### Task 2: Persist the schedule in SettingsRepository

Store/read the pattern in the `setting` table, mirroring the health-profile methods.

**Files:**
- Modify: `lib/repositories/settings_repository.dart`
- Test: `test/repositories/settings_repository_test.dart`

**Interfaces:**
- Consumes: `DialysisSchedule`, `encodeWeekdays`, `decodeWeekdays` (Task 1).
- Produces on `SettingsRepository`:
  - `Future<DialysisSchedule> getDialysisSchedule()` — returns an unset schedule (empty weekdays, `timeOfDay: '09:00'`, `durationHours: 4`, empty clinic fields) when nothing is stored.
  - `Future<void> saveDialysisSchedule(DialysisSchedule schedule)`
  - `Future<void> clearDialysisSchedule()` — removes the schedule (subsequent `getDialysisSchedule().isSet` is false).

- [ ] **Step 1: Write the failing test**

Add this test to the existing `test/repositories/settings_repository_test.dart` `main()` (the file already sets up `sqfliteFfiInit()` and a `newDb()`/repo helper — reuse whatever it defines; the snippet below constructs the repo the same way the existing tests in that file do):

```dart
  test('dialysis schedule is unset until saved, then round-trips; clear removes it',
      () async {
    final repo = SettingsRepository(
        AppDatabase(databaseFactoryFfi, path: inMemoryDatabasePath));

    final initial = await repo.getDialysisSchedule();
    expect(initial.isSet, isFalse);

    const s = DialysisSchedule(
      weekdays: {1, 3, 5},
      timeOfDay: '09:00',
      durationHours: 4,
      clinicName: 'Healthy Kidney Center',
      clinicAddress: '123 Main St',
    );
    await repo.saveDialysisSchedule(s);
    expect(await repo.getDialysisSchedule(), s);

    await repo.clearDialysisSchedule();
    expect((await repo.getDialysisSchedule()).isSet, isFalse);
  });
```

Ensure these imports are present at the top of the test file (add any missing):

```dart
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:ckd_care/db/app_database.dart';
import 'package:ckd_care/models/dialysis_schedule.dart';
import 'package:ckd_care/repositories/settings_repository.dart';
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `flutter test test/repositories/settings_repository_test.dart`
Expected: FAIL — `getDialysisSchedule`/`saveDialysisSchedule`/`clearDialysisSchedule` not defined.

- [ ] **Step 3: Implement the repository methods**

In `lib/repositories/settings_repository.dart`, add the import at the top (next to the existing `health_profile.dart` import):

```dart
import 'package:ckd_care/models/dialysis_schedule.dart';
```

Add the key constants next to the existing `k...` constants:

```dart
const String kDialysisSchedWeekdays = 'dialysis_sched_weekdays';
const String kDialysisSchedTime = 'dialysis_sched_time';
const String kDialysisSchedDuration = 'dialysis_sched_duration';
const String kDialysisSchedClinic = 'dialysis_sched_clinic';
const String kDialysisSchedClinicAddress = 'dialysis_sched_clinic_address';
```

Add these methods inside the `SettingsRepository` class (after `saveHealthProfile`). Note there is already a private `_get`/`_set` helper on the class — reuse them:

```dart
  Future<DialysisSchedule> getDialysisSchedule() async {
    return DialysisSchedule(
      weekdays: decodeWeekdays(await _get(kDialysisSchedWeekdays)),
      timeOfDay: await _get(kDialysisSchedTime) ?? '09:00',
      durationHours: int.tryParse(await _get(kDialysisSchedDuration) ?? '') ?? 4,
      clinicName: await _get(kDialysisSchedClinic) ?? '',
      clinicAddress: await _get(kDialysisSchedClinicAddress) ?? '',
    );
  }

  Future<void> saveDialysisSchedule(DialysisSchedule s) async {
    await _set(kDialysisSchedWeekdays, encodeWeekdays(s.weekdays));
    await _set(kDialysisSchedTime, s.timeOfDay);
    await _set(kDialysisSchedDuration, s.durationHours.toString());
    await _set(kDialysisSchedClinic, s.clinicName);
    await _set(kDialysisSchedClinicAddress, s.clinicAddress);
  }

  Future<void> clearDialysisSchedule() async {
    // Empty weekdays means "unset"; keep other keys harmless.
    await _set(kDialysisSchedWeekdays, '');
  }
```

- [ ] **Step 4: Run the test to verify it passes**

Run: `flutter test test/repositories/settings_repository_test.dart`
Expected: PASS (existing tests + the new one).

- [ ] **Step 5: Commit**

```bash
git add lib/repositories/settings_repository.dart test/repositories/settings_repository_test.dart
git commit -m "feat: persist dialysis schedule in settings"
```

---

### Task 3: DialysisScheduleProvider + registration

A thin `ChangeNotifier` over the repository, mirroring `HealthProfileProvider`, wired into the app.

**Files:**
- Create: `lib/providers/dialysis_schedule_provider.dart`
- Modify: `lib/main.dart`
- Test: `test/providers/dialysis_schedule_provider_test.dart`

**Interfaces:**
- Consumes: `SettingsRepository` (Task 2), `DialysisSchedule` (Task 1).
- Produces: `class DialysisScheduleProvider extends ChangeNotifier` with `DialysisScheduleProvider(SettingsRepository)`, a field `DialysisSchedule schedule` (defaults to an unset schedule), `Future<void> load()`, `Future<void> save(DialysisSchedule)`, `Future<void> clear()`.

- [ ] **Step 1: Write the failing test**

```dart
// test/providers/dialysis_schedule_provider_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:ckd_care/db/app_database.dart';
import 'package:ckd_care/models/dialysis_schedule.dart';
import 'package:ckd_care/providers/dialysis_schedule_provider.dart';
import 'package:ckd_care/repositories/settings_repository.dart';

void main() {
  sqfliteFfiInit();

  test('load defaults to unset; save then load round-trips; clear unsets',
      () async {
    final repo = SettingsRepository(
        AppDatabase(databaseFactoryFfi, path: inMemoryDatabasePath));
    final p = DialysisScheduleProvider(repo);

    await p.load();
    expect(p.schedule.isSet, isFalse);

    const s = DialysisSchedule(
      weekdays: {2, 4, 6},
      timeOfDay: '07:30',
      durationHours: 3,
      clinicName: 'Clinic A',
      clinicAddress: '',
    );
    await p.save(s);
    expect(p.schedule, s);

    await p.clear();
    expect(p.schedule.isSet, isFalse);
  });
}
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `flutter test test/providers/dialysis_schedule_provider_test.dart`
Expected: FAIL — `DialysisScheduleProvider` not defined.

- [ ] **Step 3: Implement the provider**

```dart
// lib/providers/dialysis_schedule_provider.dart
import 'package:flutter/foundation.dart';
import 'package:ckd_care/models/dialysis_schedule.dart';
import 'package:ckd_care/repositories/settings_repository.dart';

class DialysisScheduleProvider extends ChangeNotifier {
  DialysisScheduleProvider(this._repo);
  final SettingsRepository _repo;

  DialysisSchedule schedule = const DialysisSchedule(
    weekdays: {},
    timeOfDay: '09:00',
    durationHours: 4,
    clinicName: '',
    clinicAddress: '',
  );

  Future<void> load() async {
    schedule = await _repo.getDialysisSchedule();
    notifyListeners();
  }

  Future<void> save(DialysisSchedule s) async {
    await _repo.saveDialysisSchedule(s);
    schedule = s;
    notifyListeners();
  }

  Future<void> clear() async {
    await _repo.clearDialysisSchedule();
    schedule = await _repo.getDialysisSchedule();
    notifyListeners();
  }
}
```

- [ ] **Step 4: Run the test to verify it passes**

Run: `flutter test test/providers/dialysis_schedule_provider_test.dart`
Expected: PASS.

- [ ] **Step 5: Register the provider in `lib/main.dart`**

Add the import near the other provider imports:

```dart
import 'package:ckd_care/providers/dialysis_schedule_provider.dart';
```

In the `MultiProvider`'s `providers:` list (inside `CkdApp.build`), add alongside the existing `HealthProfileProvider` entry:

```dart
        ChangeNotifierProvider(
            create: (_) => DialysisScheduleProvider(settingsRepo)),
```

(`settingsRepo` is already a field on `CkdApp` and is used by the neighboring providers.)

- [ ] **Step 6: Analyze + full suite**

Run: `flutter analyze` → "No issues found!"
Run: `flutter test` → all pass.

- [ ] **Step 7: Commit**

```bash
git add lib/providers/dialysis_schedule_provider.dart lib/main.dart test/providers/dialysis_schedule_provider_test.dart
git commit -m "feat: DialysisScheduleProvider wired into the app"
```

---

### Task 4: Schedule setup / edit screen

A form to choose weekdays, time, duration, and clinic — save or clear.

**Files:**
- Create: `lib/screens/dialysis_schedule_edit_screen.dart`
- Test: none new (form screen; covered by manual verification in Task 6).

**Interfaces:**
- Consumes: `DialysisScheduleProvider` (Task 3), `DialysisSchedule`, `kWeekdayAbbr`, `formatTime12` (Task 1), `AppColors` (`lib/theme/app_theme.dart`).
- Produces: `class DialysisScheduleEditScreen extends StatefulWidget` with `const DialysisScheduleEditScreen({super.key})`.

- [ ] **Step 1: Implement the edit screen**

```dart
// lib/screens/dialysis_schedule_edit_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:ckd_care/models/dialysis_schedule.dart';
import 'package:ckd_care/providers/dialysis_schedule_provider.dart';
import 'package:ckd_care/theme/app_theme.dart';

class DialysisScheduleEditScreen extends StatefulWidget {
  const DialysisScheduleEditScreen({super.key});
  @override
  State<DialysisScheduleEditScreen> createState() =>
      _DialysisScheduleEditScreenState();
}

class _DialysisScheduleEditScreenState
    extends State<DialysisScheduleEditScreen> {
  late Set<int> _weekdays;
  late TimeOfDay _time;
  late int _duration;
  late final TextEditingController _clinic;
  late final TextEditingController _address;

  @override
  void initState() {
    super.initState();
    final s = context.read<DialysisScheduleProvider>().schedule;
    _weekdays = {...s.weekdays};
    final parts = s.timeOfDay.split(':');
    _time = TimeOfDay(
        hour: int.tryParse(parts[0]) ?? 9, minute: int.tryParse(parts[1]) ?? 0);
    _duration = s.durationHours;
    _clinic = TextEditingController(text: s.clinicName);
    _address = TextEditingController(text: s.clinicAddress);
  }

  @override
  void dispose() {
    _clinic.dispose();
    _address.dispose();
    super.dispose();
  }

  Future<void> _pickTime() async {
    final t = await showTimePicker(context: context, initialTime: _time);
    if (t != null) setState(() => _time = t);
  }

  Future<void> _save() async {
    if (_weekdays.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Pick at least one day')));
      return;
    }
    final navigator = Navigator.of(context);
    final hh = _time.hour.toString().padLeft(2, '0');
    final mm = _time.minute.toString().padLeft(2, '0');
    await context.read<DialysisScheduleProvider>().save(DialysisSchedule(
          weekdays: _weekdays,
          timeOfDay: '$hh:$mm',
          durationHours: _duration,
          clinicName: _clinic.text.trim(),
          clinicAddress: _address.text.trim(),
        ));
    navigator.pop();
  }

  Future<void> _clear() async {
    final navigator = Navigator.of(context);
    await context.read<DialysisScheduleProvider>().clear();
    navigator.pop();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final hadSchedule = context.read<DialysisScheduleProvider>().schedule.isSet;

    return Scaffold(
      appBar: AppBar(title: const Text('Dialysis schedule')),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        Text('DAYS', style: text.titleSmall),
        const SizedBox(height: 8),
        Wrap(spacing: 8, runSpacing: 8, children: [
          for (var d = 1; d <= 7; d++)
            FilterChip(
              label: Text(kWeekdayAbbr[d - 1]),
              selected: _weekdays.contains(d),
              onSelected: (on) => setState(
                  () => on ? _weekdays.add(d) : _weekdays.remove(d)),
            ),
        ]),
        const SizedBox(height: 20),
        Text('TIME', style: text.titleSmall),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          icon: const Icon(Icons.access_time_rounded),
          label: Text(formatTime12(DateTime(2026, 1, 1, _time.hour, _time.minute))),
          onPressed: _pickTime,
        ),
        const SizedBox(height: 20),
        Text('DURATION', style: text.titleSmall),
        const SizedBox(height: 8),
        DropdownButtonFormField<int>(
          initialValue: _duration,
          decoration: const InputDecoration(border: OutlineInputBorder()),
          items: [
            for (var h = 1; h <= 8; h++)
              DropdownMenuItem(value: h, child: Text('$h hour${h == 1 ? '' : 's'}')),
          ],
          onChanged: (v) => setState(() => _duration = v ?? _duration),
        ),
        const SizedBox(height: 20),
        TextField(
          controller: _clinic,
          decoration: const InputDecoration(
              labelText: 'Clinic name', border: OutlineInputBorder()),
        ),
        const SizedBox(height: 14),
        TextField(
          controller: _address,
          decoration: const InputDecoration(
              labelText: 'Clinic address (optional)',
              border: OutlineInputBorder()),
        ),
        const SizedBox(height: 24),
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: AppColors.dialysis),
          onPressed: _save,
          child: const Text('Save schedule'),
        ),
        if (hadSchedule) ...[
          const SizedBox(height: 8),
          TextButton(
            onPressed: _clear,
            child: Text('Remove schedule',
                style: TextStyle(color: cs.error)),
          ),
        ],
      ]),
    );
  }
}
```

- [ ] **Step 2: Analyze**

Run: `flutter analyze`
Expected: "No issues found!" (If the installed Flutter rejects `initialValue:` on `DropdownButtonFormField`, use `value:` instead — one-word swap.)

- [ ] **Step 3: Commit**

```bash
git add lib/screens/dialysis_schedule_edit_screen.dart
git commit -m "feat: dialysis schedule edit screen"
```

---

### Task 5: Next-session card widget + schedule view screen

The reusable purple "Next session" card and the screen that shows it plus the upcoming list.

**Files:**
- Create: `lib/widgets/next_dialysis_card.dart`
- Create: `lib/screens/dialysis_schedule_screen.dart`
- Test: none new (presentational; the underlying computation is unit-tested in Task 1). Manual verification in Task 6.

**Interfaces:**
- Consumes: `DialysisSession`, `nextSession`, `upcomingSessions`, `weekdayAbbr`, `monthAbbr`, `formatTime12` (Task 1); `DialysisScheduleProvider` (Task 3); `DialysisScheduleEditScreen` (Task 4); `AppColors` (theme).
- Produces:
  - `class NextDialysisCard extends StatelessWidget` — `const NextDialysisCard({super.key, required this.session, this.onTap})` where `session` is a `DialysisSession` and `onTap` is `VoidCallback?`.
  - `class DialysisScheduleScreen extends StatefulWidget` — `const DialysisScheduleScreen({super.key})`.

- [ ] **Step 1: Implement the next-session card**

```dart
// lib/widgets/next_dialysis_card.dart
import 'package:flutter/material.dart';
import 'package:ckd_care/models/dialysis_schedule.dart';
import 'package:ckd_care/theme/app_theme.dart';

/// The purple "Next session" hero card: big date block + time/duration/clinic.
class NextDialysisCard extends StatelessWidget {
  const NextDialysisCard({super.key, required this.session, this.onTap});
  final DialysisSession session;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    const purple = AppColors.dialysis;
    final s = session;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: purple.withValues(alpha: 0.10),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: purple.withValues(alpha: 0.35)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('NEXT SESSION',
                  style: text.titleSmall?.copyWith(color: purple)),
              const SizedBox(height: 12),
              Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
                // Date block
                Container(
                  width: 66,
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  decoration: BoxDecoration(
                    color: purple,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Column(children: [
                    Text(monthAbbr(s.start).toUpperCase(),
                        style: text.labelMedium?.copyWith(
                            color: Colors.white, fontWeight: FontWeight.w800)),
                    Text('${s.start.day}',
                        style: text.headlineMedium?.copyWith(color: Colors.white)),
                    Text(weekdayAbbr(s.start).toUpperCase(),
                        style: text.labelMedium?.copyWith(
                            color: Colors.white70, fontWeight: FontWeight.w700)),
                  ]),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(formatTime12(s.start), style: text.titleLarge),
                      const SizedBox(height: 2),
                      Text('Duration: ${s.durationHours} hour'
                          '${s.durationHours == 1 ? '' : 's'}',
                          style: text.bodyMedium),
                      if (s.clinicName.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(s.clinicName, style: text.bodyMedium),
                      ],
                    ],
                  ),
                ),
              ]),
            ],
          ),
        ),
      ),
    );
  }
}
```

- [ ] **Step 2: Implement the schedule view screen**

```dart
// lib/screens/dialysis_schedule_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:ckd_care/models/dialysis_schedule.dart';
import 'package:ckd_care/providers/dialysis_schedule_provider.dart';
import 'package:ckd_care/screens/dialysis_schedule_edit_screen.dart';
import 'package:ckd_care/theme/app_theme.dart';
import 'package:ckd_care/widgets/next_dialysis_card.dart';

class DialysisScheduleScreen extends StatefulWidget {
  const DialysisScheduleScreen({super.key});
  @override
  State<DialysisScheduleScreen> createState() => _DialysisScheduleScreenState();
}

class _DialysisScheduleScreenState extends State<DialysisScheduleScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback(
        (_) => context.read<DialysisScheduleProvider>().load());
  }

  void _openEdit() => Navigator.push(context,
      MaterialPageRoute(builder: (_) => const DialysisScheduleEditScreen()));

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final schedule = context.watch<DialysisScheduleProvider>().schedule;
    final now = DateTime.now();
    final sessions =
        schedule.isSet ? upcomingSessions(schedule, now: now, count: 6) : const <DialysisSession>[];

    return Scaffold(
      appBar: AppBar(
        title: const Text('Dialysis schedule'),
        actions: [
          if (schedule.isSet)
            IconButton(
                icon: const Icon(Icons.edit_outlined), onPressed: _openEdit),
        ],
      ),
      body: !schedule.isSet
          ? _Empty(onSetup: _openEdit)
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
              children: [
                if (sessions.isNotEmpty)
                  NextDialysisCard(session: sessions.first, onTap: _openEdit),
                const SizedBox(height: 20),
                Text('UPCOMING SCHEDULE', style: text.titleSmall),
                const SizedBox(height: 8),
                for (var i = 1; i < sessions.length; i++)
                  _UpcomingRow(session: sessions[i]),
                if (sessions.length <= 1)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text('No further sessions in the next weeks.',
                        style: text.bodyMedium),
                  ),
              ],
            ),
    );
  }
}

class _UpcomingRow extends StatelessWidget {
  const _UpcomingRow({required this.session});
  final DialysisSession session;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final s = session;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: cs.outlineVariant),
      ),
      child: Row(children: [
        Icon(Icons.event_rounded, color: AppColors.dialysis, size: 22),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                  '${weekdayAbbr(s.start)}, ${monthAbbr(s.start)} ${s.start.day}',
                  style: text.titleMedium),
              Text(formatTime12(s.start), style: text.labelMedium),
            ],
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: AppColors.dialysis.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(999),
          ),
          child: Text('Scheduled',
              style: text.labelMedium?.copyWith(
                  color: AppColors.dialysis, fontWeight: FontWeight.w800)),
        ),
      ]),
    );
  }
}

class _Empty extends StatelessWidget {
  const _Empty({required this.onSetup});
  final VoidCallback onSetup;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Text('🗓️', style: TextStyle(fontSize: 44)),
          const SizedBox(height: 12),
          Text('No schedule yet', style: text.titleLarge),
          const SizedBox(height: 4),
          Text('Add your dialysis days and time to see your next session here.',
              style: text.bodyMedium, textAlign: TextAlign.center),
          const SizedBox(height: 20),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.dialysis),
            onPressed: onSetup,
            child: const Text('Set up schedule'),
          ),
        ]),
      ),
    );
  }
}
```

- [ ] **Step 3: Analyze**

Run: `flutter analyze`
Expected: "No issues found!"

- [ ] **Step 4: Commit**

```bash
git add lib/widgets/next_dialysis_card.dart lib/screens/dialysis_schedule_screen.dart
git commit -m "feat: dialysis schedule screen (next session + upcoming list)"
```

---

### Task 6: Wire into Settings + dashboard, then verify

Reach the feature from Settings and surface the next session on the dashboard.

**Files:**
- Modify: `lib/screens/settings_screen.dart`
- Modify: `lib/screens/dashboard_screen.dart`
- Test: manual verification (below).

**Interfaces:**
- Consumes: `DialysisScheduleScreen` (Task 5), `DialysisScheduleProvider` (Task 3), `nextSession` (Task 1), `NextDialysisCard` (Task 5).

- [ ] **Step 1: Add the Settings entry**

In `lib/screens/settings_screen.dart`, add the import:

```dart
import 'package:ckd_care/screens/dialysis_schedule_screen.dart';
```

Insert this `ListTile` + `Divider` immediately after the existing "Dialysis centers" `ListTile`'s following `const Divider()` (so order is: … Dialysis centers, Divider, **Dialysis schedule, Divider**, Daily fluid limit …):

```dart
      ListTile(
        leading: const Icon(Icons.event_available_outlined),
        title: const Text('Dialysis schedule'),
        subtitle: const Text('Your sessions and next appointment'),
        trailing: const Icon(Icons.chevron_right),
        onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
                builder: (_) => const DialysisScheduleScreen())),
      ),
      const Divider(),
```

- [ ] **Step 2: Surface the next session on the dashboard**

In `lib/screens/dashboard_screen.dart`, add imports:

```dart
import 'package:ckd_care/models/dialysis_schedule.dart';
import 'package:ckd_care/providers/dialysis_schedule_provider.dart';
import 'package:ckd_care/screens/dialysis_schedule_screen.dart';
import 'package:ckd_care/widgets/next_dialysis_card.dart';
```

In `_DashboardScreenState.initState`, also load the schedule (the file already has an `initState` that posts a `DashboardProvider.refresh()`); add a second line inside the same `addPostFrameCallback` body, or a second callback:

```dart
    WidgetsBinding.instance.addPostFrameCallback(
        (_) => context.read<DialysisScheduleProvider>().load());
```

In `build`, after the existing `final d = context.watch<DashboardProvider>();`, add:

```dart
    final schedule = context.watch<DialysisScheduleProvider>().schedule;
    final nextDialysis =
        schedule.isSet ? nextSession(schedule, now: DateTime.now()) : null;
```

Then in the `ListView`'s `children:`, insert the card right after `_hero()` and before `_dateBar(d)`:

```dart
        if (nextDialysis != null) ...[
          NextDialysisCard(
            session: nextDialysis,
            onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (_) => const DialysisScheduleScreen())),
          ),
          const SizedBox(height: 16),
        ],
```

- [ ] **Step 3: Analyze + full suite**

Run: `flutter analyze` → "No issues found!"
Run: `flutter test` → all pass (existing suite + Tasks 1–3 tests).

- [ ] **Step 4: Manual verification (device/emulator)**

Run `flutter run` (Android emulator), then:
1. Settings → **Dialysis schedule** opens; with nothing set it shows the empty state with a "Set up schedule" button.
2. Set up: pick **Mon/Wed/Fri**, time **9:00 AM**, duration **4 hours**, clinic **"Healthy Kidney Center"**, Save.
3. The schedule screen now shows a purple **Next session** card with the correct next MWF date/time and "Duration: 4 hours" + clinic, and an **Upcoming schedule** list of the following sessions, each with a "Scheduled" badge.
4. The **dashboard** shows the same next-session card under the greeting/hero; tapping it opens the schedule screen.
5. Edit (pencil) → change a value → Save reflects immediately; **Remove schedule** returns to the empty state and the dashboard card disappears.
6. Both light and dark themes render correctly.

- [ ] **Step 5: Commit**

```bash
git add lib/screens/settings_screen.dart lib/screens/dashboard_screen.dart
git commit -m "feat: reach dialysis schedule from Settings + dashboard next-session card"
```

---

## Self-Review

**Spec coverage (feature = personal dialysis schedule, next-session card + upcoming list like the reference):**
- Record a recurring schedule (days/time/duration/clinic) → `DialysisSchedule` (Task 1) + edit screen (Task 4) + persistence (Task 2). ✓
- "Next session" card (date block, time, duration, clinic) → `NextDialysisCard` (Task 5), matching the reference layout. ✓
- "Upcoming schedule" list with status badges → `_UpcomingRow` list (Task 5). ✓
- Surfaced prominently (reference shows it on the dashboard) → dashboard card (Task 6). ✓
- Computation correct across week boundaries / today-past-vs-future → pure functions unit-tested (Task 1). ✓
- Offline, no new table/dependency → settings-table storage (Task 2). ✓

**Placeholder scan:** No TBD/TODO; every code step is complete.

**Type consistency:** `DialysisSchedule` fields + `isSet` (Task 1) are used identically by the repository (Task 2), provider (Task 3), edit screen (Task 4), view screen and dashboard (Tasks 5–6). `upcomingSessions(schedule, {now, count})` / `nextSession(schedule, {now})` signatures match between Task 1's definition and Tasks 5–6's use. `NextDialysisCard({session, onTap})` matches between Task 5's definition and Task 6's use. `DialysisScheduleProvider.load/save/clear/schedule` match between Task 3 and its consumers. Weekday convention (1..7) and `'HH:mm'` storage are stated once in Global Constraints and used consistently.

**Deferred (not gaps, YAGNI):**
- One-off overrides (moving/cancelling a single session), attendance/history logging, and pre-session reminder notifications — explicitly out of scope for v1; the recurring pattern covers the common case and the reference view.
- Per-day different times (e.g. Mon 07:00 but Fri 13:00) — v1 uses one time for all chosen days; add later if needed.
- A dedicated bottom-nav tab — kept in Settings (with a dashboard card for prominence) to avoid overcrowding the 5-tab nav, consistent with Dialysis centers and Health profile.
