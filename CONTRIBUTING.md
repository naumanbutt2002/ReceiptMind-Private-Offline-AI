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

Fixtures are receipts the parser is tested against: the OCR text in `packages/receipt_parser/test/fixtures/receipts/<country>/`
(`.txt`, or `.ocr.json` with line boxes) plus a `.expected.json` with the values a person reads on the receipt.

1. **Anonymise first.** Remove or replace names, card numbers, loyalty and member IDs, and home addresses. Store names,
   dates and amounts stay.
2. Save the OCR text as `<country>/<country>_<kind>_<nn>.txt`, e.g. `fr/fr_bakery_01.txt`.
3. Draft the expected values from what the parser reads today:
   ```bash
   cd packages/receipt_parser
   dart run tool/new_fixture.dart test/fixtures/receipts/fr/fr_bakery_01.txt --currency EUR --date-order dmy --source real
   ```
4. Open the `.expected.json` and correct every value against the paper receipt. Amounts are strings with a dot
   (`"12.50"`). If the parser gets a field wrong and you can't fix it, list the field in `"xfail"`: the tests stay green and the
   report counts it as a failure, which tells us what to fix next.
5. Check the result with `dart test` and `dart run tool/parser_report.dart --verbose`, then open a pull request.

In a later version, a developer mode in the app will export a scanned receipt as a fixture directly.

### Adding a language

Keywords live in `packages/receipt_parser/lib/src/lexicon/` (`en.dart`, `de.dart`). Copy one, translate the words, and add it
to `Lexicon.all`. No parser knowledge is needed.
