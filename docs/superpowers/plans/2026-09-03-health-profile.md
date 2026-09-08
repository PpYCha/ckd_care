# Health Profile Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Let the user optionally record a health profile — CKD stage, dialysis status, diabetes, elevated potassium/phosphorus, and a fluid restriction — persisted locally and editable from Settings, so later personalization (sub-plan E) and contextual guidance can read it.

**Architecture:** The profile is a small typed `HealthProfile` value object persisted as individual keys in the existing `setting` key/value table via `SettingsRepository` (no schema change). A `HealthProfileProvider` (ChangeNotifier) exposes `profile`/`load`/`save`. A Settings entry opens a `HealthProfileScreen` to view/edit it. Everything is optional — an unset profile means "general guidance".

**Tech Stack:** Flutter, `provider`, existing `sqflite` `setting` table + `SettingsRepository`.

## Global Constraints

- **All fields optional.** CKD stage may be unset (`null`); dialysis defaults to `none`; the flags default `false`. An unset stage means "not provided → general guidance". Never invent a stage.
- **No new schema.** Persist as `setting` keys prefixed `profile_`: `profile_ckd_stage`, `profile_dialysis`, `profile_diabetes`, `profile_elevated_potassium`, `profile_elevated_phosphorus`, `profile_fluid_restriction`.
- **Not a diagnosis.** The profile screen states it is used only to tailor general educational guidance and is not medical advice; the user's care team's instructions take priority.
- **CKD stages are exactly** `stage1..stage5`; **dialysis statuses are exactly** `none`, `hemodialysis`, `peritoneal`.
- Values stored as text: stage as `'1'..'5'` (empty string when unset), dialysis as its enum `.name`, booleans as `'true'`/`'false'`.
- `flutter analyze` clean and `flutter test` green is the gate for every task.

---

## File Structure

```
lib/
  models/health_profile.dart       # CREATE: CkdStage + DialysisStatus enums, HealthProfile value object
  repositories/settings_repository.dart  # MODIFY: getHealthProfile / saveHealthProfile
  providers/health_profile_provider.dart # CREATE: ChangeNotifier (profile/load/save)
  main.dart                        # MODIFY: provide HealthProfileProvider
  screens/health_profile_screen.dart     # CREATE: edit UI
  screens/settings_screen.dart     # MODIFY: "Health profile" entry
test/
  models/health_profile_test.dart         # CREATE: enum labels + copyWith + equality
  repositories/settings_repository_test.dart  # MODIFY: profile round-trip
  providers/health_profile_provider_test.dart # CREATE: load/save updates state
```

---

### Task 1: HealthProfile model + persistence

The typed model (enums + value object with equality/copyWith) and the repository read/write against the `setting` table.

**Files:**
- Create: `lib/models/health_profile.dart`
- Modify: `lib/repositories/settings_repository.dart`
- Test: `test/models/health_profile_test.dart`, `test/repositories/settings_repository_test.dart`

**Interfaces:**
- Consumes: `SettingsRepository` private `_get`/`_set`.
- Produces:
  - `enum CkdStage { stage1, stage2, stage3, stage4, stage5 }` with `String get label` (`'Stage 1'`…), `int get number` (1..5).
  - `CkdStage? ckdStageFromNumber(String? stored)` and `String ckdStageToStored(CkdStage?)`.
  - `enum DialysisStatus { none, hemodialysis, peritoneal }` with `String get label`.
  - `class HealthProfile` — `final CkdStage? ckdStage; final DialysisStatus dialysisStatus; final bool diabetes, elevatedPotassium, elevatedPhosphorus, fluidRestriction;` const constructor (dialysis defaults `none`, bools default `false`); `bool get isSet => ckdStage != null;`; `copyWith(...)`; value equality (`==`/`hashCode`).
  - `SettingsRepository.getHealthProfile() → Future<HealthProfile>`, `SettingsRepository.saveHealthProfile(HealthProfile) → Future<void>`.

- [ ] **Step 1: Write the failing model test**

