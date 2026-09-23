# Health Trends Graphs Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a dashboard-launched Health trends screen showing fluid intake/output and dialysis pre/post weight graphs across daily, weekly, monthly, and yearly ranges.

**Architecture:** Add a small trends model layer, extend the existing repositories with read-only range rollups, introduce a `TrendsProvider`, then render a `TrendsScreen` with lightweight `CustomPainter` charts. The dashboard remains the daily workflow; trends are a secondary read-only analysis workflow opened by a card.

**Tech Stack:** Flutter, Provider, sqflite, sqflite_common_ffi tests, Material widgets, `CustomPainter`; no new chart dependency.

**Spec:** `docs/superpowers/specs/2026-09-23-health-trends-graphs-design.md`

## Global Constraints

- Use existing SQLite data only; do not add duplicate tracking tables.
- Do not add a new bottom navigation item.
- Do not change existing `totalsForDay`, `entriesForDay`, `saveWeights`, or session-key semantics.
- Exclude soft-deleted `fluid_entry` rows from trends.
- Keep dialysis weight measurements attached to concrete dated sessions, not recurring schedule defaults.
- Use local date ranges: day, Monday-Sunday week, calendar month, calendar year.
- Use custom `CustomPainter` chart widgets; do not add a chart package for the first version.
- Trends screen is read-only; do not edit fluid entries or dialysis weights from trends.

## Review Focus

- Boundary dates: entries exactly at range start are included; entries at the next range start are excluded.
- Missing buckets: fluid charts still show zero-valued buckets for dates/months without logs.
- Missing weights: pre-only and post-only session logs remain visible without inventing the absent value.
- Yearly weights: pre and post monthly averages are computed independently when one side is missing.
- Empty states: ranges with no meaningful records show empty copy instead of blank chart space.

---

## File Structure

- Create `lib/models/trend_models.dart`: period/range/point models and date-range helpers.
- Modify `lib/repositories/fluid_repository.dart`: add `trendForRange(TrendRange range)`.
- Modify `test/repositories/fluid_repository_test.dart`: add fluid trend aggregation coverage.
- Modify `lib/repositories/dialysis_session_log_repository.dart`: add `trendForRange(TrendRange range)`.
- Modify `test/repositories/dialysis_session_log_repository_test.dart`: add weight trend range coverage.
- Create `lib/providers/trends_provider.dart`: load and navigate trend data.
- Create `test/providers/trends_provider_test.dart`: provider range/navigation/loading tests.
- Create `lib/widgets/trend_charts.dart`: custom painters for fluid bars and weight lines.
- Create `test/widgets/trend_charts_test.dart`: chart smoke and empty rendering tests.
- Create `lib/screens/trends_screen.dart`: tabs, period controls, summaries, charts, empty states.
- Modify `lib/screens/dashboard_screen.dart`: add Health trends card and navigation.
- Modify `lib/main.dart`: provide `TrendsProvider`.
- Modify `test/widget_test.dart`: include the new provider and assert the dashboard card exists.
- Create `test/screens/trends_screen_test.dart`: screen tab and empty-state coverage.

---

### Task 1: Trends Models And Range Helpers

**Files:**
- Create: `lib/models/trend_models.dart`
- Test: `test/models/trend_models_test.dart`

**Interfaces:**
- Produces: `enum TrendPeriod { day, week, month, year }`
- Produces: `class TrendRange { final TrendPeriod period; final DateTime anchorDate; final DateTime start; final DateTime endExclusive; final String label; }`
- Produces: `TrendRange trendRangeFor(TrendPeriod period, DateTime anchorDate)`
- Produces: `class FluidTrendPoint { final String label; final DateTime bucketStart; final int intakeMl; final int outputMl; int get netMl; bool get hasData; }`
- Produces: `class WeightTrendPoint { final String label; final DateTime bucketStart; final double? preWeightKg; final double? postWeightKg; bool get hasData; double? get removedKg; }`
- Later tasks consume these exact names.

- [ ] **Step 1: Write model/range tests**

Create `test/models/trend_models_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:ckd_care/models/trend_models.dart';

void main() {
  test('trendRangeFor day uses local midnight start and exclusive next day', () {
    final range = trendRangeFor(TrendPeriod.day, DateTime(2026, 9, 23, 15, 30));

    expect(range.start, DateTime(2026, 9, 23));
    expect(range.endExclusive, DateTime(2026, 9, 24));
    expect(range.label, 'Sep 23, 2026');
  });

  test('trendRangeFor week uses Monday through exclusive next Monday', () {
    final range = trendRangeFor(TrendPeriod.week, DateTime(2026, 9, 23));

    expect(range.start, DateTime(2026, 9, 21));
    expect(range.endExclusive, DateTime(2026, 9, 28));
    expect(range.label, 'Sep 21-27, 2026');
  });

  test('trendRangeFor month and year use calendar boundaries', () {
    final month = trendRangeFor(TrendPeriod.month, DateTime(2026, 2, 12));
    final year = trendRangeFor(TrendPeriod.year, DateTime(2026, 9, 23));

    expect(month.start, DateTime(2026, 2));
    expect(month.endExclusive, DateTime(2026, 3));
    expect(month.label, 'February 2026');
    expect(year.start, DateTime(2026));
    expect(year.endExclusive, DateTime(2027));
    expect(year.label, '2026');
  });

  test('trend points compute net fluid and removed weight', () {
    final fluid = FluidTrendPoint(
      label: '9 AM',
      bucketStart: DateTime(2026, 9, 23, 9),
      intakeMl: 500,
      outputMl: 125,
    );
    final weights = WeightTrendPoint(
      label: 'Sep 23',
      bucketStart: DateTime(2026, 9, 23, 9),
      preWeightKg: 70.5,
      postWeightKg: 68.75,
    );

    expect(fluid.netMl, 375);
    expect(fluid.hasData, isTrue);
    expect(weights.removedKg, closeTo(1.75, 0.001));
    expect(weights.hasData, isTrue);
  });
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `flutter test test/models/trend_models_test.dart`

Expected: FAIL because `package:ckd_care/models/trend_models.dart` does not exist.

- [ ] **Step 3: Implement trend models**

Create `lib/models/trend_models.dart`:

```dart
enum TrendPeriod { day, week, month, year }

