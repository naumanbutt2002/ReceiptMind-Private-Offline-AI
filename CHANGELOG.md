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
- Rule-based receipt parser: rebuilds rows from OCR layout, reads merchant, date, total, subtotal, tax (including VAT/MwSt
  tables), tip, currency and payment method, with a confidence and reason per field and a validator for totals and dates.
- English and German keyword lexicons, 28 synthetic receipt fixtures (AU, US, UK, DE) and an accuracy report tool.
- Scanning: camera scan with edge detection or gallery import with cropping; on-device ML Kit OCR.
- Review screen: pre-filled fields with warning flags, photo zoom, recognised text, manual entry and editing.
- Receipt list with search, category filters, month sections, monthly totals per currency and swipe-to-delete with undo.
- Receipt detail, categories management, settings (theme, currency, date format), CSV export, About & privacy.
- Developer mode: OCR debug view and "Export as fixture".
- Photos stored compressed with EXIF removed; orphaned files cleaned up at start-up.

### Fixed
- ML Kit text recognition failed in release builds because R8 renamed its classes; keep rules added.
- Dates read by ML Kit with a stray space (`12/09/ 2026`) are now recognised.
