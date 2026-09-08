// test/models/dialysis_center_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:ckd_care/models/dialysis_center.dart';

void main() {
  test('fromJson parses fields and builds a joined address', () {
    final c = DialysisCenter.fromJson({
      'num': 1,
      'region': 'CORDILLERA ADMINISTRATIVE REGION',
      'province': 'ABRA',
      'name': 'HEALTH SCREEN LABORATORY AND DIAGNOSTIC CENTER',
      'tels': ['9363412735'],
      'emails': ['abrahealthscreen@gmail.com'],
      'street': 'CAPITULACION ST., ZONE 1',
      'municipality': 'BANGUED',
      'expiry': ['12/31/2027'],
      'sec': 'P',
    });
    expect(c.num, 1);
    expect(c.province, 'ABRA');
    expect(c.tels.single, '9363412735');
    expect(c.address, 'CAPITULACION ST., ZONE 1, BANGUED');
  });

  test('fromJson tolerates missing optional lists', () {
    final c = DialysisCenter.fromJson({
      'num': 5, 'region': 'REGION I', 'province': 'DAGUPAN CITY',
      'name': 'X', 'street': '', 'municipality': '', 'sec': '',
    });
    expect(c.tels, isEmpty);
    expect(c.emails, isEmpty);
    expect(c.expiry, isEmpty);
    expect(c.address, '');
  });
}
