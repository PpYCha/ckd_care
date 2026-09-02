import 'package:flutter_test/flutter_test.dart';
import 'package:ckd_care/services/notification_service.dart';

void main() {
  test('notificationId is stable and unique per (medicine, time)', () {
    expect(NotificationService.notificationId(1, '08:00'),
        NotificationService.notificationId(1, '08:00'));
    expect(NotificationService.notificationId(1, '08:00'),
        isNot(NotificationService.notificationId(1, '20:00')));
    expect(NotificationService.notificationId(1, '08:00'),
        isNot(NotificationService.notificationId(2, '08:00')));
  });

  test('id encodes medicine and minute-of-day', () {
    // medicine 2 at 08:30 -> 2*1440 + 510
    expect(NotificationService.notificationId(2, '08:30'), 2 * 1440 + 510);
  });
}
