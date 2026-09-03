import 'package:flutter/foundation.dart';

enum CkdStage { stage1, stage2, stage3, stage4, stage5 }

extension CkdStageInfo on CkdStage {
  int get number => index + 1;
  String get label => 'Stage $number';
}

/// Stored as '1'..'5'; empty string means "not set".
String ckdStageToStored(CkdStage? stage) =>
    stage == null ? '' : stage.number.toString();

CkdStage? ckdStageFromNumber(String? stored) {
  final n = int.tryParse((stored ?? '').trim());
  if (n == null || n < 1 || n > 5) return null;
  return CkdStage.values[n - 1];
}

enum DialysisStatus { none, hemodialysis, peritoneal }

extension DialysisStatusInfo on DialysisStatus {
  String get label => switch (this) {
        DialysisStatus.none => 'Not on dialysis',
        DialysisStatus.hemodialysis => 'Hemodialysis',
        DialysisStatus.peritoneal => 'Peritoneal dialysis',
      };
}

/// Optional user health context used only to tailor general guidance. An unset
/// [ckdStage] means the user hasn't provided one — show general guidance.
@immutable
class HealthProfile {
  const HealthProfile({
    this.ckdStage,
    this.dialysisStatus = DialysisStatus.none,
    this.diabetes = false,
    this.elevatedPotassium = false,
    this.elevatedPhosphorus = false,
    this.fluidRestriction = false,
  });

  final CkdStage? ckdStage;
  final DialysisStatus dialysisStatus;
  final bool diabetes;
  final bool elevatedPotassium;
  final bool elevatedPhosphorus;
  final bool fluidRestriction;

  bool get isSet => ckdStage != null;

  HealthProfile copyWith({
    CkdStage? ckdStage,
    DialysisStatus? dialysisStatus,
    bool? diabetes,
    bool? elevatedPotassium,
    bool? elevatedPhosphorus,
    bool? fluidRestriction,
  }) =>
      HealthProfile(
        ckdStage: ckdStage ?? this.ckdStage,
        dialysisStatus: dialysisStatus ?? this.dialysisStatus,
        diabetes: diabetes ?? this.diabetes,
        elevatedPotassium: elevatedPotassium ?? this.elevatedPotassium,
        elevatedPhosphorus: elevatedPhosphorus ?? this.elevatedPhosphorus,
        fluidRestriction: fluidRestriction ?? this.fluidRestriction,
      );

  @override
  bool operator ==(Object other) =>
      other is HealthProfile &&
      other.ckdStage == ckdStage &&
      other.dialysisStatus == dialysisStatus &&
      other.diabetes == diabetes &&
      other.elevatedPotassium == elevatedPotassium &&
      other.elevatedPhosphorus == elevatedPhosphorus &&
      other.fluidRestriction == fluidRestriction;

  @override
  int get hashCode => Object.hash(ckdStage, dialysisStatus, diabetes,
      elevatedPotassium, elevatedPhosphorus, fluidRestriction);
}
