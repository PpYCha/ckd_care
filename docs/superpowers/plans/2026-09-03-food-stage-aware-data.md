# Stage-Aware Food Data Implementation Plan (sub-plan C)

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Enrich the food data with serving sizes and qualitative potassium/phosphorus/sodium levels, add CKD-stage-band advice computed from each food's nutrient profile (not a blanket stage rule), expand the dataset with common Filipino foods, and show all of this on the food detail page.

**Architecture:** Extend the existing `Food` value object with optional nutrient levels + serving size. Add a `StageBand` enum, a pure `stageBandForProfile(HealthProfile)` mapper, and a pure `stageAdvice(Food, StageBand)` that derives short guidance from the food's status + nutrient levels. The detail page gains a "By CKD stage" section rendering advice across bands. No personalization yet (sub-plan E highlights the user's own band).

**Tech Stack:** Flutter, existing Food Section, `HealthProfile` (from sub-plan A).

## Global Constraints

- **Qualitative nutrients, not fabricated numbers.** Potassium/phosphorus/sodium are `NutrientLevel { low, moderate, high }` (nullable = unspecified). This is how renal food lists work and avoids inventing exact mg/calorie values. Serving size is a plain human string.
- **Never blanket-restrict by stage.** `stageAdvice` derives guidance from the food's own nutrient levels + status; later bands add "confirm with your labs / dietitian" wording, and every band's advice defers to the user's care team. No advice says a food is "safe for all" or "never eat".
- **New Food fields are optional** (nullable / default) so existing entries keep compiling; enrich incrementally.
- **`StageBand` is exactly** `early12` (stage 1–2), `stage3`, `stage4`, `stage5`, `dialysis`.
- Dataset additions prioritize foods common in the Philippines; content is general educational guidance to be verified by a renal dietitian.
- `flutter analyze` clean and `flutter test` green is the gate for every task.

---

## File Structure

```
lib/
  models/food.dart              # MODIFY: NutrientLevel; Food gains servingSize + potassium/phosphorus/sodium
  data/food_stage_advice.dart   # CREATE: StageBand, stageBandForProfile, stageAdvice
  data/food_data.dart           # MODIFY: enrich existing foods + add Filipino foods
  screens/food_detail_screen.dart  # MODIFY: serving + nutrient levels + "By CKD stage" section
test/
  data/food_stage_advice_test.dart   # CREATE: band mapping + advice derivation
  data/food_data_test.dart           # MODIFY: keep integrity green with new fields
```

---

### Task 1: Nutrient levels on the model + stage advice

Extend `Food`, add the `StageBand` enum, the profile→band mapper, and the advice deriver, all pure and tested.

**Files:**
- Modify: `lib/models/food.dart`
- Create: `lib/data/food_stage_advice.dart`
- Test: `test/data/food_stage_advice_test.dart`

**Interfaces:**
- Consumes: `Food`, `FoodStatus`, `HealthProfile`, `CkdStage`, `DialysisStatus`.
- Produces:
  - `enum NutrientLevel { low, moderate, high }` with `String get label`.
  - `Food` gains `final String? servingSize; final NutrientLevel? potassium; final NutrientLevel? phosphorus; final NutrientLevel? sodium;` (all optional, defaulting null).
  - `enum StageBand { early12, stage3, stage4, stage5, dialysis }` with `String get label`.
  - `StageBand? stageBandForProfile(HealthProfile p)` — null when no stage set; stage5 + dialysis → `dialysis`.
  - `String stageAdvice(Food food, StageBand band)` — short guidance derived from status + nutrient levels.

- [ ] **Step 1: Add the nutrient fields to Food**

In `lib/models/food.dart`, add the enum after `FoodStatus`'s extension (before the `Food` class):

```dart
enum NutrientLevel { low, moderate, high }

extension NutrientLevelLabel on NutrientLevel {
  String get label => switch (this) {
        NutrientLevel.low => 'Low',
        NutrientLevel.moderate => 'Moderate',
        NutrientLevel.high => 'High',
      };
}
```

