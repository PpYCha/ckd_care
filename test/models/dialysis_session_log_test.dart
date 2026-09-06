import 'package:flutter_test/flutter_test.dart';
import 'package:ckd_care/models/dialysis_session_log.dart';

void main() {
  test('session key normalizes seconds and milliseconds', () {
    expect(
      sessionKeyFor(DateTime(2026, 9, 2, 9, 0, 30, 400)),
      DateTime(2026, 9, 2, 9).toIso8601String(),
    );
  });

  test('removedWeightKg is only computed when post is not above pre', () {
    final now = DateTime(2026, 9, 2, 10);
    final log = DialysisSessionLog(
      sessionKey: 'k',
      sessionStart: DateTime(2026, 9, 2, 9),
      preWeightKg: 70.5,
      postWeightKg: 68.25,
      updatedAt: now,
    );
    expect(log.removedWeightKg, 2.25);

    expect(log.copyWith(postWeightKg: 71.0).removedWeightKg, isNull);
    expect(log.copyWith(preWeightKg: null).removedWeightKg, isNull);
  });

  test('map conversion preserves decimal weights', () {
    final updated = DateTime(2026, 9, 2, 10);
    final log = DialysisSessionLog(
      id: 7,
      sessionKey: '2026-09-02T09:00:00.000',
      sessionStart: DateTime(2026, 9, 2, 9),
      preWeightKg: 65.75,
      postWeightKg: 64.5,
      updatedAt: updated,
    );
    expect(DialysisSessionLog.fromMap(log.toMap()), log);
  });
}
