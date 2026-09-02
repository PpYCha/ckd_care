import 'package:flutter/material.dart';
import 'package:ckd_care/models/dose_log.dart';
import 'package:ckd_care/providers/dashboard_provider.dart';
import 'package:ckd_care/theme/app_theme.dart';

/// One scheduled dose: name + time, a status avatar, and a Taken/Skip toggle.
/// An unmarked dose is Pending; tapping (re)marks it, so a mistouched Taken can
/// be switched to Skip. [enabled] is false for future dates (not yet due).
class DoseTile extends StatelessWidget {
  const DoseTile(
      {super.key, required this.dose, required this.onMark, this.enabled = true});
  final DueDose dose;
  final void Function(DoseStatus) onMark;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final (statusLabel, statusColor, icon) = switch (dose.status) {
      DoseStatus.taken => ('Taken', AppColors.good, Icons.check_rounded),
      DoseStatus.skipped => ('Skipped', AppColors.over, Icons.close_rounded),
      null => ('Pending', AppColors.inkSoft, Icons.medication_outlined),
    };

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.line),
      ),
      child: Row(children: [
        Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: statusColor.withValues(alpha: 0.12),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: statusColor, size: 22),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(dose.medicineName,
                  style: text.titleMedium, maxLines: 1, overflow: TextOverflow.ellipsis),
              const SizedBox(height: 1),
              Text('${dose.timeOfDay}  ·  $statusLabel',
                  style: text.labelMedium?.copyWith(
                      color: statusColor, fontWeight: FontWeight.w700)),
            ],
          ),
        ),
        const SizedBox(width: 8),
        _DoseToggle(status: dose.status, enabled: enabled, onMark: onMark),
      ]),
    );
  }
}

class _DoseToggle extends StatelessWidget {
  const _DoseToggle(
      {required this.status, required this.enabled, required this.onMark});
  final DoseStatus? status;
  final bool enabled;
  final void Function(DoseStatus) onMark;

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: enabled ? 1 : 0.4,
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        _pill(
          icon: Icons.check_rounded,
          label: 'Taken',
          color: AppColors.good,
          selected: status == DoseStatus.taken,
          onTap: enabled ? () => onMark(DoseStatus.taken) : null,
        ),
        const SizedBox(width: 6),
        _pill(
          icon: Icons.close_rounded,
          label: 'Skip',
          color: AppColors.over,
          selected: status == DoseStatus.skipped,
          onTap: enabled ? () => onMark(DoseStatus.skipped) : null,
        ),
      ]),
    );
  }

  Widget _pill({
    required IconData icon,
    required String label,
    required Color color,
    required bool selected,
    required VoidCallback? onTap,
  }) {
    return Material(
      color: selected ? color.withValues(alpha: 0.14) : Colors.transparent,
      borderRadius: BorderRadius.circular(11),
      child: InkWell(
        borderRadius: BorderRadius.circular(11),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(11),
            border: Border.all(
                color: selected ? color : AppColors.line,
                width: selected ? 1.4 : 1),
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(icon, size: 16, color: selected ? color : AppColors.inkSoft),
            const SizedBox(width: 4),
            Text(label,
                style: TextStyle(
                    fontFamily: 'Nunito',
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: selected ? color : AppColors.inkSoft)),
          ]),
        ),
      ),
    );
  }
}
