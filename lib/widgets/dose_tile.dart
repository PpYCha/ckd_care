import 'package:flutter/material.dart';
import 'package:ckd_care/models/dose_log.dart';
import 'package:ckd_care/providers/dashboard_provider.dart';

/// A dose row with a Taken/Skip toggle. Empty selection = Pending. Tapping a
/// segment (re)marks the dose, so a mistouched Taken can be switched to Skip.
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
      trailing: SegmentedButton<DoseStatus>(
        segments: const [
          ButtonSegment(
              value: DoseStatus.taken,
              icon: Icon(Icons.check),
              tooltip: 'Taken'),
          ButtonSegment(
              value: DoseStatus.skipped,
              icon: Icon(Icons.close),
              tooltip: 'Skip'),
        ],
        selected: dose.status == null ? <DoseStatus>{} : {dose.status!},
        emptySelectionAllowed: true,
        showSelectedIcon: false,
        style: const ButtonStyle(visualDensity: VisualDensity.compact),
        onSelectionChanged: (sel) {
          if (sel.isNotEmpty) onMark(sel.first);
        },
      ),
    );
  }
}
