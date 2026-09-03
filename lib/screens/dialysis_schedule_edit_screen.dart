// lib/screens/dialysis_schedule_edit_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:ckd_care/models/dialysis_center.dart';
import 'package:ckd_care/models/dialysis_schedule.dart';
import 'package:ckd_care/providers/dialysis_schedule_provider.dart';
import 'package:ckd_care/screens/dialysis_center_picker_screen.dart';
import 'package:ckd_care/theme/app_theme.dart';

class DialysisScheduleEditScreen extends StatefulWidget {
  const DialysisScheduleEditScreen({super.key});
  @override
  State<DialysisScheduleEditScreen> createState() =>
      _DialysisScheduleEditScreenState();
}

class _DialysisScheduleEditScreenState
    extends State<DialysisScheduleEditScreen> {
  late Set<int> _weekdays;
  late TimeOfDay _time;
  late int _duration;
  late final TextEditingController _clinic;
  late final TextEditingController _address;

  @override
  void initState() {
    super.initState();
    final s = context.read<DialysisScheduleProvider>().schedule;
    _weekdays = {...s.weekdays};
    final parts = s.timeOfDay.split(':');
    _time = TimeOfDay(
        hour: int.tryParse(parts[0]) ?? 9, minute: int.tryParse(parts[1]) ?? 0);
    _duration = s.durationHours;
    _clinic = TextEditingController(text: s.clinicName);
    _address = TextEditingController(text: s.clinicAddress);
  }

  @override
  void dispose() {
    _clinic.dispose();
    _address.dispose();
    super.dispose();
  }

  Future<void> _pickTime() async {
    final t = await showTimePicker(context: context, initialTime: _time);
    if (t != null) setState(() => _time = t);
  }

  Future<void> _pickCenter() async {
    final center = await Navigator.push<DialysisCenter>(
      context,
      MaterialPageRoute(builder: (_) => const DialysisCenterPickerScreen()),
    );
    if (center == null || !mounted) return;
    setState(() {
      _clinic.text = center.name;
      _address.text = center.address;
    });
  }

  Future<void> _save() async {
    if (_weekdays.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Pick at least one day')));
      return;
    }
    final navigator = Navigator.of(context);
    final hh = _time.hour.toString().padLeft(2, '0');
    final mm = _time.minute.toString().padLeft(2, '0');
    await context.read<DialysisScheduleProvider>().save(DialysisSchedule(
          weekdays: _weekdays,
          timeOfDay: '$hh:$mm',
          durationHours: _duration,
          clinicName: _clinic.text.trim(),
          clinicAddress: _address.text.trim(),
        ));
    navigator.pop();
  }

  Future<void> _clear() async {
    final navigator = Navigator.of(context);
    await context.read<DialysisScheduleProvider>().clear();
    navigator.pop();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final hadSchedule = context.read<DialysisScheduleProvider>().schedule.isSet;

    return Scaffold(
      appBar: AppBar(title: const Text('Dialysis schedule')),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        Text('DAYS', style: text.titleSmall),
        const SizedBox(height: 8),
        Wrap(spacing: 8, runSpacing: 8, children: [
          for (var d = 1; d <= 7; d++)
            FilterChip(
              label: Text(kWeekdayAbbr[d - 1]),
              selected: _weekdays.contains(d),
              onSelected: (on) => setState(
                  () => on ? _weekdays.add(d) : _weekdays.remove(d)),
            ),
        ]),
        const SizedBox(height: 20),
        Text('TIME', style: text.titleSmall),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          icon: const Icon(Icons.access_time_rounded),
          label: Text(formatTime12(DateTime(2026, 1, 1, _time.hour, _time.minute))),
          onPressed: _pickTime,
        ),
        const SizedBox(height: 20),
        Text('DURATION', style: text.titleSmall),
        const SizedBox(height: 8),
        DropdownButtonFormField<int>(
          initialValue: _duration,
          decoration: const InputDecoration(border: OutlineInputBorder()),
          items: [
            for (var h = 1; h <= 8; h++)
              DropdownMenuItem(value: h, child: Text('$h hour${h == 1 ? '' : 's'}')),
          ],
          onChanged: (v) => setState(() => _duration = v ?? _duration),
        ),
        const SizedBox(height: 20),
        Text('CLINIC', style: text.titleSmall),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          icon: const Icon(Icons.search_rounded),
          label: const Text('Choose from accredited centers'),
          onPressed: _pickCenter,
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _clinic,
          decoration: const InputDecoration(
              labelText: 'Clinic name', border: OutlineInputBorder()),
        ),
        const SizedBox(height: 14),
        TextField(
          controller: _address,
          decoration: const InputDecoration(
              labelText: 'Clinic address (optional)',
              border: OutlineInputBorder()),
        ),
        const SizedBox(height: 24),
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: AppColors.dialysis),
          onPressed: _save,
          child: const Text('Save schedule'),
        ),
        if (hadSchedule) ...[
          const SizedBox(height: 8),
          TextButton(
            onPressed: _clear,
            child: Text('Remove schedule',
                style: TextStyle(color: cs.error)),
          ),
        ],
      ]),
    );
  }
}
