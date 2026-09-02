import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:ckd_care/models/fluid_entry.dart';
import 'package:ckd_care/providers/fluid_provider.dart';
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
    WidgetsBinding.instance.addPostFrameCallback((_) =>
        context.read<FluidProvider>().loadDay(FluidEntry.dayOf(DateTime.now())));
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

  Widget _summary(FluidProvider p) {
    final cs = Theme.of(context).colorScheme;
    var intake = 0, output = 0;
    for (final e in p.entries) {
      if (e.type == FluidType.intake) {
        intake += e.amountMl;
      } else {
        output += e.amountMl;
      }
    }
    Widget half(String label, int v, Color color) => Expanded(
          child: Column(children: [
            Text('$v mL',
                style: TextStyle(
                    fontFamily: 'Nunito',
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: color)),
            Text(label, style: Theme.of(context).textTheme.labelMedium),
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
    return Scaffold(
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 96),
        children: [
          _summary(p),
          const SizedBox(height: 16),
          for (final e in p.entries) _row(e),
          if (p.entries.isEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 48),
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
