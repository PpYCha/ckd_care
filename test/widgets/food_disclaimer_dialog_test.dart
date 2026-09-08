import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ckd_care/widgets/food_disclaimer_dialog.dart';

void main() {
  testWidgets('Continue is disabled until the checkbox is ticked', (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(body: FoodDisclaimerDialog()),
    ));

    final continueFinder = find.widgetWithText(FilledButton, 'I Understand & Continue');
    expect(continueFinder, findsOneWidget);
    // Disabled = onPressed is null.
    expect(tester.widget<FilledButton>(continueFinder).onPressed, isNull);

    // Scroll to make checkbox visible
    await tester.dragUntilVisible(
      find.byType(Checkbox),
      find.byType(SingleChildScrollView),
      const Offset(0, -300),
    );

    await tester.tap(find.byType(Checkbox));
    await tester.pump();

    expect(tester.widget<FilledButton>(continueFinder).onPressed, isNotNull);
    expect(find.widgetWithText(TextButton, 'Go Back'), findsOneWidget);
  });
}
