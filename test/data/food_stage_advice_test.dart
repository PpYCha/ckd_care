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
