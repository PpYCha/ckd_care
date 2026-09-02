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