Extend the `Food` constructor and fields (add the four optional members):

```dart
  const Food({
    required this.name,
    required this.category,
    required this.status,
    required this.why,
    required this.concerns,
    required this.prep,
    this.goodMethods = const [],
    this.avoidMethods = const [],
    this.servingSize,
    this.potassium,
    this.phosphorus,
    this.sodium,
  });

  final String name;
  final FoodCategory category;
  final FoodStatus status;
  final String why;
  final List<String> concerns;
  final String prep;
  final List<String> goodMethods;
  final List<String> avoidMethods;
  final String? servingSize; // e.g. '1 small apple (~100–150 g)'
  final NutrientLevel? potassium;
  final NutrientLevel? phosphorus;
  final NutrientLevel? sodium;
```

- [ ] **Step 2: Write the failing advice test**

Create `test/data/food_stage_advice_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:ckd_care/data/food_stage_advice.dart';
import 'package:ckd_care/models/food.dart';
import 'package:ckd_care/models/health_profile.dart';

Food food({
  FoodStatus status = FoodStatus.recommended,
  NutrientLevel? potassium,
  NutrientLevel? phosphorus,
  NutrientLevel? sodium,
}) =>
    Food(
      name: 'X',
      category: FoodCategory.fruits,
      status: status,
      why: 'why',
      concerns: const [],
      prep: 'prep',
      potassium: potassium,
      phosphorus: phosphorus,
      sodium: sodium,
    );

void main() {
  test('stageBandForProfile maps stage + dialysis', () {
    expect(stageBandForProfile(const HealthProfile()), isNull);
    expect(stageBandForProfile(const HealthProfile(ckdStage: CkdStage.stage1)),
        StageBand.early12);
    expect(stageBandForProfile(const HealthProfile(ckdStage: CkdStage.stage2)),
        StageBand.early12);
    expect(stageBandForProfile(const HealthProfile(ckdStage: CkdStage.stage3)),
        StageBand.stage3);
    expect(stageBandForProfile(const HealthProfile(ckdStage: CkdStage.stage4)),
        StageBand.stage4);
    expect(stageBandForProfile(const HealthProfile(ckdStage: CkdStage.stage5)),
        StageBand.stage5);
    // Any dialysis status overrides to the dialysis band.
    expect(
      stageBandForProfile(const HealthProfile(
          ckdStage: CkdStage.stage5,
          dialysisStatus: DialysisStatus.hemodialysis)),
      StageBand.dialysis,
    );
  });

  test('stageAdvice: early bands are general; later bands mention labs', () {
    final highK = food(potassium: NutrientLevel.high);
    final early = stageAdvice(highK, StageBand.early12);
    final s4 = stageAdvice(highK, StageBand.stage4);
    expect(early.toLowerCase(), contains('balanced'));
    expect(s4.toLowerCase(), contains('potassium'));
    expect(s4.toLowerCase(), contains('lab'));
    // Dialysis advice always defers to the care team.
    expect(stageAdvice(highK, StageBand.dialysis).toLowerCase(),
        contains('dietitian'));
  });

  test('stageAdvice: an avoid food is discouraged across bands', () {
    final avoid = food(status: FoodStatus.avoid, sodium: NutrientLevel.high);
    for (final b in StageBand.values) {
      expect(stageAdvice(avoid, b).toLowerCase(), contains('limit'));
    }
  });
}
```

- [ ] **Step 3: Run to verify it fails**

Run: `flutter test test/data/food_stage_advice_test.dart`
Expected: FAIL — `food_stage_advice.dart` doesn't exist.

- [ ] **Step 4: Create the stage-advice module**

Create `lib/data/food_stage_advice.dart`:

