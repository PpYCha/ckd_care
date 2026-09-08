# Food Section Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a "Food" tab: a categorized, filterable reference of kidney-friendly and restricted foods for CKD, each with why, nutrient concerns, and simple preparation/cooking guidance — framed as general information, not medical advice.

**Architecture:** Static reference content — no database, no schema, no network. Foods are a curated `const List<Food>` in a data file. Two read-only screens (list grouped by category with a status filter; a detail screen) plus a 5th bottom-nav tab. Pure grouping/filter helpers are unit-tested; a data-integrity test guards the dataset.

**Tech Stack:** Flutter, `provider` (not needed here — screens read the const list directly), existing `AppColors`/theme.

## Global Constraints

- **Static content only.** No DB, no assets loading, no new dependencies. The dataset is a `const` list in `lib/data/food_data.dart`.
- **Not medical advice.** Every entry point shows a disclaimer. Copy, used verbatim: *"General guidance, not medical advice. Your needs depend on your kidney function, dialysis status, and lab results (potassium, phosphorus) — always follow your care team's plan."*
- **Status vocabulary is exactly three values:** Recommended, Limit, Avoid. Colors: Recommended → `AppColors.good`, Limit → `AppColors.warn`, Avoid → `AppColors.over`.
- **Categories (7):** Fruits, Vegetables, Meat & protein, Grains & carbs, Drinks, Snacks, Other.
- Reads from the theme's `ColorScheme` for neutrals (surface/outlineVariant/onSurface/onSurfaceVariant) so it works in light and dark, consistent with the rest of the app.
- `flutter analyze` clean and `flutter test` green is the gate for every task.

---

## File Structure

```
lib/
  models/food.dart          # CREATE: Food + FoodCategory + FoodStatus + label/color helpers
  data/food_data.dart       # CREATE: const kFoods list; groupByCategory/filterFoods helpers
  screens/food_screen.dart  # CREATE: list — disclaimer, status filter chips, grouped by category
  screens/food_detail_screen.dart # CREATE: one food's full info
  main.dart                 # MODIFY: add the 5th "Food" nav tab
test/
  data/food_data_test.dart  # CREATE: data-integrity + filter/group helper tests
```

---

### Task 1: Food model + curated dataset + helpers

The model, the curated `const` list, and the pure grouping/filter helpers, with tests that guard both content integrity and the helpers.

**Files:**
- Create: `lib/models/food.dart`, `lib/data/food_data.dart`
- Test: `test/data/food_data_test.dart`

**Interfaces:**
- Produces:
  - `enum FoodCategory { fruits, vegetables, protein, grains, drinks, snacks, other }` with `String get label`.
  - `enum FoodStatus { recommended, limit, avoid }` with `String get label`.
  - `class Food` — `final String name; final FoodCategory category; final FoodStatus status; final String why; final List<String> concerns; final String prep; final List<String> goodMethods; final List<String> avoidMethods;` (all via a `const` constructor).
  - `const List<Food> kFoods` (in `food_data.dart`).
  - `List<Food> filterFoods(List<Food> all, FoodStatus? status)` — all when status is null.
  - `Map<FoodCategory, List<Food>> groupByCategory(List<Food> foods)` — category order = enum order; only non-empty groups included.

- [ ] **Step 1: Write the failing tests**

