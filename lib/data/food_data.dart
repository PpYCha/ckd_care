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
