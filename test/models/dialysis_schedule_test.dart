import 'package:flutter_test/flutter_test.dart';
import 'package:ckd_care/models/dialysis_schedule.dart';

void main() {
  // Mon/Wed/Fri, 09:00, 4h. Weekdays: Mon=1, Wed=3, Fri=5.
  const mwf = DialysisSchedule(
    weekdays: {1, 3, 5},
    timeOfDay: '09:00',
    durationHours: 4,
    clinicName: 'Healthy Kidney Center',
    clinicAddress: '123 Main St',
  );

  test('isSet reflects whether any weekday is chosen', () {
    expect(mwf.isSet, isTrue);
    expect(
      const DialysisSchedule(
              weekdays: {},
              timeOfDay: '09:00',
              durationHours: 4,
              clinicName: '',
              clinicAddress: '')
          .isSet,
      isFalse,
    );
  });

  test('nextSession is the soonest future occurrence', () {
    // Tuesday 2026-09-01 10:00 -> next is Wednesday 2026-09-02 09:00.
    final next = nextSession(mwf, now: DateTime(2026, 9, 1, 10));
    expect(next, isNotNull);
    expect(next!.start, DateTime(2026, 9, 2, 9, 0));
    expect(next.durationHours, 4);
    expect(next.clinicName, 'Healthy Kidney Center');
    expect(next.end, DateTime(2026, 9, 2, 13, 0));
  });

  test("a session earlier today is excluded; later today is included", () {
    // Wednesday 2026-09-02 at 08:00 (before 09:00) -> today's 09:00 counts.
    final before = nextSession(mwf, now: DateTime(2026, 9, 2, 8));
    expect(before!.start, DateTime(2026, 9, 2, 9, 0));
    // Wednesday 2026-09-02 at 09:30 (after start) -> today's is past, next is Friday.
    final after = nextSession(mwf, now: DateTime(2026, 9, 2, 9, 30));
    expect(after!.start, DateTime(2026, 9, 4, 9, 0));
  });

  test('upcomingSessions returns the next N in order', () {
    // From Tuesday 2026-09-01 10:00: Wed 09-02, Fri 09-04, Mon 09-07.
    final list = upcomingSessions(mwf, now: DateTime(2026, 9, 1, 10), count: 3);
    expect(list.map((s) => s.start).toList(), [
      DateTime(2026, 9, 2, 9, 0),
      DateTime(2026, 9, 4, 9, 0),
      DateTime(2026, 9, 7, 9, 0),
    ]);
  });

  test('an unset schedule yields no sessions', () {
    const empty = DialysisSchedule(
        weekdays: {},
        timeOfDay: '09:00',
        durationHours: 4,
        clinicName: '',
        clinicAddress: '');
    expect(nextSession(empty, now: DateTime(2026, 9, 1)), isNull);
    expect(upcomingSessions(empty, now: DateTime(2026, 9, 1)), isEmpty);
  });

  test('encode/decode weekdays round-trips and sorts', () {
    expect(encodeWeekdays({5, 1, 3}), '1,3,5');
    expect(decodeWeekdays('1,3,5'), {1, 3, 5});
    expect(decodeWeekdays(''), <int>{});
    expect(decodeWeekdays(null), <int>{});
  });

  test('formatTime12 renders 12-hour clock', () {
    expect(formatTime12(DateTime(2026, 1, 1, 9, 0)), '9:00 AM');
    expect(formatTime12(DateTime(2026, 1, 1, 13, 5)), '1:05 PM');
    expect(formatTime12(DateTime(2026, 1, 1, 0, 0)), '12:00 AM');
    expect(formatTime12(DateTime(2026, 1, 1, 12, 0)), '12:00 PM');
  });

  test('equality is by value', () {
    expect(
      mwf,
      const DialysisSchedule(
        weekdays: {1, 3, 5},
        timeOfDay: '09:00',
        durationHours: 4,
        clinicName: 'Healthy Kidney Center',
        clinicAddress: '123 Main St',
      ),
    );
  });
}