Create `test/data/food_data_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:ckd_care/data/food_data.dart';
import 'package:ckd_care/models/food.dart';

void main() {
  test('dataset is well-formed', () {
    expect(kFoods.length, greaterThanOrEqualTo(18));
    for (final f in kFoods) {
      expect(f.name.trim(), isNotEmpty, reason: 'name');
      expect(f.why.trim(), isNotEmpty, reason: '${f.name} why');
      expect(f.prep.trim(), isNotEmpty, reason: '${f.name} prep');
      expect(f.concerns, isNotEmpty, reason: '${f.name} concerns');
      // Recommended/Limit foods say how to cook them; Avoid foods list what to avoid.
      if (f.status == FoodStatus.avoid) {
        expect(f.avoidMethods, isNotEmpty, reason: '${f.name} avoidMethods');
      } else {
        expect(f.goodMethods, isNotEmpty, reason: '${f.name} goodMethods');
      }
    }
  });

  test('covers every category and every status', () {
    expect(kFoods.map((f) => f.category).toSet(), FoodCategory.values.toSet());
    expect(kFoods.map((f) => f.status).toSet(), FoodStatus.values.toSet());
  });

  test('filterFoods filters by status; null returns all', () {
    expect(filterFoods(kFoods, null).length, kFoods.length);
    final rec = filterFoods(kFoods, FoodStatus.recommended);
    expect(rec, isNotEmpty);
    expect(rec.every((f) => f.status == FoodStatus.recommended), isTrue);
  });

  test('groupByCategory keeps enum order and drops empty groups', () {
    final subset = [
      kFoods.firstWhere((f) => f.category == FoodCategory.drinks),
      kFoods.firstWhere((f) => f.category == FoodCategory.fruits),
    ];
    final grouped = groupByCategory(subset);
    expect(grouped.keys.toList(), [FoodCategory.fruits, FoodCategory.drinks]);
    expect(grouped.values.every((l) => l.isNotEmpty), isTrue);
  });
}
```

- [ ] **Step 2: Run to verify it fails**

Run: `flutter test test/data/food_data_test.dart`
Expected: FAIL — `food.dart` / `food_data.dart` don't exist.

- [ ] **Step 3: Create the model**

Create `lib/models/food.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:ckd_care/theme/app_theme.dart';

enum FoodCategory { fruits, vegetables, protein, grains, drinks, snacks, other }

extension FoodCategoryLabel on FoodCategory {
  String get label => switch (this) {
        FoodCategory.fruits => 'Fruits',
        FoodCategory.vegetables => 'Vegetables',
        FoodCategory.protein => 'Meat & protein',
        FoodCategory.grains => 'Grains & carbs',
        FoodCategory.drinks => 'Drinks',
        FoodCategory.snacks => 'Snacks',
        FoodCategory.other => 'Other',
      };
}

enum FoodStatus { recommended, limit, avoid }

extension FoodStatusLabel on FoodStatus {
  String get label => switch (this) {
        FoodStatus.recommended => 'Recommended',
        FoodStatus.limit => 'Limit',
        FoodStatus.avoid => 'Avoid',
      };

  Color get color => switch (this) {
        FoodStatus.recommended => AppColors.good,
        FoodStatus.limit => AppColors.warn,
        FoodStatus.avoid => AppColors.over,
      };
}

/// One reference food entry. Static content — see [kFoods].
class Food {
  const Food({
    required this.name,
    required this.category,
    required this.status,
    required this.why,
    required this.concerns,
    required this.prep,
    this.goodMethods = const [],
    this.avoidMethods = const [],
  });

  final String name;
  final FoodCategory category;
  final FoodStatus status;
  final String why;
  final List<String> concerns; // e.g. ['High potassium']
  final String prep; // one-line preparation guidance
  final List<String> goodMethods; // recommended cooking methods
  final List<String> avoidMethods; // methods/forms to avoid
}
```

- [ ] **Step 4: Create the dataset + helpers**

Create `lib/data/food_data.dart`:

