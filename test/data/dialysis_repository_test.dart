import 'package:flutter_test/flutter_test.dart';
import 'package:ckd_care/data/dialysis_repository.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('loads the asset and exposes regions/provinces/centers', () async {
    final repo = DialysisRepository();
    await repo.load(); // uses rootBundle
    expect(repo.isLoaded, isTrue);
    expect(repo.regions.length, 17);
    // fixed display order: CAR first, BARMM last
    expect(repo.regions.first, 'CORDILLERA ADMINISTRATIVE REGION');
    expect(repo.regions.last, 'BANGSAMORO AUTONOMOUS REGION (BARMM)');

    final provinces = repo.provincesIn('CORDILLERA ADMINISTRATIVE REGION');
    expect(provinces, contains('ABRA'));
    expect(provinces, equals([...provinces]..sort())); // alphabetical

    final abra = repo.centersIn('CORDILLERA ADMINISTRATIVE REGION', 'ABRA');
    expect(abra, isNotEmpty);
    expect(abra.every((c) => c.province == 'ABRA'), isTrue);
    // sorted by name
    final names = abra.map((c) => c.name).toList();
    expect(names, equals([...names]..sort()));
  });

  test('load is idempotent', () async {
    final repo = DialysisRepository();
    await repo.load();
    final n = repo.regions.length;
    await repo.load();
    expect(repo.regions.length, n);
  });
}
