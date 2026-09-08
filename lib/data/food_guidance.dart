import 'package:ckd_care/data/food_stage_advice.dart';

/// Situations where users should consult a nephrologist or renal dietitian.
const List<String> kConsultReasons = [
  'You have been newly diagnosed with CKD.',
  'Your CKD stage has recently changed.',
  'You have CKD stage 3, 4, 5, or kidney failure and need an individualized diet plan.',
  'You are starting or stopping dialysis.',
  'You are considering a major change to your diet.',
  'You are unsure whether to restrict potassium, phosphorus, protein, sodium, or fluids.',
  'Recent blood tests show abnormal potassium, phosphorus, sodium, or albumin.',
  'You have diabetes, high blood pressure, heart disease, or other conditions that affect your diet.',
  'You are losing weight unintentionally or have a poor appetite.',
  'You have trouble eating enough food or protein.',
  'You take medications or supplements that may affect potassium, phosphorus, or fluid balance.',
  'You are unsure whether a food, herbal product, supplement, or traditional remedy is safe for you.',
];

/// Symptoms warranting prompt (non-emergency) medical review.
const List<String> kPromptReview = [
  'Noticeable swelling of the legs, feet, hands, or face.',
  'A clear decrease in how much you urinate.',
  'Persistent nausea or vomiting.',
  'Persistent loss of appetite.',
  'Significant or unexplained weight changes.',
  'Increasing tiredness or weakness.',
  'Persistent muscle cramps.',
  'New or worsening shortness of breath.',
  'Blood pressure that is getting harder to control.',
  'Persistent itching or other new symptoms of advanced kidney disease.',
  'New symptoms after a big change to your diet.',
];

/// Symptoms that may signal a medical emergency — seek care immediately.
const List<String> kEmergencySigns = [
  'Chest pain or pressure.',
  'Severe difficulty breathing.',
  'Fainting or loss of consciousness.',
  'Severe confusion or being unable to stay awake.',
  'A very fast, very slow, or irregular heartbeat with weakness, dizziness, or chest discomfort.',
  'Sudden severe weakness or paralysis.',
  'Severe or ongoing vomiting with signs of dehydration.',
];

/// One-line dietary focus per CKD stage / dialysis (label, guidance).
const List<(String, String)> kStageQuickReference = [
  ('Stage 1', 'Balanced diet, lower sodium, healthy portions, and control of diabetes and blood pressure.'),
  ('Stage 2', 'Keep protecting your kidneys; watch sodium and protein portions.'),
  ('Stage 3', 'Pay closer attention to sodium, protein, potassium, and phosphorus based on your labs.'),
  ('Stage 4', 'More individualized planning; sodium, potassium, phosphorus, protein, and fluids may need closer monitoring.'),
  ('Stage 5', 'An individualized renal diet; needs differ between dialysis and non-dialysis.'),
  ('Dialysis', 'Protein and other needs can differ significantly from non-dialysis CKD — follow your individual plan.'),
];

const String kFoodNonEmergencyDisclaimer =
    'This Food Section provides general health and nutrition information for '
    'education only. It is not a diagnosis, treatment, or personalized dietary '
    'prescription, and does not replace advice from a qualified healthcare '
    'professional.\n\n'
    'Kidney disease and nutritional needs vary from person to person. Food '
    'recommendations may depend on your CKD stage, lab results, medications, '
    'dialysis status, diabetes, blood pressure, and fluid balance. A food '
    'marked "Recommended" or "Limit" is not necessarily right or wrong for '
    'everyone with CKD.\n\n'
    'Do not start, stop, or significantly change your diet, medications, '
    'supplements, fluids, dialysis, or nutrient intake based only on this app. '
    'When in doubt about a food, ask your doctor, nephrologist, or renal dietitian.';

const String kFoodEmergencyMessage =
    'This may be a medical emergency. Do not rely on this app for treatment. '
    'Contact your local emergency service or go to the nearest emergency '
    'department immediately.';

/// A short clinician-consultation note tailored to the user's stage band.
/// A null band (no profile) returns a general note.
String clinicianAlert(StageBand? band) => switch (band) {
      null =>
        'Consult your healthcare professional if you have abnormal lab results '
            'or other medical conditions.',
      StageBand.early12 =>
        'General nutrition guidance may be appropriate, but consult your '
            'healthcare professional if you have abnormal lab results or other '
            'conditions.',
      StageBand.stage3 =>
        'Consider discussing your diet with your healthcare professional, '
            'especially if your potassium or phosphorus is abnormal.',
      StageBand.stage4 =>
        'Individualized renal dietary guidance is recommended. Consult your '
            'nephrologist or renal dietitian before major dietary changes.',
      StageBand.stage5 =>
        'Professional renal dietary guidance is strongly recommended. Do not '
            'independently restrict or increase potassium, phosphorus, protein, '
            'or fluids — talk to your renal dietitian.',
      StageBand.dialysis =>
        'Your nutritional and fluid needs may differ from non-dialysis CKD. '
            'Follow the individualized plan from your nephrologist or renal '
            'dietitian.',
    };