```dart
import 'package:ckd_care/models/food.dart';

/// General CKD-oriented food guidance. Not medical advice — individual needs
/// vary with kidney function, dialysis status, and lab values.
const List<Food> kFoods = [
  // --- Fruits ---
  Food(
    name: 'Apple',
    category: FoodCategory.fruits,
    status: FoodStatus.recommended,
    why: 'Low in potassium and a good source of fiber.',
    concerns: ['Low potassium'],
    prep: 'Wash well; eat raw with the skin, or bake for a warm snack.',
    goodMethods: ['Raw', 'Baked'],
    avoidMethods: ['Battered and deep-fried'],
  ),
  Food(
    name: 'Blueberries',
    category: FoodCategory.fruits,
    status: FoodStatus.recommended,
    why: 'Low in potassium and rich in antioxidants.',
    concerns: ['Low potassium'],
    prep: 'Rinse; eat fresh or add to cereal.',
    goodMethods: ['Raw', 'Baked'],
    avoidMethods: ['Canned in heavy syrup'],
  ),
  Food(
    name: 'Banana',
    category: FoodCategory.fruits,
    status: FoodStatus.limit,
    why: 'High in potassium, which can build up when kidneys are weak.',
    concerns: ['High potassium'],
    prep: 'Keep portions small and pair with low-potassium foods.',
    goodMethods: ['Raw (small portion)'],
    avoidMethods: ['Large servings'],
  ),
  Food(
    name: 'Orange & orange juice',
    category: FoodCategory.fruits,
    status: FoodStatus.limit,
    why: 'High in potassium; juice concentrates it further.',
    concerns: ['High potassium'],
    prep: 'Prefer a small whole fruit over juice.',
    goodMethods: ['Small whole fruit'],
    avoidMethods: ['Juice', 'Large servings'],
  ),

  // --- Vegetables ---
  Food(
    name: 'Red bell pepper',
    category: FoodCategory.vegetables,
    status: FoodStatus.recommended,
    why: 'Low in potassium and high in vitamin C.',
    concerns: ['Low potassium'],
    prep: 'Rinse; eat raw in salads or roast.',
    goodMethods: ['Raw', 'Roasted', 'Grilled'],
    avoidMethods: ['Salted or pickled'],
  ),
  Food(
    name: 'Cabbage',
    category: FoodCategory.vegetables,
    status: FoodStatus.recommended,
    why: 'Low in potassium and versatile.',
    concerns: ['Low potassium'],
    prep: 'Shred for slaw or lightly steam.',
    goodMethods: ['Steamed', 'Raw', 'Stir-fried (little oil)'],
    avoidMethods: ['Salt-heavy pickling'],
  ),
  Food(
    name: 'Cauliflower',
    category: FoodCategory.vegetables,
    status: FoodStatus.recommended,
    why: 'Low in potassium and a good potato substitute.',
    concerns: ['Low potassium'],
    prep: 'Steam or roast; mash as a potato swap.',
    goodMethods: ['Steamed', 'Roasted'],
    avoidMethods: ['Cream or cheese sauces'],
  ),
  Food(
    name: 'Potato',
    category: FoodCategory.vegetables,
    status: FoodStatus.limit,
    why: 'High in potassium, but soaking and double-boiling lowers it.',
    concerns: ['High potassium'],
    prep: 'Peel, dice, soak in water 2+ hours, then boil in fresh water (leaching).',
    goodMethods: ['Boiled after leaching'],
    avoidMethods: ['Baked whole', 'Fried', 'Chips'],
  ),
  Food(
    name: 'Spinach',
    category: FoodCategory.vegetables,
    status: FoodStatus.limit,
    why: 'Potassium concentrates when it is cooked down.',
    concerns: ['High potassium'],
    prep: 'Prefer small raw amounts; avoid large cooked portions.',
    goodMethods: ['Raw (small portion)'],
    avoidMethods: ['Large cooked servings'],
  ),

  // --- Meat & protein ---
  Food(
    name: 'Skinless chicken breast',
    category: FoodCategory.protein,
    status: FoodStatus.recommended,
    why: 'Lean, high-quality protein with less phosphorus than processed meat.',
    concerns: ['Protein — watch portion size'],
    prep: 'Trim fat; grill, bake, or poach without salty marinades.',
    goodMethods: ['Grilled', 'Baked', 'Poached'],
    avoidMethods: ['Breaded and fried', 'Salty brines'],
  ),
  Food(
    name: 'Egg whites',
    category: FoodCategory.protein,
    status: FoodStatus.recommended,
    why: 'High-quality protein that is low in phosphorus.',
    concerns: ['Low phosphorus'],
    prep: 'Use the whites; scramble or boil without added salt.',
    goodMethods: ['Boiled', 'Scrambled (little oil)'],
    avoidMethods: ['Added salt or cheese'],
  ),
  Food(
    name: 'Salmon',
    category: FoodCategory.protein,
    status: FoodStatus.limit,
    why: 'Heart-healthy omega-3s, but watch protein and phosphorus portions.',
    concerns: ['Phosphorus', 'Protein — watch portion size'],
    prep: 'Bake or grill a small fillet; skip salty rubs.',
    goodMethods: ['Baked', 'Grilled'],
    avoidMethods: ['Smoked or cured (high sodium)'],
  ),
  Food(
    name: 'Processed meats (bacon, sausage, ham)',
    category: FoodCategory.protein,
    status: FoodStatus.avoid,
    why: 'Very high in sodium and phosphate additives.',
    concerns: ['High sodium', 'Phosphate additives'],
    prep: 'Replace with fresh lean meat, poultry, or egg whites.',
    goodMethods: [],
    avoidMethods: ['All cured or processed forms'],
  ),

  // --- Grains & carbs ---
  Food(
    name: 'White rice',
    category: FoodCategory.grains,
    status: FoodStatus.recommended,
    why: 'Low in potassium and phosphorus.',
    concerns: ['Low phosphorus'],
    prep: 'Rinse; boil in plain water without salt.',
    goodMethods: ['Boiled', 'Steamed'],
    avoidMethods: ['Cooked in salty broth'],
  ),
  Food(
    name: 'White bread',
    category: FoodCategory.grains,
    status: FoodStatus.recommended,
    why: 'Usually lower in phosphorus and potassium than whole-grain bread.',
    concerns: ['Low phosphorus'],
    prep: 'Choose plain white; check labels for phosphate additives.',
    goodMethods: ['As-is', 'Toasted'],
    avoidMethods: ['Whole-grain if phosphorus is restricted'],
  ),
  Food(
    name: 'Whole-wheat bread',
    category: FoodCategory.grains,
    status: FoodStatus.limit,
    why: 'Higher in phosphorus and potassium than white bread.',
    concerns: ['Phosphorus', 'Potassium'],
    prep: 'Limit portions if your phosphorus is restricted.',
    goodMethods: ['Small portions'],
    avoidMethods: ['Large servings'],
  ),

  // --- Drinks ---
  Food(
    name: 'Water',
    category: FoodCategory.drinks,
    status: FoodStatus.recommended,
    why: 'The best drink — but stay within your daily fluid limit.',
    concerns: ['Counts toward your fluid limit'],
    prep: 'Sip through the day; track it with the Fluid tab.',
    goodMethods: ['Plain'],
    avoidMethods: ['Going over your fluid limit'],
  ),
  Food(
    name: 'Dark colas',
    category: FoodCategory.drinks,
    status: FoodStatus.avoid,
    why: 'Contain phosphoric acid — a source of added phosphorus.',
    concerns: ['Phosphorus additives'],
    prep: 'Swap for water or a clear, low-phosphorus drink.',
    goodMethods: [],
    avoidMethods: ['Dark/cola sodas'],
  ),

  // --- Snacks ---
  Food(
    name: 'Unsalted popcorn',
    category: FoodCategory.snacks,
    status: FoodStatus.recommended,
    why: 'A low-sodium whole-grain snack.',
    concerns: ['Low sodium'],
    prep: 'Air-pop; skip the salt and butter.',
    goodMethods: ['Air-popped'],
    avoidMethods: ['Microwave, salted, or buttered'],
  ),
  Food(
    name: 'Potato chips & salted snacks',
    category: FoodCategory.snacks,
    status: FoodStatus.avoid,
    why: 'High in both sodium and potassium.',
    concerns: ['High sodium', 'High potassium'],
    prep: 'Swap for unsalted popcorn or plain rice cakes.',
    goodMethods: [],
    avoidMethods: ['Salted chips', 'Salted crackers'],
  ),

  // --- Other ---
  Food(
    name: 'Salt substitute (potassium chloride)',
    category: FoodCategory.other,
    status: FoodStatus.avoid,
    why: 'Replaces sodium with potassium, which is dangerous when kidneys are weak.',
    concerns: ['Very high potassium'],
    prep: 'Flavor with herbs, spices, lemon, or garlic instead.',
    goodMethods: [],
    avoidMethods: ['Any potassium-based salt substitute'],
  ),
  Food(
    name: 'Fresh herbs & spices',
    category: FoodCategory.other,
    status: FoodStatus.recommended,
    why: 'Add flavor without sodium or potassium concerns.',
    concerns: ['Low sodium'],
    prep: 'Use fresh or dried herbs, garlic, and lemon in place of salt.',
    goodMethods: ['Any'],
    avoidMethods: ['Seasoning blends with added salt'],
  ),
];

/// All foods when [status] is null, otherwise only those with that status.
List<Food> filterFoods(List<Food> all, FoodStatus? status) =>
    status == null ? all : all.where((f) => f.status == status).toList();

/// Groups foods by category in enum order, omitting empty categories.
Map<FoodCategory, List<Food>> groupByCategory(List<Food> foods) {
  final map = <FoodCategory, List<Food>>{};
  for (final c in FoodCategory.values) {
    final inCat = foods.where((f) => f.category == c).toList();
    if (inCat.isNotEmpty) map[c] = inCat;
  }
  return map;
}
```

