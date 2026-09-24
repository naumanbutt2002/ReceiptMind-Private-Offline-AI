# ReceiptMind: Private Offline AI Receipt Scanner

[![CI](https://github.com/naumanbutt2002/ReceiptMind-Private-Offline-AI/actions/workflows/ci.yml/badge.svg)](https://github.com/naumanbutt2002/ReceiptMind-Private-Offline-AI/actions/workflows/ci.yml)
[![License: Apache-2.0](https://img.shields.io/badge/license-Apache--2.0-blue.svg)](LICENSE)
[![Flutter](https://img.shields.io/badge/Flutter-3.47-02569B?logo=flutter)](https://flutter.dev)

**Snap a receipt and the phone reads it.** Merchant, date, total, tax and category are extracted
**on the device** and saved to a private expense tracker. No account, no cloud, no ads, no tracking.
Your receipts never leave your phone.

> 🚧 **Early development.** v0.1 (scan → review → track → export) is being built in the open.
> See the [implementation plan](docs/PLAN.md) and the [roadmap](#roadmap).

## Privacy

- Receipt photos, recognised text and your spending data are stored **only on your device**.
- The Android release build has **no `INTERNET` permission**, so the app cannot send anything anywhere.
  CI checks every release APK for this, and you can verify it yourself with `aapt2 dump permissions`.
- Android cloud backup is turned off, so receipts are not copied to Google Drive behind your back.
  An explicit, encrypted backup you control is planned for v0.3.
- No analytics and no crash reporting.
- Text recognition uses Google ML Kit **on-device**. ML Kit normally sends anonymous usage metrics
  (device model, app version, latency) to Google; without network permission it cannot. Receipt
  content is never part of those metrics. A fully open-source build using Tesseract is planned.

## How it works

```
📷 Capture ──► 🔤 OCR ──► 🧩 Parse ──► ✏️ Review ──► 💾 Save ──► 📊 Insights
 auto-crop    ML Kit,     rules now,    you confirm   SQLite on    totals, export
              on-device   on-device AI  every field   your phone
                          from v0.2
```

- **Rule-based parser** (always on, instant): a pure-Dart package tested against real receipt layouts
  from many countries ([`packages/receipt_parser`](packages/receipt_parser)).
- **On-device AI** (optional, v0.2): a small local LLM for messy receipts, line items and categories.
  You choose whether to download it.

## Roadmap

| Version | Scope |
|---|---|
| **v0.1** | Scan / import, on-device OCR, rule parser, review screen, receipt list, search, categories, monthly totals, CSV export, dark mode |
| v0.2 | Optional on-device AI model, line items, auto-categorisation, charts and budgets |
| v0.3 | App lock, encrypted backup, home-screen widget, batch import, share-to-app, multi-currency |
| v1.0 | Warranty reminders, tax reports, tap a field to see where it was found on the photo |

## Build from source

Requirements: Flutter 3.47+ (Dart 3.13+), Android SDK 36, and Xcode 16+ for iOS.

```bash
flutter pub get
flutter run
```

Generated code (`*.g.dart`, localizations) is committed, so you only need `build_runner` when you change
annotated code. See [CONTRIBUTING.md](CONTRIBUTING.md).

## Contributing

Contributions are welcome. **Adding receipts from your country** is the easiest way to help, and it
needs no Flutter knowledge. Start with [CONTRIBUTING.md](CONTRIBUTING.md) and look for
[`good first issue`](https://github.com/naumanbutt2002/ReceiptMind-Private-Offline-AI/labels/good%20first%20issue).

## License

[Apache License 2.0](LICENSE) © 2026 Muhammad Nauman. See [NOTICE](NOTICE) for third-party terms.
