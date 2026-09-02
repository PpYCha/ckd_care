import 'package:flutter_test/flutter_test.dart';
import 'package:ckd_care/models/dose_log.dart';
import 'package:ckd_care/models/medicine.dart';
import 'package:ckd_care/providers/dashboard_provider.dart';
import 'package:ckd_care/repositories/fluid_repository.dart';

// Minimal fakes implementing only what DashboardProvider calls.
class _FakeFluid implements FluidRepository {
  @override
  Future<DailyFluidTotals> totalsForDay(String day) async =>
      const DailyFluidTotals(intakeMl: 650, outputMl: 200);
  @override
  noSuchMethod(Invocation i) => super.noSuchMethod(i);
}

class _FakeSettings {
  Future<int?> getFluidLimitMl() async => 1000;
}

class _FakeMedicine {
  final logged = <String>[];
  Future<List<Medicine>> activeMedicines() async => [
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
  Future<DoseStatus?> statusFor(int id, DateTime t) async => null;
  Future<void> logDose(int id, DateTime t, DoseStatus s) async =>
      logged.add('$id|$s');
}

class _FakeNotifications {
  final cancelled = <String>[];
  Future<void> cancelDose(int medicineId, String timeOfDay) async =>
      cancelled.add('$medicineId|$timeOfDay');
}

void main() {
  test('refresh aggregates fluid + due doses for today', () async {
    final p = DashboardProvider(
      fluid: _FakeFluid(),
      settings: _FakeSettings(),
      medicine: _FakeMedicine(),
      notifications: _FakeNotifications(),
      now: () => DateTime(2026, 9, 2, 12),
    );
    await p.refresh();

    expect(p.fluidTotals!.intakeMl, 650);
    expect(p.fluidLimitMl, 1000);
    expect(p.dueToday.single.medicineName, 'Losartan');
    expect(p.dueToday.single.scheduledTime, DateTime(2026, 9, 2, 8));
  });

  test('markDose logs the dose and does not touch scheduling', () async {
    final meds = _FakeMedicine();
    final notes = _FakeNotifications();
    final p = DashboardProvider(
      fluid: _FakeFluid(),
      settings: _FakeSettings(),
      medicine: meds,
      notifications: notes,
      now: () => DateTime(2026, 9, 2, 12),
    );
    await p.refresh();
    await p.markDose(p.dueToday.single, DoseStatus.taken);

    expect(meds.logged, ['1|DoseStatus.taken']);
    expect(notes.cancelled, isEmpty);
  });
}
