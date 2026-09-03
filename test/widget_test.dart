import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:ckd_care/db/app_database.dart';
import 'package:ckd_care/models/medicine.dart';
import 'package:ckd_care/providers/dashboard_provider.dart';
import 'package:ckd_care/providers/dialysis_schedule_provider.dart';
import 'package:ckd_care/repositories/fluid_repository.dart';
import 'package:ckd_care/repositories/settings_repository.dart';
import 'package:ckd_care/screens/dashboard_screen.dart';
import 'package:ckd_care/widgets/fluid_gauge.dart';

class _FakeFluid {
  Future<DailyFluidTotals> totalsForDay(String day) async =>
      const DailyFluidTotals(intakeMl: 650, outputMl: 200);
}

class _FakeSettings {
  Future<int?> getFluidLimitMl() async => 1000;
}

class _FakeMedicine {
  Future<List<Medicine>> dashboardMedicines(String today) async => [
        Medicine(
            id: 1,
            uuid: 'u1',
            name: 'Losartan',
            stockQty: 10,
            createdAt: DateTime(2026, 9, 2),
            updatedAt: DateTime(2026, 9, 2))
      ];
  Future<List<MedicineTime>> timesFor(int id) async => [
        MedicineTime(
            uuid: 't1',
            medicineUuid: 'u1',
            timeOfDay: '08:00',
            updatedAt: DateTime(2026, 9, 2))
      ];
  Future<dynamic> statusFor(int id, DateTime t) async => null;
}

class _FakeNotifications {}

void main() {
  sqfliteFfiInit();

  testWidgets('dashboard renders gauge and due dose', (tester) async {
    // Use a phone-sized viewport so the (lazily built) medicine tile below the
    // greeting/hero header is in the tree for the finders.
    tester.view.physicalSize = const Size(1080, 2600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final provider = DashboardProvider(
      fluid: _FakeFluid(),
      settings: _FakeSettings(),
      medicine: _FakeMedicine(),
      notifications: _FakeNotifications(),
      now: () => DateTime(2026, 9, 2, 12),
    );
    final scheduleProvider = DialysisScheduleProvider(SettingsRepository(
        AppDatabase(databaseFactoryFfi, path: inMemoryDatabasePath)));
    await tester.pumpWidget(MaterialApp(
      home: MultiProvider(
        providers: [
          ChangeNotifierProvider<DashboardProvider>.value(value: provider),
          ChangeNotifierProvider<DialysisScheduleProvider>.value(
              value: scheduleProvider),
        ],
        child: const Scaffold(body: DashboardScreen()),
      ),
    ));
    await tester.pumpAndSettle();

    // Gauge renders today's intake vs limit (the "650" and "/ 1000 mL" spans).
    expect(find.byType(FluidGauge), findsOneWidget);
    expect(find.textContaining('650', findRichText: true), findsWidgets);
    expect(find.textContaining('1000', findRichText: true), findsWidgets);
    expect(find.textContaining('Losartan'), findsOneWidget);
  });
}