class TrendRange {
  const TrendRange({
    required this.period,
    required this.anchorDate,
    required this.start,
    required this.endExclusive,
    required this.label,
  });

  final TrendPeriod period;
  final DateTime anchorDate;
  final DateTime start;
  final DateTime endExclusive;
  final String label;
}

class FluidTrendPoint {
  const FluidTrendPoint({
    required this.label,
    required this.bucketStart,
    required this.intakeMl,
    required this.outputMl,
  });

  final String label;
  final DateTime bucketStart;
  final int intakeMl;
  final int outputMl;

  int get netMl => intakeMl - outputMl;
  bool get hasData => intakeMl > 0 || outputMl > 0;
}

class WeightTrendPoint {
  const WeightTrendPoint({
    required this.label,
    required this.bucketStart,
    required this.preWeightKg,
    required this.postWeightKg,
  });

  final String label;
  final DateTime bucketStart;
  final double? preWeightKg;
  final double? postWeightKg;

  bool get hasData => preWeightKg != null || postWeightKg != null;
  double? get removedKg {
    final pre = preWeightKg;
    final post = postWeightKg;
    if (pre == null || post == null) return null;
    return pre - post;
  }
}

TrendRange trendRangeFor(TrendPeriod period, DateTime anchorDate) {
  final anchor = DateTime(anchorDate.year, anchorDate.month, anchorDate.day);
  return switch (period) {
    TrendPeriod.day => TrendRange(
        period: period,
        anchorDate: anchor,
        start: anchor,
        endExclusive: anchor.add(const Duration(days: 1)),
        label: _dayLabel(anchor),
      ),
    TrendPeriod.week => _weekRange(anchor),
    TrendPeriod.month => TrendRange(
        period: period,
        anchorDate: anchor,
        start: DateTime(anchor.year, anchor.month),
        endExclusive: DateTime(anchor.year, anchor.month + 1),
        label: '${_fullMonth(anchor.month)} ${anchor.year}',
      ),
    TrendPeriod.year => TrendRange(
        period: period,
        anchorDate: anchor,
        start: DateTime(anchor.year),
        endExclusive: DateTime(anchor.year + 1),
        label: '${anchor.year}',
      ),
  };
}

TrendRange _weekRange(DateTime anchor) {
  final start = anchor.subtract(Duration(days: anchor.weekday - 1));
  final end = start.add(const Duration(days: 7));
  final sameYear = start.year == end.subtract(const Duration(days: 1)).year;
  final endDay = end.subtract(const Duration(days: 1));
  final label = sameYear
      ? '${_shortMonth(start.month)} ${start.day}-${endDay.day}, ${start.year}'
      : '${_shortMonth(start.month)} ${start.day}, ${start.year}-${_shortMonth(endDay.month)} ${endDay.day}, ${endDay.year}';
  return TrendRange(
    period: TrendPeriod.week,
    anchorDate: anchor,
    start: start,
    endExclusive: end,
    label: label,
  );
}

String _dayLabel(DateTime d) => '${_shortMonth(d.month)} ${d.day}, ${d.year}';

String _shortMonth(int month) => const [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ][month - 1];

String _fullMonth(int month) => const [
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December',
    ][month - 1];
```

- [ ] **Step 4: Run model tests**

Run: `flutter test test/models/trend_models_test.dart`

Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/models/trend_models.dart test/models/trend_models_test.dart
git commit -m "feat: add trend range models"
```

---

### Task 2: Fluid Repository Trend Rollups

**Files:**
- Modify: `lib/repositories/fluid_repository.dart`
- Modify: `test/repositories/fluid_repository_test.dart`

**Interfaces:**
- Consumes: `TrendRange`, `TrendPeriod`, `FluidTrendPoint`
- Produces: `Future<List<FluidTrendPoint>> trendForRange(TrendRange range)`

- [ ] **Step 1: Add failing fluid trend tests**

Append these tests inside `test/repositories/fluid_repository_test.dart`:

```dart
  test('trendForRange day groups intake and output by hour and excludes next day boundary', () async {
    final range = trendRangeFor(TrendPeriod.day, DateTime(2026, 9, 23, 12));
    await repo.add(entry(FluidType.intake, 300, DateTime(2026, 9, 23, 8, 15)));
    await repo.add(entry(FluidType.output, 100, DateTime(2026, 9, 23, 8, 45)));
    await repo.add(entry(FluidType.intake, 999, DateTime(2026, 9, 24)));

    final points = await repo.trendForRange(range);

    expect(points, hasLength(24));
    expect(points[8].label, '8 AM');
    expect(points[8].intakeMl, 300);
    expect(points[8].outputMl, 100);
    expect(points[8].netMl, 200);
    expect(points.every((p) => p.bucketStart.isBefore(range.endExclusive)), isTrue);
  });

  test('trendForRange week returns zero buckets for missing days', () async {
    final range = trendRangeFor(TrendPeriod.week, DateTime(2026, 9, 23));
    await repo.add(entry(FluidType.intake, 250, DateTime(2026, 9, 21, 8)));
    await repo.add(entry(FluidType.output, 75, DateTime(2026, 9, 23, 18)));

    final points = await repo.trendForRange(range);

    expect(points, hasLength(7));
    expect(points[0].label, 'Mon');
    expect(points[0].intakeMl, 250);
    expect(points[0].outputMl, 0);
    expect(points[1].hasData, isFalse);
    expect(points[2].outputMl, 75);
  });

  test('trendForRange year groups totals by month', () async {
    final range = trendRangeFor(TrendPeriod.year, DateTime(2026, 6, 1));
    await repo.add(entry(FluidType.intake, 100, DateTime(2026, 1, 2, 8)));
    await repo.add(entry(FluidType.intake, 200, DateTime(2026, 1, 3, 8)));
    await repo.add(entry(FluidType.output, 50, DateTime(2026, 12, 31, 23, 59)));

    final points = await repo.trendForRange(range);

    expect(points, hasLength(12));
    expect(points.first.label, 'Jan');
    expect(points.first.intakeMl, 300);
    expect(points.first.outputMl, 0);
    expect(points.last.label, 'Dec');
    expect(points.last.outputMl, 50);
  });
```

