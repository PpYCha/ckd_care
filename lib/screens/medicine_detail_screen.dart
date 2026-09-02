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
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _name =
      TextEditingController(text: widget.medicine?.name ?? '');
  late final TextEditingController _dosage =
      TextEditingController(text: widget.medicine?.dosage ?? '');
  late final TextEditingController _stock = TextEditingController(
      text: widget.medicine?.stockQty.toString() ?? '');
  final List<String> _times = [];
  DateTime? _endDate;
  bool _timesError = false;

  @override
  void initState() {
    super.initState();
    final m = widget.medicine;
    if (m != null) {
      _endDate = m.endDate;
      // Pre-load existing times for edit.
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        final times = await context.read<MedicineProvider>().timesForMedicine(m.id!);
        if (mounted) setState(() => _times..clear()..addAll(times));
      });
    }
  }

  Future<void> _pickTime() async {
    final t = await showTimePicker(context: context, initialTime: TimeOfDay.now());
    if (t != null) {
      setState(() {
        _times.add(
            '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}');
        _timesError = false;
      });
    }
  }

  Future<void> _pickEndDate() async {
    final now = DateTime.now();
    final d = await showDatePicker(
      context: context,
      initialDate: _endDate ?? now,
      firstDate: now.subtract(const Duration(days: 365)),
      lastDate: DateTime(now.year + 5),
    );
    if (d != null) setState(() => _endDate = d);
  }

  Future<void> _save() async {
    final formOk = _formKey.currentState!.validate();
    setState(() => _timesError = _times.isEmpty);
    if (!formOk || _times.isEmpty) return;

    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    final med = Medicine(
      id: widget.medicine?.id,
      uuid: widget.medicine?.uuid ?? newUuid(),
      name: _name.text.trim(),
      dosage: _dosage.text.trim().isEmpty ? null : _dosage.text.trim(),
      stockQty: int.parse(_stock.text.trim()),
      endDate: _endDate,
      createdAt: widget.medicine?.createdAt ?? DateTime.now(),
      updatedAt: DateTime.now(),
    );
    await context.read<MedicineProvider>().save(med, _times..sort());
    if (!mounted) return;
    navigator.pop();
    messenger.showSnackBar(
        const SnackBar(content: Text('Saved successfully')));
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
      body: Form(
        key: _formKey,
        child: ListView(padding: const EdgeInsets.all(16), children: [
          TextFormField(
            controller: _name,
            decoration: const InputDecoration(
                labelText: 'Name *', hintText: 'Required'),
            validator: (v) =>
                (v == null || v.trim().isEmpty) ? 'Name is required' : null,
          ),
          TextFormField(
            controller: _dosage,
            decoration: const InputDecoration(labelText: 'Dosage'),
          ),
          TextFormField(
            controller: _stock,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
                labelText: 'Stock quantity *', hintText: 'Required'),
            validator: (v) {
              final n = int.tryParse((v ?? '').trim());
              if (n == null) return 'Enter a whole number';
              if (n < 0) return 'Stock cannot be negative';
              return null;
            },
          ),
          const SizedBox(height: 16),
          Row(children: [
            Expanded(
              child: Text(_endDate == null
                  ? 'End date: none (indefinite)'
                  : 'Taken until ${Medicine.fmtDate(_endDate!)}'),
            ),
            if (_endDate != null)
              IconButton(
                  icon: const Icon(Icons.clear),
                  onPressed: () => setState(() => _endDate = null)),
            TextButton(onPressed: _pickEndDate, child: const Text('Set end date')),
          ]),
          const SizedBox(height: 8),
          const Text('Reminder times *'),
          Wrap(spacing: 8, children: [
            for (final t in _times)
              Chip(
                label: Text(t),
                onDeleted: () => setState(() => _times.remove(t)),
              ),
            ActionChip(label: const Text('+ time'), onPressed: _pickTime),
          ]),
          if (_timesError)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text('Add at least one time',
                  style: TextStyle(color: Theme.of(context).colorScheme.error)),
            ),
          const SizedBox(height: 24),
          FilledButton(onPressed: _save, child: const Text('Save')),
        ]),
      ),
    );
  }
}
