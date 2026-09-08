import 'package:flutter/material.dart';
import 'package:ckd_care/data/food_disclaimer.dart';
import 'package:ckd_care/theme/app_theme.dart';

/// Blocking medical disclaimer shown before the Food Section. Pops `true` when
/// the user acknowledges and continues, `false` when they go back.
class FoodDisclaimerDialog extends StatefulWidget {
  const FoodDisclaimerDialog({super.key});
  @override
  State<FoodDisclaimerDialog> createState() => _FoodDisclaimerDialogState();
}

class _FoodDisclaimerDialogState extends State<FoodDisclaimerDialog> {
  bool _checked = false;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return AlertDialog(
      title: const Text(kFoodDisclaimerTitle),
      content: SizedBox(
        width: double.maxFinite,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(kFoodDisclaimerMessage, style: text.bodyMedium),
              const SizedBox(height: 14),
              // Emergency notice — visually distinct from the general message.
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.over.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Icon(Icons.emergency_outlined,
                      size: 20, color: AppColors.over),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(kFoodEmergencyNotice,
                        style: text.bodyMedium?.copyWith(color: AppColors.over)),
                  ),
                ]),
              ),
              const SizedBox(height: 6),
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                controlAffinity: ListTileControlAffinity.leading,
                value: _checked,
                onChanged: (v) => setState(() => _checked = v ?? false),
                title: Text(kFoodDisclaimerCheckbox, style: text.bodyMedium),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('Go Back'),
        ),
        FilledButton(
          onPressed: _checked ? () => Navigator.pop(context, true) : null,
          child: const Text('I Understand & Continue'),
        ),
      ],
    );
  }
}
