import 'dart:io';

enum VersionBump { patch, minor, major }

extension VersionBumpX on VersionBump {
  static VersionBump parse(String value) {
    return switch (value) {
      'patch' => VersionBump.patch,
      'minor' => VersionBump.minor,
      'major' => VersionBump.major,
      _ => throw FormatException(
          'Expected one of: patch, minor, major. Got "$value".',
        ),
    };
  }
}

class Version {
  const Version(this.major, this.minor, this.patch, this.build);

  final int major;
  final int minor;
  final int patch;
  final int build;

  static final _pattern = RegExp(r'^(\d+)\.(\d+)\.(\d+)\+(\d+)$');

  static Version parse(String value) {
    final match = _pattern.firstMatch(value.trim());
    if (match == null) {
      throw FormatException(
        'Expected version format like 1.2.3+4. Got "$value".',
      );
    }
    return Version(
      int.parse(match.group(1)!),
      int.parse(match.group(2)!),
      int.parse(match.group(3)!),
      int.parse(match.group(4)!),
    );
  }

  Version bump(VersionBump bump) {
    return switch (bump) {
      VersionBump.patch => Version(major, minor, patch + 1, build + 1),
      VersionBump.minor => Version(major, minor + 1, 0, build + 1),
      VersionBump.major => Version(major + 1, 0, 0, build + 1),
    };
  }

  @override
  String toString() => '$major.$minor.$patch+$build';

  @override
  bool operator ==(Object other) {
    return other is Version &&
        other.major == major &&
        other.minor == minor &&
        other.patch == patch &&
        other.build == build;
  }

  @override
  int get hashCode => Object.hash(major, minor, patch, build);
}

void main(List<String> args) {
  if (args.length != 1) {
    stderr.writeln('Usage: dart run tool/version.dart <patch|minor|major>');
    exitCode = 64;
    return;
  }

  final bump = VersionBumpX.parse(args.single);
  final pubspec = File('pubspec.yaml');
  if (!pubspec.existsSync()) {
    stderr.writeln('pubspec.yaml not found. Run this from the project root.');
    exitCode = 66;
    return;
  }

  final original = pubspec.readAsStringSync();
  final versionLine = RegExp(r'^version:\s*(\S+)\s*$', multiLine: true);
  final match = versionLine.firstMatch(original);
  if (match == null) {
    stderr.writeln('No version: line found in pubspec.yaml.');
    exitCode = 65;
    return;
  }

  final current = Version.parse(match.group(1)!);
  final next = current.bump(bump);
  final updated = original.replaceFirst(versionLine, 'version: $next');
  pubspec.writeAsStringSync(updated);

  stdout.writeln('$current -> $next');
}
