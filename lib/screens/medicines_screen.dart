import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
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

  @override
  Widget build(BuildContext context) {
    final p = context.watch<MedicineProvider>();
    return Scaffold(
      body: ListView(children: [
        for (final m in p.medicines)
          ListTile(
            title: Text(m.name),
            subtitle: Text(m.dosage ?? ''),
            onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (_) => MedicineDetailScreen(medicine: m))),
          ),
        if (p.medicines.isEmpty) const ListTile(title: Text('No medicines yet')),
      ]),
      floatingActionButton: FloatingActionButton(
        onPressed: () => Navigator.push(
            context,
            MaterialPageRoute(
                builder: (_) => const MedicineDetailScreen(medicine: null))),
        child: const Icon(Icons.add),
      ),
    );
  }
}
