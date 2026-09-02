# Food Disclaimer & Acknowledgment Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Gate the existing Food tab behind a versioned, once-per-version medical-disclaimer acknowledgment (modal with required checkbox + "I Understand & Continue" / "Go Back"), persisted locally, and add the short educational notice plus a high-risk contextual warning to food detail pages.

**Architecture:** The acknowledgment (disclaimer version + timestamp) persists in the existing `setting` key/value table via `SettingsRepository`. `SettingsProvider` exposes acknowledged?/acknowledge. The `HomeShell` intercepts selection of the Food tab: if the current disclaimer version isn't acknowledged, it shows a modal; "Go Back" leaves the current tab (no access), "I Understand & Continue" records the ack and opens Food. Detail pages show the short notice always and a high-risk warning for foods carrying a potassium/phosphorus/sodium concern.

**Tech Stack:** Flutter, `provider`, existing `sqflite` `setting` table + `SettingsRepository`/`SettingsProvider`, existing Food Section.

## Global Constraints

- **Not medical advice; never alarming; never absolute.** No "safe for all CKD patients" / "must never eat" / "will cure/improve kidney function" language. This plan only adds disclaimer/acknowledgment UI; it does not change any food's classification.
- **Copy is verbatim.** All disclaimer strings live once in `lib/data/food_disclaimer.dart` and are used from there — never re-typed inline.
- **Version-gated, once per version.** Current version is `kFoodDisclaimerVersion = '1.0'`. The modal shows only when the stored acknowledged version ≠ current version; a materially updated disclaimer bumps the version and re-prompts.
- **Decline = no access.** "Go Back" must not record acknowledgment and must not open the Food tab; it leaves the user on their current tab. No "Accept Medical Responsibility" / rights-waiver language.
- **Persistence reuses the `setting` table** (keys `food_disclaimer_ack_version`, `food_disclaimer_ack_at`) — no schema change.
- Emergency guidance is stated inside the modal and visually distinct from the general (non-emergency) message.
- Detail-page notice does NOT require a second acknowledgment.
- `flutter analyze` clean and `flutter test` green is the gate for every task.

---

## File Structure

```
lib/
  data/food_disclaimer.dart        # CREATE: version, all copy consts, foodDisclaimerNeeded(), isHighRiskFood()
  repositories/settings_repository.dart  # MODIFY: getFoodDisclaimerAckVersion / setFoodDisclaimerAck
  providers/settings_provider.dart # MODIFY: foodDisclaimerAcknowledged() / acknowledgeFoodDisclaimer()
  widgets/food_disclaimer_dialog.dart    # CREATE: the modal (checkbox gates Continue)
  main.dart                        # MODIFY: HomeShell gates the Food tab
  screens/food_detail_screen.dart  # MODIFY: short notice + high-risk warning
test/
  data/food_disclaimer_test.dart          # CREATE: foodDisclaimerNeeded + isHighRiskFood
  repositories/settings_repository_test.dart  # MODIFY: ack round-trip
  widgets/food_disclaimer_dialog_test.dart    # CREATE: Continue disabled until checkbox
```

---

### Task 1: Disclaimer copy/version, helpers, and persistence

Central copy + version, two pure helpers, and the persistence + provider methods.

**Files:**
- Create: `lib/data/food_disclaimer.dart`
- Modify: `lib/repositories/settings_repository.dart`, `lib/providers/settings_provider.dart`
- Test: `test/data/food_disclaimer_test.dart`, `test/repositories/settings_repository_test.dart`

**Interfaces:**
- Consumes: `Food` (from `lib/models/food.dart`), `SettingsRepository` (private `_get`/`_set`), `SettingsProvider._repo`.
- Produces:
  - `const String kFoodDisclaimerVersion` (`'1.0'`), plus copy consts: `kFoodDisclaimerTitle`, `kFoodDisclaimerMessage`, `kFoodEmergencyNotice`, `kFoodDisclaimerCheckbox`, `kFoodDetailNotice`, `kFoodHighRiskNotice`.
  - `bool foodDisclaimerNeeded(String? storedVersion)` — true when `storedVersion != kFoodDisclaimerVersion`.
  - `bool isHighRiskFood(Food food)` — true when any concern (lowercased) contains `'high'` or `'additive'`.
  - `SettingsRepository.getFoodDisclaimerAckVersion() → Future<String?>`, `SettingsRepository.setFoodDisclaimerAck(String version) → Future<void>` (stores version + `food_disclaimer_ack_at` = now).
  - `SettingsProvider.foodDisclaimerAcknowledged() → Future<bool>`, `SettingsProvider.acknowledgeFoodDisclaimer() → Future<void>`.

