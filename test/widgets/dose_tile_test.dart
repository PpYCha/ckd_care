import 'package:ckd_care/models/dose_log.dart';
import 'package:ckd_care/providers/dashboard_provider.dart';
import 'package:ckd_care/theme/app_theme.dart';
import 'package:ckd_care/widgets/dose_tile.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('shows an out-of-stock indication for a zero-stock dose', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: buildAppTheme(Brightness.light),
        home: Scaffold(
          body: DoseTile(
            dose: DueDose(
              medicineId: 1,
              medicineName: 'Losartan',
              stockQty: 0,
              timeOfDay: '08:00',
              scheduledTime: DateTime(2026, 9, 2, 8),
              status: null,
            ),
            onMark: (_) {},
          ),
        ),
      ),
    );

    expect(find.textContaining('Out of stock'), findsOneWidget);
  });

  testWidgets('does not allow an out-of-stock dose to be marked taken', (
    tester,
  ) async {
    final marks = <DoseStatus>[];
    await tester.pumpWidget(
      MaterialApp(
        theme: buildAppTheme(Brightness.light),
        home: Scaffold(
          body: DoseTile(
            dose: DueDose(
              medicineId: 1,
              medicineName: 'Losartan',
              stockQty: 0,
              timeOfDay: '08:00',
              scheduledTime: DateTime(2026, 9, 2, 8),
              status: null,
            ),
            onMark: marks.add,
          ),
        ),
      ),
    );

    await tester.tap(find.text('Taken'));
    await tester.pump();

    expect(marks, isEmpty);
  });
}