Add import:

```dart
import 'package:ckd_care/models/trend_models.dart';
```

- [ ] **Step 2: Run focused tests to verify failure**

Run: `flutter test test/repositories/fluid_repository_test.dart`

Expected: FAIL because `FluidRepository.trendForRange` is missing.

- [ ] **Step 3: Implement fluid rollups**

Modify `lib/repositories/fluid_repository.dart`:

```dart
import 'package:ckd_care/models/trend_models.dart';
```

Add inside `FluidRepository`:

```dart
  Future<List<FluidTrendPoint>> trendForRange(TrendRange range) async {
    final buckets = _fluidBuckets(range);
    final db = await _db.database;
    final rows = await db.rawQuery(
      "SELECT day, strftime('%H', logged_at) AS hour, type, "
      "COALESCE(SUM(amount_ml), 0) AS total "
      "FROM fluid_entry "
      "WHERE logged_at >= ? AND logged_at < ? AND deleted = 0 "
      "GROUP BY day, hour, type",
      [range.start.toIso8601String(), range.endExclusive.toIso8601String()],
    );

    final totals = <String, ({int intake, int output})>{};
    for (final row in rows) {
      final key = _fluidBucketKey(range.period, row['day'] as String,
          int.tryParse(row['hour'] as String? ?? '0') ?? 0);
      final current = totals[key] ?? (intake: 0, output: 0);
      final total = (row['total'] as num).toInt();
      totals[key] = row['type'] == FluidType.intake.name
          ? (intake: current.intake + total, output: current.output)
          : (intake: current.intake, output: current.output + total);
    }

    return buckets
        .map((bucket) {
          final value = totals[bucket.key] ?? (intake: 0, output: 0);
          return FluidTrendPoint(
            label: bucket.label,
            bucketStart: bucket.start,
            intakeMl: value.intake,
            outputMl: value.output,
          );
        })
        .toList(growable: false);
  }
```

Add private helpers below the class:

```dart
typedef _FluidBucket = ({String key, String label, DateTime start});

List<_FluidBucket> _fluidBuckets(TrendRange range) {
  return switch (range.period) {
    TrendPeriod.day => List.generate(24, (hour) {
        final start = DateTime(range.start.year, range.start.month,
            range.start.day, hour);
        return (
          key: '${_dayKey(start)}|$hour',
          label: _hourLabel(hour),
          start: start,
        );
      }),
    TrendPeriod.week => List.generate(7, (i) {
        final start = range.start.add(Duration(days: i));
        return (key: _dayKey(start), label: _weekdayLabel(start.weekday), start: start);
      }),
    TrendPeriod.month => List.generate(
        range.endExclusive.difference(range.start).inDays,
        (i) {
          final start = range.start.add(Duration(days: i));
          return (key: _dayKey(start), label: '${start.day}', start: start);
        },
      ),
    TrendPeriod.year => List.generate(12, (i) {
        final start = DateTime(range.start.year, i + 1);
        return (key: '${start.year}-${_two(i + 1)}', label: _monthLabel(i + 1), start: start);
      }),
  };
}

String _fluidBucketKey(TrendPeriod period, String day, int hour) {
  return switch (period) {
    TrendPeriod.day => '$day|$hour',
    TrendPeriod.week => day,
    TrendPeriod.month => day,
    TrendPeriod.year => day.substring(0, 7),
  };
}

String _dayKey(DateTime d) => '${d.year}-${_two(d.month)}-${_two(d.day)}';
String _two(int n) => n.toString().padLeft(2, '0');
String _hourLabel(int hour) {
  if (hour == 0) return '12 AM';
  if (hour < 12) return '$hour AM';
  if (hour == 12) return '12 PM';
  return '${hour - 12} PM';
}

String _weekdayLabel(int weekday) =>
    const ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'][weekday - 1];

String _monthLabel(int month) =>
    const ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'][month - 1];
```

- [ ] **Step 4: Run focused repository tests**

Run: `flutter test test/repositories/fluid_repository_test.dart`

Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/repositories/fluid_repository.dart test/repositories/fluid_repository_test.dart
git commit -m "feat: add fluid trend rollups"
```

---

### Task 3: Dialysis Weight Repository Trend Queries

**Files:**
- Modify: `lib/repositories/dialysis_session_log_repository.dart`
- Modify: `test/repositories/dialysis_session_log_repository_test.dart`

**Interfaces:**
- Consumes: `TrendRange`, `TrendPeriod`, `WeightTrendPoint`
- Produces: `Future<List<WeightTrendPoint>> trendForRange(TrendRange range)`

- [ ] **Step 1: Add failing weight trend tests**

Append to `test/repositories/dialysis_session_log_repository_test.dart`:

```dart
  test('trendForRange preserves session points and excludes exclusive end boundary', () async {
    final range = trendRangeFor(TrendPeriod.week, DateTime(2026, 9, 23));
    await repo.saveWeights(
      sessionStart: DateTime(2026, 9, 21, 9),
      preWeightKg: 70.5,
      postWeightKg: 68.75,
    );
    await repo.saveWeights(
      sessionStart: DateTime(2026, 9, 28, 9),
      preWeightKg: 99,
      postWeightKg: 98,
    );

    final points = await repo.trendForRange(range);

    expect(points, hasLength(1));
    expect(points.single.label, 'Sep 21');
    expect(points.single.preWeightKg, 70.5);
    expect(points.single.postWeightKg, 68.75);
  });

  test('trendForRange keeps pre-only and post-only sessions visible', () async {
    final range = trendRangeFor(TrendPeriod.month, DateTime(2026, 9, 1));
    await repo.saveWeights(sessionStart: DateTime(2026, 9, 2, 9), preWeightKg: 70);
    await repo.saveWeights(sessionStart: DateTime(2026, 9, 4, 9), postWeightKg: 68);

    final points = await repo.trendForRange(range);

    expect(points, hasLength(2));
    expect(points[0].preWeightKg, 70);
    expect(points[0].postWeightKg, isNull);
    expect(points[1].preWeightKg, isNull);
    expect(points[1].postWeightKg, 68);
  });

  test('trendForRange yearly averages pre and post values independently by month', () async {
    final range = trendRangeFor(TrendPeriod.year, DateTime(2026, 5, 1));
    await repo.saveWeights(
      sessionStart: DateTime(2026, 1, 2, 9),
      preWeightKg: 70,
      postWeightKg: 68,
    );
    await repo.saveWeights(
      sessionStart: DateTime(2026, 1, 5, 9),
      preWeightKg: 72,
    );
    await repo.saveWeights(
      sessionStart: DateTime(2026, 2, 2, 9),
      postWeightKg: 67,
    );

    final points = await repo.trendForRange(range);

    expect(points, hasLength(12));
    expect(points[0].label, 'Jan');
    expect(points[0].preWeightKg, 71);
    expect(points[0].postWeightKg, 68);
    expect(points[1].preWeightKg, isNull);
    expect(points[1].postWeightKg, 67);
  });
