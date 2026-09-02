import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:ckd_care/models/fluid_entry.dart';
import 'package:ckd_care/providers/fluid_provider.dart';
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

  @override
  Widget build(BuildContext context) {
    final p = context.watch<FluidProvider>();
    return Scaffold(
      body: ListView(children: [
        for (final e in p.entries)
          Dismissible(
            key: ValueKey(e.id),
            direction: DismissDirection.endToStart,
            background: Container(
              color: Colors.red,
              alignment: Alignment.centerRight,
              padding: const EdgeInsets.only(right: 16),
              child: const Icon(Icons.delete, color: Colors.white),
            ),
            onDismissed: (_) => context.read<FluidProvider>().remove(e.id!),
            child: ListTile(
              leading: Icon(e.type == FluidType.intake
                  ? Icons.water_drop
                  : Icons.opacity_outlined),
              title: Text('${e.amountMl} mL'),
              subtitle: Text('${e.type.name} • '
                  '${e.loggedAt.hour.toString().padLeft(2, '0')}:'
                  '${e.loggedAt.minute.toString().padLeft(2, '0')}'),
              trailing: const Icon(Icons.edit),
              onTap: () => _edit(e),
            ),
          ),
        if (p.entries.isEmpty) const ListTile(title: Text('No entries today')),
      ]),
      floatingActionButton: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          FloatingActionButton.extended(
              heroTag: 'in',
              onPressed: () => _add(FluidType.intake),
              label: const Text('Intake')),
          const SizedBox(width: 12),
          FloatingActionButton.extended(
              heroTag: 'out',
              onPressed: () => _add(FluidType.output),
              label: const Text('Output')),
        ],
      ),
    );
  }
}
