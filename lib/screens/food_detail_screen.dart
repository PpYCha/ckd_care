import 'package:flutter/material.dart';
import 'package:ckd_care/models/food.dart';

class FoodDetailScreen extends StatelessWidget {
  const FoodDetailScreen({super.key, required this.food});
  final Food food;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;

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
          section('Why', Text(food.why, style: text.bodyLarge)),
          section(
            'Nutrient concerns',
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [for (final c in food.concerns) Chip(label: Text(c))],
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
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: cs.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(children: [
              Icon(Icons.info_outline, size: 20, color: cs.onSurfaceVariant),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'General guidance, not medical advice. Your needs depend on '
                  'your kidney function, dialysis status, and lab results '
                  '(potassium, phosphorus) — always follow your care team\'s plan.',
                  style: text.bodyMedium,
                ),
              ),
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