Create `test/models/health_profile_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:ckd_care/models/health_profile.dart';

void main() {
  test('CkdStage label/number and stored conversion round-trip', () {
    expect(CkdStage.stage3.label, 'Stage 3');
    expect(CkdStage.stage3.number, 3);
    expect(ckdStageToStored(CkdStage.stage3), '3');
    expect(ckdStageToStored(null), '');
    expect(ckdStageFromNumber('3'), CkdStage.stage3);
    expect(ckdStageFromNumber(''), isNull);
    expect(ckdStageFromNumber(null), isNull);
    expect(ckdStageFromNumber('9'), isNull);
  });

  test('DialysisStatus labels', () {
    expect(DialysisStatus.none.label, 'Not on dialysis');
    expect(DialysisStatus.hemodialysis.label, 'Hemodialysis');
    expect(DialysisStatus.peritoneal.label, 'Peritoneal dialysis');
  });

  test('HealthProfile copyWith and equality', () {
    const base = HealthProfile();
    expect(base.isSet, isFalse);
    expect(base.dialysisStatus, DialysisStatus.none);

    final edited = base.copyWith(
        ckdStage: CkdStage.stage4, diabetes: true, elevatedPotassium: true);
    expect(edited.isSet, isTrue);
    expect(edited.ckdStage, CkdStage.stage4);
    expect(edited.diabetes, isTrue);
    expect(edited.elevatedPotassium, isTrue);
    expect(edited.elevatedPhosphorus, isFalse); // unchanged
    expect(edited == base, isFalse);
    expect(
      edited,
      const HealthProfile(
          ckdStage: CkdStage.stage4, diabetes: true, elevatedPotassium: true),
    );
  });
}
```

- [ ] **Step 2: Run to verify it fails**

Run: `flutter test test/models/health_profile_test.dart`
Expected: FAIL — `health_profile.dart` doesn't exist.

- [ ] **Step 3: Create the model**

Create `lib/models/health_profile.dart`:

```dart
import 'package:flutter/foundation.dart';

enum CkdStage { stage1, stage2, stage3, stage4, stage5 }

extension CkdStageInfo on CkdStage {
  int get number => index + 1;
  String get label => 'Stage $number';
}

/// Stored as '1'..'5'; empty string means "not set".
String ckdStageToStored(CkdStage? stage) =>
    stage == null ? '' : stage.number.toString();

CkdStage? ckdStageFromNumber(String? stored) {
  final n = int.tryParse((stored ?? '').trim());
  if (n == null || n < 1 || n > 5) return null;
  return CkdStage.values[n - 1];
}

enum DialysisStatus { none, hemodialysis, peritoneal }

extension DialysisStatusInfo on DialysisStatus {
  String get label => switch (this) {
        DialysisStatus.none => 'Not on dialysis',
        DialysisStatus.hemodialysis => 'Hemodialysis',
        DialysisStatus.peritoneal => 'Peritoneal dialysis',
      };
}

/// Optional user health context used only to tailor general guidance. An unset
/// [ckdStage] means the user hasn't provided one — show general guidance.
@immutable
class HealthProfile {
  const HealthProfile({
    this.ckdStage,
    this.dialysisStatus = DialysisStatus.none,
    this.diabetes = false,
    this.elevatedPotassium = false,
    this.elevatedPhosphorus = false,
    this.fluidRestriction = false,
  });

  final CkdStage? ckdStage;
  final DialysisStatus dialysisStatus;
  final bool diabetes;
  final bool elevatedPotassium;
  final bool elevatedPhosphorus;
  final bool fluidRestriction;

  bool get isSet => ckdStage != null;

  HealthProfile copyWith({
    CkdStage? ckdStage,
    DialysisStatus? dialysisStatus,
    bool? diabetes,
    bool? elevatedPotassium,
    bool? elevatedPhosphorus,
    bool? fluidRestriction,
  }) =>
      HealthProfile(
        ckdStage: ckdStage ?? this.ckdStage,
        dialysisStatus: dialysisStatus ?? this.dialysisStatus,
        diabetes: diabetes ?? this.diabetes,
        elevatedPotassium: elevatedPotassium ?? this.elevatedPotassium,
        elevatedPhosphorus: elevatedPhosphorus ?? this.elevatedPhosphorus,
        fluidRestriction: fluidRestriction ?? this.fluidRestriction,
      );

  @override
  bool operator ==(Object other) =>
      other is HealthProfile &&
      other.ckdStage == ckdStage &&
      other.dialysisStatus == dialysisStatus &&
      other.diabetes == diabetes &&
      other.elevatedPotassium == elevatedPotassium &&
      other.elevatedPhosphorus == elevatedPhosphorus &&
      other.fluidRestriction == fluidRestriction;

  @override
  int get hashCode => Object.hash(ckdStage, dialysisStatus, diabetes,
      elevatedPotassium, elevatedPhosphorus, fluidRestriction);
}
```