```dart
import 'package:ckd_care/models/food.dart';
import 'package:ckd_care/models/health_profile.dart';

/// Grouping of CKD stages/dialysis used for dietary guidance bands.
enum StageBand { early12, stage3, stage4, stage5, dialysis }

extension StageBandLabel on StageBand {
  String get label => switch (this) {
        StageBand.early12 => 'Stage 1–2',
        StageBand.stage3 => 'Stage 3',
        StageBand.stage4 => 'Stage 4',
        StageBand.stage5 => 'Stage 5',
        StageBand.dialysis => 'Dialysis',
      };
}

/// The band that applies to a profile — null if no CKD stage is set. Any
/// dialysis status maps to the dialysis band regardless of stage.
StageBand? stageBandForProfile(HealthProfile p) {
  if (p.dialysisStatus != DialysisStatus.none) return StageBand.dialysis;
  return switch (p.ckdStage) {
    null => null,
    CkdStage.stage1 || CkdStage.stage2 => StageBand.early12,
    CkdStage.stage3 => StageBand.stage3,
    CkdStage.stage4 => StageBand.stage4,
    CkdStage.stage5 => StageBand.stage5,
  };
}

/// Short, non-alarming guidance for [food] at [band], derived from the food's
/// own nutrient profile — never a blanket "restrict because of your stage".
/// Every band ultimately defers to the user's labs and care team.
String stageAdvice(Food food, StageBand band) {
  if (food.status == FoodStatus.avoid) {
    return 'Best to limit or avoid — ${_lowerWhy(food)}. Ask your dietitian '
        'about alternatives.';
  }

  final flags = <String>[
    if (food.potassium == NutrientLevel.high) 'potassium',
    if (food.phosphorus == NutrientLevel.high) 'phosphorus',
    if (food.sodium == NutrientLevel.high) 'sodium',
  ];

  switch (band) {
    case StageBand.early12:
      return flags.isEmpty
          ? 'Usually fits a balanced, kidney-protective diet. Keep sodium moderate.'
          : 'Usually fine within a balanced diet; keep sodium moderate and '
              'portions sensible.';
    case StageBand.stage3:
      return flags.isEmpty
          ? 'Generally suitable. Watch overall sodium and portion sizes.'
          : 'Watch ${_join(flags)} and portion size — check against your recent '
              'lab results.';
    case StageBand.stage4:
    case StageBand.stage5:
      return flags.isEmpty
          ? 'Often suitable, but keep portions moderate. Confirm with your recent '
              'lab results and dietitian.'
          : 'May need limiting if your ${_join(flags)} ${flags.length == 1 ? 'is' : 'are'} '
              'elevated — your lab results and dietitian decide.';
    case StageBand.dialysis:
      return flags.contains('potassium') || flags.contains('phosphorus')
          ? 'Portion and frequency depend on your labs and dialysis plan — '
              'follow your nephrologist or renal dietitian.'
          : 'Fit into your individualized plan — follow your renal dietitian, '
              'as needs differ on dialysis.';
  }
}

String _join(List<String> items) {
  if (items.length == 1) return items.first;
  if (items.length == 2) return '${items[0]} and ${items[1]}';
  return '${items.sublist(0, items.length - 1).join(', ')}, and ${items.last}';
}

String _lowerWhy(Food food) {
  final w = food.why.trim();
  if (w.isEmpty) return 'it may be high in sodium, potassium, or phosphorus';
  final lower = w[0].toLowerCase() + w.substring(1);
  return lower.endsWith('.') ? lower.substring(0, lower.length - 1) : lower;
}
```

- [ ] **Step 5: Run to verify it passes**

Run: `flutter test test/data/food_stage_advice_test.dart`
Expected: PASS (3 tests).

- [ ] **Step 6: Analyze + full suite**

Run: `flutter analyze` → "No issues found!"
Run: `flutter test` → all pass (existing food tests unaffected — new Food fields are optional).

- [ ] **Step 7: Commit**

```bash
git add lib/models/food.dart lib/data/food_stage_advice.dart test/data/food_stage_advice_test.dart
git commit -m "feat: nutrient levels on Food + CKD stage-band advice"
```