- [ ] **Step 1: Write the failing helper tests**

Create `test/data/food_disclaimer_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:ckd_care/data/food_disclaimer.dart';
import 'package:ckd_care/models/food.dart';

Food food(List<String> concerns) => Food(
      name: 'X',
      category: FoodCategory.fruits,
      status: FoodStatus.recommended,
      why: 'why',
      concerns: concerns,
      prep: 'prep',
      goodMethods: const ['Raw'],
    );

void main() {
  test('foodDisclaimerNeeded: null or old version needs ack; current does not', () {
    expect(foodDisclaimerNeeded(null), isTrue);
    expect(foodDisclaimerNeeded('0.9'), isTrue);
    expect(foodDisclaimerNeeded(kFoodDisclaimerVersion), isFalse);
  });

  test('isHighRiskFood flags high/additive concerns, not low ones', () {
    expect(isHighRiskFood(food(['High potassium'])), isTrue);
    expect(isHighRiskFood(food(['Phosphorus additives'])), isTrue);
    expect(isHighRiskFood(food(['Very high potassium'])), isTrue);
    expect(isHighRiskFood(food(['Low potassium'])), isFalse);
    expect(isHighRiskFood(food(['Counts toward your fluid limit'])), isFalse);
  });
}
```

- [ ] **Step 2: Run to verify it fails**

Run: `flutter test test/data/food_disclaimer_test.dart`
Expected: FAIL — `food_disclaimer.dart` doesn't exist.

- [ ] **Step 3: Create the copy + helpers**

Create `lib/data/food_disclaimer.dart`:

```dart
import 'package:ckd_care/models/food.dart';

/// Bump when the disclaimer text materially changes — users re-acknowledge.
const String kFoodDisclaimerVersion = '1.0';

const String kFoodDisclaimerTitle = 'Important Medical Information';

const String kFoodDisclaimerMessage =
    'This Food Section provides general educational information about nutrition '
    'and kidney health. It is not medical advice, a diagnosis, or a '
    'personalized treatment plan.\n\n'
    'Your dietary needs may vary depending on your CKD stage, laboratory '
    'results, medications, dialysis status, diabetes, blood pressure, and other '
    'health conditions.\n\n'
    'Do not make significant changes to your diet, fluid intake, potassium, '
    'phosphorus, protein, sodium, medications, or dialysis schedule based solely '
    'on this application.\n\n'
    'For personalized dietary advice, consult your doctor, nephrologist, or '
    'registered renal dietitian.';

const String kFoodEmergencyNotice =
    'If you are experiencing severe or rapidly worsening symptoms, seek '
    'emergency medical care immediately. Do not rely on this application for '
    'emergency medical advice.';

const String kFoodDisclaimerCheckbox =
    'I understand that this information is for educational purposes only and is '
    'not a substitute for professional medical advice.';

const String kFoodDetailNotice =
    'Educational Information Only: This information does not replace advice from '
    'your doctor or renal dietitian. Your recommended serving size or dietary '
    'restrictions may differ based on your individual health and laboratory '
    'results.';

const String kFoodHighRiskNotice =
    'Personalized medical guidance is recommended. Dietary requirements for '
    'advanced CKD and dialysis can vary significantly between individuals. '
    'Consult your nephrologist or renal dietitian before making significant '
    'dietary changes.';

/// True when the stored acknowledged version differs from the current version.
bool foodDisclaimerNeeded(String? storedVersion) =>
    storedVersion != kFoodDisclaimerVersion;

/// A food warrants the extra high-risk notice when it carries a "high" or
/// "additive" nutrient concern (clinically sensitive in advanced CKD/dialysis).
/// Stage/profile-based triggers are added in a later sub-plan.
bool isHighRiskFood(Food food) => food.concerns.any((c) {
      final l = c.toLowerCase();
      return l.contains('high') || l.contains('additive');
    });
```

- [ ] **Step 4: Run to verify the helper tests pass**

Run: `flutter test test/data/food_disclaimer_test.dart`
Expected: PASS (2 tests).

- [ ] **Step 5: Write the failing persistence test**

Add to `test/repositories/settings_repository_test.dart` inside `main()`:

