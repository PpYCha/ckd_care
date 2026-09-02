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
    // Bare sensitive-nutrient concerns (no "high") also flag.
    expect(isHighRiskFood(food(['Phosphorus'])), isTrue);
    expect(isHighRiskFood(food(['Phosphorus', 'Potassium'])), isTrue);
    // "Low" concerns and non-nutrient notes do not.
    expect(isHighRiskFood(food(['Low potassium'])), isFalse);
    expect(isHighRiskFood(food(['Low phosphorus'])), isFalse);
    expect(isHighRiskFood(food(['Counts toward your fluid limit'])), isFalse);
  });
}
