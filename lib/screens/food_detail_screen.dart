import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:ckd_care/data/food_disclaimer.dart';
import 'package:ckd_care/data/food_guidance.dart';
import 'package:ckd_care/data/food_stage_advice.dart';
import 'package:ckd_care/models/food.dart';
import 'package:ckd_care/providers/health_profile_provider.dart';
import 'package:ckd_care/screens/health_profile_screen.dart';
import 'package:ckd_care/theme/app_theme.dart';

class FoodDetailScreen extends StatelessWidget {
  const FoodDetailScreen({super.key, required this.food});
  final Food food;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final band = stageBandForProfile(
        context.watch<HealthProfileProvider>().profile);

    Widget section(String title, Widget child) => Padding(
          padding: const EdgeInsets.only(top: 20),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title.toUpperCase(), style: text.titleSmall),
            const SizedBox(height: 8),
            child,
          ]),
        );

    Widget methodList(List<String> items, IconData icon, Color color) => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (final m in items)
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Icon(icon, size: 18, color: color),
                  const SizedBox(width: 8),
                  Expanded(child: Text(m, style: text.bodyLarge)),
                ]),
              ),
          ],
        );

    return Scaffold(
      appBar: AppBar(title: Text(food.name)),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: [
          Row(children: [
            _StatusBadge(status: food.status),
            const SizedBox(width: 8),
            Text(food.category.label, style: text.bodyMedium),
          ]),
          const SizedBox(height: 16),
          if (band != null)
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: cs.primary.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: cs.primary.withValues(alpha: 0.4)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    Icon(Icons.person_pin_circle_outlined,
                        size: 18, color: cs.primary),
                    const SizedBox(width: 8),
                    Text('For your stage — ${band.label}',
                        style: text.labelMedium?.copyWith(
                            color: cs.primary, fontWeight: FontWeight.w800)),
                  ]),
                  const SizedBox(height: 8),
                  Text(stageAdvice(food, band), style: text.bodyLarge),
                  const SizedBox(height: 8),
                  Text(clinicianAlert(band), style: text.bodyMedium),
                ],
              ),
            )
          else
            Material(
              color: cs.surface,
              borderRadius: BorderRadius.circular(14),
              child: InkWell(
                borderRadius: BorderRadius.circular(14),
                onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => const HealthProfileScreen())),
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: cs.outlineVariant),
                  ),
                  child: Row(children: [
                    Icon(Icons.tune, size: 18, color: cs.onSurfaceVariant),
                    const SizedBox(width: 8),
                    Expanded(
                        child: Text(
                            'Set your CKD stage for guidance tailored to you.',
                            style: text.bodyMedium)),
                    Icon(Icons.chevron_right, color: cs.onSurfaceVariant),
                  ]),
                ),
              ),
            ),
          section('Why', Text(food.why, style: text.bodyLarge)),
          section(
            'Nutrient concerns',
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [for (final c in food.concerns) Chip(label: Text(c))],
            ),
          ),
          if (food.servingSize != null)
            section('Suggested serving', Text(food.servingSize!, style: text.bodyLarge)),
          if (food.potassium != null ||
              food.phosphorus != null ||
              food.sodium != null)
            section(
              'Nutrient levels',
              Wrap(spacing: 8, runSpacing: 8, children: [
                if (food.potassium != null)
                  _NutrientChip(label: 'Potassium', level: food.potassium!),
                if (food.phosphorus != null)
                  _NutrientChip(label: 'Phosphorus', level: food.phosphorus!),
                if (food.sodium != null)
                  _NutrientChip(label: 'Sodium', level: food.sodium!),
              ]),
            ),
          section(
            'By CKD stage',
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final band in StageBand.values)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(band.label,
                            style: text.labelMedium
                                ?.copyWith(fontWeight: FontWeight.w800)),
                        const SizedBox(height: 2),
                        Text(stageAdvice(food, band), style: text.bodyMedium),
                      ],
                    ),
                  ),
              ],
            ),
          ),
          section('How to prepare', Text(food.prep, style: text.bodyLarge)),
          if (food.goodMethods.isNotEmpty)
            section('Good cooking methods',
                methodList(food.goodMethods, Icons.check_circle, food.status.color)),
          if (food.avoidMethods.isNotEmpty)
            section('Avoid',
                methodList(food.avoidMethods, Icons.cancel, cs.onSurfaceVariant)),
          const SizedBox(height: 24),
          if (isHighRiskFood(food)) ...[
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.warn.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Icon(Icons.priority_high_rounded,
                    size: 20, color: AppColors.warn),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(kFoodHighRiskNotice,
                      style: text.bodyMedium?.copyWith(color: AppColors.warn)),
                ),
              ]),
            ),
          ],
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: cs.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(children: [
              Icon(Icons.info_outline, size: 20, color: cs.onSurfaceVariant),
              const SizedBox(width: 10),
              Expanded(child: Text(kFoodDetailNotice, style: text.bodyMedium)),
            ]),
          ),
        ],
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.status});
  final FoodStatus status;
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: status.color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(status.label,
          style: TextStyle(
              fontFamily: 'Nunito',
              fontSize: 13,
              fontWeight: FontWeight.w800,
              color: status.color)),
    );
  }
}

class _NutrientChip extends StatelessWidget {
  const _NutrientChip({required this.label, required this.level});
  final String label;
  final NutrientLevel level;

  @override
  Widget build(BuildContext context) {
    final color = switch (level) {
      NutrientLevel.low => AppColors.good,
      NutrientLevel.moderate => AppColors.warn,
      NutrientLevel.high => AppColors.over,
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text('$label: ${level.label}',
          style: TextStyle(
              fontFamily: 'Nunito',
              fontSize: 12.5,
              fontWeight: FontWeight.w800,
              color: color)),
    );
  }
}
