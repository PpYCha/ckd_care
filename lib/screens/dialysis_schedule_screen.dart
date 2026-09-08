import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:ckd_care/models/dialysis_session_log.dart';
import 'package:ckd_care/models/dialysis_schedule.dart';
import 'package:ckd_care/providers/dialysis_schedule_provider.dart';
import 'package:ckd_care/providers/dialysis_session_log_provider.dart';
import 'package:ckd_care/screens/dialysis_schedule_edit_screen.dart';
import 'package:ckd_care/theme/app_theme.dart';
import 'package:ckd_care/widgets/next_dialysis_card.dart';

class DialysisScheduleScreen extends StatefulWidget {
  const DialysisScheduleScreen({super.key});
  @override
  State<DialysisScheduleScreen> createState() => _DialysisScheduleScreenState();
}

class _DialysisScheduleScreenState extends State<DialysisScheduleScreen> {
  String _loadedSessionKeys = '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => context.read<DialysisScheduleProvider>().load(),
    );
  }

  void _openEdit() => Navigator.push(
    context,
    MaterialPageRoute(builder: (_) => const DialysisScheduleEditScreen()),
  );

  void _loadLogsFor(List<DialysisSession> sessions) {
    final keys = sessions.map((s) => sessionKeyFor(s.start)).join('|');
    if (keys == _loadedSessionKeys) return;
    _loadedSessionKeys = keys;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<DialysisSessionLogProvider>().loadForSessions(
        sessions.map((s) => s.start),
      );
    });
  }

  Future<void> _editWeights(DialysisSession session) async {
    final provider = context.read<DialysisSessionLogProvider>();
    final existing = provider.logFor(session.start);
    final pre = TextEditingController(
      text: existing?.preWeightKg == null
          ? ''
          : _formatWeight(existing!.preWeightKg!),
    );
    final post = TextEditingController(
      text: existing?.postWeightKg == null
          ? ''
          : _formatWeight(existing!.postWeightKg!),
    );
    String? error;

    double? parse(String value) {
      final trimmed = value.trim();
      if (trimmed.isEmpty) return null;
      final parsed = double.tryParse(trimmed);
      if (parsed == null || parsed <= 0) return double.nan;
      return parsed;
    }

    final result = await showDialog<({double? pre, double? post})>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          return AlertDialog(
            title: const Text('Session weights'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: pre,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: const InputDecoration(
                    labelText: 'Pre weight (kg)',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: post,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: const InputDecoration(
                    labelText: 'Post weight (kg)',
                    border: OutlineInputBorder(),
                  ),
                ),
                if (error != null) ...[
                  const SizedBox(height: 10),
                  Text(
                    error!,
                    style: TextStyle(color: Theme.of(ctx).colorScheme.error),
                  ),
                ],
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () {
                  final preValue = parse(pre.text);
                  final postValue = parse(post.text);
                  if (preValue?.isNaN == true || postValue?.isNaN == true) {
                    setDialogState(
                      () => error =
                          'Enter positive numbers, or leave fields blank.',
                    );
                    return;
                  }
                  Navigator.pop(ctx, (pre: preValue, post: postValue));
                },
                child: const Text('Save'),
              ),
            ],
          );
        },
      ),
    );

    pre.dispose();
    post.dispose();
    if (result == null || !mounted) return;
    await provider.saveWeights(
      sessionStart: session.start,
      preWeightKg: result.pre,
      postWeightKg: result.post,
    );
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text('Weights saved')));
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final schedule = context.watch<DialysisScheduleProvider>().schedule;
    final now = DateTime.now();
    final sessions = schedule.isSet
        ? upcomingSessions(schedule, now: now, count: 6)
        : const <DialysisSession>[];
    if (schedule.isSet) _loadLogsFor(sessions);
    final logs = context.watch<DialysisSessionLogProvider>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Dialysis schedule'),
        actions: [
          if (schedule.isSet)
            IconButton(
              icon: const Icon(Icons.edit_outlined),
              onPressed: _openEdit,
            ),
        ],
      ),
      body: !schedule.isSet
          ? _Empty(onSetup: _openEdit)
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
              children: [
                if (sessions.isNotEmpty)
                  NextDialysisCard(
                    session: sessions.first,
                    log: logs.logFor(sessions.first.start),
                    onTap: _openEdit,
                    onEditWeights: () => _editWeights(sessions.first),
                  ),
                const SizedBox(height: 20),
                Text('UPCOMING SCHEDULE', style: text.titleSmall),
                const SizedBox(height: 8),
                for (var i = 1; i < sessions.length; i++)
                  _UpcomingRow(
                    session: sessions[i],
                    log: logs.logFor(sessions[i].start),
                    onEditWeights: () => _editWeights(sessions[i]),
                  ),
                if (sessions.length <= 1)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      'No further sessions in the next weeks.',
                      style: text.bodyMedium,
                    ),
                  ),
              ],
            ),
    );
  }
}

class _UpcomingRow extends StatelessWidget {
  const _UpcomingRow({
    required this.session,
    required this.log,
    required this.onEditWeights,
  });
  final DialysisSession session;
  final DialysisSessionLog? log;
  final VoidCallback onEditWeights;

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
      child: Row(
        children: [
          Icon(Icons.event_rounded, color: AppColors.dialysis, size: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${weekdayAbbr(s.start)}, ${monthAbbr(s.start)} ${s.start.day}',
                  style: text.titleMedium,
                ),
                Text(formatTime12(s.start), style: text.labelMedium),
                if (log != null && log!.hasWeights) ...[
                  const SizedBox(height: 4),
                  Text(
                    _weightSummary(log!),
                    style: text.labelMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ],
            ),
          ),
          IconButton(
            tooltip: 'Record weights',
            icon: const Icon(Icons.monitor_weight_outlined),
            onPressed: onEditWeights,
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: AppColors.dialysis.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              'Scheduled',
              style: text.labelMedium?.copyWith(
                color: AppColors.dialysis,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

String _formatWeight(double value) {
  final rounded = value.toStringAsFixed(1);
  return rounded.endsWith('.0') ? value.toStringAsFixed(0) : rounded;
}

String _kg(double value) => '${_formatWeight(value)} kg';

String _weightSummary(DialysisSessionLog log) {
  final parts = <String>[
    if (log.preWeightKg != null) 'Pre ${_kg(log.preWeightKg!)}',
    if (log.postWeightKg != null) 'Post ${_kg(log.postWeightKg!)}',
    if (log.removedWeightKg != null) 'Removed ${_kg(log.removedWeightKg!)}',
  ];
  return parts.join(' · ');
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
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('🗓️', style: TextStyle(fontSize: 44)),
            const SizedBox(height: 12),
            Text('No schedule yet', style: text.titleLarge),
            const SizedBox(height: 4),
            Text(
              'Add your dialysis days and time to see your next session here.',
              style: text.bodyMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.dialysis,
              ),
              onPressed: onSetup,
              child: const Text('Set up schedule'),
            ),
          ],
        ),
      ),
    );
  }
}
