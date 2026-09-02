import 'package:flutter/material.dart';
import 'package:ckd_care/models/dose_log.dart';
import 'package:ckd_care/providers/dashboard_provider.dart';

class DoseTile extends StatelessWidget {
  const DoseTile({super.key, required this.dose, required this.onMark});
  final DueDose dose;
  final void Function(DoseStatus) onMark;

  @override
  Widget build(BuildContext context) {
    final subtitle = switch (dose.status) {
      DoseStatus.taken => 'Taken',
      DoseStatus.skipped => 'Skipped',
      null => 'Pending',
    };
    return ListTile(
      title: Text('${dose.medicineName} — ${dose.timeOfDay}'),
      subtitle: Text(subtitle),
      trailing: dose.status != null
          ? Icon(dose.status == DoseStatus.taken ? Icons.check_circle : Icons.cancel)
          : Row(mainAxisSize: MainAxisSize.min, children: [
              TextButton(onPressed: () => onMark(DoseStatus.taken), child: const Text('Taken')),
              TextButton(onPressed: () => onMark(DoseStatus.skipped), child: const Text('Skip')),
            ]),
    );
  }
}
