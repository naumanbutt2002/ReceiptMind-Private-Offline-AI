import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:receipt_parser/fixtures.dart';
import 'package:receipt_parser/receipt_parser.dart' hide PaymentMethod;
import 'package:share_plus/share_plus.dart';

import '../../../core/db/tables/enums.dart';
import '../../scan/application/receipt_draft.dart';

/// Hands files to the platform share sheet. Tests use a fake.
abstract interface class FixtureSharer {
  Future<void> shareFiles(List<String> paths, {String? subject});
}

/// [FixtureSharer] backed by `share_plus`. Nothing is uploaded: the user picks
/// where the files go.
final class SharePlusFixtureSharer implements FixtureSharer {
  const SharePlusFixtureSharer();

  @override
  Future<void> shareFiles(List<String> paths, {String? subject}) async {
    await SharePlus.instance.share(
      ShareParams(
        files: [
          for (final path in paths)
            XFile(
              path,
              mimeType: path.endsWith('.json')
                  ? 'application/json'
                  : 'text/plain',
            ),
        ],
        subject: subject,
      ),
    );
  }
}

/// The three files of one exported fixture.
final class FixtureFiles {
  const FixtureFiles({
    required this.name,
    required this.ocrJson,
    required this.text,
    required this.expectedJson,
  });

  /// Base name without extensions, e.g. `au_woolworths_metro_20260912`.
  final String name;

  /// `<name>.ocr.json`: the OCR layout dump.
  final File ocrJson;

  /// `<name>.txt`: the plain OCR text.
  final File text;

  /// `<name>.expected.json`: the user-corrected values.
  final File expectedJson;

  List<File> get all => [ocrJson, text, expectedJson];
}

/// Writes a scan as a parser fixture (`.ocr.json`, `.txt` and a draft
/// `.expected.json` built from the user-corrected values) to a temporary
/// folder and shares the files. The format is the one in
/// `packages/receipt_parser/test/fixtures/receipts/` and `tool/new_fixture.dart`.
final class FixtureExporter {
  const FixtureExporter({required this.tempDirectory, required this.sharer});

  /// The app's temporary directory (`getTemporaryDirectory` in the app).
  final Future<Directory> Function() tempDirectory;
  final FixtureSharer sharer;

  /// Folder under [tempDirectory] that holds the last export. It is emptied
  /// before every export so old receipts don't pile up.
  static const folderName = 'fixture_export';

  /// Writes the three files and returns them.
  Future<FixtureFiles> write({
    required OcrDocument document,
    required ReceiptDraft corrected,
    required ParseOptions options,
    required String name,
  }) async {
    final base = sanitizeFixtureName(name);
    final dir = Directory(p.join((await tempDirectory()).path, folderName));
    if (dir.existsSync()) await dir.delete(recursive: true);
    await dir.create(recursive: true);

    final files = FixtureFiles(
      name: base,
      ocrJson: File(p.join(dir.path, '$base.ocr.json')),
      text: File(p.join(dir.path, '$base.txt')),
      expectedJson: File(p.join(dir.path, '$base.expected.json')),
    );
    await files.ocrJson.writeAsString(_prettyJson(document.toJson()));
    await files.text.writeAsString('${document.text}\n');
    await files.expectedJson.writeAsString(
      _prettyJson(expectedFixtureJson(corrected, options)),
    );
    return files;
  }

  /// Writes the files, then opens the share sheet with them.
  Future<FixtureFiles> export({
    required OcrDocument document,
    required ReceiptDraft corrected,
    required ParseOptions options,
    required String name,
    String? subject,
  }) async {
    final files = await write(
      document: document,
      corrected: corrected,
      options: options,
      name: name,
    );
    await sharer.shareFiles([
      for (final f in files.all) f.path,
    ], subject: subject);
    return files;
  }
}

/// The `.expected.json` content for [corrected]: the parse options, every
/// field that has a value (amounts as decimal strings with the currency's
/// minor digits), no `xfail`, `source: real`.
Map<String, Object?> expectedFixtureJson(
  ReceiptDraft corrected,
  ParseOptions options,
) {
  final currency = corrected.currency;
  final digits = Currencies.isWellFormed(currency)
      ? Currencies.of(currency).minorDigits
      : 2;
  String? amount(int? minor) =>
      minor == null ? null : formatMinorUnits(minor, digits);
  final merchant = corrected.merchant.trim();
  final values = <String, String?>{
    'merchant': merchant.isEmpty ? null : merchant,
    'date': corrected.date?.toIso(),
    'total': amount(corrected.totalMinor),
    'subtotal': amount(corrected.subtotalMinor),
    'tax': amount(corrected.taxMinor),
    'tip': amount(corrected.tipMinor),
    'currency': currency,
    // Fixtures only know card and cash; "other" is left out.
    'paymentMethod': switch (corrected.paymentMethod) {
      PaymentMethod.card => 'card',
      PaymentMethod.cash => 'cash',
      PaymentMethod.other || null => null,
    },
  };
  return {
    'options': parseOptionsToJson(options),
    'expected': {for (final field in fixtureFields) field: ?values[field]},
    'xfail': <String>[],
    'source': 'real',
    'notes': '',
  };
}

/// A default base name: `<country>_<merchant>_<yyyymmdd>`, e.g.
/// `au_woolworths_metro_20260912`. Parts that are unknown are left out.
String defaultFixtureName({
  required String merchant,
  LocalDate? date,
  String? countryCode,
}) {
  var store = sanitizeFixtureName(merchant, fallback: 'receipt');
  if (store.length > 24) {
    store = store.substring(0, 24).replaceAll(RegExp(r'_+$'), '');
  }
  return sanitizeFixtureName(
    [
      if (countryCode != null && countryCode.isNotEmpty) countryCode,
      store,
      if (date != null) date.toIso().replaceAll('-', ''),
    ].join('_'),
  );
}

/// [name] as a safe file name: lower case, letters/digits/underscores only.
/// Falls back to [fallback] when nothing is left.
String sanitizeFixtureName(String name, {String fallback = 'receipt'}) {
  final cleaned = name
      .toLowerCase()
      .split('')
      .map((c) => _ascii[c] ?? c)
      .join()
      .replaceAll(RegExp('[^a-z0-9]+'), '_')
      .replaceAll(RegExp(r'^_+|_+$'), '');
  return cleaned.isEmpty ? fallback : cleaned;
}

/// Common Latin letters with accents, folded for file names.
const _ascii = {
  'ä': 'ae',
  'ö': 'oe',
  'ü': 'ue',
  'ß': 'ss',
  'à': 'a',
  'á': 'a',
  'â': 'a',
  'ã': 'a',
  'å': 'a',
  'æ': 'ae',
  'ç': 'c',
  'è': 'e',
  'é': 'e',
  'ê': 'e',
  'ë': 'e',
  'ì': 'i',
  'í': 'i',
  'î': 'i',
  'ï': 'i',
  'ñ': 'n',
  'ò': 'o',
  'ó': 'o',
  'ô': 'o',
  'õ': 'o',
  'ø': 'o',
  'ù': 'u',
  'ú': 'u',
  'û': 'u',
  'ý': 'y',
  'ÿ': 'y',
};

String _prettyJson(Object? json) =>
    '${const JsonEncoder.withIndent('  ').convert(json)}\n';
