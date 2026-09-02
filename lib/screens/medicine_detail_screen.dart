import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:ckd_care/db/ids.dart';
import 'package:ckd_care/models/medicine.dart';
import 'package:ckd_care/providers/medicine_provider.dart';

/// Add/edit a medicine. `medicine == null` means create.
class MedicineDetailScreen extends StatefulWidget {
  const MedicineDetailScreen({super.key, required this.medicine});
  final Medicine? medicine;
  @override
  State<MedicineDetailScreen> createState() => _MedicineDetailScreenState();
}

class _MedicineDetailScreenState extends State<MedicineDetailScreen> {
  late final TextEditingController _name =
      TextEditingController(text: widget.medicine?.name ?? '');
  late final TextEditingController _dosage =
      TextEditingController(text: widget.medicine?.dosage ?? '');
  final List<String> _times = [];

  Future<void> _pickTime() async {
    final t = await showTimePicker(context: context, initialTime: TimeOfDay.now());
    if (t != null) {
      setState(() => _times.add(
          '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}'));
    }
  }

  Future<void> _save() async {
    if (_name.text.trim().isEmpty || _times.isEmpty) return;
    final med = Medicine(
      id: widget.medicine?.id,
      uuid: widget.medicine?.uuid ?? newUuid(),
      name: _name.text.trim(),
      dosage: _dosage.text.trim().isEmpty ? null : _dosage.text.trim(),
      stockQty: widget.medicine?.stockQty ?? 0,
      endDate: widget.medicine?.endDate,
      createdAt: widget.medicine?.createdAt ?? DateTime.now(),
      updatedAt: DateTime.now(),
    );
    await context.read<MedicineProvider>().save(med, _times..sort());
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.medicine == null ? 'Add medicine' : 'Edit medicine'),
        actions: [
          if (widget.medicine != null)
            IconButton(
              icon: const Icon(Icons.delete),
              onPressed: () async {
                final provider = context.read<MedicineProvider>();
                final navigator = Navigator.of(context);
                await provider.deactivate(widget.medicine!);
                if (mounted) navigator.pop();
              },
            ),
        ],
      ),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        TextField(controller: _name, decoration: const InputDecoration(labelText: 'Name')),
        TextField(controller: _dosage, decoration: const InputDecoration(labelText: 'Dosage')),
        const SizedBox(height: 16),
        Wrap(spacing: 8, children: [
          for (final t in _times) Chip(label: Text(t)),
          ActionChip(label: const Text('+ time'), onPressed: _pickTime),
        ]),
        const SizedBox(height: 24),
        FilledButton(onPressed: _save, child: const Text('Save')),
      ]),
    );
  }
}
