import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:ckd_care/db/app_database.dart';
import 'package:ckd_care/models/health_profile.dart';
import 'package:ckd_care/providers/health_profile_provider.dart';
import 'package:ckd_care/repositories/settings_repository.dart';

void main() {
  sqfliteFfiInit();

  test('load then save updates the exposed profile', () async {
    final db = AppDatabase(databaseFactoryFfi, path: inMemoryDatabasePath);
    final provider = HealthProfileProvider(SettingsRepository(db));

    await provider.load();
    expect(provider.profile, const HealthProfile());

    const p = HealthProfile(
        ckdStage: CkdStage.stage3, dialysisStatus: DialysisStatus.peritoneal);
    await provider.save(p);
    expect(provider.profile, p);

    // A fresh provider on the same db reads it back.
    final fresh = HealthProfileProvider(SettingsRepository(db));
    await fresh.load();
    expect(fresh.profile, p);

    await db.close();
  });
}
