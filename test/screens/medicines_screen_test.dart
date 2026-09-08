import 'package:ckd_care/models/medicine.dart';
import 'package:ckd_care/providers/dashboard_provider.dart';
import 'package:ckd_care/providers/medicine_provider.dart';
import 'package:ckd_care/screens/medicines_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

class _SeededMedicineProvider extends ChangeNotifier
    implements MedicineProvider {
  _SeededMedicineProvider(this.medicines, this.timesByMedicine);

  @override
  List<Medicine> medicines;

  @override
  Map<int, List<String>> timesByMedicine;

  @override
  Future<void> load() async {}

  @override
  Future<void> deactivate(Medicine med) async {}

  @override
  Future<void> save(Medicine med, List<String> times) async {
    medicines = [
      for (final current in medicines)
        if (current.id == med.id) med else current,
    ];
    timesByMedicine = {...timesByMedicine, med.id!: times};
    notifyListeners();
  }

  @override
  Future<List<String>> timesForMedicine(int id) async =>
      timesByMedicine[id] ?? const [];
}

class _TrackingDashboardProvider extends DashboardProvider {
  _TrackingDashboardProvider()
    : super(
        fluid: Object(),
        settings: Object(),
        medicine: Object(),
        notifications: Object(),
      );

  int refreshCount = 0;

  @override
  Future<void> refresh() async {
    refreshCount++;
  }
}

void main() {
  testWidgets('groups medicines by maintenance and to be consumed', (
    tester,
  ) async {
    final now = DateTime(2026, 9, 7);
    final provider = _SeededMedicineProvider(
      [
        Medicine(
          id: 1,
          uuid: 'maintenance',
          name: 'Losartan',
          stockQty: 30,
          createdAt: now,
          updatedAt: now,
        ),
        Medicine(
          id: 2,
          uuid: 'course',
          name: 'Antibiotic',
          stockQty: 10,
          consumeUntilEmpty: true,
          createdAt: now,
          updatedAt: now,
        ),
      ],
      {
        1: ['08:00'],
        2: ['20:00'],
      },
    );

    await tester.pumpWidget(
      MaterialApp(
        home: ChangeNotifierProvider<MedicineProvider>.value(
          value: provider,
          child: const MedicinesScreen(),
        ),
      ),
    );
    await tester.pump();
    await tester.pump();

    expect(find.text('Maintenance (1)'), findsOneWidget);
    expect(find.text('To be consumed (1)'), findsOneWidget);
    expect(find.text('Losartan'), findsOneWidget);
    expect(find.text('Antibiotic'), findsOneWidget);
  });

  testWidgets('saving an edit refreshes the dashboard and shows confirmation', (
    tester,
  ) async {
    final now = DateTime(2026, 9, 8);
    final medicines = _SeededMedicineProvider(
      [
        Medicine(
          id: 1,
          uuid: 'losartan',
          name: 'Losartan',
          stockQty: 0,
          createdAt: now,
          updatedAt: now,
        ),
      ],
      {
        1: ['08:00'],
      },
    );
    final dashboard = _TrackingDashboardProvider();

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<MedicineProvider>.value(value: medicines),
          ChangeNotifierProvider<DashboardProvider>.value(value: dashboard),
        ],
        child: const MaterialApp(home: MedicinesScreen()),
      ),
    );
    await tester.pump();

    await tester.tap(find.text('Losartan'));
    await tester.pump();
    await tester.pump();
    await tester.enterText(find.byType(TextFormField).at(1), '10');
    await tester.tap(find.text('Save'));
    await tester.pump();
    await tester.pump();

    expect(find.text('Stock 10'), findsOneWidget);
    expect(find.text('Medicine updated'), findsOneWidget);
    expect(dashboard.refreshCount, 1);
  });
}
