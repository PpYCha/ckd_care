import 'package:ckd_care/db/app_database.dart';
import 'package:ckd_care/db/ids.dart';
import 'package:ckd_care/models/dose_log.dart';
import 'package:ckd_care/models/medicine.dart';

class MedicineRepository {
  MedicineRepository(this._db);
  final AppDatabase _db;

  Future<int> saveMedicine(Medicine med, List<String> times) async {
    final db = await _db.database;
    final now = DateTime.now().toIso8601String();
    return db.transaction((txn) async {
      final int id;
      if (med.id == null) {
        id = await txn.insert('medicine', med.toMap());
      } else {
        id = med.id!;
        await txn.update('medicine', med.toMap(),
            where: 'id = ?', whereArgs: [id]);
      }
      // Soft-delete existing time rows (sync tombstones), then insert new ones.
      await txn.update('medicine_time', {'deleted': 1, 'updated_at': now},
          where: 'medicine_id = ? AND deleted = 0', whereArgs: [id]);
      for (final t in times) {
        await txn.insert('medicine_time', {
          'uuid': newUuid(),
          'medicine_id': id,
          'time_of_day': t,
          'updated_at': now,
          'deleted': 0,
        });
      }
      return id;
    });
  }

  Future<List<Medicine>> activeMedicines() async {
    final db = await _db.database;
    final rows = await db.query('medicine',
        where: 'active = 1 AND deleted = 0', orderBy: 'name COLLATE NOCASE ASC');
    return rows.map(Medicine.fromMap).toList();
  }

  Future<List<MedicineTime>> timesFor(int medicineId) async {
    final db = await _db.database;
    final rows = await db.query('medicine_time',
        where: 'medicine_id = ? AND deleted = 0',
        whereArgs: [medicineId],
        orderBy: 'time_of_day ASC');
    return rows.map(MedicineTime.fromMap).toList();
  }

  Future<void> deactivate(int medicineId) async {
    final db = await _db.database;
    await db.update(
        'medicine',
        {'active': 0, 'updated_at': DateTime.now().toIso8601String()},
        where: 'id = ?',
        whereArgs: [medicineId]);
  }

  Future<void> logDose(int medicineId, DateTime scheduledTime, DoseStatus status) async {
    final db = await _db.database;
    final iso = scheduledTime.toIso8601String();
    final now = DateTime.now().toIso8601String();
    final existing = await db.query('dose_log',
        columns: ['id'],
        where: 'medicine_id = ? AND scheduled_time = ?',
        whereArgs: [medicineId, iso]);
    if (existing.isEmpty) {
      await db.insert('dose_log', {
        'uuid': newUuid(),
        'medicine_id': medicineId,
        'scheduled_time': iso,
        'status': status.name,
        'acted_at': now,
        'updated_at': now,
        'deleted': 0,
      });
    } else {
      await db.update('dose_log',
          {'status': status.name, 'acted_at': now, 'updated_at': now},
          where: 'id = ?', whereArgs: [existing.first['id']]);
    }
  }

  Future<List<DoseLog>> dosesForMedicine(int medicineId) async {
    final db = await _db.database;
    final rows = await db.query('dose_log',
        where: 'medicine_id = ? AND deleted = 0', whereArgs: [medicineId],
        orderBy: 'scheduled_time DESC');
    return rows.map(DoseLog.fromMap).toList();
  }

  Future<DoseStatus?> statusFor(int medicineId, DateTime scheduledTime) async {
    final db = await _db.database;
    final rows = await db.query('dose_log',
        columns: ['status'],
        where: 'medicine_id = ? AND scheduled_time = ? AND deleted = 0',
        whereArgs: [medicineId, scheduledTime.toIso8601String()]);
    return rows.isEmpty ? null : DoseStatus.values.byName(rows.first['status'] as String);
  }
}
