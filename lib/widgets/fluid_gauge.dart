import 'package:flutter/material.dart';

/// Threshold color for the gauge: red above limit, amber at/above 80%, else green.
Color gaugeColor(int intakeMl, int limitMl) {
  if (limitMl == 0) return Colors.green;
  final ratio = intakeMl / limitMl;
  if (ratio > 1.0) return Colors.red;
  if (ratio >= 0.8) return Colors.amber;
  return Colors.green;
}

class FluidGauge extends StatelessWidget {
  const FluidGauge({super.key, required this.intakeMl, required this.limitMl});
  final int intakeMl;
  final int? limitMl;

  @override
  Widget build(BuildContext context) {
    if (limitMl == null) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Text('Set a daily fluid limit in Settings'),
        ),
      );
    }
    final limit = limitMl!;
    final ratio = limit == 0 ? 0.0 : intakeMl / limit;
    final color = gaugeColor(intakeMl, limit);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('$intakeMl / $limit mL',
              style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 8),
          LinearProgressIndicator(
              value: ratio.clamp(0.0, 1.0), color: color, minHeight: 10),
        ]),
      ),
    );
  }
}