Note: `copyWith` cannot clear `ckdStage` back to null (a `null` argument means "unchanged"). The edit screen never needs to clear the stage to null — it always sets a concrete stage or leaves it — so this is acceptable; the "Not sure" option in the UI is handled by building a fresh `HealthProfile` rather than `copyWith(ckdStage: null)`.

- [ ] **Step 4: Run to verify the model test passes**

Run: `flutter test test/models/health_profile_test.dart`
Expected: PASS (3 tests).

- [ ] **Step 5: Write the failing persistence test**

Add to `test/repositories/settings_repository_test.dart`. Add the import at the top if not present:

```dart
import 'package:ckd_care/models/health_profile.dart';
```

Add inside `main()`:

```dart
  test('health profile round-trips; defaults when unset', () async {
    final empty = await repo.getHealthProfile();
    expect(empty, const HealthProfile()); // unset stage, none, all false

    const p = HealthProfile(
      ckdStage: CkdStage.stage4,
      dialysisStatus: DialysisStatus.hemodialysis,
      diabetes: true,
      elevatedPotassium: true,
    );
    await repo.saveHealthProfile(p);
    expect(await repo.getHealthProfile(), p);
  });
```

- [ ] **Step 6: Run to verify it fails**

Run: `flutter test test/repositories/settings_repository_test.dart`
Expected: FAIL — `getHealthProfile` not defined.

- [ ] **Step 7: Add the repository methods**

In `lib/repositories/settings_repository.dart`, add the import at the top:

```dart
import 'package:ckd_care/models/health_profile.dart';
```

Add key constants near the other `k*` setting-key consts:

```dart
const String kProfileCkdStage = 'profile_ckd_stage';
const String kProfileDialysis = 'profile_dialysis';
const String kProfileDiabetes = 'profile_diabetes';
const String kProfileElevatedPotassium = 'profile_elevated_potassium';
const String kProfileElevatedPhosphorus = 'profile_elevated_phosphorus';
const String kProfileFluidRestriction = 'profile_fluid_restriction';
```

Add these methods to `SettingsRepository`:

```dart
  Future<HealthProfile> getHealthProfile() async {
    Future<bool> flag(String key) async => (await _get(key)) == 'true';
    final dialysisName = await _get(kProfileDialysis);
    return HealthProfile(
      ckdStage: ckdStageFromNumber(await _get(kProfileCkdStage)),
      dialysisStatus: DialysisStatus.values.firstWhere(
        (d) => d.name == dialysisName,
        orElse: () => DialysisStatus.none,
      ),
      diabetes: await flag(kProfileDiabetes),
      elevatedPotassium: await flag(kProfileElevatedPotassium),
      elevatedPhosphorus: await flag(kProfileElevatedPhosphorus),
      fluidRestriction: await flag(kProfileFluidRestriction),
    );
  }

  Future<void> saveHealthProfile(HealthProfile p) async {
    await _set(kProfileCkdStage, ckdStageToStored(p.ckdStage));
    await _set(kProfileDialysis, p.dialysisStatus.name);
    await _set(kProfileDiabetes, p.diabetes.toString());
    await _set(kProfileElevatedPotassium, p.elevatedPotassium.toString());
    await _set(kProfileElevatedPhosphorus, p.elevatedPhosphorus.toString());
    await _set(kProfileFluidRestriction, p.fluidRestriction.toString());
  }
```

