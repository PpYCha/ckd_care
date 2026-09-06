# ckd_care

A new Flutter project.

## Getting Started

This project is a starting point for a Flutter application.

A few resources to get you started if this is your first Flutter project:

- [Learn Flutter](https://docs.flutter.dev/get-started/learn-flutter)
- [Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Flutter learning resources](https://docs.flutter.dev/reference/learning-resources)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.

flutter emulators --launch Pixel_4a_API_34

flutter run -d emulator-5554

flutter clean
flutter pub get
flutter build apk --release

Once the process finishes, you will find your compiled APK file(s) in your project folder at this path:
build/app/outputs/flutter-apk/

flutter build appbundle --release
C:\projects\personal\ckd_care\build\app\outputs\bundle\release\app-release.aab

## Release version bumps

Google Play requires every uploaded Android app bundle to use a new version
code. Bump the app version before building a new release:

```powershell
dart run tool/version.dart patch
dart run tool/version.dart minor
dart run tool/version.dart major
```

Examples:

- `patch`: `1.0.1+2` -> `1.0.2+3`
- `minor`: `1.0.1+2` -> `1.1.0+3`
- `major`: `1.0.1+2` -> `2.0.0+3`

Then build the new bundle:

```powershell
flutter build appbundle --release
```
