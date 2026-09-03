import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:ckd_care/data/food_data.dart';
import 'package:ckd_care/data/food_stage_advice.dart';
import 'package:ckd_care/models/food.dart';
import 'package:ckd_care/providers/health_profile_provider.dart';
import 'package:ckd_care/screens/food_detail_screen.dart';
import 'package:ckd_care/screens/food_guidance_screen.dart';
import 'package:ckd_care/screens/health_profile_screen.dart';

class FoodScreen extends StatefulWidget {
  const FoodScreen({super.key});
  @override
  State<FoodScreen> createState() => _FoodScreenState();
}

class _FoodScreenState extends State<FoodScreen> {
  FoodStatus? _filter; // null = All

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final grouped = groupByCategory(filterFoods(kFoods, _filter));
    final band = stageBandForProfile(
        context.watch<HealthProfileProvider>().profile);

    Widget chip(String label, FoodStatus? value) {
      final selected = _filter == value;
      return Padding(
        padding: const EdgeInsets.only(right: 8),
        child: ChoiceChip(
          label: Text(label),
          selected: selected,
          onSelected: (_) => setState(() => _filter = value),
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
      children: [
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
              child: Text(kFoodDisclaimer, style: text.bodyMedium),
            ),
          ]),
        ),
        const SizedBox(height: 10),
        Material(
          color: cs.surface,
          borderRadius: BorderRadius.circular(14),
          child: InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (_) => const FoodGuidanceScreen())),
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: cs.outlineVariant),
              ),
              child: Row(children: [
                Icon(Icons.health_and_safety_outlined,
                    size: 20, color: cs.primary),
                const SizedBox(width: 10),
                Expanded(
                    child: Text('When to consult a doctor or dietitian',
                        style: text.titleSmall
                            ?.copyWith(color: cs.onSurface))),
                Icon(Icons.chevron_right, color: cs.onSurfaceVariant),
              ]),
            ),
          ),
        ),
        const SizedBox(height: 10),
        if (band != null)
          Row(children: [
            Icon(Icons.check_circle_outline, size: 16, color: cs.primary),
            const SizedBox(width: 6),
            Text('Guidance tailored for ${band.label}',
                style: text.labelMedium?.copyWith(color: cs.primary)),
          ])
        else
          InkWell(
            onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (_) => const HealthProfileScreen())),
            child: Row(children: [
              Icon(Icons.tune, size: 16, color: cs.onSurfaceVariant),
              const SizedBox(width: 6),
              Expanded(
                child: Text('Set your CKD stage for tailored guidance',
                    style: text.labelMedium),
              ),
              Icon(Icons.chevron_right, size: 18, color: cs.onSurfaceVariant),
            ]),
          ),
        const SizedBox(height: 12),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(children: [
            chip('All', null),
            chip('Recommended', FoodStatus.recommended),
            chip('Limit', FoodStatus.limit),
            chip('Avoid', FoodStatus.avoid),
          ]),
        ),
        const SizedBox(height: 4),
        for (final entry in grouped.entries) ...[
          Padding(
            padding: const EdgeInsets.only(top: 16, bottom: 8, left: 2),
            child: Text(entry.key.label.toUpperCase(), style: text.titleSmall),
          ),
          for (final food in entry.value) _FoodRow(food: food),
        ],
        if (grouped.isEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 48),
            child: Center(
                child: Text('No foods match this filter.',
                    style: text.bodyMedium)),
          ),
      ],
    );
  }
}

class _FoodRow extends StatelessWidget {
  const _FoodRow({required this.food});
  final Food food;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: cs.outlineVariant),
      ),
      child: ListTile(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        onTap: () => Navigator.push(context,
            MaterialPageRoute(builder: (_) => FoodDetailScreen(food: food))),
        leading: Container(
          width: 10,
          height: 44,
          decoration: BoxDecoration(
              color: food.status.color, borderRadius: BorderRadius.circular(6)),
        ),
        title: Text(food.name, style: text.titleMedium),
        subtitle: Text(food.concerns.join(' · '), style: text.labelMedium),
        trailing: Text(food.status.label,
            style: TextStyle(
                fontFamily: 'Nunito',
                fontSize: 13,
                fontWeight: FontWeight.w800,
                color: food.status.color)),
      ),
    );
  }
}