```dart
  test('food disclaimer ack version round-trips; null until set', () async {
    expect(await repo.getFoodDisclaimerAckVersion(), isNull);
    await repo.setFoodDisclaimerAck('1.0');
    expect(await repo.getFoodDisclaimerAckVersion(), '1.0');
  });
```

- [ ] **Step 6: Run to verify it fails**

Run: `flutter test test/repositories/settings_repository_test.dart`
Expected: FAIL — `getFoodDisclaimerAckVersion` not defined.

- [ ] **Step 7: Add the repository methods**

In `lib/repositories/settings_repository.dart`, add the key constants near the top (below the existing `kNotifications` const):

```dart
const String kFoodDisclaimerAckVersion = 'food_disclaimer_ack_version';
const String kFoodDisclaimerAckAt = 'food_disclaimer_ack_at';
```

And add these methods to the `SettingsRepository` class (after `setNotificationsEnabled`):

```dart
  Future<String?> getFoodDisclaimerAckVersion() => _get(kFoodDisclaimerAckVersion);

  Future<void> setFoodDisclaimerAck(String version) async {
    await _set(kFoodDisclaimerAckVersion, version);
    await _set(kFoodDisclaimerAckAt, DateTime.now().toIso8601String());
  }
```

- [ ] **Step 8: Run to verify it passes**

Run: `flutter test test/repositories/settings_repository_test.dart`
Expected: PASS.

- [ ] **Step 9: Add the provider methods**

In `lib/providers/settings_provider.dart`, add the import at the top:

```dart
import 'package:ckd_care/data/food_disclaimer.dart';
```

And add these methods to `SettingsProvider` (after `setNotifications`):

```dart
  Future<bool> foodDisclaimerAcknowledged() async =>
      !foodDisclaimerNeeded(await _repo.getFoodDisclaimerAckVersion());

  Future<void> acknowledgeFoodDisclaimer() =>
      _repo.setFoodDisclaimerAck(kFoodDisclaimerVersion);
```

- [ ] **Step 10: Analyze + full suite**

Run: `flutter analyze` → "No issues found!"
Run: `flutter test` → all pass.

- [ ] **Step 11: Commit**

```bash
git add lib/data/food_disclaimer.dart lib/repositories/settings_repository.dart lib/providers/settings_provider.dart test/data/food_disclaimer_test.dart test/repositories/settings_repository_test.dart
git commit -m "feat: food disclaimer copy, version, helpers, and ack persistence"
```

---

### Task 2: Disclaimer modal dialog

The modal: title, scrollable general message, a visually distinct emergency notice, a required checkbox, "Go Back", and an "I Understand & Continue" button disabled until the checkbox is ticked. Returns `true` on continue, `false` on go-back.

**Files:**
- Create: `lib/widgets/food_disclaimer_dialog.dart`
- Test: `test/widgets/food_disclaimer_dialog_test.dart`

**Interfaces:**
- Consumes: copy consts from `food_disclaimer.dart`, `AppColors`.
- Produces: `class FoodDisclaimerDialog extends StatefulWidget` (const constructor). Shown via `showDialog<bool>(barrierDismissible: false, builder: (_) => const FoodDisclaimerDialog())`; pops `true` (continue) or `false` (go back).

- [ ] **Step 1: Write the failing widget test**

Create `test/widgets/food_disclaimer_dialog_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ckd_care/widgets/food_disclaimer_dialog.dart';

void main() {
  testWidgets('Continue is disabled until the checkbox is ticked', (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(body: FoodDisclaimerDialog()),
    ));

    final continueFinder = find.widgetWithText(FilledButton, 'I Understand & Continue');
    expect(continueFinder, findsOneWidget);
    // Disabled = onPressed is null.
    expect(tester.widget<FilledButton>(continueFinder).onPressed, isNull);

    await tester.tap(find.byType(Checkbox));
    await tester.pump();

    expect(tester.widget<FilledButton>(continueFinder).onPressed, isNotNull);
    expect(find.widgetWithText(TextButton, 'Go Back'), findsOneWidget);
  });
}
```

- [ ] **Step 2: Run to verify it fails**

Run: `flutter test test/widgets/food_disclaimer_dialog_test.dart`
Expected: FAIL — `food_disclaimer_dialog.dart` doesn't exist.

- [ ] **Step 3: Create the dialog**

