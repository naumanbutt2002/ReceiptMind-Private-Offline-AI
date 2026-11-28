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
(cd packages/receipt_parser && dart test && dart run tool/parser_report.dart --check)
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

Fixtures are receipts the parser is tested against: the OCR result in `packages/receipt_parser/test/fixtures/receipts/<cc>/`
(`.ocr.json` with line boxes, or plain `.txt`) plus a `.expected.json` with the values a person reads on the receipt.
`<cc>` is the lower-case country code of the folder (`au`, `de`, `uk`, `us`, …). When both an `.ocr.json` and a `.txt`
exist, the tests use the `.ocr.json`. Real receipts from new countries are the most useful contribution, and you
don't need to know Flutter or the parser to add one.

### Add a receipt fixture in 5 minutes

You need the app on an Android phone or emulator (a release APK, or `flutter run` from this repo) and the paper receipt.

1. **Turn on developer mode.** Open **Settings** and tap **Version** 7 times in a row (less than 3 seconds between
   taps). A "Developer mode is on" message appears, and a **Developer mode** switch shows up under Version.
   Use the same switch to turn it off later.
2. **Scan the receipt.** On the **Receipts** tab tap **Add receipt**, then **Scan** (or **Import from photos** and crop).
3. **Fix the fields on the review screen.** Correct every value so it matches the paper receipt: merchant, date,
   total, currency and payment method, and under **More details** the subtotal, tax and tip. Leave a field empty if
   it isn't printed. Whatever you enter becomes the expected values of the fixture.
4. **Export before you save.** Tap the bug icon (**Developer tools**) in the top bar, then **Export as fixture**.
   The icon is only shown on the review screen of a new scan, so don't save the receipt first.
   (**Inspect OCR** in the same menu shows the OCR boxes, the rebuilt rows and the parser trace.)
5. **Read the "Before you share" reminder** and pick a file name. Use `<cc>_<store type>_<nn>`, e.g. `fr_bakery_01`,
   rather than the suggested merchant-and-date name. Tap **Continue**.
6. **Share the three files to yourself** from the share sheet (save to Files, Drive, or e-mail them to yourself):
   `<name>.ocr.json`, `<name>.txt` and `<name>.expected.json`. Nothing is uploaded by the app; you choose where the
   files go.
7. **Anonymise** on your computer with the [checklist](#anonymisation-checklist) below. Edit every `"text"` value in
   the `.ocr.json` (lines *and* the `words` inside them) and the `.txt` the same way. If that is too fiddly, delete
   the `.ocr.json` and keep only the anonymised `.txt`; the layout is lost, but the fixture still works.
8. **Place the files** in `packages/receipt_parser/test/fixtures/receipts/<cc>/`, creating the folder for a new
   country. Use the folder's prefix in the file names (receipts from the United Kingdom go in `uk/`, even though the
   phone's region is `GB`). Check the number `<nn>` isn't taken yet.
9. **Check the `.expected.json`.** `options` holds the currency, date order and "today" the scan was parsed with;
   `expected` holds your corrected values (amounts as strings with a dot, e.g. `"12.50"`). Add a short `notes`
   line about what makes the receipt hard, such as "total printed in a VAT table".
10. **Run the tests and the report:**
    ```bash
    cd packages/receipt_parser
    dart test
    dart run tool/parser_report.dart --verbose
    ```
    If the parser gets a field wrong and you can't fix it, list the field in `"xfail"` (e.g. `"xfail": ["tax"]`). The
    tests stay green and the report counts it as a failure, which tells us what to fix next.
11. **Open a pull request**, e.g. `test(fixtures): add French bakery receipt`, and tick the anonymisation box in the
    template.

Don't want to open a pull request? Use the **Receipt not parsed correctly** issue form and attach the anonymised files
instead.

### Without the app: from a text file

1. Anonymise the OCR text with the [checklist](#anonymisation-checklist) below.
2. Save it as `<cc>/<cc>_<kind>_<nn>.txt`, e.g. `fr/fr_bakery_01.txt`.
3. Draft the expected values from what the parser reads today:
   ```bash
   cd packages/receipt_parser
   dart run tool/new_fixture.dart test/fixtures/receipts/fr/fr_bakery_01.txt --currency EUR --date-order dmy --source real
   ```
4. Open the `.expected.json` and correct every value against the paper receipt. Amounts are strings with a dot
   (`"12.50"`). Fields the parser can't read yet go in `"xfail"`, as above.
5. Check the result with `dart test` and `dart run tool/parser_report.dart --verbose`, then open a pull request.

### Anonymisation checklist

Everything in a fixture becomes public. Before you share the files, remove or replace:

- [ ] Card numbers, including masked ones (`**** 1234`), card expiry dates and terminal/authorisation codes tied to your card
- [ ] Names: yours, the cashier's or server's, and anyone else's
- [ ] Loyalty, member, customer and account numbers, and barcodes or QR-code text that encode them
- [ ] Phone numbers, e-mail addresses and home or delivery addresses
- [ ] Anything else that identifies you, such as a car registration on a fuel receipt or a table or room booking name

Keep the store name, the store's address, dates, items and amounts: the parser needs them. Replace text with a
placeholder of similar shape (`XXXX XXXX XXXX 0000`, `Jane Doe`) instead of deleting the whole line, so the layout stays
realistic. Never commit photos of receipts.

### Adding a language

Keywords live in `packages/receipt_parser/lib/src/lexicon/` (`en.dart`, `de.dart`). Copy one, translate the words, and add it
to `Lexicon.all`. No parser knowledge is needed. All lexicons are used together on every receipt, so leave out very
short or common words that would match lines in other languages, and add at least one fixture from a country that
uses the language.

### Translating the app

The app's texts are in `lib/l10n/app_en.arb`. To add a language, copy it to `app_<language>.arb` (e.g. `app_fr.arb`),
translate the values (not the keys or `{placeholders}`), drop the `@`-entries or keep them as notes, and run
`flutter gen-l10n`. Add the language code to `CFBundleLocalizations` in `ios/Runner/Info.plist` so iOS picks it up.
Commit the `.arb` file together with the regenerated `lib/l10n/generated/` files, and check the screens in the app for
text that no longer fits.
