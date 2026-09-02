import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:ckd_care/models/medicine.dart';

class NotificationService {
  NotificationService(this._plugin);
  final FlutterLocalNotificationsPlugin _plugin;

  static const _details = NotificationDetails(
    android: AndroidNotificationDetails('meds', 'Medicine reminders',
        importance: Importance.max, priority: Priority.high),
    iOS: DarwinNotificationDetails(),
  );

  /// Stable id: medicine * 1440 + minute-of-day. Pure so callers and the
  /// scheduler always agree on which notification maps to which dose slot.
  static int notificationId(int medicineId, String timeOfDay) {
    final parts = timeOfDay.split(':');
    final minutes = int.parse(parts[0]) * 60 + int.parse(parts[1]);
    return medicineId * 1440 + minutes;
  }

  Future<void> scheduleForMedicine(int medicineId, List<MedicineTime> times) async {
    await cancelForMedicine(medicineId, times);
    for (final t in times) {
      await _plugin.zonedSchedule(
        notificationId(medicineId, t.timeOfDay),
        'Time for your medicine',
        'Tap to mark taken or skipped',
        _nextInstanceOf(t.timeOfDay),
        _details,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        matchDateTimeComponents: DateTimeComponents.time, // repeat daily
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        payload: '$medicineId|${t.timeOfDay}',
      );
    }
  }

  Future<void> cancelForMedicine(int medicineId, List<MedicineTime> times) async {
    for (final t in times) {
      await _plugin.cancel(notificationId(medicineId, t.timeOfDay));
    }
  }

  tz.TZDateTime _nextInstanceOf(String timeOfDay) {
    final parts = timeOfDay.split(':');
    final now = tz.TZDateTime.now(tz.local);
    var scheduled = tz.TZDateTime(tz.local, now.year, now.month, now.day,
        int.parse(parts[0]), int.parse(parts[1]));
    if (scheduled.isBefore(now)) {
      scheduled = scheduled.add(const Duration(days: 1));
    }
    return scheduled;
  }
}