```

Add import:

```dart
import 'package:ckd_care/models/trend_models.dart';
```

- [ ] **Step 2: Run focused tests to verify failure**

Run: `flutter test test/repositories/dialysis_session_log_repository_test.dart`

Expected: FAIL because `DialysisSessionLogRepository.trendForRange` is missing.

- [ ] **Step 3: Implement weight trend queries**

Modify `lib/repositories/dialysis_session_log_repository.dart`:

```dart
import 'package:ckd_care/models/trend_models.dart';
```

Add inside `DialysisSessionLogRepository`:

```dart
  Future<List<WeightTrendPoint>> trendForRange(TrendRange range) async {
    final db = await _db.database;
    final rows = await db.query(
      'dialysis_session_log',
      where: 'session_start >= ? AND session_start < ? '
          'AND (pre_weight_kg IS NOT NULL OR post_weight_kg IS NOT NULL)',
      whereArgs: [
        normalizedSessionStart(range.start).toIso8601String(),
        normalizedSessionStart(range.endExclusive).toIso8601String(),
      ],
      orderBy: 'session_start ASC',
    );
    final logs = rows.map(DialysisSessionLog.fromMap).toList(growable: false);

    if (range.period == TrendPeriod.year) {
      return _yearlyWeightPoints(range, logs);
    }

    return logs
        .map((log) => WeightTrendPoint(
              label: _sessionLabel(log.sessionStart),
              bucketStart: log.sessionStart,
              preWeightKg: log.preWeightKg,
              postWeightKg: log.postWeightKg,
            ))
        .toList(growable: false);
  }
```

Add private helpers below the class:

```dart
List<WeightTrendPoint> _yearlyWeightPoints(
  TrendRange range,
  List<DialysisSessionLog> logs,
) {
  return List.generate(12, (i) {
    final month = i + 1;
    final monthLogs = logs.where((log) => log.sessionStart.month == month);
    return WeightTrendPoint(
      label: _monthLabel(month),
      bucketStart: DateTime(range.start.year, month),
      preWeightKg: _average(monthLogs.map((log) => log.preWeightKg)),
      postWeightKg: _average(monthLogs.map((log) => log.postWeightKg)),
    );
  });
}

double? _average(Iterable<double?> values) {
  var total = 0.0;
  var count = 0;
  for (final value in values) {
    if (value == null) continue;
    total += value;
    count++;
  }
  if (count == 0) return null;
  return total / count;
}

String _sessionLabel(DateTime start) => '${_monthLabel(start.month)} ${start.day}';

String _monthLabel(int month) =>
    const ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'][month - 1];
```

- [ ] **Step 4: Run focused repository tests**

Run: `flutter test test/repositories/dialysis_session_log_repository_test.dart`

Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/repositories/dialysis_session_log_repository.dart test/repositories/dialysis_session_log_repository_test.dart
git commit -m "feat: add dialysis weight trends"
```

---

### Task 4: Trends Provider

**Files:**
- Create: `lib/providers/trends_provider.dart`
- Create: `test/providers/trends_provider_test.dart`
- Modify: `lib/main.dart`

**Interfaces:**
- Consumes: `FluidRepository.trendForRange`, `DialysisSessionLogRepository.trendForRange`
- Produces: `class TrendsProvider extends ChangeNotifier`
- Produces: `TrendPeriod period`, `DateTime selectedDate`, `TrendRange range`, `List<FluidTrendPoint> fluidPoints`, `List<WeightTrendPoint> weightPoints`, `bool loading`, `Object? error`
- Produces: `Future<void> refresh()`, `Future<void> setPeriod(TrendPeriod next)`, `Future<void> previousRange()`, `Future<void> nextRange()`, `Future<void> selectDate(DateTime date)`

- [ ] **Step 1: Write provider tests**

