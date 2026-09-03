# Food Guidance & Safety Pages Implementation Plan (sub-plan D)

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a "When to consult a doctor or dietitian" guidance page — with routine-consult, prompt-review, and clearly separated emergency guidance, a CKD-stage quick reference, a non-emergency disclaimer, and a profile-aware clinician alert — reachable from the Food section.

**Architecture:** Static content in `lib/data/food_guidance.dart` (const lists + a `clinicianAlert(StageBand?)` helper). A `FoodGuidanceScreen` renders the sections; the emergency block is visually distinct from everything else. An entry card at the top of the Food list opens it. The screen reads `HealthProfileProvider` to show the alert for the user's own stage band (general note when no profile).

**Tech Stack:** Flutter, existing Food Section, `HealthProfile`/`HealthProfileProvider` (sub-plan A), `StageBand`/`stageBandForProfile` (sub-plan C), `AppColors`.

## Global Constraints

- **Educational, not alarming, never diagnostic.** The page names situations where professional assessment is appropriate; it does not diagnose. No absolute claims.
- **Emergency guidance is visually separate** from the non-emergency disclaimer and routine-consult content (distinct red/emergency styling + its own heading).
- **Copy is faithful to the spec** and lives once in `lib/data/food_guidance.dart`.
- **Never tells users to change/stop medications, dialysis, or prescribed limits.** Content only advises *consulting* professionals.
- Profile-aware alert degrades gracefully: no profile → a general "consult if you have abnormal labs or other conditions" note.
- `flutter analyze` clean and `flutter test` green is the gate for every task.

---

## File Structure

```
lib/
  data/food_guidance.dart          # CREATE: const content lists + copy + clinicianAlert(StageBand?)
  screens/food_guidance_screen.dart  # CREATE: the guidance page
  screens/food_screen.dart         # MODIFY: entry card opening the guidance page
test/
  data/food_guidance_test.dart     # CREATE: lists non-empty; clinicianAlert per band
```

---

### Task 1: Guidance content + clinician alert

All the copy and lists, plus the profile-band alert helper.

**Files:**
- Create: `lib/data/food_guidance.dart`
- Test: `test/data/food_guidance_test.dart`

**Interfaces:**
- Consumes: `StageBand` (from `lib/data/food_stage_advice.dart`).
- Produces:
  - `const List<String> kConsultReasons`, `kPromptReview`, `kEmergencySigns`.
  - `const List<(String, String)> kStageQuickReference` (stage label, guidance).
  - `const String kFoodNonEmergencyDisclaimer`, `kFoodEmergencyMessage`.
  - `String clinicianAlert(StageBand? band)`.

- [ ] **Step 1: Write the failing test**

Create `test/data/food_guidance_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:ckd_care/data/food_guidance.dart';
import 'package:ckd_care/data/food_stage_advice.dart';

void main() {
  test('content lists are populated', () {
    expect(kConsultReasons.length, greaterThanOrEqualTo(6));
    expect(kPromptReview.length, greaterThanOrEqualTo(6));
    expect(kEmergencySigns.length, greaterThanOrEqualTo(5));
    expect(kStageQuickReference.length, 6); // stages 1-5 + dialysis
    expect(kFoodNonEmergencyDisclaimer.trim(), isNotEmpty);
    expect(kFoodEmergencyMessage.toLowerCase(), contains('emergency'));
  });

  test('clinicianAlert returns guidance for every band and a general note when null', () {
    expect(clinicianAlert(null).toLowerCase(), contains('consult'));
    for (final b in StageBand.values) {
      expect(clinicianAlert(b).trim(), isNotEmpty);
    }
    // Advanced bands strongly recommend professional guidance.
    expect(clinicianAlert(StageBand.stage5).toLowerCase(), contains('dietitian'));
    expect(clinicianAlert(StageBand.dialysis).toLowerCase(), contains('dietitian'));
  });
}
```

- [ ] **Step 2: Run to verify it fails**

Run: `flutter test test/data/food_guidance_test.dart`
Expected: FAIL — `food_guidance.dart` doesn't exist.

- [ ] **Step 3: Create the content**

Create `lib/data/food_guidance.dart`:

```dart
import 'package:ckd_care/data/food_stage_advice.dart';

/// Situations where users should consult a nephrologist or renal dietitian.
const List<String> kConsultReasons = [
  'You have been newly diagnosed with CKD.',
  'Your CKD stage has recently changed.',
  'You have CKD stage 3, 4, 5, or kidney failure and need an individualized diet plan.',
  'You are starting or stopping dialysis.',
  'You are considering a major change to your diet.',
  'You are unsure whether to restrict potassium, phosphorus, protein, sodium, or fluids.',
  'Recent blood tests show abnormal potassium, phosphorus, sodium, or albumin.',
  'You have diabetes, high blood pressure, heart disease, or other conditions that affect your diet.',
  'You are losing weight unintentionally or have a poor appetite.',
  'You have trouble eating enough food or protein.',
  'You take medications or supplements that may affect potassium, phosphorus, or fluid balance.',
  'You are unsure whether a food, herbal product, supplement, or traditional remedy is safe for you.',
];

/// Symptoms warranting prompt (non-emergency) medical review.
const List<String> kPromptReview = [
  'Noticeable swelling of the legs, feet, hands, or face.',
  'A clear decrease in how much you urinate.',
  'Persistent nausea or vomiting.',
  'Persistent loss of appetite.',
  'Significant or unexplained weight changes.',
  'Increasing tiredness or weakness.',
  'Persistent muscle cramps.',
  'New or worsening shortness of breath.',
  'Blood pressure that is getting harder to control.',
  'Persistent itching or other new symptoms of advanced kidney disease.',
  'New symptoms after a big change to your diet.',
];

/// Symptoms that may signal a medical emergency — seek care immediately.
const List<String> kEmergencySigns = [
  'Chest pain or pressure.',
  'Severe difficulty breathing.',
  'Fainting or loss of consciousness.',
  'Severe confusion or being unable to stay awake.',
  'A very fast, very slow, or irregular heartbeat with weakness, dizziness, or chest discomfort.',
  'Sudden severe weakness or paralysis.',
  'Severe or ongoing vomiting with signs of dehydration.',
];

/// One-line dietary focus per CKD stage / dialysis (label, guidance).
const List<(String, String)> kStageQuickReference = [
  ('Stage 1', 'Balanced diet, lower sodium, healthy portions, and control of diabetes and blood pressure.'),
  ('Stage 2', 'Keep protecting your kidneys; watch sodium and protein portions.'),
  ('Stage 3', 'Pay closer attention to sodium, protein, potassium, and phosphorus based on your labs.'),
  ('Stage 4', 'More individualized planning; sodium, potassium, phosphorus, protein, and fluids may need closer monitoring.'),
  ('Stage 5', 'An individualized renal diet; needs differ between dialysis and non-dialysis.'),
  ('Dialysis', 'Protein and other needs can differ significantly from non-dialysis CKD — follow your individual plan.'),
];

const String kFoodNonEmergencyDisclaimer =
    'This Food Section provides general health and nutrition information for '
    'education only. It is not a diagnosis, treatment, or personalized dietary '
    'prescription, and does not replace advice from a qualified healthcare '
    'professional.\n\n'
    'Kidney disease and nutritional needs vary from person to person. Food '
    'recommendations may depend on your CKD stage, lab results, medications, '
    'dialysis status, diabetes, blood pressure, and fluid balance. A food '
    'marked "Recommended" or "Limit" is not necessarily right or wrong for '
    'everyone with CKD.\n\n'
    'Do not start, stop, or significantly change your diet, medications, '
    'supplements, fluids, dialysis, or nutrient intake based only on this app. '
    'When in doubt about a food, ask your doctor, nephrologist, or renal dietitian.';

const String kFoodEmergencyMessage =
    'This may be a medical emergency. Do not rely on this app for treatment. '
    'Contact your local emergency service or go to the nearest emergency '
    'department immediately.';

/// A short clinician-consultation note tailored to the user's stage band.
/// A null band (no profile) returns a general note.
String clinicianAlert(StageBand? band) => switch (band) {
      null =>
        'Consult your healthcare professional if you have abnormal lab results '
            'or other medical conditions.',
      StageBand.early12 =>
        'General nutrition guidance may be appropriate, but consult your '
            'healthcare professional if you have abnormal lab results or other '
            'conditions.',
      StageBand.stage3 =>
        'Consider discussing your diet with your healthcare professional, '
            'especially if your potassium or phosphorus is abnormal.',
      StageBand.stage4 =>
        'Individualized renal dietary guidance is recommended. Consult your '
            'nephrologist or renal dietitian before major dietary changes.',
      StageBand.stage5 =>
        'Professional renal dietary guidance is strongly recommended. Do not '
            'independently restrict or increase potassium, phosphorus, protein, '
            'or fluids — talk to your renal dietitian.',
      StageBand.dialysis =>
        'Your nutritional and fluid needs may differ from non-dialysis CKD. '
            'Follow the individualized plan from your nephrologist or renal '
            'dietitian.',
    };
```

