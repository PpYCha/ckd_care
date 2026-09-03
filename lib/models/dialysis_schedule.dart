import 'package:flutter/foundation.dart';

/// A recurring weekly dialysis pattern. Weekdays use [DateTime.weekday] values
/// (1 = Monday … 7 = Sunday). Concrete sessions are computed, never stored.
@immutable
class DialysisSchedule {
  const DialysisSchedule({
    required this.weekdays,
    required this.timeOfDay,
    required this.durationHours,
    required this.clinicName,
    required this.clinicAddress,
  });

  final Set<int> weekdays; // 1..7 (Mon..Sun)
  final String timeOfDay; // 'HH:mm'
  final int durationHours;
  final String clinicName;
  final String clinicAddress;

  bool get isSet => weekdays.isNotEmpty;

  DialysisSchedule copyWith({
    Set<int>? weekdays,
    String? timeOfDay,
    int? durationHours,
    String? clinicName,
    String? clinicAddress,
  }) =>
      DialysisSchedule(
        weekdays: weekdays ?? this.weekdays,
        timeOfDay: timeOfDay ?? this.timeOfDay,
        durationHours: durationHours ?? this.durationHours,
        clinicName: clinicName ?? this.clinicName,
        clinicAddress: clinicAddress ?? this.clinicAddress,
      );

  @override
  bool operator ==(Object other) =>
      other is DialysisSchedule &&
      setEquals(other.weekdays, weekdays) &&
      other.timeOfDay == timeOfDay &&
      other.durationHours == durationHours &&
      other.clinicName == clinicName &&
      other.clinicAddress == clinicAddress;

  @override
  int get hashCode => Object.hash(
        Object.hashAllUnordered(weekdays),
        timeOfDay,
        durationHours,
        clinicName,
        clinicAddress,
      );
}

/// A concrete, dated occurrence derived from a [DialysisSchedule].
@immutable
class DialysisSession {
  const DialysisSession({
    required this.start,
    required this.durationHours,
    required this.clinicName,
    required this.clinicAddress,
  });

  final DateTime start;
  final int durationHours;
  final String clinicName;
  final String clinicAddress;

  DateTime get end => start.add(Duration(hours: durationHours));
}

/// The next [count] sessions with a start strictly after [now], soonest first.
List<DialysisSession> upcomingSessions(DialysisSchedule schedule,
    {required DateTime now, int count = 6}) {
  if (!schedule.isSet) return const [];
  final parts = schedule.timeOfDay.split(':');
  final hour = int.parse(parts[0]);
  final minute = int.parse(parts[1]);

  final result = <DialysisSession>[];
  var day = DateTime(now.year, now.month, now.day);
  final maxDays = count * 7 + 7; // weekly pattern: this always finds `count`
  for (var i = 0; i < maxDays && result.length < count; i++) {
    if (schedule.weekdays.contains(day.weekday)) {
      final start = DateTime(day.year, day.month, day.day, hour, minute);
      if (start.isAfter(now)) {
        result.add(DialysisSession(
          start: start,
          durationHours: schedule.durationHours,
          clinicName: schedule.clinicName,
          clinicAddress: schedule.clinicAddress,
        ));
      }
    }
    day = day.add(const Duration(days: 1));
  }
  return result;
}

DialysisSession? nextSession(DialysisSchedule schedule, {required DateTime now}) {
  final list = upcomingSessions(schedule, now: now, count: 1);
  return list.isEmpty ? null : list.first;
}

String encodeWeekdays(Set<int> weekdays) =>
    (weekdays.toList()..sort()).join(',');

Set<int> decodeWeekdays(String? csv) {
  final s = (csv ?? '').trim();
  if (s.isEmpty) return <int>{};
  return s.split(',').map((e) => int.parse(e.trim())).toSet();
}

const List<String> kWeekdayAbbr = [
  'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'
];
const List<String> kMonthAbbr = [
  'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
  'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
];

String weekdayAbbr(DateTime t) => kWeekdayAbbr[t.weekday - 1];
String monthAbbr(DateTime t) => kMonthAbbr[t.month - 1];

String formatTime12(DateTime t) {
  final h = t.hour % 12 == 0 ? 12 : t.hour % 12;
  final ampm = t.hour < 12 ? 'AM' : 'PM';
  return '$h:${t.minute.toString().padLeft(2, '0')} $ampm';
}
