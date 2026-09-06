import 'package:flutter_test/flutter_test.dart';

import '../tool/version.dart';

void main() {
  group('Version', () {
    test('parses Flutter pubspec versions', () {
      expect(Version.parse('1.2.3+4'), const Version(1, 2, 3, 4));
    });

    test('increments patch and build code', () {
      expect(
        Version.parse('1.2.3+4').bump(VersionBump.patch),
        const Version(1, 2, 4, 5),
      );
    });

    test('increments minor, resets patch, and increments build code', () {
      expect(
        Version.parse('1.2.3+4').bump(VersionBump.minor),
        const Version(1, 3, 0, 5),
      );
    });

    test('increments major, resets minor and patch, and increments build code', () {
      expect(
        Version.parse('1.2.3+4').bump(VersionBump.major),
        const Version(2, 0, 0, 5),
      );
    });

    test('rejects unsupported bump names', () {
      expect(
        () => VersionBumpX.parse('build'),
        throwsA(isA<FormatException>()),
      );
    });
  });
}