- [ ] **Step 8: Run to verify it passes**

Run: `flutter test test/repositories/settings_repository_test.dart`
Expected: PASS.

- [ ] **Step 9: Analyze + full suite**

Run: `flutter analyze` → "No issues found!"
Run: `flutter test` → all pass.

- [ ] **Step 10: Commit**

```bash
git add lib/models/health_profile.dart lib/repositories/settings_repository.dart test/models/health_profile_test.dart test/repositories/settings_repository_test.dart
git commit -m "feat: HealthProfile model and settings persistence"
```

---

### Task 2: HealthProfileProvider + app wiring

The provider and its registration in the app's provider tree.

**Files:**
- Create: `lib/providers/health_profile_provider.dart`
- Modify: `lib/main.dart`
- Test: `test/providers/health_profile_provider_test.dart`

**Interfaces:**
- Consumes: `SettingsRepository`, `HealthProfile`.
- Produces: `class HealthProfileProvider extends ChangeNotifier` — `HealthProfile profile` (defaults `const HealthProfile()`), `Future<void> load()`, `Future<void> save(HealthProfile)`.

- [ ] **Step 1: Write the failing provider test**

Create `test/providers/health_profile_provider_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:ckd_care/db/app_database.dart';
import 'package:ckd_care/models/health_profile.dart';
import 'package:ckd_care/providers/health_profile_provider.dart';
import 'package:ckd_care/repositories/settings_repository.dart';

void main() {
  sqfliteFfiInit();

  test('load then save updates the exposed profile', () async {
    final db = AppDatabase(databaseFactoryFfi, path: inMemoryDatabasePath);
    final provider = HealthProfileProvider(SettingsRepository(db));

    await provider.load();
    expect(provider.profile, const HealthProfile());

    const p = HealthProfile(
        ckdStage: CkdStage.stage3, dialysisStatus: DialysisStatus.peritoneal);
    await provider.save(p);
    expect(provider.profile, p);

    // A fresh provider on the same db reads it back.
    final fresh = HealthProfileProvider(SettingsRepository(db));
    await fresh.load();
    expect(fresh.profile, p);

    await db.close();
  });
}
```

- [ ] **Step 2: Run to verify it fails**

Run: `flutter test test/providers/health_profile_provider_test.dart`
Expected: FAIL — `health_profile_provider.dart` doesn't exist.

- [ ] **Step 3: Create the provider**

Create `lib/providers/health_profile_provider.dart`:

```dart
import 'package:flutter/foundation.dart';
import 'package:ckd_care/models/health_profile.dart';
import 'package:ckd_care/repositories/settings_repository.dart';

class HealthProfileProvider extends ChangeNotifier {
  HealthProfileProvider(this._repo);
  final SettingsRepository _repo;

  HealthProfile profile = const HealthProfile();

  Future<void> load() async {
    profile = await _repo.getHealthProfile();
    notifyListeners();
  }

  Future<void> save(HealthProfile p) async {
    await _repo.saveHealthProfile(p);
    profile = p;
    notifyListeners();
  }
}
```

- [ ] **Step 4: Run to verify it passes**

Run: `flutter test test/providers/health_profile_provider_test.dart`
Expected: PASS.

- [ ] **Step 5: Register the provider in main.dart**

In `lib/main.dart`, add the import near the other provider imports:

```dart
import 'package:ckd_care/providers/health_profile_provider.dart';
```

In `CkdApp.build`, add a provider to the `MultiProvider`'s `providers` list (alongside the others):

```dart
        ChangeNotifierProvider(create: (_) => HealthProfileProvider(settingsRepo)),
```

(`settingsRepo` is already a field of `CkdApp`.)

- [ ] **Step 6: Analyze + full suite**

Run: `flutter analyze` → "No issues found!"
Run: `flutter test` → all pass.

- [ ] **Step 7: Commit**

