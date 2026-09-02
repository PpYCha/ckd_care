import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:ckd_care/models/dose_log.dart';
import 'package:ckd_care/models/fluid_entry.dart';
import 'package:ckd_care/providers/dashboard_provider.dart';
import 'package:ckd_care/providers/fluid_provider.dart';
import 'package:ckd_care/widgets/dose_tile.dart';
import 'package:ckd_care/widgets/fluid_amount_dialog.dart';
import 'package:ckd_care/widgets/fluid_gauge.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});
  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => context.read<DashboardProvider>().refresh(),
    );
  }

  Future<void> _pickDate() async {
    final d = context.read<DashboardProvider>();
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: d.selectedDate,
      firstDate: DateTime(now.year - 2),
      lastDate: DateTime(now.year + 2),
    );
    if (picked != null) await d.selectDate(picked);
  }

  Future<void> _quickAddFluid(FluidType type) async {
    final messenger = ScaffoldMessenger.of(context);
    final fluid = context.read<FluidProvider>();
    final dash = context.read<DashboardProvider>();
    final ml = await showFluidAmountDialog(context, title: 'Add ${type.name} (mL)');
    if (ml == null || !mounted) return;
    await fluid.add(type, ml);
    await dash.refresh();
    messenger.showSnackBar(SnackBar(
        content: Text('${type == FluidType.intake ? 'Intake' : 'Output'} added')));
  }

  Future<void> _mark(DueDose dose, DoseStatus status) async {
    final messenger = ScaffoldMessenger.of(context);
    await context.read<DashboardProvider>().markDose(dose, status);
    messenger.showSnackBar(SnackBar(
        content: Text(
            status == DoseStatus.taken ? 'Marked as taken' : 'Marked as skipped')));
  }

  String _dateLabel(DashboardProvider d) {
    if (d.isToday) return 'Today';
    return FluidEntry.dayOf(d.selectedDate);
  }

  List<DueDose> _bucket(List<DueDose> all, int startH, int endH) =>
      all.where((x) => x.scheduledTime.hour >= startH && x.scheduledTime.hour < endH)
          .toList();

  Widget _section(String title, List<DueDose> doses) {
    if (doses.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 8, left: 4, bottom: 2),
          child: Text(title, style: Theme.of(context).textTheme.titleSmall),
        ),
        ...doses.map((dose) => DoseTile(dose: dose, onMark: (s) => _mark(dose, s))),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final d = context.watch<DashboardProvider>();
    final totals = d.fluidTotals;
    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        // Date navigation bar.
        Row(children: [
          IconButton(
              icon: const Icon(Icons.chevron_left),
              onPressed: () => context.read<DashboardProvider>().previousDay()),
          Expanded(
            child: TextButton.icon(
              onPressed: _pickDate,
              icon: const Icon(Icons.calendar_today, size: 18),
              label: Text(_dateLabel(d)),
            ),
          ),
          IconButton(
              icon: const Icon(Icons.chevron_right),
              onPressed: () => context.read<DashboardProvider>().nextDay()),
        ]),
        FluidGauge(intakeMl: totals?.intakeMl ?? 0, limitMl: d.fluidLimitMl),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Intake: ${totals?.intakeMl ?? 0} mL   •   '
                  'Output: ${totals?.outputMl ?? 0} mL   •   '
                  'Net: ${totals?.netMl ?? 0} mL'),
              if (d.isToday)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Row(children: [
                    OutlinedButton.icon(
                      icon: const Icon(Icons.water_drop),
                      label: const Text('Intake'),
                      onPressed: () => _quickAddFluid(FluidType.intake),
                    ),
                    const SizedBox(width: 8),
                    OutlinedButton.icon(
                      icon: const Icon(Icons.opacity_outlined),
                      label: const Text('Output'),
                      onPressed: () => _quickAddFluid(FluidType.output),
                    ),
                  ]),
                ),
            ]),
          ),
        ),
        const Divider(),
        Text('Medicines', style: Theme.of(context).textTheme.titleMedium),
        _section('Morning', _bucket(d.dueDoses, 0, 12)),
        _section('Afternoon', _bucket(d.dueDoses, 12, 17)),
        _section('Evening', _bucket(d.dueDoses, 17, 24)),
        if (d.dueDoses.isEmpty)
          const ListTile(title: Text('No medicines scheduled')),
      ],
    );
  }
}
