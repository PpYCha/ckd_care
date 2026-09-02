import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:ckd_care/models/fluid_entry.dart';
import 'package:ckd_care/providers/fluid_provider.dart';

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

  Future<void> _addDialog(FluidType type) async {
    final controller = TextEditingController();
    final ml = await showDialog<int>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Add ${type.name} (mL)'),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          autofocus: true,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          TextButton(
              onPressed: () => Navigator.pop(ctx, int.tryParse(controller.text)),
              child: const Text('Add')),
        ],
      ),
    );
    if (ml != null && ml > 0 && mounted) {
      await context.read<FluidProvider>().add(type, ml);
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = context.watch<FluidProvider>();
    return Scaffold(
      body: ListView(children: [
        for (final e in p.entries)
          Dismissible(
            key: ValueKey(e.id),
            onDismissed: (_) => context.read<FluidProvider>().remove(e.id!),
            child: ListTile(
              leading: Icon(e.type == FluidType.intake
                  ? Icons.water_drop
                  : Icons.opacity_outlined),
              title: Text('${e.amountMl} mL'),
              subtitle: Text('${e.type.name} • '
                  '${e.loggedAt.hour.toString().padLeft(2, '0')}:'
                  '${e.loggedAt.minute.toString().padLeft(2, '0')}'),
            ),
          ),
        if (p.entries.isEmpty) const ListTile(title: Text('No entries today')),
      ]),
      floatingActionButton: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          FloatingActionButton.extended(
              heroTag: 'in',
              onPressed: () => _addDialog(FluidType.intake),
              label: const Text('Intake')),
          const SizedBox(width: 12),
          FloatingActionButton.extended(
              heroTag: 'out',
              onPressed: () => _addDialog(FluidType.output),
              label: const Text('Output')),
        ],
      ),
    );
  }
}
