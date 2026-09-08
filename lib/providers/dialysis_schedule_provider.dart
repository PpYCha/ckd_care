import 'package:flutter/foundation.dart';
import 'package:ckd_care/models/dialysis_schedule.dart';
import 'package:ckd_care/repositories/settings_repository.dart';

class DialysisScheduleProvider extends ChangeNotifier {
  DialysisScheduleProvider(this._repo);
  final SettingsRepository _repo;

  DialysisSchedule schedule = const DialysisSchedule(
    weekdays: {},
    timeOfDay: '09:00',
    durationHours: 4,
    clinicName: '',
    clinicAddress: '',
  );

  Future<void> load() async {
    schedule = await _repo.getDialysisSchedule();
    notifyListeners();
  }

  Future<void> save(DialysisSchedule s) async {
    await _repo.saveDialysisSchedule(s);
    schedule = s;
    notifyListeners();
  }

  Future<void> clear() async {
    await _repo.clearDialysisSchedule();
    schedule = await _repo.getDialysisSchedule();
    notifyListeners();
  }
}
