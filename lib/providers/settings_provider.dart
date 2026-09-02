import 'package:flutter/foundation.dart';
import 'package:ckd_care/repositories/settings_repository.dart';

class SettingsProvider extends ChangeNotifier {
  SettingsProvider(this._repo);
  final SettingsRepository _repo;

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
    notifyListeners();
  }
}
