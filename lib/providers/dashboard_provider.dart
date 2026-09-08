// Collaborators are injected as `dynamic` named params (a deliberate test seam
// per the plan) so private fields must be set in the initializer list, not via
// initializing formals — the lint's suggested fix does not apply here.
// ignore_for_file: prefer_initializing_formals
import 'package:flutter/foundation.dart';
import 'package:ckd_care/models/dose_log.dart';
import 'package:ckd_care/models/fluid_entry.dart';
import 'package:ckd_care/repositories/fluid_repository.dart';

class DueDose {
  const DueDose({
    required this.medicineId,
    required this.medicineName,
    required this.stockQty,
    required this.timeOfDay,
    required this.scheduledTime,
    required this.status,
  });
  final int medicineId;
  final String medicineName;
  final int stockQty;
  final String timeOfDay;
  final DateTime scheduledTime;
  final DoseStatus? status;
}

class DashboardProvider extends ChangeNotifier {
  DashboardProvider({
    required dynamic fluid,
    required dynamic settings,
    required dynamic medicine,
    // Accepted for API stability (constructed with a notifications
    // collaborator by callers/tests) but no longer used: markDose must not
    // touch scheduling (see Fix 3).
    required dynamic notifications,
    DateTime Function()? now,
  }) : _fluid = fluid,
       _settings = settings,
       _medicine = medicine,
       _now = now ?? DateTime.now;

  final dynamic _fluid;
  final dynamic _settings;
  final dynamic _medicine;
  final DateTime Function() _now;

  DailyFluidTotals? fluidTotals;
  int? fluidLimitMl;
  List<DueDose> dueDoses = const [];

  DateTime? _selectedDate;
  DateTime get selectedDate {
    final base = _selectedDate ?? _now();
    return DateTime(base.year, base.month, base.day);
  }

  bool get isToday {
    final t = _now();
    return selectedDate == DateTime(t.year, t.month, t.day);
  }

  Future<void> selectDate(DateTime d) async {
    _selectedDate = DateTime(d.year, d.month, d.day);
    await refresh();
  }

  Future<void> previousDay() =>
      selectDate(selectedDate.subtract(const Duration(days: 1)));
  Future<void> nextDay() =>
      selectDate(selectedDate.add(const Duration(days: 1)));

  Future<void> refresh() async {
    final today = selectedDate;
    final day = FluidEntry.dayOf(today);
    fluidTotals = await _fluid.totalsForDay(day);
    fluidLimitMl = await _settings.getFluidLimitMl();

    final meds = await _medicine.dashboardMedicines(day);
    final due = <DueDose>[];
    for (final m in meds) {
      final times = await _medicine.timesFor(m.id);
      for (final t in times) {
        final parts = (t.timeOfDay as String).split(':');
        final scheduled = DateTime(
          today.year,
          today.month,
          today.day,
          int.parse(parts[0]),
          int.parse(parts[1]),
        );
        final status = await _medicine.statusFor(m.id, scheduled);
        due.add(
          DueDose(
            medicineId: m.id,
            medicineName: m.name,
            stockQty: m.stockQty,
            timeOfDay: t.timeOfDay,
            scheduledTime: scheduled,
            status: status,
          ),
        );
      }
    }
    due.sort((a, b) => a.scheduledTime.compareTo(b.scheduledTime));
    dueDoses = due;
    notifyListeners();
  }

  Future<void> markDose(DueDose dose, DoseStatus status) async {
    await _medicine.logDose(dose.medicineId, dose.scheduledTime, status);
    await refresh();
  }
}
