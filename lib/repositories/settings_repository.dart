import 'package:sqflite/sqflite.dart';
import 'package:ckd_care/db/app_database.dart';
import 'package:ckd_care/models/health_profile.dart';
import 'package:ckd_care/models/dialysis_schedule.dart';

const String kFluidLimit = 'fluid_limit_ml';
const String kNotifications = 'notifications_enabled';
const String kFoodDisclaimerAckVersion = 'food_disclaimer_ack_version';
const String kFoodDisclaimerAckAt = 'food_disclaimer_ack_at';
const String kProfileCkdStage = 'profile_ckd_stage';
const String kProfileDialysis = 'profile_dialysis';
const String kProfileDiabetes = 'profile_diabetes';
const String kProfileElevatedPotassium = 'profile_elevated_potassium';
const String kProfileElevatedPhosphorus = 'profile_elevated_phosphorus';
const String kProfileFluidRestriction = 'profile_fluid_restriction';
const String kDialysisSchedWeekdays = 'dialysis_sched_weekdays';
const String kDialysisSchedTime = 'dialysis_sched_time';
const String kDialysisSchedDuration = 'dialysis_sched_duration';
const String kDialysisSchedClinic = 'dialysis_sched_clinic';
const String kDialysisSchedClinicAddress = 'dialysis_sched_clinic_address';

class SettingsRepository {
  SettingsRepository(this._db);
  final AppDatabase _db;

  Future<String?> _get(String key) async {
    final db = await _db.database;
    final rows = await db.query('setting',
        columns: ['value'], where: 'key = ?', whereArgs: [key]);
    return rows.isEmpty ? null : rows.first['value'] as String;
  }

  Future<void> _set(String key, String value) async {
    final db = await _db.database;
    await db.insert('setting', {'key': key, 'value': value},
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<int?> getFluidLimitMl() async {
    final v = await _get(kFluidLimit);
    return v == null ? null : int.tryParse(v);
  }

  Future<void> setFluidLimitMl(int ml) => _set(kFluidLimit, ml.toString());

  Future<bool> getNotificationsEnabled() async =>
      (await _get(kNotifications) ?? 'true') == 'true';

  Future<void> setNotificationsEnabled(bool enabled) =>
      _set(kNotifications, enabled.toString());

  Future<String?> getFoodDisclaimerAckVersion() => _get(kFoodDisclaimerAckVersion);

  Future<void> setFoodDisclaimerAck(String version) async {
    await _set(kFoodDisclaimerAckVersion, version);
    await _set(kFoodDisclaimerAckAt, DateTime.now().toIso8601String());
  }

  Future<HealthProfile> getHealthProfile() async {
    Future<bool> flag(String key) async => (await _get(key)) == 'true';
    final dialysisName = await _get(kProfileDialysis);
    return HealthProfile(
      ckdStage: ckdStageFromNumber(await _get(kProfileCkdStage)),
      dialysisStatus: DialysisStatus.values.firstWhere(
        (d) => d.name == dialysisName,
        orElse: () => DialysisStatus.none,
      ),
      diabetes: await flag(kProfileDiabetes),
      elevatedPotassium: await flag(kProfileElevatedPotassium),
      elevatedPhosphorus: await flag(kProfileElevatedPhosphorus),
      fluidRestriction: await flag(kProfileFluidRestriction),
    );
  }

  Future<void> saveHealthProfile(HealthProfile p) async {
    await _set(kProfileCkdStage, ckdStageToStored(p.ckdStage));
    await _set(kProfileDialysis, p.dialysisStatus.name);
    await _set(kProfileDiabetes, p.diabetes.toString());
    await _set(kProfileElevatedPotassium, p.elevatedPotassium.toString());
    await _set(kProfileElevatedPhosphorus, p.elevatedPhosphorus.toString());
    await _set(kProfileFluidRestriction, p.fluidRestriction.toString());
  }

  Future<DialysisSchedule> getDialysisSchedule() async {
    return DialysisSchedule(
      weekdays: decodeWeekdays(await _get(kDialysisSchedWeekdays)),
      timeOfDay: await _get(kDialysisSchedTime) ?? '09:00',
      durationHours: int.tryParse(await _get(kDialysisSchedDuration) ?? '') ?? 4,
      clinicName: await _get(kDialysisSchedClinic) ?? '',
      clinicAddress: await _get(kDialysisSchedClinicAddress) ?? '',
    );
  }

  Future<void> saveDialysisSchedule(DialysisSchedule s) async {
    await _set(kDialysisSchedWeekdays, encodeWeekdays(s.weekdays));
    await _set(kDialysisSchedTime, s.timeOfDay);
    await _set(kDialysisSchedDuration, s.durationHours.toString());
    await _set(kDialysisSchedClinic, s.clinicName);
    await _set(kDialysisSchedClinicAddress, s.clinicAddress);
  }

  Future<void> clearDialysisSchedule() async {
    // Empty weekdays means "unset"; keep other keys harmless.
    await _set(kDialysisSchedWeekdays, '');
  }
}