- [ ] **Step 4: Run to verify it passes**

Run: `flutter test test/data/food_guidance_test.dart`
Expected: PASS (2 tests).

- [ ] **Step 5: Analyze + full suite**

Run: `flutter analyze` → "No issues found!"
Run: `flutter test` → all pass.

- [ ] **Step 6: Commit**

```bash
git add lib/data/food_guidance.dart test/data/food_guidance_test.dart
git commit -m "feat: food guidance content (consult/prompt/emergency, stage reference, clinician alert)"
```

---

### Task 2: Guidance screen + Food entry card

The page rendering the content, and a card on the Food list that opens it.

**Files:**
- Create: `lib/screens/food_guidance_screen.dart`
- Modify: `lib/screens/food_screen.dart`
- Test: none new (presentational; content covered by Task 1). Manual verification below.

**Interfaces:**
- Consumes: `food_guidance.dart` content + `clinicianAlert`, `HealthProfileProvider`, `stageBandForProfile`, `AppColors`.

- [ ] **Step 1: Create the guidance screen**

Create `lib/screens/food_guidance_screen.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:ckd_care/data/food_guidance.dart';
import 'package:ckd_care/data/food_stage_advice.dart';
import 'package:ckd_care/providers/health_profile_provider.dart';
import 'package:ckd_care/theme/app_theme.dart';

class FoodGuidanceScreen extends StatelessWidget {
  const FoodGuidanceScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final band = stageBandForProfile(
        context.watch<HealthProfileProvider>().profile);

    Widget heading(String t) => Padding(
          padding: const EdgeInsets.only(top: 22, bottom: 8),
          child: Text(t, style: text.titleMedium),
        );

    Widget bullets(List<String> items, {Color? dot}) => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (final s in items)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Padding(
                    padding: const EdgeInsets.only(top: 7, right: 10),
                    child: Icon(Icons.circle,
                        size: 6, color: dot ?? cs.onSurfaceVariant),
                  ),
                  Expanded(child: Text(s, style: text.bodyLarge)),
                ]),
              ),
          ],
        );

    Widget noticeCard(String body, {required Color color, IconData? icon}) =>
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Icon(icon ?? Icons.info_outline, size: 20, color: color),
            const SizedBox(width: 10),
            Expanded(
                child: Text(body,
                    style: text.bodyMedium?.copyWith(color: color))),
          ]),
        );

    return Scaffold(
      appBar: AppBar(title: const Text('When to get help')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: [
          // Profile-aware clinician alert.
          noticeCard(clinicianAlert(band),
              color: AppColors.primary, icon: Icons.medical_information_outlined),

          heading('Talk to a nephrologist or renal dietitian if…'),
          bullets(kConsultReasons),

          heading('Get medical review soon if you notice…'),
          bullets(kPromptReview, dot: AppColors.warn),

          heading('Emergency — get care now'),
          const SizedBox(height: 2),
          noticeCard(kFoodEmergencyMessage,
              color: AppColors.over, icon: Icons.emergency_outlined),
          const SizedBox(height: 10),
          bullets(kEmergencySigns, dot: AppColors.over),

          heading('Diet focus by CKD stage'),
          for (final (stage, guidance) in kStageQuickReference)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(stage,
                      style: text.labelMedium
                          ?.copyWith(fontWeight: FontWeight.w800)),
                  const SizedBox(height: 2),
                  Text(guidance, style: text.bodyMedium),
                ],
              ),
            ),

          heading('About this information'),
          Text(kFoodNonEmergencyDisclaimer, style: text.bodyMedium),
        ],
      ),
    );
  }
}
```