Create `test/providers/trends_provider_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:ckd_care/models/trend_models.dart';
import 'package:ckd_care/providers/trends_provider.dart';

class _FakeFluid {
  final ranges = <TrendRange>[];
  Future<List<FluidTrendPoint>> trendForRange(TrendRange range) async {
    ranges.add(range);
    return [
      FluidTrendPoint(
        label: 'Mon',
        bucketStart: range.start,
        intakeMl: 500,
        outputMl: 200,
      ),
    ];
  }
}

class _FakeWeights {
  final ranges = <TrendRange>[];
  Future<List<WeightTrendPoint>> trendForRange(TrendRange range) async {
    ranges.add(range);
    return [
      WeightTrendPoint(
        label: 'Mon',
        bucketStart: range.start,
        preWeightKg: 70,
        postWeightKg: 68.5,
      ),
    ];
  }
}

void main() {
  test('refresh loads fluid and weight points for current range', () async {
    final fluid = _FakeFluid();
    final weights = _FakeWeights();
    final provider = TrendsProvider(
      fluid: fluid,
      weights: weights,
      now: () => DateTime(2026, 9, 23, 12),
    );

    await provider.refresh();

    expect(provider.loading, isFalse);
    expect(provider.error, isNull);
    expect(provider.period, TrendPeriod.day);
    expect(provider.range.start, DateTime(2026, 9, 23));
    expect(provider.fluidPoints.single.intakeMl, 500);
    expect(provider.weightPoints.single.preWeightKg, 70);
  });

  test('setPeriod rebuilds range and reloads data', () async {
    final provider = TrendsProvider(
      fluid: _FakeFluid(),
      weights: _FakeWeights(),
      now: () => DateTime(2026, 9, 23, 12),
    );

    await provider.setPeriod(TrendPeriod.week);

    expect(provider.period, TrendPeriod.week);
    expect(provider.range.start, DateTime(2026, 9, 21));
    expect(provider.range.endExclusive, DateTime(2026, 9, 28));
  });

  test('previousRange and nextRange move by selected period', () async {
    final provider = TrendsProvider(
      fluid: _FakeFluid(),
      weights: _FakeWeights(),
      now: () => DateTime(2026, 9, 23, 12),
    );

    await provider.setPeriod(TrendPeriod.month);
    await provider.previousRange();
    expect(provider.selectedDate, DateTime(2026, 8, 23));

    await provider.nextRange();
    expect(provider.selectedDate, DateTime(2026, 9, 23));
  });

  test('refresh exposes errors without throwing', () async {
    final provider = TrendsProvider(
      fluid: _ThrowingFluid(),
      weights: _FakeWeights(),
      now: () => DateTime(2026, 9, 23, 12),
    );

    await provider.refresh();

    expect(provider.loading, isFalse);
    expect(provider.error, isA<StateError>());
    expect(provider.fluidPoints, isEmpty);
    expect(provider.weightPoints, isEmpty);
  });
}

class _ThrowingFluid {
  Future<List<FluidTrendPoint>> trendForRange(TrendRange range) async {
    throw StateError('database unavailable');
  }
}
```

- [ ] **Step 2: Run provider tests to verify failure**

Run: `flutter test test/providers/trends_provider_test.dart`

Expected: FAIL because `TrendsProvider` does not exist.

- [ ] **Step 3: Implement provider**

Create `lib/providers/trends_provider.dart`:

```dart
import 'package:flutter/foundation.dart';
import 'package:ckd_care/models/trend_models.dart';

class TrendsProvider extends ChangeNotifier {
  TrendsProvider({
    required dynamic fluid,
    required dynamic weights,
    DateTime Function()? now,
  })  : _fluid = fluid,
        _weights = weights,
        _now = now ?? DateTime.now {
    selectedDate = _dateOnly(_now());
    range = trendRangeFor(period, selectedDate);
  }

  final dynamic _fluid;
  final dynamic _weights;
  final DateTime Function() _now;

  TrendPeriod period = TrendPeriod.day;
  late DateTime selectedDate;
  late TrendRange range;
  List<FluidTrendPoint> fluidPoints = const [];
  List<WeightTrendPoint> weightPoints = const [];
  bool loading = false;
  Object? error;

  Future<void> refresh() async {
    loading = true;
    error = null;
    notifyListeners();
    try {
      range = trendRangeFor(period, selectedDate);
      final fluid = await _fluid.trendForRange(range);
      final weights = await _weights.trendForRange(range);
      fluidPoints = fluid;
      weightPoints = weights;
    } catch (e) {
      error = e;
      fluidPoints = const [];
      weightPoints = const [];
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  Future<void> setPeriod(TrendPeriod next) async {
    if (period == next) return;
    period = next;
    await refresh();
  }

  Future<void> selectDate(DateTime date) async {
    selectedDate = _dateOnly(date);
    await refresh();
  }

  Future<void> previousRange() async {
    selectedDate = _shiftDate(-1);
    await refresh();
  }

  Future<void> nextRange() async {
    selectedDate = _shiftDate(1);
    await refresh();
  }

  DateTime _shiftDate(int direction) {
    return switch (period) {
      TrendPeriod.day => selectedDate.add(Duration(days: direction)),
      TrendPeriod.week => selectedDate.add(Duration(days: 7 * direction)),
      TrendPeriod.month => DateTime(
          selectedDate.year,
          selectedDate.month + direction,
          selectedDate.day,
        ),
      TrendPeriod.year => DateTime(
          selectedDate.year + direction,
          selectedDate.month,
          selectedDate.day,
        ),
    };
  }
}

DateTime _dateOnly(DateTime date) => DateTime(date.year, date.month, date.day);
```

- [ ] **Step 4: Wire provider in app**

Modify `lib/main.dart`:

```dart
import 'package:ckd_care/providers/trends_provider.dart';
```

Add to `MultiProvider` after `DialysisSessionLogProvider` or near `DashboardProvider`:

```dart
        ChangeNotifierProvider(
          create: (_) => TrendsProvider(
            fluid: fluidRepo,
            weights: dialysisSessionLogRepo,
          ),
        ),
```

- [ ] **Step 5: Run provider tests**

Run: `flutter test test/providers/trends_provider_test.dart`

Expected: PASS.

- [ ] **Step 6: Commit**

```bash
git add lib/providers/trends_provider.dart test/providers/trends_provider_test.dart lib/main.dart
git commit -m "feat: add trends provider"
```

---

### Task 5: Chart Widgets

**Files:**
- Create: `lib/widgets/trend_charts.dart`
- Create: `test/widgets/trend_charts_test.dart`

**Interfaces:**
- Consumes: `FluidTrendPoint`, `WeightTrendPoint`
- Produces: `class FluidTrendChart extends StatelessWidget`
- Produces: `class WeightTrendChart extends StatelessWidget`

- [ ] **Step 1: Write widget smoke tests**

