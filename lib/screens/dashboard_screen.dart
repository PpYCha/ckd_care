import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:ckd_care/providers/dashboard_provider.dart';
import 'package:ckd_care/widgets/dose_tile.dart';
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

  @override
  Widget build(BuildContext context) {
    final d = context.watch<DashboardProvider>();
    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        FluidGauge(
          intakeMl: d.fluidTotals?.intakeMl ?? 0,
          limitMl: d.fluidLimitMl,
        ),
        if (d.fluidTotals != null)
          Padding(
            padding: const EdgeInsets.all(8),
            child: Text(
              'Net balance: ${d.fluidTotals!.netMl} mL '
              '(out ${d.fluidTotals!.outputMl} mL)',
            ),
          ),
        const Divider(),
        Text(
          'Today\'s medicines',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        ...d.dueDoses.map(
          (dose) => DoseTile(
            dose: dose,
            onMark: (s) => context.read<DashboardProvider>().markDose(dose, s),
          ),
        ),
        if (d.dueDoses.isEmpty)
          const ListTile(title: Text('No medicines scheduled')),
      ],
    );
  }
}
