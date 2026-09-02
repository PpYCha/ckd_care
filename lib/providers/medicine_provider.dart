import 'package:flutter/foundation.dart';
import 'package:ckd_care/models/medicine.dart';
import 'package:ckd_care/repositories/medicine_repository.dart';
import 'package:ckd_care/repositories/settings_repository.dart';
import 'package:ckd_care/services/notification_service.dart';

class MedicineProvider extends ChangeNotifier {
  MedicineProvider(this._repo, this._notifications, this._settingsRepo);
  final MedicineRepository _repo;
  final NotificationService _notifications;
  final SettingsRepository _settingsRepo;

  List<Medicine> medicines = const [];

  Future<void> load() async {
    medicines = await _repo.activeMedicines();
    notifyListeners();
  }

  Future<void> save(Medicine med, List<String> times) async {
    final id = await _repo.saveMedicine(med, times);
    if (await _settingsRepo.getNotificationsEnabled()) {
      await _notifications.scheduleForMedicine(id, await _repo.timesFor(id));
    }
    await load();
  }

  Future<void> deactivate(Medicine med) async {
    final times = await _repo.timesFor(med.id!);
    await _repo.deactivate(med.id!);
    await _notifications.cancelForMedicine(med.id!, times);
    await load();
  }
}
