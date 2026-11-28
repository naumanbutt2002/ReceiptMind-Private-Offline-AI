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
- Scanning: camera scan with edge detection or gallery import with cropping; on-device ML Kit OCR. Clear screens
  when camera or photo access is off or the scanner isn't available, with manual entry as the fallback.
- Review screen: pre-filled fields with warning flags, photo zoom, recognised text, manual entry and editing;
  changing the currency keeps the amounts' values, and leaving with unsaved changes asks first.
- Receipt list with search, category filters, month sections, monthly totals per currency and swipe-to-delete with undo.
- Receipt detail with "Share photo", categories management, settings (theme, currency, date format), CSV export,
  About & privacy.
- Developer mode (tap Version in Settings 7 times): OCR debug view with the parser trace and "Export as fixture".
- Photos stored compressed with EXIF removed; orphaned files and scanner temp files cleaned up.
- Clear errors when the phone runs out of storage while saving, or when a scanned photo is gone before saving
  (save without the photo or discard).
- Accessibility: screen-reader labels on icon buttons and photos; works with large text and in dark mode.
- Contributor guide with a step-by-step fixture walkthrough and anonymisation checklist; issue forms (bug, feature,
  receipt not parsed) and a pull request template.

### Fixed
- ML Kit text recognition failed in release builds because R8 renamed its classes; keep rules added.
- Dates read by ML Kit with a stray space (`12/09/ 2026`) are now recognised.
