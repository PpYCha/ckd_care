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
      return flags.isEmpty
          ? 'Often suitable, but keep portions moderate. Confirm with your recent '
              'lab results and dietitian.'
          : 'May need limiting if your ${_join(flags)} ${flags.length == 1 ? 'is' : 'are'} '
              'elevated — your lab results and dietitian decide.';
    case StageBand.stage5:
      return flags.isEmpty
          ? 'Keep portions moderate and get your renal dietitian\'s guidance — '
              'needs are highly individual at this stage.'
          : 'Likely needs limiting if your ${_join(flags)} ${flags.length == 1 ? 'is' : 'are'} '
              'elevated. Follow your nephrologist or renal dietitian.';
    case StageBand.dialysis:
      return flags.isEmpty
          ? 'Fit into your individualized plan — follow your renal dietitian, '
              'as needs differ on dialysis.'
          : 'Portion and frequency depend on your labs and dialysis plan — '
              'follow your nephrologist or renal dietitian.';
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
