import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:ckd_care/models/medicine.dart';
import 'package:ckd_care/providers/dashboard_provider.dart';
import 'package:ckd_care/providers/medicine_provider.dart';
import 'package:ckd_care/screens/medicine_detail_screen.dart';
import 'package:ckd_care/theme/app_theme.dart';

class MedicinesScreen extends StatefulWidget {
  const MedicinesScreen({super.key});
  @override
  State<MedicinesScreen> createState() => _MedicinesScreenState();
}

class _MedicinesScreenState extends State<MedicinesScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => context.read<MedicineProvider>().load(),
    );
  }

  /// Opens add/edit and shows a confirmation toast based on the returned result.
  /// The toast is shown here (not in the detail screen) so the messenger belongs
  /// to a widget that stays mounted after the detail route pops.
  Future<void> _openDetail(Medicine? medicine) async {
    final medicines = context.read<MedicineProvider>();
    final dashboard = context.read<DashboardProvider>();
    final result = await Navigator.push<String>(
      context,
      MaterialPageRoute(
        builder: (_) => MedicineDetailScreen(medicine: medicine),
      ),
    );
    if (!mounted || result == null) return;
    await medicines.load();
    await dashboard.refresh();
    if (!mounted) return;
    final msg = switch (result) {
      'added' => 'Medicine added',
      'updated' => 'Medicine updated',
      'deleted' => 'Medicine deleted',
      _ => null,
    };
    if (msg != null) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(msg)));
    }
  }

  Widget _stockBadge(int stock) {
    final (label, color) = stock == 0
        ? ('Out of stock', AppColors.over)
        : stock <= 7
        ? ('Low · $stock', AppColors.warn)
        : ('Stock $stock', AppColors.good);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontFamily: 'Nunito',
          fontSize: 12,
          fontWeight: FontWeight.w800,
          color: color,
        ),
      ),
    );
  }

  Widget _card(Medicine m, List<String> times) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: cs.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: BorderSide(color: cs.outlineVariant),
        ),
        clipBehavior: Clip.antiAlias,
        child: ListTile(
          contentPadding: const EdgeInsets.fromLTRB(14, 8, 14, 8),
          onTap: () => _openDetail(m),
          leading: Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: AppColors.medicine.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.medication_rounded,
              color: AppColors.medicine,
              size: 24,
            ),
          ),
          title: Text(m.name, style: Theme.of(context).textTheme.titleMedium),
          subtitle: Padding(
            padding: const EdgeInsets.only(top: 3),
            child: Text(
              [
                if (times.isNotEmpty)
                  '${times.length}× daily · ${times.join(', ')}',
                if (m.endDate != null) 'Until ${Medicine.fmtDate(m.endDate!)}',
              ].join('  ·  '),
              style: Theme.of(context).textTheme.labelMedium,
            ),
          ),
          trailing: _stockBadge(m.stockQty),
        ),
      ),
    );
  }

  Widget _section(
    String title,
    List<Medicine> medicines,
    Map<int, List<String>> timesByMedicine,
  ) {
    if (medicines.isEmpty) return const SizedBox.shrink();
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(2, 12, 2, 10),
          child: Row(
            children: [
              Text(
                '$title (${medicines.length})',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(child: Divider(color: cs.outlineVariant, height: 1)),
            ],
          ),
        ),
        for (final m in medicines) _card(m, timesByMedicine[m.id] ?? const []),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final p = context.watch<MedicineProvider>();
    final maintenance = p.medicines
        .where((m) => !m.consumeUntilEmpty)
        .toList(growable: false);
    final toBeConsumed = p.medicines
        .where((m) => m.consumeUntilEmpty)
        .toList(growable: false);

    return Scaffold(
      body: p.medicines.isEmpty
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.medication_outlined,
                    size: 46,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'No medicines yet',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Tap + to add your first medicine.',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ],
              ),
            )
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 2, 16, 96),
              children: [
                _section('Maintenance', maintenance, p.timesByMedicine),
                _section('To be consumed', toBeConsumed, p.timesByMedicine),
              ],
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openDetail(null),
        backgroundColor: AppColors.medicine,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: const Text('Add medicine'),
      ),
    );
  }
}
