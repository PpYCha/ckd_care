import 'package:sqflite/sqflite.dart';
import 'package:ckd_care/db/app_database.dart';

const String kFluidLimit = 'fluid_limit_ml';
const String kNotifications = 'notifications_enabled';

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
}