Create `test/widgets/trend_charts_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ckd_care/models/trend_models.dart';
import 'package:ckd_care/widgets/trend_charts.dart';

void main() {
  testWidgets('FluidTrendChart renders labels and painter', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: FluidTrendChart(points: [
          FluidTrendPoint(
            label: 'Mon',
            bucketStart: DateTime(2026, 9, 21),
            intakeMl: 500,
            outputMl: 200,
          ),
        ]),
      ),
    ));

    expect(find.byType(CustomPaint), findsOneWidget);
    expect(find.text('Mon'), findsOneWidget);
  });

  testWidgets('WeightTrendChart renders labels and painter with missing post value', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: WeightTrendChart(points: [
          WeightTrendPoint(
            label: 'Sep 21',
            bucketStart: DateTime(2026, 9, 21),
            preWeightKg: 70,
            postWeightKg: null,
          ),
        ]),
      ),
    ));

    expect(find.byType(CustomPaint), findsOneWidget);
    expect(find.text('Sep 21'), findsOneWidget);
  });
}
```

- [ ] **Step 2: Run tests to verify failure**

Run: `flutter test test/widgets/trend_charts_test.dart`

Expected: FAIL because `trend_charts.dart` does not exist.

- [ ] **Step 3: Implement chart widgets**

Create `lib/widgets/trend_charts.dart` with:

```dart
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:ckd_care/models/trend_models.dart';
import 'package:ckd_care/theme/app_theme.dart';

class FluidTrendChart extends StatelessWidget {
  const FluidTrendChart({super.key, required this.points});
  final List<FluidTrendPoint> points;

  @override
  Widget build(BuildContext context) {
    return _ChartFrame(
      labels: _edgeLabels(points.map((p) => p.label).toList()),
      child: CustomPaint(
        painter: _FluidTrendPainter(
          points: points,
          intakeColor: AppColors.water,
          outputColor: Theme.of(context).colorScheme.primary,
          axisColor: Theme.of(context).colorScheme.outlineVariant,
        ),
      ),
    );
  }
}

class WeightTrendChart extends StatelessWidget {
  const WeightTrendChart({super.key, required this.points});
  final List<WeightTrendPoint> points;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return _ChartFrame(
      labels: _edgeLabels(points.map((p) => p.label).toList()),
      child: CustomPaint(
        painter: _WeightTrendPainter(
          points: points,
          preColor: cs.primary,
          postColor: AppColors.water,
          axisColor: cs.outlineVariant,
        ),
      ),
    );
  }
}

class _ChartFrame extends StatelessWidget {
  const _ChartFrame({required this.child, required this.labels});
  final Widget child;
  final List<String> labels;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        SizedBox(height: 190, width: double.infinity, child: child),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: labels
              .map((label) => Text(label, style: Theme.of(context).textTheme.labelSmall))
              .toList(),
        ),
      ],
    );
  }
}

List<String> _edgeLabels(List<String> labels) {
  if (labels.isEmpty) return const ['', ''];
  if (labels.length == 1) return [labels.single];
  return [labels.first, labels.last];
}
```

Then add private painters in the same file. Keep them simple: compute max value, draw axis line, draw grouped bars for fluid, draw connected segments only between non-null points for weights. Use `math.max` and leave `shouldRepaint` comparing old points by identity:

```dart
class _FluidTrendPainter extends CustomPainter {
  _FluidTrendPainter({
    required this.points,
    required this.intakeColor,
    required this.outputColor,
    required this.axisColor,
  });

  final List<FluidTrendPoint> points;
  final Color intakeColor;
  final Color outputColor;
  final Color axisColor;

  @override
  void paint(Canvas canvas, Size size) {
    final axis = Paint()..color = axisColor..strokeWidth = 1;
    canvas.drawLine(Offset(0, size.height), Offset(size.width, size.height), axis);
    if (points.isEmpty) return;
    final maxValue = points.fold<int>(
      1,
      (max, p) => math.max(max, math.max(p.intakeMl, p.outputMl)),
    );
    final groupWidth = size.width / points.length;
    final barWidth = math.max(3.0, groupWidth * 0.24);
    for (var i = 0; i < points.length; i++) {
      final x = i * groupWidth + groupWidth / 2;
      _drawBar(canvas, size, x - barWidth, barWidth, points[i].intakeMl / maxValue, intakeColor);
      _drawBar(canvas, size, x + 2, barWidth, points[i].outputMl / maxValue, outputColor);
    }
  }

  void _drawBar(Canvas canvas, Size size, double x, double width, double ratio, Color color) {
    final height = (size.height - 8) * ratio;
    final rect = Rect.fromLTWH(x, size.height - height, width, height);
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, const Radius.circular(3)),
      Paint()..color = color,
    );
  }

  @override
  bool shouldRepaint(covariant _FluidTrendPainter oldDelegate) =>
      oldDelegate.points != points;
}
```

```dart
class _WeightTrendPainter extends CustomPainter {
  _WeightTrendPainter({
    required this.points,
    required this.preColor,
    required this.postColor,
    required this.axisColor,
  });

  final List<WeightTrendPoint> points;
  final Color preColor;
  final Color postColor;
  final Color axisColor;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawLine(
      Offset(0, size.height),
      Offset(size.width, size.height),
      Paint()..color = axisColor..strokeWidth = 1,
    );
    final values = [
      ...points.map((p) => p.preWeightKg).whereType<double>(),
      ...points.map((p) => p.postWeightKg).whereType<double>(),
    ];
    if (values.isEmpty) return;
    final minValue = values.reduce(math.min);
    final maxValue = values.reduce(math.max);
    final span = math.max(0.1, maxValue - minValue);
    _drawSeries(canvas, size, points.map((p) => p.preWeightKg).toList(), minValue, span, preColor);
    _drawSeries(canvas, size, points.map((p) => p.postWeightKg).toList(), minValue, span, postColor);
  }

  void _drawSeries(Canvas canvas, Size size, List<double?> values, double minValue, double span, Color color) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 2.5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    Offset? previous;
    for (var i = 0; i < values.length; i++) {
      final value = values[i];
      if (value == null) {
        previous = null;
        continue;
      }
      final x = values.length == 1 ? size.width / 2 : (size.width * i) / (values.length - 1);
      final y = size.height - ((value - minValue) / span * (size.height - 16)) - 8;
      final point = Offset(x, y);
      canvas.drawCircle(point, 3.5, Paint()..color = color);
      if (previous != null) canvas.drawLine(previous, point, paint);
      previous = point;
    }
  }

  @override
  bool shouldRepaint(covariant _WeightTrendPainter oldDelegate) =>
      oldDelegate.points != points;
}
```