Create `lib/widgets/food_disclaimer_dialog.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:ckd_care/data/food_disclaimer.dart';
import 'package:ckd_care/theme/app_theme.dart';

/// Blocking medical disclaimer shown before the Food Section. Pops `true` when
/// the user acknowledges and continues, `false` when they go back.
class FoodDisclaimerDialog extends StatefulWidget {
  const FoodDisclaimerDialog({super.key});
  @override
  State<FoodDisclaimerDialog> createState() => _FoodDisclaimerDialogState();
}

class _FoodDisclaimerDialogState extends State<FoodDisclaimerDialog> {
  bool _checked = false;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return AlertDialog(
      title: const Text(kFoodDisclaimerTitle),
      content: SizedBox(
        width: double.maxFinite,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(kFoodDisclaimerMessage, style: text.bodyMedium),
              const SizedBox(height: 14),
              // Emergency notice — visually distinct from the general message.
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.over.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Icon(Icons.emergency_outlined,
                      size: 20, color: AppColors.over),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(kFoodEmergencyNotice,
                        style: text.bodyMedium?.copyWith(color: AppColors.over)),
                  ),
                ]),
              ),
              const SizedBox(height: 6),
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                controlAffinity: ListTileControlAffinity.leading,
                value: _checked,
                onChanged: (v) => setState(() => _checked = v ?? false),
                title: Text(kFoodDisclaimerCheckbox, style: text.bodyMedium),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('Go Back'),
        ),
        FilledButton(
          onPressed: _checked ? () => Navigator.pop(context, true) : null,
          child: const Text('I Understand & Continue'),
        ),
      ],
    );
  }
}
```

- [ ] **Step 4: Run to verify it passes**

Run: `flutter test test/widgets/food_disclaimer_dialog_test.dart`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/widgets/food_disclaimer_dialog.dart test/widgets/food_disclaimer_dialog_test.dart
git commit -m "feat: food disclaimer modal (checkbox gates Continue)"
```

---

### Task 3: Gate the Food tab + detail-page notices

Intercept Food-tab selection in `HomeShell` to show the modal when unacknowledged (decline stays on the current tab), and add the short educational notice + high-risk warning to the food detail page.

**Files:**
- Modify: `lib/main.dart`, `lib/screens/food_detail_screen.dart`
- Test: none new (integration/UI; helpers + persistence + dialog are covered by Tasks 1–2). Manual verification below.

**Interfaces:**
- Consumes: `SettingsProvider.foodDisclaimerAcknowledged/acknowledgeFoodDisclaimer`, `FoodDisclaimerDialog`, `kFoodDetailNotice`, `kFoodHighRiskNotice`, `isHighRiskFood`, `AppColors`.

- [ ] **Step 1: Gate the Food tab in HomeShell**

In `lib/main.dart`, add imports near the other imports:

```dart
import 'package:ckd_care/data/food_disclaimer.dart';
import 'package:ckd_care/widgets/food_disclaimer_dialog.dart';
```

In `_HomeShellState`, add a Food-index constant below `int _index = 0;`:

```dart
  static const _foodIndex = 3;
```

Replace the `NavigationBar`'s `onDestinationSelected: (i) => setState(() => _index = i),` with a call to an async handler:

```dart
        onDestinationSelected: _onSelect,
```

And add the handler method to `_HomeShellState`:

```dart
  Future<void> _onSelect(int i) async {
    if (i == _foodIndex) {
      final settings = context.read<SettingsProvider>();
      if (!await settings.foodDisclaimerAcknowledged()) {
        if (!mounted) return;
        final ok = await showDialog<bool>(
          context: context,
          barrierDismissible: false,
          builder: (_) => const FoodDisclaimerDialog(),
        );
        if (ok != true) return; // declined: stay on the current tab
        await settings.acknowledgeFoodDisclaimer();
        if (!mounted) return;
      }
    }
    setState(() => _index = i);
  }
```

(`context.read<SettingsProvider>()` works because `HomeShell` sits under the `MultiProvider` in `CkdApp`.)

- [ ] **Step 2: Add the short notice + high-risk warning to the detail page**

In `lib/screens/food_detail_screen.dart`, change the imports so it uses the disclaimer copy (replace the `food_data.dart` import if present):

```dart
import 'package:ckd_care/data/food_disclaimer.dart';
```

Replace the bottom disclaimer `Container` (the one currently rendering `kFoodDisclaimer`) with the short educational notice plus a conditional high-risk warning:

```dart
          if (isHighRiskFood(food)) ...[
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.warn.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Icon(Icons.priority_high_rounded,
                    size: 20, color: AppColors.warn),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(kFoodHighRiskNotice,
                      style: text.bodyMedium?.copyWith(color: AppColors.warn)),
                ),
              ]),
            ),
          ],
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: cs.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(children: [
              Icon(Icons.info_outline, size: 20, color: cs.onSurfaceVariant),
              const SizedBox(width: 10),
              Expanded(child: Text(kFoodDetailNotice, style: text.bodyMedium)),
            ]),
          ),
