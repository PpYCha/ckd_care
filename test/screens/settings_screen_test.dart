import 'package:ckd_care/db/app_database.dart';
import 'package:ckd_care/providers/health_profile_provider.dart';
import 'package:ckd_care/providers/settings_provider.dart';
import 'package:ckd_care/repositories/medicine_repository.dart';
import 'package:ckd_care/repositories/settings_repository.dart';
import 'package:ckd_care/screens/settings_screen.dart';
import 'package:ckd_care/services/notification_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:provider/provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  sqfliteFfiInit();

  late AppDatabase db;
  late SettingsRepository settings;

  setUp(() async {
    PackageInfo.setMockInitialValues(
      appName: 'KidneyTrack',
      packageName: 'com.example.ckd_care',
      version: '1.2.3',
      buildNumber: '4',
      buildSignature: '',
      installerStore: null,
    );
    db = AppDatabase(databaseFactoryFfi, path: inMemoryDatabasePath);
    settings = SettingsRepository(db);
  });

  tearDown(() async {
    await db.close();
  });

  testWidgets('settings opens about details with app metadata version', (
    tester,
  ) async {
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider(
            create: (_) => SettingsProvider(
              settings,
              MedicineRepository(db),
              NotificationService(FlutterLocalNotificationsPlugin()),
            ),
          ),
          ChangeNotifierProvider(
            create: (_) => HealthProfileProvider(settings),
          ),
        ],
        child: const MaterialApp(home: Scaffold(body: SettingsScreen())),
      ),
    );
    await tester.pump();

    await tester.tap(find.text('About KidneyTrack'));
    await tester.pumpAndSettle();

    expect(find.text('KidneyTrack'), findsWidgets);
    expect(find.text('Version 1.2.3 (build 4)'), findsOneWidget);
    expect(find.textContaining('personal CKD companion'), findsOneWidget);
    expect(find.textContaining('stored locally'), findsOneWidget);
  });
}