```bash
git add lib/providers/health_profile_provider.dart lib/main.dart test/providers/health_profile_provider_test.dart
git commit -m "feat: HealthProfileProvider wired into the app"
```

---

### Task 3: Health Profile screen + Settings entry

The edit screen (stage, dialysis, flags) and a Settings tile that opens it and shows a summary.

**Files:**
- Create: `lib/screens/health_profile_screen.dart`
- Modify: `lib/screens/settings_screen.dart`
- Test: none new (UI; model/persistence/provider are covered by Tasks 1–2). Manual verification below.

**Interfaces:**
- Consumes: `HealthProfileProvider`, `HealthProfile`, `CkdStage`, `DialysisStatus`.

- [ ] **Step 1: Create the health profile screen**

Create `lib/screens/health_profile_screen.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:ckd_care/models/health_profile.dart';
import 'package:ckd_care/providers/health_profile_provider.dart';

class HealthProfileScreen extends StatefulWidget {
  const HealthProfileScreen({super.key});
  @override
  State<HealthProfileScreen> createState() => _HealthProfileScreenState();
}

class _HealthProfileScreenState extends State<HealthProfileScreen> {
  late HealthProfile _draft;

  @override
  void initState() {
    super.initState();
    _draft = context.read<HealthProfileProvider>().profile;
  }

  Future<void> _save() async {
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    await context.read<HealthProfileProvider>().save(_draft);
    if (!mounted) return;
    navigator.pop();
    messenger.showSnackBar(const SnackBar(content: Text('Profile saved')));
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Health profile')),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        Text(
          'Optional. Used to tailor general food guidance — it is not medical '
          'advice, and your care team\'s instructions always take priority.',
          style: text.bodyMedium,
        ),
        const SizedBox(height: 20),
        Text('CKD stage', style: text.titleMedium),
        const SizedBox(height: 8),
        Wrap(spacing: 8, children: [
          ChoiceChip(
            label: const Text('Not sure'),
            selected: _draft.ckdStage == null,
            onSelected: (_) => setState(() => _draft = HealthProfile(
                  dialysisStatus: _draft.dialysisStatus,
                  diabetes: _draft.diabetes,
                  elevatedPotassium: _draft.elevatedPotassium,
                  elevatedPhosphorus: _draft.elevatedPhosphorus,
                  fluidRestriction: _draft.fluidRestriction,
                )),
          ),
          for (final st in CkdStage.values)
            ChoiceChip(
              label: Text(st.label),
              selected: _draft.ckdStage == st,
              onSelected: (_) =>
                  setState(() => _draft = _draft.copyWith(ckdStage: st)),
            ),
        ]),
        const SizedBox(height: 20),
        Text('Dialysis', style: text.titleMedium),
        const SizedBox(height: 8),
        Wrap(spacing: 8, children: [
          for (final d in DialysisStatus.values)
            ChoiceChip(
              label: Text(d.label),
              selected: _draft.dialysisStatus == d,
              onSelected: (_) =>
                  setState(() => _draft = _draft.copyWith(dialysisStatus: d)),
            ),
        ]),
        const SizedBox(height: 12),
        const Divider(),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Diabetes'),
          value: _draft.diabetes,
          onChanged: (v) => setState(() => _draft = _draft.copyWith(diabetes: v)),
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Elevated potassium (per recent labs)'),
          value: _draft.elevatedPotassium,
          onChanged: (v) =>
              setState(() => _draft = _draft.copyWith(elevatedPotassium: v)),
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Elevated phosphorus (per recent labs)'),
          value: _draft.elevatedPhosphorus,
          onChanged: (v) =>
              setState(() => _draft = _draft.copyWith(elevatedPhosphorus: v)),
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('On a fluid restriction'),
          value: _draft.fluidRestriction,
          onChanged: (v) =>
              setState(() => _draft = _draft.copyWith(fluidRestriction: v)),
        ),
        const SizedBox(height: 24),
        FilledButton(onPressed: _save, child: const Text('Save profile')),
      ]),
    );
  }
}
```

