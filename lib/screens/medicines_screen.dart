import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:ckd_care/models/medicine.dart';
import 'package:ckd_care/providers/medicine_provider.dart';
import 'package:ckd_care/screens/medicine_detail_screen.dart';

class MedicinesScreen extends StatefulWidget {
  const MedicinesScreen({super.key});
  @override
  State<MedicinesScreen> createState() => _MedicinesScreenState();
}

class _MedicinesScreenState extends State<MedicinesScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance
        .addPostFrameCallback((_) => context.read<MedicineProvider>().load());
  }

  /// Opens add/edit and shows a confirmation toast based on the returned result.
  /// The toast is shown here (not in the detail screen) so the messenger belongs
  /// to a widget that stays mounted after the detail route pops.
  Future<void> _openDetail(Medicine? medicine) async {
    final messenger = ScaffoldMessenger.of(context);
    final result = await Navigator.push<String>(
      context,
      MaterialPageRoute(builder: (_) => MedicineDetailScreen(medicine: medicine)),
    );
    if (!mounted || result == null) return;
    final msg = switch (result) {
      'added' => 'Medicine added',
      'updated' => 'Medicine updated',
      'deleted' => 'Medicine deleted',
      _ => null,
    };
    if (msg != null) {
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(msg)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = context.watch<MedicineProvider>();
    return Scaffold(
      body: ListView(children: [
        for (final m in p.medicines)
          ListTile(
            title: Text(m.name),
            subtitle: Text([
              // Dosage = doses per day = number of reminder times.
              'Dosage: ${(p.timesByMedicine[m.id] ?? []).length}',
              if ((p.timesByMedicine[m.id] ?? []).isNotEmpty)
                (p.timesByMedicine[m.id] ?? []).join(', '),
              'Stock: ${m.stockQty}',
              if (m.endDate != null) 'Until ${Medicine.fmtDate(m.endDate!)}',
            ].join('  •  ')),
            trailing: m.stockQty == 0
                ? const Chip(label: Text('Out of stock'))
                : null,
            onTap: () => _openDetail(m),
          ),
        if (p.medicines.isEmpty) const ListTile(title: Text('No medicines yet')),
      ]),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _openDetail(null),
        child: const Icon(Icons.add),
      ),
    );
  }
}
