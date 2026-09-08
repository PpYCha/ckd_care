import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:ckd_care/models/fluid_entry.dart';
import 'package:ckd_care/providers/fluid_provider.dart';
import 'package:ckd_care/providers/settings_provider.dart';
import 'package:ckd_care/theme/app_theme.dart';
import 'package:ckd_care/widgets/fluid_amount_dialog.dart';

class FluidScreen extends StatefulWidget {
  const FluidScreen({super.key});
  @override
  State<FluidScreen> createState() => _FluidScreenState();
}

class _FluidScreenState extends State<FluidScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<FluidProvider>().loadDay(FluidEntry.dayOf(DateTime.now()));
      context.read<SettingsProvider>().load();
    });
  }

  Future<void> _add(FluidType type) async {
    final messenger = ScaffoldMessenger.of(context);
    final provider = context.read<FluidProvider>();
    final ml = await showFluidAmountDialog(context, title: 'Add ${type.name} (mL)');
    if (ml == null || !mounted) return;
    await provider.add(type, ml);
    messenger.showSnackBar(SnackBar(
        content: Text('${type == FluidType.intake ? 'Intake' : 'Output'} added')));
  }

  Future<void> _edit(FluidEntry e) async {
    final messenger = ScaffoldMessenger.of(context);
    final provider = context.read<FluidProvider>();
    final ml = await showFluidAmountDialog(context,
        title: 'Edit ${e.type.name} (mL)', initial: e.amountMl);
    if (ml == null || !mounted) return;
    await provider.update(FluidEntry(
      id: e.id,
      uuid: e.uuid,
      type: e.type,
      amountMl: ml,
      loggedAt: e.loggedAt,
      day: e.day,
      note: e.note,
      updatedAt: DateTime.now(),
    ));
    messenger.showSnackBar(const SnackBar(content: Text('Entry updated')));
  }

  ({int intake, int output}) _totals(FluidProvider p) {
    var intake = 0, output = 0;
    for (final e in p.entries) {
      if (e.type == FluidType.intake) {
        intake += e.amountMl;
      } else {
        output += e.amountMl;
      }
    }
    return (intake: intake, output: output);
  }

  Widget _gaugeCard(int intake, int? limit) {
    final cs = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;

    if (limit == null) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Row(children: [
            const Text('💧', style: TextStyle(fontSize: 28)),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('No fluid limit yet', style: text.titleMedium),
                  const SizedBox(height: 2),
                  Text('Set a daily limit in Settings to see your progress.',
                      style: text.bodyMedium),
                ],
              ),
            ),
          ]),
        ),
      );
    }

    final ratio = limit == 0 ? 0.0 : intake / limit;
    final color = AppColors.fluidStatus(ratio);
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
        child: Column(children: [
          Text("TODAY'S INTAKE", style: text.titleSmall),
          const SizedBox(height: 16),
          SizedBox(
            width: 210,
            height: 210,
            child: CustomPaint(
              painter: _RingPainter(
                ratio: ratio.clamp(0.0, 1.0),
                color: color,
                track: cs.surfaceContainerHighest,
              ),
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('💧', style: TextStyle(fontSize: 30)),
                    const SizedBox(height: 4),
                    Text('$intake',
                        style: text.displaySmall?.copyWith(color: color)),
                    Text('of $limit mL goal', style: text.bodyMedium),
                  ],
                ),
              ),
            ),
          ),
        ]),
      ),
    );
  }

  Widget _encouragement(int intake, int? limit) {
    if (limit == null) return const SizedBox.shrink();
    final cs = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final ratio = limit == 0 ? 0.0 : intake / limit;
    final (msg, color) = ratio > 1.0
        ? (
            "You've passed today's limit. Go easy on fluids and check with "
                'your care team.',
            AppColors.over
          )
        : ratio >= 0.8
            ? (
                'Getting close to your limit — sip slowly through the rest '
                    'of the day.',
                AppColors.warn
              )
            : (
                'Good job! Keep drinking within your daily limit. 💧',
                AppColors.good
              );
    return Container(
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(Icons.emoji_emotions_outlined, size: 20, color: color),
        const SizedBox(width: 10),
        Expanded(
          child: Text(msg,
              style: text.bodyMedium?.copyWith(
                  color: cs.onSurface, fontWeight: FontWeight.w600)),
        ),
      ]),
    );
  }

  Widget _totalsRow(int intake, int output) {
    final cs = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    Widget half(String label, int v, Color color) => Expanded(
          child: Column(children: [
            Text('$v mL',
                style: text.titleLarge?.copyWith(color: color)),
            Text(label, style: text.labelMedium),
          ]),
        );
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: Row(children: [
          half('Intake today', intake, AppColors.water),
          Container(width: 1, height: 36, color: cs.outlineVariant),
          half('Output today', output, cs.primary),
        ]),
      ),
    );
  }

  Widget _row(FluidEntry e) {
    final cs = Theme.of(context).colorScheme;
    final isIntake = e.type == FluidType.intake;
    final color = isIntake ? AppColors.water : cs.primary;
    final time = '${e.loggedAt.hour.toString().padLeft(2, '0')}:'
        '${e.loggedAt.minute.toString().padLeft(2, '0')}';
    return Dismissible(
      key: ValueKey(e.id),
      direction: DismissDirection.endToStart,
      background: Container(
        decoration: BoxDecoration(
            color: AppColors.over, borderRadius: BorderRadius.circular(16)),
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 18),
        child: const Icon(Icons.delete_outline, color: Colors.white),
      ),
      onDismissed: (_) => context.read<FluidProvider>().remove(e.id!),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        decoration: BoxDecoration(
          color: cs.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: cs.outlineVariant),
        ),
        child: ListTile(
          onTap: () => _edit(e),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          leading: Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12), shape: BoxShape.circle),
            child: Icon(
                isIntake ? Icons.water_drop_rounded : Icons.opacity_rounded,
                color: color,
                size: 22),
          ),
          title: Text('${e.amountMl} mL',
              style: Theme.of(context).textTheme.titleMedium),
          subtitle: Text('${isIntake ? 'Intake' : 'Output'}  ·  $time',
              style: Theme.of(context).textTheme.labelMedium),
          trailing: Icon(Icons.edit_outlined,
              color: cs.onSurfaceVariant, size: 20),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final p = context.watch<FluidProvider>();
    final limit = context.watch<SettingsProvider>().fluidLimitMl;
    final t = _totals(p);
    return Scaffold(
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 96),
        children: [
          _gaugeCard(t.intake, limit),
          _encouragement(t.intake, limit),
          const SizedBox(height: 12),
          _totalsRow(t.intake, t.output),
          const SizedBox(height: 16),
          for (final e in p.entries) _row(e),
          if (p.entries.isEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 32),
              child: Center(
                child: Column(children: [
                  Icon(Icons.local_drink_outlined,
                      size: 44,
                      color: Theme.of(context).colorScheme.onSurfaceVariant),
                  const SizedBox(height: 10),
                  Text('No fluid logged today',
                      style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 2),
                  Text('Use the buttons below to add intake or output.',
                      style: Theme.of(context).textTheme.bodyMedium),
                ]),
              ),
            ),
        ],
      ),
      floatingActionButton: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          FloatingActionButton.extended(
              heroTag: 'in',
              backgroundColor: AppColors.water,
              icon: const Icon(Icons.add),
              onPressed: () => _add(FluidType.intake),
              label: const Text('Intake')),
          const SizedBox(width: 12),
          FloatingActionButton.extended(
              heroTag: 'out',
              icon: const Icon(Icons.add),
              onPressed: () => _add(FluidType.output),
              label: const Text('Output')),
        ],
      ),
    );
  }
}

/// A 270° arc gauge: faint track behind, status-colored progress on top.
class _RingPainter extends CustomPainter {
  _RingPainter({required this.ratio, required this.color, required this.track});
  final double ratio;
  final Color color;
  final Color track;

  static const _start = math.pi * 0.75; // 135°
  static const _sweep = math.pi * 1.5; // 270°

  @override
  void paint(Canvas canvas, Size size) {
    const stroke = 20.0;
    final rect = Rect.fromLTWH(
        stroke / 2, stroke / 2, size.width - stroke, size.height - stroke);
    final base = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round
      ..color = track;
    canvas.drawArc(rect, _start, _sweep, false, base);
    if (ratio > 0) {
      final prog = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke
        ..strokeCap = StrokeCap.round
        ..color = color;
      canvas.drawArc(rect, _start, _sweep * ratio, false, prog);
    }
  }

  @override
  bool shouldRepaint(_RingPainter old) =>
      old.ratio != ratio || old.color != color || old.track != track;
}
