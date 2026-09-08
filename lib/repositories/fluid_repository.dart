import 'package:ckd_care/db/app_database.dart';
import 'package:ckd_care/models/fluid_entry.dart';

class DailyFluidTotals {
  const DailyFluidTotals({required this.intakeMl, required this.outputMl});
  final int intakeMl;
  final int outputMl;
  int get netMl => intakeMl - outputMl;
}

class FluidRepository {
  FluidRepository(this._db);
  final AppDatabase _db;

  Future<int> add(FluidEntry entry) async {
    final db = await _db.database;
    return db.insert('fluid_entry', entry.toMap());
  }

  Future<void> update(FluidEntry entry) async {
    final db = await _db.database;
    await db.update('fluid_entry', entry.toMap(),
        where: 'id = ?', whereArgs: [entry.id]);
  }

  Future<void> delete(int id) async {
    final db = await _db.database;
    await db.update(
      'fluid_entry',
      {'deleted': 1, 'updated_at': DateTime.now().toIso8601String()},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<List<FluidEntry>> entriesForDay(String day) async {
    final db = await _db.database;
    final rows = await db.query('fluid_entry',
        where: 'day = ? AND deleted = 0',
        whereArgs: [day],
        orderBy: 'logged_at ASC');
    return rows.map(FluidEntry.fromMap).toList();
  }

  Future<DailyFluidTotals> totalsForDay(String day) async {
    final db = await _db.database;
    final rows = await db.rawQuery(
      "SELECT type, COALESCE(SUM(amount_ml), 0) AS total "
      "FROM fluid_entry WHERE day = ? AND deleted = 0 GROUP BY type",
      [day],
    );
    var intake = 0, output = 0;
    for (final r in rows) {
      final total = (r['total'] as num).toInt();
      if (r['type'] == FluidType.intake.name) intake = total;
      if (r['type'] == FluidType.output.name) output = total;
    }
    return DailyFluidTotals(intakeMl: intake, outputMl: output);
  }
}
