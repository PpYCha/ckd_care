import 'package:ckd_care/models/food.dart';

/// Bump when the disclaimer text materially changes — users re-acknowledge.
const String kFoodDisclaimerVersion = '1.0';

const String kFoodDisclaimerTitle = 'Important Medical Information';

const String kFoodDisclaimerMessage =
    'This Food Section provides general educational information about nutrition '
    'and kidney health. It is not medical advice, a diagnosis, or a '
    'personalized treatment plan.\n\n'
    'Your dietary needs may vary depending on your CKD stage, laboratory '
    'results, medications, dialysis status, diabetes, blood pressure, and other '
    'health conditions.\n\n'
    'Do not make significant changes to your diet, fluid intake, potassium, '
    'phosphorus, protein, sodium, medications, or dialysis schedule based solely '
    'on this application.\n\n'
    'For personalized dietary advice, consult your doctor, nephrologist, or '
    'registered renal dietitian.';

const String kFoodEmergencyNotice =
    'If you are experiencing severe or rapidly worsening symptoms, seek '
    'emergency medical care immediately. Do not rely on this application for '
    'emergency medical advice.';

const String kFoodDisclaimerCheckbox =
    'I understand that this information is for educational purposes only and is '
    'not a substitute for professional medical advice.';

const String kFoodDetailNotice =
    'Educational Information Only: This information does not replace advice from '
    'your doctor or renal dietitian. Your recommended serving size or dietary '
    'restrictions may differ based on your individual health and laboratory '
    'results.';

const String kFoodHighRiskNotice =
    'Personalized medical guidance is recommended. Dietary requirements for '
    'advanced CKD and dialysis can vary significantly between individuals. '
    'Consult your nephrologist or renal dietitian before making significant '
    'dietary changes.';

/// True when the stored acknowledged version differs from the current version.
bool foodDisclaimerNeeded(String? storedVersion) =>
    storedVersion != kFoodDisclaimerVersion;

/// A food warrants the extra high-risk notice when it carries a concern about a
/// clinically sensitive nutrient (potassium, phosphorus, sodium) or an additive,
/// unless the concern is explicitly a "low" one. Keying off the food's own
/// properties is interim — stage/profile-based triggers come in a later sub-plan.
bool isHighRiskFood(Food food) => food.concerns.any((c) {
      final l = c.toLowerCase();
      if (l.contains('low')) return false;
      return l.contains('potassium') ||
          l.contains('phosphorus') ||
          l.contains('phosphate') ||
          l.contains('sodium') ||
          l.contains('additive');
    });
