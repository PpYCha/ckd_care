import 'package:ckd_care/models/medicine.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:ckd_care/services/notification_service.dart';

class _CancelFailsPlugin extends Fake
    implements FlutterLocalNotificationsPlugin {
  @override
  Future<void> cancel(int id, {String? tag}) async {
    throw StateError('notification access unavailable');
  }
}

void main() {
  test('notificationId is stable and unique per (medicine, time)', () {
    expect(
      NotificationService.notificationId(1, '08:00'),
      NotificationService.notificationId(1, '08:00'),
    );
    expect(
      NotificationService.notificationId(1, '08:00'),
      isNot(NotificationService.notificationId(1, '20:00')),
    );
    expect(
      NotificationService.notificationId(1, '08:00'),
      isNot(NotificationService.notificationId(2, '08:00')),
    );
  });

  test('id encodes medicine and minute-of-day', () {
    // medicine 2 at 08:30 -> 2*1440 + 510
    expect(NotificationService.notificationId(2, '08:30'), 2 * 1440 + 510);
  });

  test('scheduleForMedicine ignores a cancellation failure', () async {
    final service = NotificationService(_CancelFailsPlugin());

    await expectLater(
      service.scheduleForMedicine(1, [
        MedicineTime(
          uuid: 'time-1',
          medicineUuid: 'medicine-1',
          timeOfDay: '08:00',
          updatedAt: DateTime(2026, 9, 8),
        ),
      ]),
      completes,
    );
  });
}
