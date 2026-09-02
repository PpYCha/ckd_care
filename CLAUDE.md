# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project

`ckd_care` is a Flutter application. It currently contains only the default `flutter create` counter-app scaffold (`lib/main.dart`) — no custom architecture exists yet. Update this file once real app structure (state management, routing, features) is introduced.

Dart SDK: `^3.13.2` (see `pubspec.yaml`). Platforms scaffolded: Android, iOS, web, Windows, Linux, macOS.

## Commands

- Install dependencies: `flutter pub get`
- Run the app (device/emulator required): `flutter run`
- Static analysis / lint: `flutter analyze`
- Run all tests: `flutter test`
- Run a single test file: `flutter test test/widget_test.dart`
- Build: `flutter build <platform>` (e.g. `apk`, `ios`, `windows`, `web`)

Lints come from `package:flutter_lints/flutter.yaml` via `analysis_options.yaml`; platform build directories (`android/`, `ios/`, `web/`, `windows/`, `macos/`, `linux/`) are excluded from analysis.