- [ ] **Step 2: Add the entry card to the Food list**

In `lib/screens/food_screen.dart`, add the import:

```dart
import 'package:ckd_care/screens/food_guidance_screen.dart';
```

Immediately after the disclaimer `Container` (the one rendering `kFoodDisclaimer`) and before `const SizedBox(height: 12)`, insert a tappable card:

```dart
        const SizedBox(height: 10),
        Material(
          color: cs.surface,
          borderRadius: BorderRadius.circular(14),
          child: InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (_) => const FoodGuidanceScreen())),
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: cs.outlineVariant),
              ),
              child: Row(children: [
                const Icon(Icons.health_and_safety_outlined,
                    size: 20, color: AppColors.primary),
                const SizedBox(width: 10),
                Expanded(
                    child: Text('When to consult a doctor or dietitian',
                        style: text.titleSmall
                            ?.copyWith(color: cs.onSurface))),
                Icon(Icons.chevron_right, color: cs.onSurfaceVariant),
              ]),
            ),
          ),
        ),
```

Add the theme import if `AppColors` is not already imported in `food_screen.dart`:

```dart
import 'package:ckd_care/theme/app_theme.dart';
```

- [ ] **Step 3: Analyze + full suite**

Run: `flutter analyze` → "No issues found!"
Run: `flutter test` → all pass.

- [ ] **Step 4: Commit**

```bash
git add lib/screens/food_guidance_screen.dart lib/screens/food_screen.dart
git commit -m "feat: food guidance page (when to consult / emergency) + entry card"
```

---

## Manual verification checklist (device/emulator)

Run after Task 2 via `flutter run -d Pixel_4a_API_34`:

1. The Food list shows a **When to consult a doctor or dietitian** card below the disclaimer; tapping it opens the guidance page.
2. The page shows, in order: a clinician alert (matching your profile stage, or a general note if unset), "Talk to a nephrologist…" reasons, "Get medical review soon…" signs, an **Emergency** block that is visually distinct (red) with the emergency message + signs, a per-stage diet reference, and the about/disclaimer text.
3. Set a Health profile of Stage 5 (Settings) → reopen the page → the clinician alert now reads the stronger "professional renal dietary guidance is strongly recommended" text.
4. Emergency content is clearly separated from the non-emergency disclaimer (different section + red styling).
5. Both light and dark themes render correctly.

---

## Self-Review

**Spec coverage (sub-plan D scope — spec sections 13 "When to consult" + 14 "Non-emergency disclaimer"):**
- Consult a nephrologist/dietitian list → `kConsultReasons` + screen section. ✓
- Prompt medical review list → `kPromptReview`. ✓
- Emergency warning list + message, visually separated → `kEmergencySigns` + `kFoodEmergencyMessage`, distinct red block. ✓
- CKD-stage quick reference → `kStageQuickReference`. ✓
- Non-emergency disclaimer → `kFoodNonEmergencyDisclaimer`. ✓
- Contextual clinician alert by stage (spec 13F) → `clinicianAlert(StageBand?)` driven by the profile. ✓
- Never instructs stopping meds/dialysis/changing limits → content only advises consulting. ✓
- Not alarming / educational decision-support → calm styling; emergency isolated. ✓

**Placeholder scan:** No TBD/TODO; all content + code inline.

**Type consistency:** `kConsultReasons`/`kPromptReview`/`kEmergencySigns`/`kStageQuickReference`/`kFoodNonEmergencyDisclaimer`/`kFoodEmergencyMessage`/`clinicianAlert(StageBand?)`, `FoodGuidanceScreen`, `stageBandForProfile`, `HealthProfileProvider.profile` used consistently.

**Deferred (not gaps):** the acknowledgment-dialog emergency line and the food-detail short/high-risk notices already shipped in sub-plan B; personalized per-food status using the profile is sub-plan E. This page is general safety guidance + a profile-aware consult alert.
