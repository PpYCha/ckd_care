import 'package:flutter/foundation.dart';
import 'package:ckd_care/repositories/medicine_repository.dart';
import 'package:ckd_care/repositories/settings_repository.dart';
import 'package:ckd_care/services/notification_service.dart';

class SettingsProvider extends ChangeNotifier {
  SettingsProvider(this._repo, this._medicineRepo, this._notifications);
  final SettingsRepository _repo;
  final MedicineRepository _medicineRepo;
  final NotificationService _notifications;

  int? fluidLimitMl;
  bool notificationsEnabled = true;

  Future<void> load() async {
    fluidLimitMl = await _repo.getFluidLimitMl();
    notificationsEnabled = await _repo.getNotificationsEnabled();
    notifyListeners();
  }

  Future<void> setLimit(int ml) async {
    await _repo.setFluidLimitMl(ml);
    fluidLimitMl = ml;
    notifyListeners();
  }

  Future<void> setNotifications(bool v) async {
    await _repo.setNotificationsEnabled(v);
    notificationsEnabled = v;
    if (v) {
      for (final m in await _medicineRepo.activeMedicines()) {
        await _notifications.scheduleForMedicine(
            m.id!, await _medicineRepo.timesFor(m.id!));
      }
    } else {
      for (final m in await _medicineRepo.activeMedicines()) {
        await _notifications.cancelForMedicine(
            m.id!, await _medicineRepo.timesFor(m.id!));
      }
    }
    notifyListeners();
  }
}
