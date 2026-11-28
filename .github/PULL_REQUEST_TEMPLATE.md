## Summary

<!-- What does this change and why? Link the issue it fixes, e.g. "Fixes #12". -->

## Type of change

- [ ] Receipt fixture(s)
- [ ] Parser or lexicon
- [ ] App feature or UI
- [ ] Bug fix
- [ ] Translation
- [ ] Docs or tooling

## Checks run

<!-- Tick what you ran locally. There is no CI, so these checks are the review gate. -->

- [ ] `dart format .` (no changes left)
- [ ] `flutter analyze` shows no issues
- [ ] `flutter test` passes
- [ ] `cd packages/receipt_parser && dart test` passes
- [ ] `cd packages/receipt_parser && dart run tool/parser_report.dart --check` passes (parser, lexicon or fixture changes)
- [ ] Generated code is up to date (`flutter gen-l10n` / `dart run build_runner build` after changing providers, Drift tables or ARB files)

<!-- For parser changes, paste the parser_report table before and after if the numbers moved. -->

## Screenshots (UI changes)

<!-- Light and dark mode. Use demo data, never a real receipt with personal data. -->

| Light | Dark |
|---|---|
|  |  |

## Privacy

- [ ] Fixtures and screenshots are anonymised: no card numbers, names, loyalty or member IDs, phone numbers, e-mail or home addresses.
- [ ] The change adds no network access, analytics or new permission (the release build must not contain `INTERNET`).
