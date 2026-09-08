import 'package:flutter/foundation.dart';
import 'package:ckd_care/models/health_profile.dart';
import 'package:ckd_care/repositories/settings_repository.dart';

class HealthProfileProvider extends ChangeNotifier {
  HealthProfileProvider(this._repo);
  final SettingsRepository _repo;

  HealthProfile profile = const HealthProfile();

  Future<void> load() async {
    profile = await _repo.getHealthProfile();
    notifyListeners();
  }

  Future<void> save(HealthProfile p) async {
    await _repo.saveHealthProfile(p);
    profile = p;
    notifyListeners();
  }
}
