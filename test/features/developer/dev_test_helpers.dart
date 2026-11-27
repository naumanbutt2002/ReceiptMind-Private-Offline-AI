import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:receipt_mind/core/db/tables/enums.dart';
import 'package:receipt_mind/core/settings/settings_providers.dart';
import 'package:receipt_mind/core/settings/settings_repository.dart';
import 'package:receipt_mind/features/scan/application/receipt_draft.dart';
import 'package:receipt_mind/features/scan/application/scan_state.dart';
import 'package:receipt_mind/l10n/generated/app_localizations.dart';
import 'package:receipt_parser/receipt_parser.dart' hide PaymentMethod;

import '../../helpers/test_app.dart';

const fixturesRoot = 'packages/receipt_parser/test/fixtures/receipts';

final auOptions = ParseOptions(
  defaultCurrency: 'AUD',
  dateOrder: DateOrder.dmy,
  today: LocalDate(2026, 9, 24),
);

/// The OCR layout dump of a fixture, e.g. `au/au_fuel_01`.
OcrDocument layoutFixture(String id) => OcrDocument.fromJson(
  jsonDecode(File('$fixturesRoot/$id.ocr.json').readAsStringSync())
      as Map<String, Object?>,
);

/// Every `.ocr.json` fixture in the parser package.
List<File> layoutFixtureFiles() =>
    Directory(fixturesRoot)
        .listSync(recursive: true)
        .whereType<File>()
        .where((f) => f.path.endsWith('.ocr.json'))
        .toList()
      ..sort((a, b) => a.path.compareTo(b.path));

/// Review data for [document] as the scan controller builds it.
ReviewData debugReviewData(
  OcrDocument document, {
  ParseOptions? options,
  String? imagePath,
}) {
  options ??= auOptions;
  final parsed = const RuleReceiptParser().parse(document, options);
  final issues = const ReceiptValidator().validate(parsed, options);
  return ReviewData(
    document: document,
    parsed: parsed,
    issues: issues,
    draft: ReceiptDraft(
      currency: parsed.currency.value,
      extractionMethod: ExtractionMethod.rules,
      merchant: parsed.merchant?.value ?? '',
      date: parsed.date?.value,
      totalMinor: parsed.total?.value,
      sourceImagePath: imagePath,
    ),
  );
}

/// Provider overrides with in-memory settings.
Future<List<Override>> settingsOverrides({bool developerMode = true}) async {
  final prefs = await inMemoryPrefs({
    SettingsRepository.keyDefaultCurrency: 'AUD',
    SettingsRepository.keyDateOrder: 'dmy',
    SettingsRepository.keyDeveloperMode: developerMode,
  });
  return [
    sharedPreferencesProvider.overrideWithValue(prefs),
    deviceLocaleProvider.overrideWithValue('en_AU'),
  ];
}

/// [home] in a localised MaterialApp.
Widget localizedApp(Widget home) => MaterialApp(
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  home: home,
);

/// [home] in a localised MaterialApp inside a ProviderScope.
Widget scopedApp(Widget home, List<Override> overrides) =>
    ProviderScope(overrides: overrides, child: localizedApp(home));