- [ ] **Step 5: Run to verify it passes**

Run: `flutter test test/data/food_data_test.dart`
Expected: PASS (4 tests).

- [ ] **Step 6: Commit**

```bash
git add lib/models/food.dart lib/data/food_data.dart test/data/food_data_test.dart
git commit -m "feat: add food model, curated CKD dataset, and filter/group helpers"
```

---

### Task 2: Food detail screen

A single food's full information: status, why, nutrient concerns, preparation, and cooking methods — with the disclaimer.

**Files:**
- Create: `lib/screens/food_detail_screen.dart`
- Test: none (presentational; content is covered by Task 1's data test).

**Interfaces:**
- Consumes: `Food`, `FoodStatus.color/label`, `FoodCategory.label`, `AppColors`.
- Produces: `class FoodDetailScreen extends StatelessWidget` with `const FoodDetailScreen({required this.food})`.

- [ ] **Step 1: Create the detail screen**

Create `lib/screens/food_detail_screen.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:ckd_care/models/food.dart';

class FoodDetailScreen extends StatelessWidget {
  const FoodDetailScreen({super.key, required this.food});
  final Food food;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;

    Widget section(String title, Widget child) => Padding(
          padding: const EdgeInsets.only(top: 20),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title.toUpperCase(), style: text.titleSmall),
            const SizedBox(height: 8),
            child,
          ]),
        );

    Widget methodList(List<String> items, IconData icon, Color color) => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (final m in items)
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Icon(icon, size: 18, color: color),
                  const SizedBox(width: 8),
                  Expanded(child: Text(m, style: text.bodyLarge)),
                ]),
              ),
          ],
        );

    return Scaffold(
      appBar: AppBar(title: Text(food.name)),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: [
          Row(children: [
            _StatusBadge(status: food.status),
            const SizedBox(width: 8),
            Text(food.category.label, style: text.bodyMedium),
          ]),
          section('Why', Text(food.why, style: text.bodyLarge)),
          section(
            'Nutrient concerns',
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [for (final c in food.concerns) Chip(label: Text(c))],
            ),
          ),
          section('How to prepare', Text(food.prep, style: text.bodyLarge)),
          if (food.goodMethods.isNotEmpty)
            section('Good cooking methods',
                methodList(food.goodMethods, Icons.check_circle, food.status.color)),
          if (food.avoidMethods.isNotEmpty)
            section('Avoid',
                methodList(food.avoidMethods, Icons.cancel, cs.onSurfaceVariant)),
          const SizedBox(height: 24),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: cs.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(children: [
              Icon(Icons.info_outline, size: 20, color: cs.onSurfaceVariant),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'General guidance, not medical advice. Your needs depend on '
                  'your kidney function, dialysis status, and lab results '
                  '(potassium, phosphorus) — always follow your care team\'s plan.',
                  style: text.bodyMedium,
                ),
              ),
            ]),
          ),
        ],
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.status});
  final FoodStatus status;
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: status.color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(status.label,
          style: TextStyle(
              fontFamily: 'Nunito',
              fontSize: 13,
              fontWeight: FontWeight.w800,
              color: status.color)),
    );
  }
}
```

- [ ] **Step 2: Analyze**

Run: `flutter analyze`
Expected: "No issues found!"

- [ ] **Step 3: Commit**

```bash
git add lib/screens/food_detail_screen.dart
git commit -m "feat: add food detail screen"
```

---

### Task 3: Food list screen + nav tab

The list: a disclaimer, status filter chips (All / Recommended / Limit / Avoid), foods grouped by category, each tapping through to the detail screen — plus the 5th "Food" bottom-nav tab.

**Files:**
- Create: `lib/screens/food_screen.dart`
- Modify: `lib/main.dart`
- Test: none new (grouping/filter helpers are tested in Task 1).

**Interfaces:**
- Consumes: `kFoods`, `filterFoods`, `groupByCategory`, `Food`, `FoodStatus`, `FoodCategory`, `FoodDetailScreen`.
- Produces: `class FoodScreen extends StatefulWidget` (holds the selected status filter).

- [ ] **Step 1: Create the list screen**

Create `lib/screens/food_screen.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:ckd_care/data/food_data.dart';
import 'package:ckd_care/models/food.dart';
import 'package:ckd_care/screens/food_detail_screen.dart';

class FoodScreen extends StatefulWidget {
  const FoodScreen({super.key});
  @override
  State<FoodScreen> createState() => _FoodScreenState();
}

class _FoodScreenState extends State<FoodScreen> {
  FoodStatus? _filter; // null = All

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final grouped = groupByCategory(filterFoods(kFoods, _filter));

    Widget chip(String label, FoodStatus? value) {
      final selected = _filter == value;
      return Padding(
        padding: const EdgeInsets.only(right: 8),
        child: ChoiceChip(
          label: Text(label),
          selected: selected,
          onSelected: (_) => setState(() => _filter = value),
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
      children: [
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: cs.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Row(children: [
            Icon(Icons.info_outline, size: 20, color: cs.onSurfaceVariant),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'General guidance, not medical advice. Needs vary with kidney '
                'function, dialysis, and your potassium and phosphorus levels — '
                'follow your care team\'s plan.',
                style: text.bodyMedium,
              ),
            ),
          ]),
        ),
        const SizedBox(height: 12),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(children: [
            chip('All', null),
            chip('Recommended', FoodStatus.recommended),
            chip('Limit', FoodStatus.limit),
            chip('Avoid', FoodStatus.avoid),
          ]),
        ),
        const SizedBox(height: 4),
        for (final entry in grouped.entries) ...[
          Padding(
            padding: const EdgeInsets.only(top: 16, bottom: 8, left: 2),
            child: Text(entry.key.label.toUpperCase(), style: text.titleSmall),
          ),
          for (final food in entry.value) _FoodRow(food: food),
        ],
        if (grouped.isEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 48),
            child: Center(
                child: Text('No foods match this filter.',
                    style: text.bodyMedium)),
          ),
      ],
    );
  }
}

class _FoodRow extends StatelessWidget {
  const _FoodRow({required this.food});
  final Food food;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: cs.outlineVariant),
      ),
      child: ListTile(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        onTap: () => Navigator.push(context,
            MaterialPageRoute(builder: (_) => FoodDetailScreen(food: food))),
        leading: Container(
          width: 10,
          height: 44,
          decoration: BoxDecoration(
              color: food.status.color, borderRadius: BorderRadius.circular(6)),
        ),
        title: Text(food.name, style: text.titleMedium),
        subtitle: Text(food.concerns.join(' · '), style: text.labelMedium),
        trailing: Text(food.status.label,
            style: TextStyle(
                fontFamily: 'Nunito',
                fontSize: 13,
                fontWeight: FontWeight.w800,
                color: food.status.color)),
      ),
    );
  }
}
```

- [ ] **Step 2: Add the Food nav tab**

In `lib/main.dart`, add the import near the other screen imports:

```dart
import 'package:ckd_care/screens/food_screen.dart';
```

Update `_titles`, `_screens`, and the nav `destinations` in `_HomeShellState` to insert Food before Settings:

```dart
  static const _titles = ['Dashboard', 'Fluid', 'Medicines', 'Food', 'Settings'];
  static const _screens = [
    DashboardScreen(),
    FluidScreen(),
    MedicinesScreen(),
    FoodScreen(),
    SettingsScreen(),
  ];
```

```dart
        destinations: const [
          NavigationDestination(icon: Icon(Icons.dashboard), label: 'Home'),
          NavigationDestination(icon: Icon(Icons.water_drop), label: 'Fluid'),
          NavigationDestination(icon: Icon(Icons.medication), label: 'Meds'),
          NavigationDestination(icon: Icon(Icons.restaurant_rounded), label: 'Food'),
          NavigationDestination(icon: Icon(Icons.settings), label: 'Settings'),
        ],
```

- [ ] **Step 3: Analyze + full suite**

Run: `flutter analyze`
Expected: "No issues found!"

Run: `flutter test`
Expected: all pass.

- [ ] **Step 4: Commit**

```bash
git add lib/screens/food_screen.dart lib/main.dart
git commit -m "feat: add food list screen and Food nav tab"
```

---

## Manual verification checklist (device/emulator)

Run after Task 3 via `flutter run -d Pixel_4a_API_34`:

1. A 5th **Food** tab appears in the bottom nav; opening it shows the disclaimer banner.
2. Foods are grouped by category (Fruits, Vegetables, Meat & protein, Grains & carbs, Drinks, Snacks, Other), each row color-coded by status with its concern text.
3. Filter chips **All / Recommended / Limit / Avoid** narrow the list; empty filter shows the empty message.
4. Tapping a food opens its detail: status badge, category, why, nutrient concern chips, how-to-prepare, good cooking methods, avoid list, and the disclaimer at the bottom.
5. Both light and dark themes render correctly (neutrals from the color scheme; status colors constant).

---

## Self-Review

**Spec coverage:**
- Food list of good + harmful/limit foods, categorized (Fruits/Vegetables/Meat&protein/Grains&carbs/Drinks/Snacks/Other) → Task 1 `kFoods` covers all 7 categories + all 3 statuses (asserted by test); Task 3 groups by category. ✓
- Per-food info: name, category, recommended/limit/avoid, simple why, nutrient concerns (potassium/phosphorus/sodium/protein/sugar) → `Food` fields + detail screen. ✓ (concerns strings carry the nutrient notes.)
- Preparation & cooking instructions; kidney-friendly methods; recommended vs avoid method lists → `prep`, `goodMethods`, `avoidMethods`; detail screen renders all three. ✓
- Simple, practical, easy-to-understand guidance distinguishing kidney-friendly vs restricted → plain copy, status colors, filter chips. ✓
- Not-medical-advice framing + variation with kidney function/dialysis/diabetes/BP/potassium/phosphorus → disclaimer on both list and detail (verbatim in Global Constraints). ✓

**Placeholder scan:** No TBD/TODO; the full dataset and all screen code are inline.

**Type consistency:** `Food`, `FoodStatus` (recommended/limit/avoid) + `.color`/`.label`, `FoodCategory` + `.label`, `kFoods`, `filterFoods(List<Food>, FoodStatus?)`, `groupByCategory(List<Food>) → Map<FoodCategory,List<Food>>`, `FoodDetailScreen({required Food food})`, `FoodScreen` are used consistently across tasks.

**Deferred (not gaps):** search, per-food images, favoriting, and portion calculators — none requested; static reference is the scope. Sugar/diabetes is addressed via the disclaimer and per-food notes rather than a numeric tracker.
