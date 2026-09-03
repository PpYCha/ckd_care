import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:ckd_care/data/food_guidance.dart';
import 'package:ckd_care/data/food_stage_advice.dart';
import 'package:ckd_care/providers/health_profile_provider.dart';
import 'package:ckd_care/theme/app_theme.dart';

class FoodGuidanceScreen extends StatelessWidget {
  const FoodGuidanceScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final band = stageBandForProfile(
        context.watch<HealthProfileProvider>().profile);

    Widget heading(String t) => Padding(
          padding: const EdgeInsets.only(top: 22, bottom: 8),
          child: Text(t, style: text.titleMedium),
        );

    Widget bullets(List<String> items, {Color? dot}) => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (final s in items)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Padding(
                    padding: const EdgeInsets.only(top: 7, right: 10),
                    child: Icon(Icons.circle,
                        size: 6, color: dot ?? cs.onSurfaceVariant),
                  ),
                  Expanded(child: Text(s, style: text.bodyLarge)),
                ]),
              ),
          ],
        );

    Widget noticeCard(String body, {required Color color, IconData? icon}) =>
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Icon(icon ?? Icons.info_outline, size: 20, color: color),
            const SizedBox(width: 10),
            Expanded(
                child: Text(body,
                    style: text.bodyMedium?.copyWith(color: color))),
          ]),
        );

    return Scaffold(
      appBar: AppBar(title: const Text('When to get help')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: [
          // Profile-aware clinician alert.
          noticeCard(clinicianAlert(band),
              color: cs.primary, icon: Icons.medical_information_outlined),

          heading('Talk to a nephrologist or renal dietitian if…'),
          bullets(kConsultReasons),

          heading('Get medical review soon if you notice…'),
          bullets(kPromptReview, dot: AppColors.warn),

          heading('Emergency — get care now'),
          const SizedBox(height: 2),
          noticeCard(kFoodEmergencyMessage,
              color: AppColors.over, icon: Icons.emergency_outlined),
          const SizedBox(height: 10),
          bullets(kEmergencySigns, dot: AppColors.over),

          heading('Diet focus by CKD stage'),
          for (final (stage, guidance) in kStageQuickReference)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(stage,
                      style: text.labelMedium
                          ?.copyWith(fontWeight: FontWeight.w800)),
                  const SizedBox(height: 2),
                  Text(guidance, style: text.bodyMedium),
                ],
              ),
            ),

          heading('About this information'),
          Text(kFoodNonEmergencyDisclaimer, style: text.bodyMedium),
        ],
      ),
    );
  }
}
