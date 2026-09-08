import 'package:flutter_test/flutter_test.dart';
import 'package:ckd_care/models/health_profile.dart';

void main() {
  test('CkdStage label/number and stored conversion round-trip', () {
    expect(CkdStage.stage3.label, 'Stage 3');
    expect(CkdStage.stage3.number, 3);
    expect(ckdStageToStored(CkdStage.stage3), '3');
    expect(ckdStageToStored(null), '');
    expect(ckdStageFromNumber('3'), CkdStage.stage3);
    expect(ckdStageFromNumber(''), isNull);
    expect(ckdStageFromNumber(null), isNull);
    expect(ckdStageFromNumber('9'), isNull);
  });

  test('DialysisStatus labels', () {
    expect(DialysisStatus.none.label, 'Not on dialysis');
    expect(DialysisStatus.hemodialysis.label, 'Hemodialysis');
    expect(DialysisStatus.peritoneal.label, 'Peritoneal dialysis');
  });

  test('HealthProfile copyWith and equality', () {
    const base = HealthProfile();
    expect(base.isSet, isFalse);
    expect(base.dialysisStatus, DialysisStatus.none);

    final edited = base.copyWith(
        ckdStage: CkdStage.stage4, diabetes: true, elevatedPotassium: true);
    expect(edited.isSet, isTrue);
    expect(edited.ckdStage, CkdStage.stage4);
    expect(edited.diabetes, isTrue);
    expect(edited.elevatedPotassium, isTrue);
    expect(edited.elevatedPhosphorus, isFalse); // unchanged
    expect(edited == base, isFalse);
    expect(
      edited,
      const HealthProfile(
          ckdStage: CkdStage.stage4, diabetes: true, elevatedPotassium: true),
    );
  });
}