- [ ] **Step 4: Run chart tests**

Run: `flutter test test/widgets/trend_charts_test.dart`

Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/widgets/trend_charts.dart test/widgets/trend_charts_test.dart
git commit -m "feat: add trend chart widgets"
```

---

### Task 6: Trends Screen

**Files:**
- Create: `lib/screens/trends_screen.dart`
- Create: `test/screens/trends_screen_test.dart`

**Interfaces:**
- Consumes: `TrendsProvider`, `FluidTrendChart`, `WeightTrendChart`
- Produces: `class TrendsScreen extends StatefulWidget`

- [ ] **Step 1: Write TrendsScreen tests**

Create `test/screens/trends_screen_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:ckd_care/models/trend_models.dart';
import 'package:ckd_care/providers/trends_provider.dart';
import 'package:ckd_care/screens/trends_screen.dart';

class _EmptyFluid {
  Future<List<FluidTrendPoint>> trendForRange(TrendRange range) async => [];
}

class _EmptyWeights {
  Future<List<WeightTrendPoint>> trendForRange(TrendRange range) async => [];
}

void main() {
  testWidgets('TrendsScreen renders tabs period controls and empty fluid state', (tester) async {
    final provider = TrendsProvider(
      fluid: _EmptyFluid(),
      weights: _EmptyWeights(),
      now: () => DateTime(2026, 9, 23),
    );

    await tester.pumpWidget(MaterialApp(
      home: ChangeNotifierProvider<TrendsProvider>.value(
        value: provider,
        child: const TrendsScreen(),
      ),
    ));
    await tester.pump();
    await tester.pump();

    expect(find.text('Health trends'), findsOneWidget);
    expect(find.text('Fluid'), findsOneWidget);
    expect(find.text('Weights'), findsOneWidget);
    expect(find.text('Day'), findsOneWidget);
    expect(find.text('No fluid records in this range'), findsOneWidget);
  });

  testWidgets('TrendsScreen shows weights empty state on weights tab', (tester) async {
    final provider = TrendsProvider(
      fluid: _EmptyFluid(),
      weights: _EmptyWeights(),
      now: () => DateTime(2026, 9, 23),
    );

    await tester.pumpWidget(MaterialApp(
      home: ChangeNotifierProvider<TrendsProvider>.value(
        value: provider,
        child: const TrendsScreen(),
      ),
    ));
    await tester.pump();
    await tester.tap(find.text('Weights'));
    await tester.pumpAndSettle();

    expect(find.text('No session weights in this range'), findsOneWidget);
  });
}
```

- [ ] **Step 2: Run tests to verify failure**

Run: `flutter test test/screens/trends_screen_test.dart`

Expected: FAIL because `TrendsScreen` does not exist.

- [ ] **Step 3: Implement screen**

Create `lib/screens/trends_screen.dart`. Use `DefaultTabController(length: 2)`, trigger `context.read<TrendsProvider>().refresh()` in `initState`, and build:

```dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:ckd_care/models/trend_models.dart';
import 'package:ckd_care/providers/trends_provider.dart';
import 'package:ckd_care/widgets/trend_charts.dart';

class TrendsScreen extends StatefulWidget {
  const TrendsScreen({super.key});

  @override
  State<TrendsScreen> createState() => _TrendsScreenState();
}

class _TrendsScreenState extends State<TrendsScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => context.read<TrendsProvider>().refresh(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Health trends'),
          bottom: const TabBar(tabs: [
            Tab(text: 'Fluid'),
            Tab(text: 'Weights'),
          ]),
        ),
        body: Consumer<TrendsProvider>(
          builder: (context, trends, _) => Column(
            children: [
              _PeriodControls(trends: trends),
              Expanded(
                child: TabBarView(children: [
                  _FluidTrendTab(trends: trends),
                  _WeightTrendTab(trends: trends),
                ]),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
```

Add helper widgets in the same file:

```dart
class _PeriodControls extends StatelessWidget {
  const _PeriodControls({required this.trends});
  final TrendsProvider trends;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: Column(children: [
        SegmentedButton<TrendPeriod>(
          segments: const [
            ButtonSegment(value: TrendPeriod.day, label: Text('Day')),
            ButtonSegment(value: TrendPeriod.week, label: Text('Week')),
            ButtonSegment(value: TrendPeriod.month, label: Text('Month')),
            ButtonSegment(value: TrendPeriod.year, label: Text('Year')),
          ],
          selected: {trends.period},
          onSelectionChanged: (values) => trends.setPeriod(values.single),
        ),
        const SizedBox(height: 8),
        Row(children: [
          IconButton(
            icon: const Icon(Icons.chevron_left),
            onPressed: trends.previousRange,
          ),
          Expanded(
            child: Center(
              child: Text(
                trends.range.label,
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.chevron_right),
            onPressed: trends.nextRange,
          ),
        ]),
      ]),
    );
  }
}
```

Implement tabs:

```dart
class _FluidTrendTab extends StatelessWidget {
  const _FluidTrendTab({required this.trends});
  final TrendsProvider trends;

  @override
  Widget build(BuildContext context) {
    if (trends.loading) return const Center(child: CircularProgressIndicator());
    if (trends.error != null) return _RetryPanel(onRetry: trends.refresh);
    final hasData = trends.fluidPoints.any((p) => p.hasData);
    if (!hasData) return const _EmptyState(text: 'No fluid records in this range');
    final intake = trends.fluidPoints.fold<int>(0, (sum, p) => sum + p.intakeMl);
    final output = trends.fluidPoints.fold<int>(0, (sum, p) => sum + p.outputMl);
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _SummaryRow(items: [
          ('Intake', '$intake mL'),
          ('Output', '$output mL'),
          ('Net', '${intake - output} mL'),
        ]),
        const SizedBox(height: 18),
        FluidTrendChart(points: trends.fluidPoints),
      ],
    );
  }
}

class _WeightTrendTab extends StatelessWidget {
  const _WeightTrendTab({required this.trends});
  final TrendsProvider trends;

  @override
  Widget build(BuildContext context) {
    if (trends.loading) return const Center(child: CircularProgressIndicator());
    if (trends.error != null) return _RetryPanel(onRetry: trends.refresh);
    final points = trends.weightPoints.where((p) => p.hasData).toList();
    if (points.isEmpty) return const _EmptyState(text: 'No session weights in this range');
    final removed = points.map((p) => p.removedKg).whereType<double>().toList();
    final averageRemoved = removed.isEmpty
        ? null
        : removed.reduce((a, b) => a + b) / removed.length;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _SummaryRow(items: [
          ('Sessions', '${points.length}'),
          ('Avg removed', averageRemoved == null ? '--' : '${averageRemoved.toStringAsFixed(1)} kg'),
        ]),
        const SizedBox(height: 18),
        WeightTrendChart(points: trends.weightPoints),
      ],
    );
  }
}
```

Add these helper widgets in the same file:

```dart
class _SummaryRow extends StatelessWidget {
  const _SummaryRow({required this.items});
  final List<(String, String)> items;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: items
          .map(
            (item) => Expanded(
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(children: [
                    Text(item.$2, style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 2),
                    Text(item.$1, style: Theme.of(context).textTheme.labelMedium),
                  ]),
                ),
              ),
            ),
          )
          .toList(),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.show_chart_rounded,
              size: 42,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
            const SizedBox(height: 10),
            Text(text, textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}

