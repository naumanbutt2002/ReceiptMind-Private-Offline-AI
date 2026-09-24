# Contributing to ReceiptMind

Thanks for helping! This guide gets you from clone to pull request.
By taking part you agree to follow the [Code of Conduct](CODE_OF_CONDUCT.md).

## Setup

1. Install Flutter 3.47+ (stable) and the Android SDK. Xcode is only needed for iOS work.
2. Clone the repo and fetch dependencies:
   ```bash
   flutter pub get
   ```
3. Run the app on an emulator or phone with `flutter run`.

## Project layout

```
lib/                         Flutter app (feature-first: app/, core/, features/)
packages/receipt_parser/     Pure-Dart rule parser (no Flutter imports) + receipt fixtures
test/                        App tests (mirror lib/)
```

## Checks to run before a pull request

```bash
dart format .
flutter analyze
flutter test
(cd packages/receipt_parser && dart test)
```

### Generated code

Generated files (`*.g.dart`, `lib/l10n/generated/`) are committed so the project builds right after cloning.
If you change a Riverpod provider, a Drift table or `lib/l10n/app_en.arb`, regenerate and commit the result:

```bash
flutter gen-l10n
dart run build_runner build
```

## Commits and pull requests

- Use [Conventional Commits](https://www.conventionalcommits.org/): `feat(parser): detect German VAT lines`.
- Keep a pull request focused on one change and include tests.
- Describe what you tested. For UI changes, add a screenshot in light and dark mode.

## Adding receipt fixtures

Coming with v0.1: a developer mode in the app exports a scanned receipt as a test fixture, and this
section will walk through anonymising it and opening a pull request.
