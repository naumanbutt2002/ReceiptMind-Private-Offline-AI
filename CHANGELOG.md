# Changelog

All notable changes to this project are documented here.
The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project follows [Semantic Versioning](https://semver.org/).

## [Unreleased]

### Added
- Project bootstrap: Flutter app (Android + iOS), `receipt_parser` workspace package,
  app shell with Receipts and Settings tabs, light/dark theme, localization setup.
- Release builds ship without the Android `INTERNET` permission; Android cloud backup is off.
- Money type with exact minor units, locale-aware formatting and input parsing (USD, EUR, JPY, KWD, …).
- Calendar-date type and currency table shared with the parser package.
- On-device database (Drift, schema v1): receipts and categories, 7 default categories, search, month totals per currency.
- Settings: default currency and date order from the device region, stored preferences override them.