---

### Task 2: Enrich the dataset (nutrient levels, serving sizes, Filipino foods)

Add serving size + K/P/Na levels to the existing foods and append common Filipino foods.

**Files:**
- Modify: `lib/data/food_data.dart`
- Test: `test/data/food_data_test.dart`

**Interfaces:**
- Consumes: `NutrientLevel`.
- Produces: enriched `kFoods` (existing entries gain `servingSize`/`potassium`/`phosphorus`/`sodium`; new Filipino entries added). No new exported symbols.

- [ ] **Step 1: Update the integrity test to require enrichment on all entries**

In `test/data/food_data_test.dart`, add inside `main()`:

```dart
  test('every food has serving size and nutrient levels', () {
    for (final f in kFoods) {
      expect(f.servingSize, isNotNull, reason: '${f.name} servingSize');
      expect(f.potassium, isNotNull, reason: '${f.name} potassium');
      expect(f.phosphorus, isNotNull, reason: '${f.name} phosphorus');
      expect(f.sodium, isNotNull, reason: '${f.name} sodium');
    }
  });

  test('includes Filipino staples', () {
    final names = kFoods.map((f) => f.name.toLowerCase()).join(' | ');
    expect(names, contains('malunggay'));
    expect(names, contains('tinola'));
    expect(names, contains('fish sauce'));
  });
```

- [ ] **Step 2: Run to verify it fails**

Run: `flutter test test/data/food_data_test.dart`
Expected: FAIL — existing foods lack serving/nutrient levels; Filipino foods absent.

- [ ] **Step 3: Enrich every existing food entry**

In `lib/data/food_data.dart`, add `servingSize`, `potassium`, `phosphorus`, `sodium` to each existing `Food(...)`. Apply these values (append the four named args to each entry, keeping existing fields):

- Apple → `servingSize: '1 small apple (~100–150 g)', potassium: NutrientLevel.low, phosphorus: NutrientLevel.low, sodium: NutrientLevel.low`
- Blueberries → `servingSize: '1/2 cup (~75 g)', potassium: NutrientLevel.low, phosphorus: NutrientLevel.low, sodium: NutrientLevel.low`
- Banana → `servingSize: '1/2 small banana', potassium: NutrientLevel.high, phosphorus: NutrientLevel.low, sodium: NutrientLevel.low`
- Orange & orange juice → `servingSize: '1 small orange', potassium: NutrientLevel.high, phosphorus: NutrientLevel.low, sodium: NutrientLevel.low`
- Red bell pepper → `servingSize: '1/2 cup sliced (~75 g)', potassium: NutrientLevel.low, phosphorus: NutrientLevel.low, sodium: NutrientLevel.low`
- Cabbage → `servingSize: '1/2 cup cooked (~75 g)', potassium: NutrientLevel.low, phosphorus: NutrientLevel.low, sodium: NutrientLevel.low`
- Cauliflower → `servingSize: '1/2 cup (~75 g)', potassium: NutrientLevel.low, phosphorus: NutrientLevel.low, sodium: NutrientLevel.low`
- Potato → `servingSize: '1/2 cup after leaching (~75 g)', potassium: NutrientLevel.high, phosphorus: NutrientLevel.moderate, sodium: NutrientLevel.low`
- Spinach → `servingSize: '1/2 cup raw (~30 g)', potassium: NutrientLevel.high, phosphorus: NutrientLevel.moderate, sodium: NutrientLevel.low`
- Skinless chicken breast → `servingSize: '85 g cooked (palm-sized)', potassium: NutrientLevel.moderate, phosphorus: NutrientLevel.moderate, sodium: NutrientLevel.low`
- Egg whites → `servingSize: '2 egg whites', potassium: NutrientLevel.low, phosphorus: NutrientLevel.low, sodium: NutrientLevel.low`
- Salmon → `servingSize: '85 g cooked', potassium: NutrientLevel.moderate, phosphorus: NutrientLevel.high, sodium: NutrientLevel.low`
- Processed meats (bacon, sausage, ham) → `servingSize: 'Avoid — no recommended portion', potassium: NutrientLevel.moderate, phosphorus: NutrientLevel.high, sodium: NutrientLevel.high`
- White rice → `servingSize: '1/2 cup cooked', potassium: NutrientLevel.low, phosphorus: NutrientLevel.low, sodium: NutrientLevel.low`
- White bread → `servingSize: '1 slice', potassium: NutrientLevel.low, phosphorus: NutrientLevel.low, sodium: NutrientLevel.moderate`
- Whole-wheat bread → `servingSize: '1 slice', potassium: NutrientLevel.moderate, phosphorus: NutrientLevel.moderate, sodium: NutrientLevel.moderate`
- Water → `servingSize: 'Within your daily fluid limit', potassium: NutrientLevel.low, phosphorus: NutrientLevel.low, sodium: NutrientLevel.low`
- Dark colas → `servingSize: 'Avoid — choose water instead', potassium: NutrientLevel.low, phosphorus: NutrientLevel.high, sodium: NutrientLevel.low`
- Unsalted popcorn → `servingSize: '2–3 cups air-popped', potassium: NutrientLevel.low, phosphorus: NutrientLevel.low, sodium: NutrientLevel.low`
- Potato chips & salted snacks → `servingSize: 'Avoid — swap for unsalted popcorn', potassium: NutrientLevel.high, phosphorus: NutrientLevel.moderate, sodium: NutrientLevel.high`
- Salt substitute (potassium chloride) → `servingSize: 'Avoid entirely', potassium: NutrientLevel.high, phosphorus: NutrientLevel.low, sodium: NutrientLevel.low`
- Fresh herbs & spices → `servingSize: 'Season to taste', potassium: NutrientLevel.low, phosphorus: NutrientLevel.low, sodium: NutrientLevel.low`