class _RetryPanel extends StatelessWidget {
  const _RetryPanel({required this.onRetry});
  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Could not load trends right now.'),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
}
```

- [ ] **Step 4: Run screen tests**

Run: `flutter test test/screens/trends_screen_test.dart`

Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/screens/trends_screen.dart test/screens/trends_screen_test.dart
git commit -m "feat: add health trends screen"
```

---

### Task 7: Dashboard Entry Point

**Files:**
- Modify: `lib/screens/dashboard_screen.dart`
- Modify: `test/widget_test.dart`

**Interfaces:**
- Consumes: `TrendsScreen`
- Produces: dashboard Health trends card that opens `TrendsScreen`

- [ ] **Step 1: Update dashboard widget test**

Modify `test/widget_test.dart`:

Add imports:

```dart
import 'package:ckd_care/providers/trends_provider.dart';
import 'package:ckd_care/models/trend_models.dart';
```

Add fakes:

```dart
class _FakeWeights {
  Future<List<WeightTrendPoint>> trendForRange(TrendRange range) async => const [];
}
```

Ensure `_FakeFluid` includes:

```dart
  Future<List<FluidTrendPoint>> trendForRange(TrendRange range) async => const [];
```

Add `TrendsProvider` to the `MultiProvider`:

```dart
          ChangeNotifierProvider<TrendsProvider>(
            create: (_) => TrendsProvider(
              fluid: _FakeFluid(),
              weights: _FakeWeights(),
              now: () => DateTime(2026, 9, 2, 12),
            ),
          ),
```

Add assertion:

```dart
    expect(find.text('Health trends'), findsOneWidget);
```

- [ ] **Step 2: Run dashboard test to verify failure**

Run: `flutter test test/widget_test.dart`

Expected: FAIL because the dashboard does not render `Health trends` yet.

- [ ] **Step 3: Add dashboard card**

Modify `lib/screens/dashboard_screen.dart`:

Add import:

```dart
import 'package:ckd_care/screens/trends_screen.dart';
```

Add helper method inside `_DashboardScreenState`:

```dart
  Widget _trendsCard() {
    final cs = Theme.of(context).colorScheme;
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const TrendsScreen()),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(children: [
            CircleAvatar(
              backgroundColor: cs.primaryContainer,
              foregroundColor: cs.onPrimaryContainer,
              child: const Icon(Icons.show_chart_rounded),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Health trends', style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 2),
                  Text(
                    'Review fluid and dialysis weight patterns',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right, color: cs.onSurfaceVariant),
          ]),
        ),
      ),
    );
  }
```

Place in the `ListView` after `_fluidStats(d)`:

```dart
        const SizedBox(height: 12),
        _trendsCard(),
```

- [ ] **Step 4: Run dashboard test**

Run: `flutter test test/widget_test.dart`

Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/screens/dashboard_screen.dart test/widget_test.dart
git commit -m "feat: link dashboard to health trends"
```

---

### Task 8: Final Verification And Polish

**Files:**
- Modify only files needed for analyzer/test fixes.

**Interfaces:**
- Consumes all prior tasks.
- Produces a verified feature branch.

- [ ] **Step 1: Run focused tests**

Run:

```bash
flutter test test/models/trend_models_test.dart test/repositories/fluid_repository_test.dart test/repositories/dialysis_session_log_repository_test.dart test/providers/trends_provider_test.dart test/widgets/trend_charts_test.dart test/screens/trends_screen_test.dart test/widget_test.dart
```

Expected: PASS.

- [ ] **Step 2: Run analyzer**

Run: `flutter analyze`

Expected: PASS with no issues.

- [ ] **Step 3: Run full test suite**

Run: `flutter test`

Expected: PASS.

- [ ] **Step 4: Inspect working tree**

Run: `git status --short`

Expected: only unrelated pre-existing files may remain modified: `pubspec.yaml` and `macos/Flutter/GeneratedPluginRegistrant.swift`. Any feature files should be committed.

- [ ] **Step 5: Commit verification fixes if any**

If Step 1, 2, or 3 required code changes:

```bash
git add lib test
git commit -m "fix: polish health trends graphs"
```

If no code changes were required, do not create an empty commit.
