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