- [ ] **Step 4: Append Filipino foods**

Add these entries to the end of the `kFoods` list (before the closing `];`):

```dart
  // --- Filipino vegetables ---
  Food(
    name: 'Malunggay (moringa leaves)',
    category: FoodCategory.vegetables,
    status: FoodStatus.limit,
    why: 'Nutritious but high in potassium, so watch the portion.',
    concerns: ['High potassium'],
    prep: 'Use a small amount in soups; avoid large handfuls.',
    goodMethods: ['Added to soup (small amount)'],
    avoidMethods: ['Large servings'],
    servingSize: 'Small handful in soup',
    potassium: NutrientLevel.high,
    phosphorus: NutrientLevel.moderate,
    sodium: NutrientLevel.low,
  ),
  Food(
    name: 'Squash (kalabasa)',
    category: FoodCategory.vegetables,
    status: FoodStatus.limit,
    why: 'Moderately high in potassium; keep portions modest.',
    concerns: ['Potassium'],
    prep: 'Small portions steamed or in soup.',
    goodMethods: ['Steamed', 'In soup'],
    avoidMethods: ['Large servings'],
    servingSize: '1/2 cup cooked',
    potassium: NutrientLevel.moderate,
    phosphorus: NutrientLevel.low,
    sodium: NutrientLevel.low,
  ),
  Food(
    name: 'Eggplant (talong)',
    category: FoodCategory.vegetables,
    status: FoodStatus.recommended,
    why: 'Lower in potassium and versatile.',
    concerns: ['Low potassium'],
    prep: 'Grill or steam; avoid soaking in salty sauces.',
    goodMethods: ['Grilled', 'Steamed'],
    avoidMethods: ['Fried', 'Soaked in soy sauce'],
    servingSize: '1/2 cup cooked',
    potassium: NutrientLevel.low,
    phosphorus: NutrientLevel.low,
    sodium: NutrientLevel.low,
  ),

  // --- Filipino protein / dishes ---
  Food(
    name: 'Bangus (milkfish), grilled',
    category: FoodCategory.protein,
    status: FoodStatus.recommended,
    why: 'Fresh fish is good protein; grilling avoids added sodium.',
    concerns: ['Protein — watch portion size'],
    prep: 'Grill or steam with garlic and ginger; no salty rubs.',
    goodMethods: ['Grilled', 'Steamed'],
    avoidMethods: ['Fried', 'Marinated in fish sauce'],
    servingSize: '85 g cooked',
    potassium: NutrientLevel.moderate,
    phosphorus: NutrientLevel.moderate,
    sodium: NutrientLevel.low,
  ),
  Food(
    name: 'Tofu (tokwa)',
    category: FoodCategory.protein,
    status: FoodStatus.limit,
    why: 'Plant protein, but can be high in phosphorus depending on type.',
    concerns: ['Phosphorus', 'Protein — watch portion size'],
    prep: 'Pan-fry lightly or add to soup; skip salty sauces.',
    goodMethods: ['Steamed', 'Lightly pan-fried'],
    avoidMethods: ['Deep-fried', 'Soy-sauce heavy dishes'],
    servingSize: '1/2 cup (~85 g)',
    potassium: NutrientLevel.moderate,
    phosphorus: NutrientLevel.high,
    sodium: NutrientLevel.low,
  ),
  Food(
    name: 'Chicken tinola',
    category: FoodCategory.protein,
    status: FoodStatus.limit,
    why: 'A lighter dish; sodium and vegetable choices decide how kidney-friendly it is.',
    concerns: ['Sodium (from seasoning)'],
    prep: 'Season with ginger and garlic instead of broth cubes; go easy on '
        'malunggay and use sayote or cabbage.',
    goodMethods: ['Simmered with fresh aromatics'],
    avoidMethods: ['Bouillon/broth cubes', 'Lots of malunggay'],
    servingSize: '1 bowl (small piece of chicken)',
    potassium: NutrientLevel.moderate,
    phosphorus: NutrientLevel.moderate,
    sodium: NutrientLevel.moderate,
  ),
  Food(
    name: 'Sinigang',
    category: FoodCategory.protein,
    status: FoodStatus.limit,
    why: 'Sour soup is fine in moderation; watch sodium and high-potassium '
        'vegetables and broth.',
    concerns: ['Sodium', 'Potassium (broth/vegetables)'],
    prep: 'Use fresh souring (tamarind) not instant mix; limit gabi/taro and '
        'go easy on the broth.',
    goodMethods: ['Fresh tamarind souring'],
    avoidMethods: ['Instant sinigang mix', 'Drinking large amounts of broth'],
    servingSize: '1 small bowl',
    potassium: NutrientLevel.high,
    phosphorus: NutrientLevel.moderate,
    sodium: NutrientLevel.high,
  ),

  // --- Filipino condiments ---
  Food(
    name: 'Soy sauce (toyo)',
    category: FoodCategory.other,
    status: FoodStatus.avoid,
    why: 'Very high in sodium.',
    concerns: ['High sodium'],
    prep: 'Use sparingly; try a low-sodium version, calamansi, or garlic.',
    goodMethods: [],
    avoidMethods: ['Generous pouring', 'Dipping sauces'],
    servingSize: 'A few drops if any',
    potassium: NutrientLevel.low,
    phosphorus: NutrientLevel.low,
    sodium: NutrientLevel.high,
  ),
  Food(
    name: 'Fish sauce (patis)',
    category: FoodCategory.other,
    status: FoodStatus.avoid,
    why: 'Extremely high in sodium.',
    concerns: ['High sodium'],
    prep: 'Replace with calamansi, herbs, or garlic for flavor.',
    goodMethods: [],
    avoidMethods: ['Adding to dishes', 'Dipping sauces'],
    servingSize: 'Avoid',
    potassium: NutrientLevel.low,
    phosphorus: NutrientLevel.low,
    sodium: NutrientLevel.high,
  ),
  Food(
    name: 'Bagoong (fermented shrimp/fish paste)',
    category: FoodCategory.other,
    status: FoodStatus.avoid,
    why: 'Very high in sodium.',
    concerns: ['High sodium'],
    prep: 'Avoid; season with fresh aromatics instead.',
    goodMethods: [],
    avoidMethods: ['Any regular use'],
    servingSize: 'Avoid',
    potassium: NutrientLevel.low,
    phosphorus: NutrientLevel.moderate,
    sodium: NutrientLevel.high,
  ),
  Food(
    name: 'Calamansi',
    category: FoodCategory.other,
    status: FoodStatus.recommended,
    why: 'Adds flavor without sodium — a good salt alternative.',
    concerns: ['Low sodium'],
    prep: 'Squeeze over dishes in place of soy or fish sauce.',
    goodMethods: ['Fresh, as seasoning'],
    avoidMethods: ['Sweetened bottled versions with additives'],
    servingSize: 'To taste',
    potassium: NutrientLevel.low,
    phosphorus: NutrientLevel.low,
    sodium: NutrientLevel.low,
  ),

  // --- Filipino grains ---
  Food(
    name: 'Lugaw (rice porridge)',
    category: FoodCategory.grains,
    status: FoodStatus.recommended,
    why: 'Plain rice porridge is gentle and low in potassium and phosphorus.',
    concerns: ['Sodium (from toppings)'],
    prep: 'Flavor with ginger and garlic; go easy on salt, patis, and toppings.',
    goodMethods: ['Simmered plain with ginger'],
    avoidMethods: ['Heavy patis/soy toppings', 'Salted egg in large amounts'],
    servingSize: '1 bowl',
    potassium: NutrientLevel.low,
    phosphorus: NutrientLevel.low,
    sodium: NutrientLevel.low,
  ),
```

