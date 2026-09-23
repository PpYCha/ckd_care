import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:ckd_care/db/app_database.dart';
import 'package:ckd_care/providers/health_profile_provider.dart';
import 'package:ckd_care/repositories/settings_repository.dart';
import 'package:ckd_care/screens/food_screen.dart';

void main() {
  sqfliteFfiInit();

  testWidgets('food screen exposes good limit and avoid kidney filters', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1080, 2200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final db = AppDatabase(databaseFactoryFfi, path: inMemoryDatabasePath);
    addTearDown(db.close);
    final profile = HealthProfileProvider(SettingsRepository(db));

    await tester.pumpWidget(
      MaterialApp(
        home: ChangeNotifierProvider<HealthProfileProvider>.value(
          value: profile,
          child: const Scaffold(body: FoodScreen()),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Good for kidney'), findsOneWidget);
    expect(find.text('Limit / be careful'), findsOneWidget);
    expect(find.text('Bad for kidney'), findsOneWidget);

    await tester.tap(find.text('Bad for kidney'));
    await tester.pumpAndSettle();

    expect(find.text('Processed meats (bacon, sausage, ham)'), findsWidgets);
    expect(find.text('Apple'), findsNothing);
  });
}
