# Food Personalization Implementation Plan (sub-plan E)

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Use the user's health profile to surface a "For your stage" callout on each food detail page (their band's advice + clinician alert), and a profile-context hint on the Food list — falling back to general guidance, and prompting to set a stage, when no profile exists.

**Architecture:** Read `HealthProfileProvider` in the food detail + list screens, map to a `StageBand` via `stageBandForProfile` (sub-plan C), and render `stageAdvice(food, band)` (sub-plan C) + `clinicianAlert(band)` (sub-plan D) for the user's own band. No new data or models — pure wiring of existing pieces into a personalized view.

**Tech Stack:** Flutter, `provider`, existing Food Section + `HealthProfileProvider` (A), `stageBandForProfile`/`stageAdvice` (C), `clinicianAlert` (D), `HealthProfileScreen` (A), `AppColors`.

## Global Constraints

- **Graceful fallback.** No CKD stage/dialysis set → show general guidance and a gentle prompt to set a stage; never invent a stage or hide the general per-stage table.
- **Personalization tailors emphasis, not safety.** The general "By CKD stage" table and all disclaimers stay; the personalized callout is additive and still defers to labs/dietitian for later bands (its text comes from the already-reviewed `stageAdvice`/`clinicianAlert`).
- **No new clinical claims.** This sub-plan only re-presents existing, reviewed strings for the user's band.
- `flutter analyze` clean and `flutter test` green is the gate for every task.

---

## File Structure

```
lib/
  screens/food_detail_screen.dart   # MODIFY: "For your stage" callout (or set-stage hint)
  screens/food_screen.dart          # MODIFY: profile-context hint row
```

(No new files or tests — the underlying helpers are already unit-tested in sub-plans A/C/D; changes here are presentational and covered by manual verification.)

---

### Task 1: "For your stage" callout on the food detail page

Show the user's own band advice + clinician alert prominently; prompt to set a stage when none.

**Files:**
- Modify: `lib/screens/food_detail_screen.dart`
- Test: none new (helpers pre-tested). Manual verification below.

**Interfaces:**
- Consumes: `HealthProfileProvider`, `stageBandForProfile`, `StageBand`, `stageAdvice`, `clinicianAlert`, `AppColors`.

- [ ] **Step 1: Add the personalized callout**

In `lib/screens/food_detail_screen.dart`:

Add imports (if not already present):

```dart
import 'package:provider/provider.dart';
import 'package:ckd_care/data/food_guidance.dart';
import 'package:ckd_care/providers/health_profile_provider.dart';
```

`food_detail_screen.dart` already imports `food_stage_advice.dart` (for `StageBand`/`stageAdvice`) and `app_theme.dart` (for `AppColors`) and has `cs`/`text` locals in `build`. In `build`, compute the user's band near the top (after `final cs = ...` / `final text = ...`):

```dart
    final band = stageBandForProfile(
        context.watch<HealthProfileProvider>().profile);
```

Insert the callout right after the status/category `Row(children: [_StatusBadge(...), ... food.category.label ...])` and before `section('Why', ...)`:

```dart
          const SizedBox(height: 16),
          if (band != null)
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: cs.primary.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: cs.primary.withValues(alpha: 0.4)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    Icon(Icons.person_pin_circle_outlined,
                        size: 18, color: cs.primary),
                    const SizedBox(width: 8),
                    Text('For your stage — ${band.label}',
                        style: text.labelMedium?.copyWith(
                            color: cs.primary, fontWeight: FontWeight.w800)),
                  ]),
                  const SizedBox(height: 8),
                  Text(stageAdvice(food, band), style: text.bodyLarge),
                  const SizedBox(height: 8),
                  Text(clinicianAlert(band), style: text.bodyMedium),
                ],
              ),
            )
          else
            Material(
              color: cs.surface,
              borderRadius: BorderRadius.circular(14),
              child: InkWell(
                borderRadius: BorderRadius.circular(14),
                onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => const HealthProfileScreen())),
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: cs.outlineVariant),
                  ),
                  child: Row(children: [
                    Icon(Icons.tune, size: 18, color: cs.onSurfaceVariant),
                    const SizedBox(width: 8),
                    Expanded(
                        child: Text(
                            'Set your CKD stage for guidance tailored to you.',
                            style: text.bodyMedium)),
                    Icon(Icons.chevron_right, color: cs.onSurfaceVariant),
                  ]),
                ),
              ),
            ),
```

Add the import for the profile screen used by the fallback:

```dart
import 'package:ckd_care/screens/health_profile_screen.dart';
```

- [ ] **Step 2: Analyze + full suite**