- [ ] **Step 5: Run to verify it passes**

Run: `flutter test test/data/food_data_test.dart`
Expected: PASS (all integrity + Filipino-staples tests).

- [ ] **Step 6: Analyze + full suite**

Run: `flutter analyze` → "No issues found!"
Run: `flutter test` → all pass.

- [ ] **Step 7: Commit**

```bash
git add lib/data/food_data.dart test/data/food_data_test.dart
git commit -m "feat: enrich food data with nutrient levels, servings, and Filipino foods"
```

---

### Task 3: Show serving, nutrient levels, and stage advice on the detail page

Render the new data: serving size, K/P/Na level chips, and a "By CKD stage" section listing advice for every band.

**Files:**
- Modify: `lib/screens/food_detail_screen.dart`
- Test: none new (presentational; data + helpers covered by Tasks 1–2). Manual verification below.

**Interfaces:**
- Consumes: `Food` (new fields), `NutrientLevel.label`, `StageBand`, `stageAdvice`.

- [ ] **Step 1: Add serving, nutrient levels, and the stage section**

In `lib/screens/food_detail_screen.dart`, add the import:

```dart
import 'package:ckd_care/data/food_stage_advice.dart';
```

The detail screen already builds a `ListView` with a `section(title, child)` helper. Insert these blocks after the existing "Why" section and before the "How to prepare" section (adapt to the file's actual structure — use the existing `section` helper and `text`/`cs` locals):

```dart
          if (food.servingSize != null)
            section('Suggested serving', Text(food.servingSize!, style: text.bodyLarge)),
          if (food.potassium != null ||
              food.phosphorus != null ||
              food.sodium != null)
            section(
              'Nutrient levels',
              Wrap(spacing: 8, runSpacing: 8, children: [
                if (food.potassium != null)
                  _NutrientChip(label: 'Potassium', level: food.potassium!),
                if (food.phosphorus != null)
                  _NutrientChip(label: 'Phosphorus', level: food.phosphorus!),
                if (food.sodium != null)
                  _NutrientChip(label: 'Sodium', level: food.sodium!),
              ]),
            ),
          section(
            'By CKD stage',
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final band in StageBand.values)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(band.label,
                            style: text.labelMedium
                                ?.copyWith(fontWeight: FontWeight.w800)),
                        const SizedBox(height: 2),
                        Text(stageAdvice(food, band), style: text.bodyMedium),
                      ],
                    ),
                  ),
              ],
            ),
          ),
```

Add the `_NutrientChip` widget at the bottom of the file (after `_StatusBadge`):

```dart
class _NutrientChip extends StatelessWidget {
  const _NutrientChip({required this.label, required this.level});
  final String label;
  final NutrientLevel level;

  @override
  Widget build(BuildContext context) {
    final color = switch (level) {
      NutrientLevel.low => AppColors.good,
      NutrientLevel.moderate => AppColors.warn,
      NutrientLevel.high => AppColors.over,
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text('$label: ${level.label}',
          style: TextStyle(
              fontFamily: 'Nunito',
              fontSize: 12.5,
              fontWeight: FontWeight.w800,
              color: color)),
    );
  }
}
```

Ensure the file imports `AppColors` (`import 'package:ckd_care/theme/app_theme.dart';`) — add it if the analyzer reports `AppColors` undefined.

- [ ] **Step 2: Analyze + full suite**

Run: `flutter analyze` → "No issues found!" (fix any structural mismatch with the existing `section`/`text`/`cs` helpers).
Run: `flutter test` → all pass.

- [ ] **Step 3: Commit**

```bash
git add lib/screens/food_detail_screen.dart
git commit -m "feat: show serving, nutrient levels, and by-stage advice on food detail"
```

---

## Manual verification checklist (device/emulator)

Run after Task 3 via `flutter run -d Pixel_4a_API_34`:

1. Food list now includes Filipino items (Malunggay, Squash, Bangus, Tofu, Chicken tinola, Sinigang, Soy sauce, Fish sauce, Bagoong, Calamansi, Lugaw, Eggplant).
2. Open **Banana** → shows a suggested serving, nutrient-level chips (Potassium: High in brick, others low in green), and a **By CKD stage** section with distinct advice per band (Stage 1–2 general; Stage 4/5 mention potassium + labs; Dialysis defers to dietitian).
3. Open **Soy sauce** → "By CKD stage" advice discourages it across all bands (avoid food).
4. Open a plain low-risk food (**White rice**) → early-stage advice is general; later bands still frame around labs/dietitian without alarm.
5. Both light and dark themes render the chips and sections correctly.

---

## Self-Review

**Spec coverage (sub-plan C scope):**
- Per-food serving size + potassium/phosphorus/sodium → Food fields + dataset enrichment + detail display. ✓ (qualitative levels, per the safety rationale in Global Constraints — a deliberate deviation from exact numbers.)
- CKD-stage-specific guidance derived from nutritional properties, not blanket rules → `stageAdvice` + `StageBand`. ✓
- Localized Filipino foods (vegetables, protein, dishes, condiments, grains) → dataset additions. ✓
- Prep/cooking already present (sub-plan for the base Food Section); kidney-friendly methods + salt alternatives (calamansi, herbs) reinforced in new entries. ✓
- Not-blanket-by-stage principle; defer to labs/dietitian → advice wording for later bands. ✓

**Placeholder scan:** No TBD/TODO; all code + data inline.

**Type consistency:** `NutrientLevel`/`.label`, `Food.servingSize/potassium/phosphorus/sodium`, `StageBand`/`.label`, `stageBandForProfile(HealthProfile)`, `stageAdvice(Food, StageBand)`, `_NutrientChip` used consistently across tasks.

**Deferred (not gaps):** using the *user's* profile to highlight their own band + show stage-based clinician alerts is sub-plan E (this plan shows all bands generally); exact numeric nutrient values and a fully exhaustive food list are intentionally out of scope (qualitative + representative, extensible). Meal-by-meal "kidney-friendlier version" tips beyond the included dishes, and the condiments alternatives table, can grow in the same dataset.
