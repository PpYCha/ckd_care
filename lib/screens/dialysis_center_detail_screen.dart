import 'package:flutter/material.dart';
import 'package:ckd_care/models/dialysis_center.dart';

class DialysisCenterDetailScreen extends StatelessWidget {
  const DialysisCenterDetailScreen({super.key, required this.center});
  final DialysisCenter center;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;

    Widget section(String title, Widget child) => Padding(
          padding: const EdgeInsets.only(top: 20),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title.toUpperCase(), style: text.titleSmall),
            const SizedBox(height: 6),
            child,
          ]),
        );

    Widget lines(List<String> items) => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (final s in items)
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: SelectableText(s, style: text.bodyLarge),
              ),
          ],
        );

    return Scaffold(
      appBar: AppBar(title: Text(center.name)),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: [
          Text('${center.province} · ${center.region}',
              style: text.bodyMedium?.copyWith(color: cs.onSurfaceVariant)),
          if (center.address.isNotEmpty) section('Address', lines([center.address])),
          if (center.tels.isNotEmpty) section('Phone', lines(center.tels)),
          if (center.emails.isNotEmpty) section('Email', lines(center.emails)),
          if (center.expiry.isNotEmpty)
            section('Accreditation valid until', lines(center.expiry)),
          if (center.sec.trim().isNotEmpty)
            section('Accreditation code', lines([center.sec])),
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
                    'From the PhilHealth list of accredited freestanding '
                    'dialysis clinics (CY 2026). Please confirm current '
                    'accreditation and contact details directly with the '
                    'center or PhilHealth before relying on them.',
                    style: text.bodyMedium),
              ),
            ]),
          ),
        ],
      ),
    );
  }
}
