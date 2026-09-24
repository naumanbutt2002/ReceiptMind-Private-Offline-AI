# Changelog

All notable changes to this project are documented here.
The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project follows [Semantic Versioning](https://semver.org/).

## [Unreleased]

### Added
- Project bootstrap: Flutter app (Android + iOS), `receipt_parser` workspace package,
  app shell with Receipts and Settings tabs, light/dark theme, localization setup.
- Release builds ship without the Android `INTERNET` permission; Android cloud backup is off.
- CI: format, generated-code, analyze and test checks; release APK permission check; iOS build.
