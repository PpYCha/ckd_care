import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:ckd_care/models/dose_log.dart';
import 'package:ckd_care/models/fluid_entry.dart';
import 'package:ckd_care/providers/dashboard_provider.dart';
import 'package:ckd_care/providers/fluid_provider.dart';
import 'package:ckd_care/widgets/dose_tile.dart';
import 'package:ckd_care/widgets/fluid_amount_dialog.dart';
import 'package:ckd_care/widgets/fluid_gauge.dart';
import 'package:ckd_care/theme/app_theme.dart';

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

  /// A dose on a future date isn't due yet — marking it would change current
  /// stock for something not consumed, so disallow it. Past dates (back-fill)
  /// and today are fine.
  bool _isFutureDate(DashboardProvider d) {
    final t = DateTime.now();
    return d.selectedDate.isAfter(DateTime(t.year, t.month, t.day));
  }

  Future<void> _mark(DueDose dose, DoseStatus status) async {
    final dash = context.read<DashboardProvider>();
    if (_isFutureDate(dash)) return; // guarded; the toggle is also disabled
    final messenger = ScaffoldMessenger.of(context);
    await dash.markDose(dose, status);
    messenger.showSnackBar(SnackBar(
        content: Text(
            status == DoseStatus.taken ? 'Marked as taken' : 'Marked as skipped')));
  }

  String _dateLabel(DashboardProvider d) {
    if (d.isToday) return 'Today';
    final t = DateTime.now();
    final yesterday = DateTime(t.year, t.month, t.day)
        .subtract(const Duration(days: 1));
    if (d.selectedDate == yesterday) return 'Yesterday';
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    final sd = d.selectedDate;
    return '${months[sd.month - 1]} ${sd.day}, ${sd.year}';
  }

  List<DueDose> _bucket(List<DueDose> all, int startH, int endH) =>
      all.where((x) => x.scheduledTime.hour >= startH && x.scheduledTime.hour < endH)
          .toList();

  Widget _dateBar(DashboardProvider d) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.line),
      ),
      child: Row(children: [
        IconButton(
            icon: const Icon(Icons.chevron_left, color: AppColors.inkSoft),
            onPressed: () => context.read<DashboardProvider>().previousDay()),
        Expanded(
          child: TextButton.icon(
            onPressed: _pickDate,
            icon: const Icon(Icons.calendar_today_rounded, size: 17),
            label: Text(_dateLabel(d),
                style: const TextStyle(
                    fontFamily: 'Nunito',
                    fontSize: 16,
                    fontWeight: FontWeight.w800)),
          ),
        ),
        IconButton(
            icon: const Icon(Icons.chevron_right, color: AppColors.inkSoft),
            onPressed: () => context.read<DashboardProvider>().nextDay()),
      ]),
    );
  }

  Widget _fluidStats(DashboardProvider d) {
    final t = d.fluidTotals;
    Widget stat(String label, int value, Color color) => Expanded(
          child: Column(children: [
            Text('$value',
                style: TextStyle(
                    fontFamily: 'Nunito',
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: color)),
            Text(label, style: Theme.of(context).textTheme.labelMedium),
          ]),
        );
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
        child: Column(children: [
          Row(children: [
            stat('Intake mL', t?.intakeMl ?? 0, AppColors.water),
            _vRule(),
            stat('Output mL', t?.outputMl ?? 0, AppColors.inkSoft),
            _vRule(),
            stat('Net mL', t?.netMl ?? 0, AppColors.primary),
          ]),
          if (d.isToday) ...[
            const SizedBox(height: 14),
            Row(children: [
              Expanded(
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('Intake'),
                  onPressed: () => _quickAddFluid(FluidType.intake),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('Output'),
                  onPressed: () => _quickAddFluid(FluidType.output),
                ),
              ),
            ]),
          ],
        ]),
      ),
    );
  }

  Widget _vRule() => Container(
      width: 1, height: 34, color: AppColors.line,
      margin: const EdgeInsets.symmetric(horizontal: 8));

  Widget _section(String title, IconData icon, List<DueDose> doses,
      {required bool canMark}) {
    if (doses.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 14, bottom: 8),
          child: Row(children: [
            Icon(icon, size: 18, color: AppColors.primary),
            const SizedBox(width: 8),
            Text(title.toUpperCase(),
                style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(width: 8),
            Text('${doses.length}',
                style: Theme.of(context).textTheme.labelMedium),
          ]),
        ),
        ...doses.map((dose) => DoseTile(
            dose: dose, enabled: canMark, onMark: (s) => _mark(dose, s))),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final d = context.watch<DashboardProvider>();
    final canMark = !_isFutureDate(d);
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      children: [
        _dateBar(d),
        FluidGauge(
            intakeMl: d.fluidTotals?.intakeMl ?? 0, limitMl: d.fluidLimitMl),
        const SizedBox(height: 12),
        _fluidStats(d),
        const SizedBox(height: 8),
        Padding(
          padding: const EdgeInsets.only(top: 12, bottom: 2),
          child: Text('Medicines', style: Theme.of(context).textTheme.titleLarge),
        ),
        _section('Morning', Icons.wb_twilight_rounded,
            _bucket(d.dueDoses, 0, 12), canMark: canMark),
        _section('Afternoon', Icons.wb_sunny_rounded,
            _bucket(d.dueDoses, 12, 17), canMark: canMark),
        _section('Evening', Icons.nightlight_round,
            _bucket(d.dueDoses, 17, 24), canMark: canMark),
        if (d.dueDoses.isEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 24),
            child: Center(
              child: Column(children: [
                const Icon(Icons.medication_outlined,
                    size: 40, color: AppColors.inkSoft),
                const SizedBox(height: 8),
                Text('No medicines scheduled',
                    style: Theme.of(context).textTheme.bodyMedium),
              ]),
            ),
          ),
      ],
    );
  }
}
