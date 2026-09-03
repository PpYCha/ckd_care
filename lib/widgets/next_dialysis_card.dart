import 'package:flutter/material.dart';
import 'package:ckd_care/models/dialysis_schedule.dart';
import 'package:ckd_care/theme/app_theme.dart';

/// The purple "Next session" hero card: big date block + time/duration/clinic.
class NextDialysisCard extends StatelessWidget {
  const NextDialysisCard({super.key, required this.session, this.onTap});
  final DialysisSession session;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    const purple = AppColors.dialysis;
    final s = session;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: purple.withValues(alpha: 0.10),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: purple.withValues(alpha: 0.35)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('NEXT SESSION',
                  style: text.titleSmall?.copyWith(color: purple)),
              const SizedBox(height: 12),
              Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
                // Date block
                Container(
                  width: 66,
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  decoration: BoxDecoration(
                    color: purple,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Column(children: [
                    Text(monthAbbr(s.start).toUpperCase(),
                        style: text.labelMedium?.copyWith(
                            color: Colors.white, fontWeight: FontWeight.w800)),
                    Text('${s.start.day}',
                        style: text.headlineMedium?.copyWith(color: Colors.white)),
                    Text(weekdayAbbr(s.start).toUpperCase(),
                        style: text.labelMedium?.copyWith(
                            color: Colors.white70, fontWeight: FontWeight.w700)),
                  ]),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(formatTime12(s.start), style: text.titleLarge),
                      const SizedBox(height: 2),
                      Text('Duration: ${s.durationHours} hour'
                          '${s.durationHours == 1 ? '' : 's'}',
                          style: text.bodyMedium),
                      if (s.clinicName.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(s.clinicName, style: text.bodyMedium),
                      ],
                    ],
                  ),
                ),
              ]),
            ],
          ),
        ),
      ),
    );
  }
}
