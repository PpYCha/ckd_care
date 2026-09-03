import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:ckd_care/models/dialysis_schedule.dart';
import 'package:ckd_care/providers/dialysis_schedule_provider.dart';
import 'package:ckd_care/screens/dialysis_schedule_edit_screen.dart';
import 'package:ckd_care/theme/app_theme.dart';
import 'package:ckd_care/widgets/next_dialysis_card.dart';

class DialysisScheduleScreen extends StatefulWidget {
  const DialysisScheduleScreen({super.key});
  @override
  State<DialysisScheduleScreen> createState() => _DialysisScheduleScreenState();
}

class _DialysisScheduleScreenState extends State<DialysisScheduleScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback(
        (_) => context.read<DialysisScheduleProvider>().load());
  }

  void _openEdit() => Navigator.push(context,
      MaterialPageRoute(builder: (_) => const DialysisScheduleEditScreen()));

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final schedule = context.watch<DialysisScheduleProvider>().schedule;
    final now = DateTime.now();
    final sessions =
        schedule.isSet ? upcomingSessions(schedule, now: now, count: 6) : const <DialysisSession>[];

    return Scaffold(
      appBar: AppBar(
        title: const Text('Dialysis schedule'),
        actions: [
          if (schedule.isSet)
            IconButton(
                icon: const Icon(Icons.edit_outlined), onPressed: _openEdit),
        ],
      ),
      body: !schedule.isSet
          ? _Empty(onSetup: _openEdit)
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
              children: [
                if (sessions.isNotEmpty)
                  NextDialysisCard(session: sessions.first, onTap: _openEdit),
                const SizedBox(height: 20),
                Text('UPCOMING SCHEDULE', style: text.titleSmall),
                const SizedBox(height: 8),
                for (var i = 1; i < sessions.length; i++)
                  _UpcomingRow(session: sessions[i]),
                if (sessions.length <= 1)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text('No further sessions in the next weeks.',
                        style: text.bodyMedium),
                  ),
              ],
            ),
    );
  }
}

class _UpcomingRow extends StatelessWidget {
  const _UpcomingRow({required this.session});
  final DialysisSession session;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final s = session;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: cs.outlineVariant),
      ),
      child: Row(children: [
        Icon(Icons.event_rounded, color: AppColors.dialysis, size: 22),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                  '${weekdayAbbr(s.start)}, ${monthAbbr(s.start)} ${s.start.day}',
                  style: text.titleMedium),
              Text(formatTime12(s.start), style: text.labelMedium),
            ],
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: AppColors.dialysis.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(999),
          ),
          child: Text('Scheduled',
              style: text.labelMedium?.copyWith(
                  color: AppColors.dialysis, fontWeight: FontWeight.w800)),
        ),
      ]),
    );
  }
}

class _Empty extends StatelessWidget {
  const _Empty({required this.onSetup});
  final VoidCallback onSetup;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Text('🗓️', style: TextStyle(fontSize: 44)),
          const SizedBox(height: 12),
          Text('No schedule yet', style: text.titleLarge),
          const SizedBox(height: 4),
          Text('Add your dialysis days and time to see your next session here.',
              style: text.bodyMedium, textAlign: TextAlign.center),
          const SizedBox(height: 20),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.dialysis),
            onPressed: onSetup,
            child: const Text('Set up schedule'),
          ),
        ]),
      ),
    );
  }
}
