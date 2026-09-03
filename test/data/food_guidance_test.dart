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