- [ ] **Step 2: Add the Settings entry**

Replace `lib/screens/settings_screen.dart` entirely (adds the profile load + tile, keeps existing behavior):

```dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:ckd_care/models/health_profile.dart';
import 'package:ckd_care/providers/health_profile_provider.dart';
import 'package:ckd_care/providers/settings_provider.dart';
import 'package:ckd_care/screens/health_profile_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});
  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<SettingsProvider>().load();
      context.read<HealthProfileProvider>().load();
    });
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

  String _profileSummary(HealthProfile p) {
    if (!p.isSet && p.dialysisStatus == DialysisStatus.none) return 'Not set';
    final parts = <String>[
      if (p.ckdStage != null) p.ckdStage!.label,
      if (p.dialysisStatus != DialysisStatus.none) p.dialysisStatus.label,
    ];
    return parts.isEmpty ? 'Not set' : parts.join(' · ');
  }

  @override
  Widget build(BuildContext context) {
    final s = context.watch<SettingsProvider>();
    final profile = context.watch<HealthProfileProvider>().profile;
    return ListView(children: [
      ListTile(
        leading: const Icon(Icons.badge_outlined),
        title: const Text('Health profile'),
        subtitle: Text(_profileSummary(profile)),
        trailing: const Icon(Icons.chevron_right),
        onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
                builder: (_) => const HealthProfileScreen())),
      ),
      const Divider(),
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

- [ ] **Step 3: Analyze + full suite**

Run: `flutter analyze` → "No issues found!"
Run: `flutter test` → all pass.

- [ ] **Step 4: Commit**

```bash
git add lib/screens/health_profile_screen.dart lib/screens/settings_screen.dart
git commit -m "feat: health profile edit screen and Settings entry"
```

---

## Manual verification checklist (device/emulator)

Run after Task 3 via `flutter run -d Pixel_4a_API_34`:

1. Settings shows a **Health profile** row reading **Not set** initially.
2. Tapping it opens the editor with the optional-guidance note; **Not sure** is selected for CKD stage and **Not on dialysis** for dialysis.
3. Pick **Stage 4**, **Hemodialysis**, toggle **Diabetes** and **Elevated potassium** on → **Save profile** → toast "Profile saved" and you return to Settings.
4. The Settings row now reads **Stage 4 · Hemodialysis**.
5. Reopen the editor → the previous selections are preserved; fully close and relaunch the app → they persist.
6. Set stage back to **Not sure** and save → the Settings row reflects the change (no stage shown).
7. Both light and dark themes render correctly.

---

## Self-Review

**Spec coverage (sub-plan A scope — health profile storage/edit):**
- Store CKD stage (1–5, optional) → `CkdStage` + persistence. ✓
- Store dialysis status (none/hemo/peritoneal) → `DialysisStatus` + persistence. ✓
- Store diabetes, elevated potassium, elevated phosphorus, fluid restriction flags → `HealthProfile` bools + persistence. ✓
- Optional; unset = general guidance → `ckdStage` nullable, `isSet`, "Not sure" chip. ✓
- Editable from the app; persists locally; no new schema → Settings entry + `HealthProfileScreen`; `setting` table keys. ✓
- Exposed to the rest of the app for later personalization → `HealthProfileProvider` in the provider tree. ✓
- Framed as non-diagnostic guidance context → editor note. ✓

**Placeholder scan:** No TBD/TODO; all code inline.

**Type consistency:** `CkdStage`/`.label`/`.number`, `ckdStageFromNumber`/`ckdStageToStored`, `DialysisStatus`/`.label`, `HealthProfile` (fields + `isSet` + `copyWith` + equality), `SettingsRepository.getHealthProfile`/`saveHealthProfile`, `HealthProfileProvider.profile`/`load`/`save` are used consistently across tasks.

**Deferred (not gaps):** actually *using* the profile to change food recommendations or show stage-based clinician alerts is sub-plan E; numeric lab values (vs. the elevated-yes/no flags) belong to the future labs feature (Group B). This plan only stores and edits the profile.