Run: `flutter analyze` → "No issues found!" (fix any structural mismatch with the actual `build` — the callout must sit between the status Row and the first `section('Why', ...)`).
Run: `flutter test` → all pass.

- [ ] **Step 3: Commit**

```bash
git add lib/screens/food_detail_screen.dart
git commit -m "feat: personalized 'For your stage' callout on food detail"
```

---

### Task 2: Profile-context hint on the Food list

A one-line hint at the top of the Food list: tailored when a stage is set, a prompt otherwise.

**Files:**
- Modify: `lib/screens/food_screen.dart`
- Test: none new. Manual verification below.

**Interfaces:**
- Consumes: `HealthProfileProvider`, `stageBandForProfile`, `StageBand`, `HealthProfileScreen`, `AppColors`.

- [ ] **Step 1: Add the profile-context row**

In `lib/screens/food_screen.dart`, add imports (if not present):

```dart
import 'package:provider/provider.dart';
import 'package:ckd_care/data/food_stage_advice.dart';
import 'package:ckd_care/providers/health_profile_provider.dart';
import 'package:ckd_care/screens/health_profile_screen.dart';
```

In `build`, compute the band (near the existing `cs`/`text` locals):

```dart
    final band = stageBandForProfile(
        context.watch<HealthProfileProvider>().profile);
```

Immediately after the "When to consult a doctor or dietitian" entry card (added in sub-plan D) and before `const SizedBox(height: 12)` that precedes the filter chips, insert:

```dart
        const SizedBox(height: 10),
        if (band != null)
          Row(children: [
            Icon(Icons.check_circle_outline, size: 16, color: cs.primary),
            const SizedBox(width: 6),
            Text('Guidance tailored for ${band.label}',
                style: text.labelMedium?.copyWith(color: cs.primary)),
          ])
        else
          InkWell(
            onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (_) => const HealthProfileScreen())),
            child: Row(children: [
              Icon(Icons.tune, size: 16, color: cs.onSurfaceVariant),
              const SizedBox(width: 6),
              Expanded(
                child: Text('Set your CKD stage for tailored guidance',
                    style: text.labelMedium),
              ),
              Icon(Icons.chevron_right, size: 18, color: cs.onSurfaceVariant),
            ]),
          ),
```

- [ ] **Step 2: Analyze + full suite**

Run: `flutter analyze` → "No issues found!"
Run: `flutter test` → all pass.

- [ ] **Step 3: Commit**

```bash
git add lib/screens/food_screen.dart
git commit -m "feat: profile-context hint on the Food list"
```

---

## Manual verification checklist (device/emulator)

Run after Task 2 via `flutter run -d Pixel_4a_API_34`:

1. With **no** health profile set: the Food list shows a tappable "Set your CKD stage for tailored guidance" row; a food detail shows a "Set your CKD stage…" prompt card (opening the profile editor) instead of a stage callout — the general "By CKD stage" table is still shown below.
2. Set a profile of **Stage 4** (Settings → Health profile): the Food list now reads "Guidance tailored for Stage 4"; open **Banana** → a highlighted **For your stage — Stage 4** callout appears near the top with the stage-4 advice + the stage-4 clinician alert.
3. Set **Dialysis** (any type): the callout reads **For your stage — Dialysis** with the dialysis advice + dialysis clinician alert.
4. The general "By CKD stage" section and all disclaimers remain present regardless of profile.
5. Both light and dark themes render the callout correctly.

---

## Self-Review

**Spec coverage (sub-plan E scope — personalization):**
- Use CKD stage + dialysis status from the profile to tailor guidance → detail callout + list hint via `stageBandForProfile`. ✓
- Show the user's band advice + a stage-appropriate clinician alert → `stageAdvice(food, band)` + `clinicianAlert(band)`. ✓
- Fall back to general guidance + prompt when no profile → `band == null` branches (set-stage hint/card); general table retained. ✓
- Advanced-stage/dialysis contextual consult emphasis → carried by `clinicianAlert` (stage4/5/dialysis text) in the callout. ✓
- Personalization never overrides safety → disclaimers + general table remain; callout strings are the already-reviewed advice/alert copy. ✓

**Placeholder scan:** No TBD/TODO; all code inline.

**Type consistency:** `stageBandForProfile(HealthProfile)`, `StageBand.label`, `stageAdvice(Food, StageBand)`, `clinicianAlert(StageBand?)`, `HealthProfileProvider.profile`, `HealthProfileScreen` used consistently.

**Deferred (not gaps):** using elevated-potassium/phosphorus flags or diabetes from the profile to further adjust a specific food's callout is a future refinement (the current callout keys off stage band + the food's nutrient profile, which already covers the main cases); numeric labs remain out of scope (qualitative model).
