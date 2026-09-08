# Dashboard & Fluid Enhancements Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make the dashboard date-navigable with Morning/Afternoon/Evening dose sections, a fluid summary (intake/output/net) with quick-add, mistouch-correctable dose toggles, and confirmation toasts; make fluid intake/output editable with required-amount validation and toasts.

**Architecture:** Unchanged layering (`Widget → Provider → Repository → SQLite`). The dashboard provider gains a `selectedDate` so `refresh()` reads any day's records. Fluid entries gain an `update` path. A shared validating dialog centralizes the "amount required" rule. All "notifications" are in-app SnackBars (per decision), not system push.

**Tech Stack:** Flutter, `provider`, `sqflite`, existing widgets. No new dependencies (compact date bar uses the native `showDatePicker`; sections and toggle use built-in Material widgets).

## Global Constraints

- **Decisions (locked):** date navigation is a compact date bar (‹ prev · [date ▾] · next ›) using the native date picker — no calendar package. "Notifications" everywhere here = in-app SnackBar toasts, no permissions.
- Time-of-day buckets: **Morning** hour 0–11, **Afternoon** 12–16, **Evening** 17–23 (by the dose's scheduled hour).
- Fluid amount is a required whole number > 0 (validated in the shared dialog).
- All DB access via repositories; every write bumps `updated_at`; reads filter `deleted = 0`.
- `flutter analyze` clean and `flutter test` green is the gate for every task.
- Toasts use the screen's `ScaffoldMessenger`, captured before any `await` when used across an async gap.

---

## File Structure

```
lib/
  repositories/fluid_repository.dart   # MODIFY: add update(FluidEntry)
  providers/fluid_provider.dart        # MODIFY: add update(FluidEntry)
  providers/dashboard_provider.dart    # MODIFY: selectedDate + date nav; dueToday -> dueDoses; date-aware refresh
  widgets/fluid_amount_dialog.dart     # CREATE: shared validating amount dialog
  widgets/dose_tile.dart               # MODIFY: 3-state SegmentedButton (Pending/Taken/Skip)
  screens/fluid_screen.dart            # MODIFY: edit on tap, required dialog, add/edit toasts
  screens/dashboard_screen.dart        # MODIFY: date bar, sections, fluid card + quick-add, mark toast
test/
  repositories/fluid_repository_test.dart   # MODIFY: update round-trip test
  providers/dashboard_provider_test.dart    # MODIFY: dueToday->dueDoses; date-nav test
  widget_test.dart                          # MODIFY: dueToday->dueDoses reference if any
```

---

### Task 1: Fluid entry editing (repository + provider)

Adds the backend for editing a fluid entry's amount.

**Files:**
- Modify: `lib/repositories/fluid_repository.dart`, `lib/providers/fluid_provider.dart`
- Test: `test/repositories/fluid_repository_test.dart`

**Interfaces:**
- Consumes: `AppDatabase`, `FluidEntry`.
- Produces:
  - `FluidRepository.update(FluidEntry entry)` → updates the row at `entry.id` with `entry.toMap()` (amount, note, `updated_at`).
  - `FluidProvider.update(FluidEntry entry)` → calls the repo then reloads the current day.

- [ ] **Step 1: Write the failing test**

Add to `test/repositories/fluid_repository_test.dart` inside `main()`:

```dart
  test('update changes an entry amount and keeps it on its day', () async {
    final at = DateTime(2026, 9, 2, 9);
    final id = await repo.add(entry(FluidType.intake, 250, at));
    final original = (await repo.entriesForDay(FluidEntry.dayOf(at))).single;

    final edited = FluidEntry(
      id: original.id,
      uuid: original.uuid,
      type: original.type,
      amountMl: 400,
      loggedAt: original.loggedAt,
      day: original.day,
      note: original.note,
      updatedAt: DateTime(2026, 9, 2, 10),
    );
    await repo.update(edited);

    final after = (await repo.entriesForDay(FluidEntry.dayOf(at))).single;
    expect(after.id, id);
    expect(after.amountMl, 400);
  });
```

- [ ] **Step 2: Run to verify it fails**

Run: `flutter test test/repositories/fluid_repository_test.dart`
Expected: FAIL — `update` not defined on `FluidRepository`.

- [ ] **Step 3: Implement `FluidRepository.update`**

In `lib/repositories/fluid_repository.dart`, add after `add`:

```dart
  Future<void> update(FluidEntry entry) async {
    final db = await _db.database;
    await db.update('fluid_entry', entry.toMap(),
        where: 'id = ?', whereArgs: [entry.id]);
  }
```

- [ ] **Step 4: Run to verify it passes**

Run: `flutter test test/repositories/fluid_repository_test.dart`
Expected: PASS.

- [ ] **Step 5: Add `FluidProvider.update`**

In `lib/providers/fluid_provider.dart`, add after `add`:

```dart
  Future<void> update(FluidEntry entry) async {
    await _repo.update(entry);
    await loadDay(day);
  }
```

- [ ] **Step 6: Analyze + full suite**

Run: `flutter analyze` → "No issues found!"
Run: `flutter test` → all pass.

- [ ] **Step 7: Commit**

```bash
git add lib/repositories/fluid_repository.dart lib/providers/fluid_provider.dart test/repositories/fluid_repository_test.dart
git commit -m "feat: add fluid entry update (repository + provider)"
```

---

### Task 2: Fluid screen — shared required dialog, edit, toasts

Adds a shared validating amount dialog (fixes "required"), lets entries be edited by tapping, and shows toasts on add/edit.

**Files:**
- Create: `lib/widgets/fluid_amount_dialog.dart`
- Modify: `lib/screens/fluid_screen.dart`
- Test: none new (UI; validation logic is trivial and covered by manual check).

**Interfaces:**
- Produces: `Future<int?> showFluidAmountDialog(BuildContext context, {required String title, int? initial})` — returns a validated `int > 0`, or null if cancelled.
- Consumes: `FluidProvider.add`, `FluidProvider.update`, `FluidEntry`.

- [ ] **Step 1: Create the shared dialog**

Create `lib/widgets/fluid_amount_dialog.dart`:

```dart
import 'package:flutter/material.dart';

/// Prompts for a fluid amount in mL. Required + must be a whole number > 0.
/// Returns the amount, or null if cancelled.
Future<int?> showFluidAmountDialog(BuildContext context,
    {required String title, int? initial}) {
  final controller = TextEditingController(text: initial?.toString() ?? '');
  final formKey = GlobalKey<FormState>();
  return showDialog<int>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(title),
      content: Form(
        key: formKey,
        child: TextFormField(
          controller: controller,
          keyboardType: TextInputType.number,
          autofocus: true,
          decoration: const InputDecoration(
              labelText: 'Amount (mL) *', hintText: 'Required'),
          validator: (v) {
            final n = int.tryParse((v ?? '').trim());
            if (n == null) return 'Enter a whole number';
            if (n <= 0) return 'Must be greater than 0';
            return null;
          },
        ),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
        TextButton(
          onPressed: () {
            if (formKey.currentState!.validate()) {
              Navigator.pop(ctx, int.parse(controller.text.trim()));
            }
          },
          child: const Text('Save'),
        ),
      ],
    ),
  );
}
```

- [ ] **Step 2: Rewrite the fluid screen to use it, add edit + toasts**

Replace `lib/screens/fluid_screen.dart` entirely:

```dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:ckd_care/models/fluid_entry.dart';
import 'package:ckd_care/providers/fluid_provider.dart';
import 'package:ckd_care/widgets/fluid_amount_dialog.dart';

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

  Future<void> _add(FluidType type) async {
    final messenger = ScaffoldMessenger.of(context);
    final provider = context.read<FluidProvider>();
    final ml = await showFluidAmountDialog(context, title: 'Add ${type.name} (mL)');
    if (ml == null || !mounted) return;
    await provider.add(type, ml);
    messenger.showSnackBar(SnackBar(
        content: Text('${type == FluidType.intake ? 'Intake' : 'Output'} added')));
  }

  Future<void> _edit(FluidEntry e) async {
    final messenger = ScaffoldMessenger.of(context);
    final provider = context.read<FluidProvider>();
    final ml = await showFluidAmountDialog(context,
        title: 'Edit ${e.type.name} (mL)', initial: e.amountMl);
    if (ml == null || !mounted) return;
    await provider.update(FluidEntry(
      id: e.id,
      uuid: e.uuid,
      type: e.type,
      amountMl: ml,
      loggedAt: e.loggedAt,
      day: e.day,
      note: e.note,
      updatedAt: DateTime.now(),
    ));
    messenger.showSnackBar(const SnackBar(content: Text('Entry updated')));
  }

  @override
  Widget build(BuildContext context) {
    final p = context.watch<FluidProvider>();
    return Scaffold(
      body: ListView(children: [
        for (final e in p.entries)
          Dismissible(
            key: ValueKey(e.id),
            direction: DismissDirection.endToStart,
            background: Container(
              color: Colors.red,
              alignment: Alignment.centerRight,
              padding: const EdgeInsets.only(right: 16),
              child: const Icon(Icons.delete, color: Colors.white),
            ),
            onDismissed: (_) => context.read<FluidProvider>().remove(e.id!),
            child: ListTile(
              leading: Icon(e.type == FluidType.intake
                  ? Icons.water_drop
                  : Icons.opacity_outlined),
              title: Text('${e.amountMl} mL'),
              subtitle: Text('${e.type.name} • '
                  '${e.loggedAt.hour.toString().padLeft(2, '0')}:'
                  '${e.loggedAt.minute.toString().padLeft(2, '0')}'),
              trailing: const Icon(Icons.edit),
              onTap: () => _edit(e),
            ),
          ),
        if (p.entries.isEmpty) const ListTile(title: Text('No entries today')),
      ]),
      floatingActionButton: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          FloatingActionButton.extended(
              heroTag: 'in',
              onPressed: () => _add(FluidType.intake),
              label: const Text('Intake')),
          const SizedBox(width: 12),
          FloatingActionButton.extended(
              heroTag: 'out',
              onPressed: () => _add(FluidType.output),
              label: const Text('Output')),
        ],
      ),
    );
  }
}
```

- [ ] **Step 3: Analyze + full suite**

Run: `flutter analyze` → "No issues found!"
Run: `flutter test` → all pass.

- [ ] **Step 4: Commit**

```bash
git add lib/widgets/fluid_amount_dialog.dart lib/screens/fluid_screen.dart
git commit -m "feat: fluid entry edit + required-amount validation + toasts"
```

---

### Task 3: Dashboard provider — date navigation

Makes the dashboard read any selected day, and renames `dueToday` → `dueDoses` (it's no longer only today).

**Files:**
- Modify: `lib/providers/dashboard_provider.dart`
- Test: `test/providers/dashboard_provider_test.dart`, and `test/widget_test.dart` if it references `dueToday`.

**Interfaces:**
- Produces on `DashboardProvider`:
  - `DateTime selectedDate` (defaults to `_now()` date), `bool get isToday`.
  - `List<DueDose> dueDoses` (was `dueToday`).
  - `Future<void> selectDate(DateTime d)`, `Future<void> previousDay()`, `Future<void> nextDay()` — each sets `selectedDate` (date-only) and calls `refresh()`.
  - `refresh()` builds the day string and dose `scheduledTime`s from `selectedDate` (not `_now()`).

- [ ] **Step 1: Update the test (rename + date nav)**

In `test/providers/dashboard_provider_test.dart`:
- Replace every `dueToday` with `dueDoses`.
- Add a date-navigation test inside `main()`:

```dart
  test('previousDay/nextDay shift selectedDate and refresh', () async {
    final p = DashboardProvider(
      fluid: _FakeFluid(),
      settings: _FakeSettings(),
      medicine: _FakeMedicine(),
      notifications: _FakeNotifications(),
      now: () => DateTime(2026, 9, 2, 12),
    );
    await p.refresh();
    expect(p.isToday, isTrue);
    expect(p.dueDoses.single.scheduledTime, DateTime(2026, 9, 2, 8));

    await p.previousDay();
    expect(p.isToday, isFalse);
    expect(p.selectedDate, DateTime(2026, 9, 1));
    expect(p.dueDoses.single.scheduledTime, DateTime(2026, 9, 1, 8));
  });
```

- [ ] **Step 2: Run to verify it fails**

Run: `flutter test test/providers/dashboard_provider_test.dart`
Expected: FAIL — `dueDoses`, `previousDay`, `isToday` not defined.

- [ ] **Step 3: Implement date navigation**

In `lib/providers/dashboard_provider.dart`:

Replace the state fields block:

```dart
  DailyFluidTotals? fluidTotals;
  int? fluidLimitMl;
  List<DueDose> dueToday = const [];
```

with:

```dart
  DailyFluidTotals? fluidTotals;
  int? fluidLimitMl;
  List<DueDose> dueDoses = const [];

  DateTime? _selectedDate;
  DateTime get selectedDate {
    final base = _selectedDate ?? _now();
    return DateTime(base.year, base.month, base.day);
  }

  bool get isToday {
    final t = _now();
    return selectedDate == DateTime(t.year, t.month, t.day);
  }

  Future<void> selectDate(DateTime d) async {
    _selectedDate = DateTime(d.year, d.month, d.day);
    await refresh();
  }

  Future<void> previousDay() =>
      selectDate(selectedDate.subtract(const Duration(days: 1)));
  Future<void> nextDay() =>
      selectDate(selectedDate.add(const Duration(days: 1)));
```

In `refresh()`, replace the first two lines:

```dart
    final today = _now();
    final day = FluidEntry.dayOf(today);
```

with:

```dart
    final today = selectedDate;
    final day = FluidEntry.dayOf(today);
```

and replace the final assignment `dueToday = due;` with `dueDoses = due;`.

- [ ] **Step 4: Run to verify it passes**

Run: `flutter test test/providers/dashboard_provider_test.dart`
Expected: PASS.

- [ ] **Step 5: Fix any remaining `dueToday` references**

Run: `flutter analyze`
If it reports `dueToday` used in `test/widget_test.dart` or `lib/screens/dashboard_screen.dart`, those are updated in later steps/tasks — but the analyzer must be clean now for the provider + its own test. The screen still references `dueToday`; update it minimally here to `dueDoses` so analyze passes (Task 4 rewrites the screen fully):

In `lib/screens/dashboard_screen.dart`, replace the two `d.dueToday` occurrences with `d.dueDoses`.

Re-run: `flutter analyze` → "No issues found!" and `flutter test` → all pass.

- [ ] **Step 6: Commit**

```bash
git add lib/providers/dashboard_provider.dart lib/screens/dashboard_screen.dart test/providers/dashboard_provider_test.dart
git commit -m "feat: date-navigable dashboard provider (selectedDate, prev/next)"
```

---

### Task 4: Dashboard screen + DoseTile — date bar, sections, fluid card, toggle, toasts

The full dashboard UI: date bar, Morning/Afternoon/Evening sections, fluid summary with output + quick-add, mark toasts, and a mistouch-correctable dose toggle.

**Files:**
- Modify: `lib/widgets/dose_tile.dart`, `lib/screens/dashboard_screen.dart`
- Test: none new (UI). Behavior (marking, date filter) covered by Task 3 + repo tests.

**Interfaces:**
- Consumes: `DashboardProvider` (`selectedDate`, `isToday`, `dueDoses`, `previousDay/nextDay/selectDate/refresh/markDose`), `FluidProvider.add`, `showFluidAmountDialog`, `DoseStatus`.
- `DoseTile` now renders a `SegmentedButton<DoseStatus>` (Taken/Skip, empty = Pending) whose `onSelectionChanged` calls `onMark`.

- [ ] **Step 1: Rewrite DoseTile as a 3-state toggle**

Replace `lib/widgets/dose_tile.dart` entirely:

```dart
import 'package:flutter/material.dart';
import 'package:ckd_care/models/dose_log.dart';
import 'package:ckd_care/providers/dashboard_provider.dart';

/// A dose row with a Taken/Skip toggle. Empty selection = Pending. Tapping a
/// segment (re)marks the dose, so a mistouched Taken can be switched to Skip.
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
      trailing: SegmentedButton<DoseStatus>(
        segments: const [
          ButtonSegment(
              value: DoseStatus.taken,
              icon: Icon(Icons.check),
              tooltip: 'Taken'),
          ButtonSegment(
              value: DoseStatus.skipped,
              icon: Icon(Icons.close),
              tooltip: 'Skip'),
        ],
        selected: dose.status == null ? <DoseStatus>{} : {dose.status!},
        emptySelectionAllowed: true,
        showSelectedIcon: false,
        style: const ButtonStyle(visualDensity: VisualDensity.compact),
        onSelectionChanged: (sel) {
          if (sel.isNotEmpty) onMark(sel.first);
        },
      ),
    );
  }
}
```

- [ ] **Step 2: Rewrite the dashboard screen**

Replace `lib/screens/dashboard_screen.dart` entirely:

```dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:ckd_care/models/dose_log.dart';
import 'package:ckd_care/models/fluid_entry.dart';
import 'package:ckd_care/providers/dashboard_provider.dart';
import 'package:ckd_care/providers/fluid_provider.dart';
import 'package:ckd_care/widgets/dose_tile.dart';
import 'package:ckd_care/widgets/fluid_amount_dialog.dart';
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
      (_) => context.read<DashboardProvider>().refresh(),
    );
  }

  Future<void> _pickDate() async {
    final d = context.read<DashboardProvider>();
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: d.selectedDate,
      firstDate: DateTime(now.year - 2),
      lastDate: DateTime(now.year + 2),
    );
    if (picked != null) await d.selectDate(picked);
  }

  Future<void> _quickAddFluid(FluidType type) async {
    final messenger = ScaffoldMessenger.of(context);
    final fluid = context.read<FluidProvider>();
    final dash = context.read<DashboardProvider>();
    final ml = await showFluidAmountDialog(context, title: 'Add ${type.name} (mL)');
    if (ml == null || !mounted) return;
    await fluid.add(type, ml);
    await dash.refresh();
    messenger.showSnackBar(SnackBar(
        content: Text('${type == FluidType.intake ? 'Intake' : 'Output'} added')));
  }

  Future<void> _mark(DueDose dose, DoseStatus status) async {
    final messenger = ScaffoldMessenger.of(context);
    await context.read<DashboardProvider>().markDose(dose, status);
    messenger.showSnackBar(SnackBar(
        content: Text(
            status == DoseStatus.taken ? 'Marked as taken' : 'Marked as skipped')));
  }

  String _dateLabel(DashboardProvider d) {
    if (d.isToday) return 'Today';
    return FluidEntry.dayOf(d.selectedDate);
  }

  List<DueDose> _bucket(List<DueDose> all, int startH, int endH) =>
      all.where((x) => x.scheduledTime.hour >= startH && x.scheduledTime.hour < endH)
          .toList();

  Widget _section(String title, List<DueDose> doses) {
    if (doses.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 8, left: 4, bottom: 2),
          child: Text(title, style: Theme.of(context).textTheme.titleSmall),
        ),
        ...doses.map((dose) => DoseTile(dose: dose, onMark: (s) => _mark(dose, s))),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final d = context.watch<DashboardProvider>();
    final totals = d.fluidTotals;
    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        // Date navigation bar.
        Row(children: [
          IconButton(
              icon: const Icon(Icons.chevron_left),
              onPressed: () => context.read<DashboardProvider>().previousDay()),
          Expanded(
            child: TextButton.icon(
              onPressed: _pickDate,
              icon: const Icon(Icons.calendar_today, size: 18),
              label: Text(_dateLabel(d)),
            ),
          ),
          IconButton(
              icon: const Icon(Icons.chevron_right),
              onPressed: () => context.read<DashboardProvider>().nextDay()),
        ]),
        FluidGauge(intakeMl: totals?.intakeMl ?? 0, limitMl: d.fluidLimitMl),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Intake: ${totals?.intakeMl ?? 0} mL   •   '
                  'Output: ${totals?.outputMl ?? 0} mL   •   '
                  'Net: ${totals?.netMl ?? 0} mL'),
              if (d.isToday)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Row(children: [
                    OutlinedButton.icon(
                      icon: const Icon(Icons.water_drop),
                      label: const Text('Intake'),
                      onPressed: () => _quickAddFluid(FluidType.intake),
                    ),
                    const SizedBox(width: 8),
                    OutlinedButton.icon(
                      icon: const Icon(Icons.opacity_outlined),
                      label: const Text('Output'),
                      onPressed: () => _quickAddFluid(FluidType.output),
                    ),
                  ]),
                ),
            ]),
          ),
        ),
        const Divider(),
        Text('Medicines', style: Theme.of(context).textTheme.titleMedium),
        _section('Morning', _bucket(d.dueDoses, 0, 12)),
        _section('Afternoon', _bucket(d.dueDoses, 12, 17)),
        _section('Evening', _bucket(d.dueDoses, 17, 24)),
        if (d.dueDoses.isEmpty)
          const ListTile(title: Text('No medicines scheduled')),
      ],
    );
  }
}
```

- [ ] **Step 3: Analyze + full suite**

Run: `flutter analyze` → "No issues found!" (fix any lint it reports).
Run: `flutter test` → all pass.

- [ ] **Step 4: Commit**

```bash
git add lib/widgets/dose_tile.dart lib/screens/dashboard_screen.dart
git commit -m "feat: dashboard date bar, AM/PM/eve sections, fluid card + quick-add, dose toggle, toasts"
```

---

## Manual verification checklist (device/emulator)

Run after Task 4 via `flutter run -d Pixel_4a_API_34`:

1. Dashboard shows a date bar reading **Today**; ‹ / › move the day; tapping the date opens the calendar picker.
2. Medicines are grouped **Morning / Afternoon / Evening** by scheduled time; empty sections are hidden.
3. Mark a dose **Taken** → toast "Marked as taken", segment shows Taken selected.
4. Tap **Skip** on that same dose → it switches to Skipped (mistouch correction), stock restored; toast "Marked as skipped".
5. Fluid card shows **Intake / Output / Net**; on **Today**, quick-add **Intake**/**Output** works with a toast, and the numbers update.
6. Navigate to a past day → its recorded doses/fluid show; quick-add buttons are hidden (not today).
7. Fluid tab: tapping an entry opens an **edit** dialog (prefilled); saving shows "Entry updated"; adding with an empty/0 amount is **blocked with a validation error**; add shows a toast.

---

## Self-Review

**Spec coverage (Dashboard):**
- Today's medicines split Morning/Afternoon/Evening → Task 4 `_bucket`/`_section`. ✓
- Calendar to navigate dates & see records per date → Task 3 (`selectedDate`, date-aware `refresh`) + Task 4 date bar. ✓
- Output fluid on dashboard → Task 4 fluid card (Intake/Output/Net) + quick-add output. ✓
- Notification (toast) on taken/skip → Task 4 `_mark`. ✓
- Mistouch correction toggle → Task 4 DoseTile `SegmentedButton` (repo `logDose` already reverses stock). ✓

**Spec coverage (Fluid):**
- Fluid & output editable → Task 1 (`update`) + Task 2 (edit dialog on tap). ✓
- Fix notifications (toast) + required → Task 2 (`showFluidAmountDialog` validation + add/edit toasts). ✓

**Placeholder scan:** No TBD/TODO; all code blocks complete.

**Type consistency:** `dueToday`→`dueDoses` renamed in the provider and every reader (test, screen) in Task 3; `showFluidAmountDialog(context, {title, initial})→Future<int?>`, `FluidRepository.update(FluidEntry)`, `FluidProvider.update(FluidEntry)`, `DashboardProvider.selectedDate/isToday/previousDay/nextDay/selectDate` used consistently across producing and consuming tasks.

**Deferred (not gaps):** historical accuracy for depleted/deleted medicines on past dates (the dashboard uses the current `dashboardMedicines` filter, so a now-empty medicine won't show its past doses); editing a fluid entry's type or timestamp (only amount is editable); per-section empty-state text (empty sections are simply hidden).
