import 'package:flutter/foundation.dart';
import 'package:ckd_care/db/ids.dart';
import 'package:ckd_care/models/fluid_entry.dart';
import 'package:ckd_care/repositories/fluid_repository.dart';

class FluidProvider extends ChangeNotifier {
  FluidProvider(this._repo);
  final FluidRepository _repo;

  String day = FluidEntry.dayOf(DateTime.now());
  List<FluidEntry> entries = const [];

  DateTime get selectedDate {
    final parts = day.split('-').map(int.parse).toList();
    return DateTime(parts[0], parts[1], parts[2]);
  }

  bool get isToday => day == FluidEntry.dayOf(DateTime.now());

  Future<void> loadDay(String d) async {
    day = d;
    entries = await _repo.entriesForDay(d);
    notifyListeners();
  }

  Future<void> selectDate(DateTime date) => loadDay(FluidEntry.dayOf(date));

  Future<void> previousDay() =>
      selectDate(selectedDate.subtract(const Duration(days: 1)));

  Future<void> nextDay() =>
      selectDate(selectedDate.add(const Duration(days: 1)));

  Future<void> add(FluidType type, int ml, {String? note}) async {
    final now = DateTime.now();
    await _repo.add(
      FluidEntry(
        uuid: newUuid(),
        type: type,
        amountMl: ml,
        loggedAt: now,
        day: FluidEntry.dayOf(now),
        note: note,
        updatedAt: now,
      ),
    );
    await loadDay(day);
  }

  Future<void> update(FluidEntry entry) async {
    await _repo.update(entry);
    await loadDay(day);
  }

  Future<void> remove(int id) async {
    await _repo.delete(id);
    await loadDay(day);
  }
}