```

Note: `food_detail_screen.dart` uses `AppColors` for the warn/over tints — it already imports the theme. If the analyzer reports `AppColors` undefined, add `import 'package:ckd_care/theme/app_theme.dart';`.

- [ ] **Step 3: Analyze + full suite**

Run: `flutter analyze` → "No issues found!" (fix any leftover reference to the removed `kFoodDisclaimer`/`food_data` import in the detail screen).
Run: `flutter test` → all pass.

- [ ] **Step 4: Commit**

```bash
git add lib/main.dart lib/screens/food_detail_screen.dart
git commit -m "feat: gate Food tab behind disclaimer ack; add detail notices"
```

---

## Manual verification checklist (device/emulator)

Run after Task 3 via `flutter run -d Pixel_4a_API_34` (fresh install so no prior ack):

1. Tap the **Food** tab → the **Important Medical Information** modal appears; it cannot be dismissed by tapping outside.
2. The general message and a visually distinct **emergency** notice are both shown; **I Understand & Continue** is disabled until the checkbox is ticked.
3. Tap **Go Back** → the modal closes and you remain on the previous tab; the Food list is NOT shown.
4. Tap **Food** again → modal reappears (declining didn't record ack). Tick the box → **I Understand & Continue** enables → tap it → the Food list opens.
5. Tap **Food** again (and after fully closing/reopening the app) → the modal does NOT reappear (ack persisted for version 1.0).
6. Open a food detail (e.g., **Banana**) → the short **Educational Information Only** notice shows, plus an amber **high-risk** warning (banana carries a "High potassium" concern).
7. Open a low-risk food (e.g., **Apple**) → the short notice shows but NO high-risk warning.
8. Both light and dark themes render the modal and notices correctly.

---

## Self-Review

**Spec coverage (sub-plan B scope — disclaimer & acknowledgment, spec sections 13–15):**
- First-entry modal with title/message/emergency line → Task 2 dialog + Task 3 gate. ✓
- Required checkbox; Continue disabled until checked → Task 2 (asserted by widget test). ✓
- "I Understand & Continue" records ack (version + timestamp), persisted locally → Task 1 persistence + Task 3 `acknowledgeFoodDisclaimer`. ✓
- "Go Back" = no access, no ack, return to previous screen → Task 3 handler (`return` leaves current tab). ✓
- Versioning: re-prompt when version changes → `foodDisclaimerNeeded` compares stored vs `kFoodDisclaimerVersion`. ✓
- Not shown again unless version changes → Task 3 gate only shows when not acknowledged. ✓
- Detail-page short notice (not re-acknowledged) → Task 3 detail `kFoodDetailNotice`. ✓
- High-risk contextual warning → Task 3 `isHighRiskFood` → `kFoodHighRiskNotice`. ✓
- Emergency visually separate from general message → Task 2 (over-tinted emergency box). ✓
- No absolute/rights-waiver language; not alarming → copy is verbatim from spec; only "Go Back"/"I Understand & Continue". ✓

**Placeholder scan:** No TBD/TODO; all copy and code inline.

**Type consistency:** `kFoodDisclaimerVersion`, `foodDisclaimerNeeded(String?)`, `isHighRiskFood(Food)`, the copy consts, `SettingsRepository.getFoodDisclaimerAckVersion/setFoodDisclaimerAck`, `SettingsProvider.foodDisclaimerAcknowledged/acknowledgeFoodDisclaimer`, `FoodDisclaimerDialog` used consistently across tasks.

**Deferred to later sub-plans (not gaps):** stage/profile-based contextual clinician alerts and the standalone "When to consult a doctor/dietitian" + emergency/non-emergency info pages (sub-plan D); personalization from a health profile (sub-plans A + E); stage-aware food statuses and the expanded localized dataset (sub-plan C). This plan's high-risk trigger keys off food properties, not the user's CKD stage, because no health profile exists yet.
