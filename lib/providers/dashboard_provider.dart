import 'package:flutter/foundation.dart';
import 'package:ckd_care/models/dose_log.dart';
import 'package:ckd_care/models/fluid_entry.dart';
import 'package:ckd_care/repositories/fluid_repository.dart';

class DueDose {
  const DueDose({
    required this.medicineId,
    required this.medicineName,
    required this.timeOfDay,
    required this.scheduledTime,
    required this.status,
  });
  final int medicineId;
  final String medicineName;
  final String timeOfDay;
  final DateTime scheduledTime;
  final DoseStatus? status;
}

class DashboardProvider extends ChangeNotifier {
  DashboardProvider({
    required dynamic fluid,
    required dynamic settings,
    required dynamic medicine,
    required dynamic notifications,
    DateTime Function()? now,
  })  : _fluid = fluid,
        _settings = settings,
        _medicine = medicine,
        _notifications = notifications,
        _now = now ?? DateTime.now;

  final dynamic _fluid;
  final dynamic _settings;
  final dynamic _medicine;
  final dynamic _notifications;
  final DateTime Function() _now;

  DailyFluidTotals? fluidTotals;
  int? fluidLimitMl;
  List<DueDose> dueToday = const [];

  Future<void> refresh() async {
    final today = _now();
    final day = FluidEntry.dayOf(today);
    fluidTotals = await _fluid.totalsForDay(day);
    fluidLimitMl = await _settings.getFluidLimitMl();

    final meds = await _medicine.activeMedicines();
    final due = <DueDose>[];
    for (final m in meds) {
      final times = await _medicine.timesFor(m.id);
      for (final t in times) {
        final parts = (t.timeOfDay as String).split(':');
        final scheduled = DateTime(today.year, today.month, today.day,
            int.parse(parts[0]), int.parse(parts[1]));
        final status = await _medicine.statusFor(m.id, scheduled);
        due.add(DueDose(
          medicineId: m.id,
          medicineName: m.name,
          timeOfDay: t.timeOfDay,
          scheduledTime: scheduled,
          status: status,
        ));
      }
    }
    due.sort((a, b) => a.scheduledTime.compareTo(b.scheduledTime));
    dueToday = due;
    notifyListeners();
  }

  Future<void> markDose(DueDose dose, DoseStatus status) async {
    await _medicine.logDose(dose.medicineId, dose.scheduledTime, status);
    await _notifications.cancelDose(dose.medicineId, dose.timeOfDay);
    await refresh();
  }
}
