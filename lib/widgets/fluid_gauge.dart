import 'package:flutter/material.dart';
import 'package:ckd_care/theme/app_theme.dart';

/// The dashboard's hero: today's fluid intake against the daily limit, shown as
/// a calm water-level meter. Colors stay muted even over the limit — this is a
/// daily reassurance, not an alarm.
class FluidGauge extends StatelessWidget {
  const FluidGauge({super.key, required this.intakeMl, required this.limitMl});
  final int intakeMl;
  final int? limitMl;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;

    if (limitMl == null) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Row(children: [
            const Icon(Icons.water_drop_outlined,
                color: AppColors.water, size: 28),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('No fluid limit yet', style: text.titleMedium),
                  const SizedBox(height: 2),
                  Text('Set a daily limit in Settings to track your balance.',
                      style: text.bodyMedium),
                ],
              ),
            ),
          ]),
        ),
      );
    }

    final limit = limitMl!;
    final ratio = limit == 0 ? 0.0 : intakeMl / limit;
    final color = AppColors.fluidStatus(ratio);
    final over = intakeMl - limit;

    final (statusLabel, statusColor) = ratio > 1.0
        ? ('Over limit', AppColors.over)
        : ratio >= 0.8
            ? ('Near limit', AppColors.warn)
            : ('On track', AppColors.good);

    final footer = over > 0
        ? '$over mL over your limit'
        : '${limit - intakeMl} mL left today';

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('FLUID TODAY', style: text.labelMedium),
                      const SizedBox(height: 2),
                      RichText(
                        text: TextSpan(children: [
                          TextSpan(text: '$intakeMl', style: text.displaySmall),
                          TextSpan(
                              text: '  / $limit mL', style: text.bodyMedium),
                        ]),
                      ),
                    ],
                  ),
                ),
                _StatusPill(label: statusLabel, color: statusColor),
              ],
            ),
            const SizedBox(height: 16),
            _Meter(ratio: ratio, color: color),
            const SizedBox(height: 10),
            Text(footer,
                style: text.labelMedium?.copyWith(
                    color: statusColor, fontWeight: FontWeight.w700)),
          ],
        ),
      ),
    );
  }
}

class _Meter extends StatelessWidget {
  const _Meter({required this.ratio, required this.color});
  final double ratio;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: Stack(children: [
        Container(
            height: 26,
            color: Theme.of(context).colorScheme.surfaceContainerHighest),
        FractionallySizedBox(
          widthFactor: ratio.clamp(0.0, 1.0),
          child: Container(
            height: 26,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [color.withValues(alpha: 0.75), color],
              ),
            ),
          ),
        ),
      ]),
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.label, required this.color});
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(label,
          style: TextStyle(
              fontFamily: 'Nunito',
              fontSize: 12.5,
              fontWeight: FontWeight.w800,
              color: color,
              letterSpacing: 0.2)),
    );
  }
}
