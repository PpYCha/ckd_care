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
        await txn.update(
          'medicine',
          med.toMap(),
          where: 'id = ?',
          whereArgs: [id],
        );
      }
      // Soft-delete existing time rows (sync tombstones), then insert new ones.
      await txn.update(
        'medicine_time',
        {'deleted': 1, 'updated_at': now},
        where: 'medicine_id = ? AND deleted = 0',
        whereArgs: [id],
      );
      for (final t in times) {
        await txn.insert('medicine_time', {
          'uuid': newUuid(),
          'medicine_id': id,
          'medicine_uuid': med.uuid,
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
    final rows = await db.query(
      'medicine',
      where: 'active = 1 AND deleted = 0',
      orderBy: 'name COLLATE NOCASE ASC',
    );
    return rows.map(Medicine.fromMap).toList();
  }

  /// Active medicines eligible to show on the dashboard: maintenance medicines
  /// remain visible when out of stock, while finite courses do not. Medicines
  /// past their end-date are excluded. [today] is 'YYYY-MM-DD'.
  Future<List<Medicine>> dashboardMedicines(String today) async {
    final db = await _db.database;
    final rows = await db.query(
      'medicine',
      where: 'active = 1 AND deleted = 0 AND (stock_qty > 0 OR consume_until_empty = 0) AND (end_date IS NULL OR end_date >= ?)',
      whereArgs: [today],
      orderBy: 'name COLLATE NOCASE ASC',
    );
    return rows.map(Medicine.fromMap).toList();
  }

  Future<List<MedicineTime>> timesFor(int medicineId) async {
    final db = await _db.database;
    final rows = await db.query(
      'medicine_time',
      where: 'medicine_id = ? AND deleted = 0',
      whereArgs: [medicineId],
      orderBy: 'time_of_day ASC',
    );
    return rows.map(MedicineTime.fromMap).toList();
  }

  Future<void> deactivate(int medicineId) async {
    final db = await _db.database;
    await db.update(
      'medicine',
      {'active': 0, 'updated_at': DateTime.now().toIso8601String()},
      where: 'id = ?',
      whereArgs: [medicineId],
    );
  }

  Future<void> logDose(
    int medicineId,
    DateTime scheduledTime,
    DoseStatus status,
  ) async {
    final db = await _db.database;
    final iso = scheduledTime.toIso8601String();
    final now = DateTime.now().toIso8601String();
    await db.transaction((txn) async {
      final existing = await txn.query(
        'dose_log',
        columns: ['id', 'status'],
        where: 'medicine_id = ? AND scheduled_time = ? AND deleted = 0',
        whereArgs: [medicineId, iso],
      );
      final DoseStatus? oldStatus = existing.isEmpty
          ? null
          : DoseStatus.values.byName(existing.first['status'] as String);

      if (existing.isEmpty) {
        final medRows = await txn.query(
          'medicine',
          columns: ['uuid'],
          where: 'id = ?',
          whereArgs: [medicineId],
        );
        final medicineUuid = medRows.first['uuid'] as String;
        await txn.insert('dose_log', {
          'uuid': newUuid(),
          'medicine_id': medicineId,
          'medicine_uuid': medicineUuid,
          'scheduled_time': iso,
          'status': status.name,
          'acted_at': now,
          'updated_at': now,
          'deleted': 0,
        });
      } else {
        await txn.update(
          'dose_log',
          {'status': status.name, 'acted_at': now, 'updated_at': now},
          where: 'id = ?',
          whereArgs: [existing.first['id']],
        );
      }

      // Stock: becoming 'taken' consumes 1; reversing a 'taken' restores 1.
      // The clamp protects against a stale call trying to consume below zero.
      // A maintenance dose that was already taken can still be skipped after it
      // reaches zero, which correctly restores one unit.
      final adjustment =
          (oldStatus == DoseStatus.taken ? 1 : 0) -
          (status == DoseStatus.taken ? 1 : 0);
      if (adjustment != 0) {
        final medRows = await txn.query(
          'medicine',
          columns: ['stock_qty'],
          where: 'id = ?',
          whereArgs: [medicineId],
        );
        final current = medRows.first['stock_qty'] as int;
        final next = (current + adjustment).clamp(0, 1 << 31);
        await txn.update(
          'medicine',
          {'stock_qty': next, 'updated_at': now},
          where: 'id = ?',
          whereArgs: [medicineId],
        );
      }
    });
  }

  Future<List<DoseLog>> dosesForMedicine(int medicineId) async {
    final db = await _db.database;
    final rows = await db.query(
      'dose_log',
      where: 'medicine_id = ? AND deleted = 0',
      whereArgs: [medicineId],
      orderBy: 'scheduled_time DESC',
    );
    return rows.map(DoseLog.fromMap).toList();
  }

  Future<DoseStatus?> statusFor(int medicineId, DateTime scheduledTime) async {
    final db = await _db.database;
    final rows = await db.query(
      'dose_log',
      columns: ['status'],
      where: 'medicine_id = ? AND scheduled_time = ? AND deleted = 0',
      whereArgs: [medicineId, scheduledTime.toIso8601String()],
    );
    return rows.isEmpty
        ? null
        : DoseStatus.values.byName(rows.first['status'] as String);
  }
}
