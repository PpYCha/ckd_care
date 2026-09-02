import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:provider/provider.dart';
import 'package:sqflite/sqflite.dart';
import 'package:timezone/data/latest.dart' as tzdata;

import 'package:ckd_care/db/app_database.dart';
import 'package:ckd_care/providers/dashboard_provider.dart';
import 'package:ckd_care/providers/fluid_provider.dart';
import 'package:ckd_care/providers/medicine_provider.dart';
import 'package:ckd_care/providers/settings_provider.dart';
import 'package:ckd_care/repositories/fluid_repository.dart';
import 'package:ckd_care/repositories/medicine_repository.dart';
import 'package:ckd_care/repositories/settings_repository.dart';
import 'package:ckd_care/screens/dashboard_screen.dart';
import 'package:ckd_care/screens/fluid_screen.dart';
import 'package:ckd_care/screens/medicines_screen.dart';
import 'package:ckd_care/screens/settings_screen.dart';
import 'package:ckd_care/services/notification_service.dart';
import 'package:ckd_care/theme/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  tzdata.initializeTimeZones();

  final plugin = FlutterLocalNotificationsPlugin();
  await plugin.initialize(const InitializationSettings(
    android: AndroidInitializationSettings('@mipmap/ic_launcher'),
    iOS: DarwinInitializationSettings(),
  ));

  try {
    await plugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.requestNotificationsPermission();
    await plugin
        .resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin>()
        ?.requestPermissions(alert: true, badge: true, sound: true);
  } catch (e) {
    debugPrint('Notification permission request failed: $e');
  }

  final db = AppDatabase(databaseFactory);
  final fluidRepo = FluidRepository(db);
  final settingsRepo = SettingsRepository(db);
  final medicineRepo = MedicineRepository(db);
  final notifications = NotificationService(plugin);

  // Reschedule-on-boot: re-register reminders for every active medicine.
  // Best-effort — a scheduling/permission failure must not block startup.
  try {
    if (await settingsRepo.getNotificationsEnabled()) {
      for (final m in await medicineRepo.activeMedicines()) {
        await notifications.scheduleForMedicine(
            m.id!, await medicineRepo.timesFor(m.id!));
      }
    }
  } catch (e) {
    debugPrint('Boot reschedule failed: $e');
  }

  runApp(CkdApp(
    fluidRepo: fluidRepo,
    settingsRepo: settingsRepo,
    medicineRepo: medicineRepo,
    notifications: notifications,
  ));
}

class CkdApp extends StatelessWidget {
  const CkdApp({
    super.key,
    required this.fluidRepo,
    required this.settingsRepo,
    required this.medicineRepo,
    required this.notifications,
  });
  final FluidRepository fluidRepo;
  final SettingsRepository settingsRepo;
  final MedicineRepository medicineRepo;
  final NotificationService notifications;

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(
            create: (_) => SettingsProvider(
                settingsRepo, medicineRepo, notifications)),
        ChangeNotifierProvider(create: (_) => FluidProvider(fluidRepo)),
        ChangeNotifierProvider(
            create: (_) =>
                MedicineProvider(medicineRepo, notifications, settingsRepo)),
        ChangeNotifierProvider(
            create: (_) => DashboardProvider(
                  fluid: fluidRepo,
                  settings: settingsRepo,
                  medicine: medicineRepo,
                  notifications: notifications,
                )),
      ],
      child: MaterialApp(
        title: 'CKD Care',
        debugShowCheckedModeBanner: false,
        theme: buildAppTheme(),
        home: const HomeShell(),
      ),
    );
  }
}

class HomeShell extends StatefulWidget {
  const HomeShell({super.key});
  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _index = 0;
  static const _titles = ['Dashboard', 'Fluid', 'Medicines', 'Settings'];
  static const _screens = [
    DashboardScreen(),
    FluidScreen(),
    MedicinesScreen(),
    SettingsScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(_titles[_index])),
      body: _screens[_index],
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.dashboard), label: 'Home'),
          NavigationDestination(icon: Icon(Icons.water_drop), label: 'Fluid'),
          NavigationDestination(icon: Icon(Icons.medication), label: 'Meds'),
          NavigationDestination(icon: Icon(Icons.settings), label: 'Settings'),
        ],
      ),
    );
  }
}
