import 'dart:async';
import 'dart:developer' as developer;
import 'dart:isolate';

import 'package:flutter/foundation.dart';

import 'package:receipt_parser/receipt_parser.dart' hide PaymentMethod;
import 'package:receipt_parser/receipt_parser.dart'
    as parser
    show PaymentMethod;
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/clock.dart';
import '../../../core/db/tables/enums.dart';
import '../../../core/settings/settings_providers.dart';
import '../../receipts/data/receipts_providers.dart';
import '../capture/document_scanner.dart';
import '../scan_providers.dart';
import 'receipt_draft.dart';
import 'scan_state.dart';

part 'scan_controller.g.dart';

/// Runs one scan: scanner → OCR → rule parser → validator → [ScanReview].
///
/// Kept alive so the draft survives navigation to the review screen and
/// back. Automatic retry is off: a failed scan or OCR run must never be
/// started again without the user asking.
@Riverpod(keepAlive: true, retry: _noRetry)
class ScanController extends _$ScanController {
  /// Incremented by every [start] and [reset]. A scan only writes its result
  /// while its own number is still current, so a late OCR result can't
  /// overwrite a newer state.
  int _run = 0;

  @override
  ScanState build() => const ScanIdle();

  /// Opens the scanner for [source] and reads the receipt. Ends in
  /// [ScanReview], [ScanFailed], or [ScanIdle] when the user cancelled.
  Future<void> start(ScanSource source) async {
    final run = ++_run;
    bool isCurrent() => ref.mounted && run == _run;

    state = ScanCapturing(source);
    final String? imagePath;
    try {
      imagePath = await ref.read(documentScannerProvider).scan(source);
    } on ScanFailure catch (failure) {
      if (isCurrent()) state = ScanFailed(failure);
      return;
    } on Object catch (error, stackTrace) {
      _log('Scanner failed', error, stackTrace);
      if (isCurrent()) {
        state = ScanFailed(
          ScanFailure(ScanFailureReason.other, error.toString()),
        );
      }
      return;
    }
    if (!isCurrent()) return;
    if (imagePath == null) {
      state = const ScanIdle();
      return;
    }

    state = ScanReading(imagePath);
    final settings = ref.read(settingsControllerProvider);
    final today = LocalDate.fromDateTime(ref.read(clockProvider)());

    final watch = Stopwatch()..start();
    OcrDocument? document;
    try {
      document = await ref.read(ocrEngineProvider).recognize(imagePath);
    } on Object catch (error, stackTrace) {
      _log('OCR failed', error, stackTrace);
    }
    final ocrMs = watch.elapsedMilliseconds;
    if (!isCurrent()) return;

    if (document == null || document.text.trim().isEmpty) {
      _logTiming(ocrMs, 0, document?.lines.length ?? 0);
      state = ScanReview(
        ReviewData(
          ocrFailed: true,
          document: document,
          draft: ReceiptDraft(
            currency: settings.defaultCurrency,
            extractionMethod: ExtractionMethod.manual,
            sourceImagePath: imagePath,
          ),
        ),
      );
      return;
    }

    final options = ParseOptions(
      defaultCurrency: settings.defaultCurrency,
      dateOrder: settings.dateOrder,
      today: today,
    );
    final ParseResult result;
    watch.reset();
    try {
      result = await ref.read(receiptParseProvider)(document, options);
    } on Object catch (error, stackTrace) {
      // A parser bug must not lose the photo: fall back to manual entry,
      // with the banner that explains the empty form.
      _log('Parsing failed', error, stackTrace);
      if (isCurrent()) {
        state = ScanReview(
          ReviewData(
            ocrFailed: true,
            document: document,
            draft: ReceiptDraft(
              currency: settings.defaultCurrency,
              extractionMethod: ExtractionMethod.manual,
              sourceImagePath: imagePath,
              rawOcrText: document.text,
            ),
          ),
        );
      }
      return;
    }
    if (!isCurrent()) return;
    _logTiming(ocrMs, watch.elapsedMilliseconds, document.lines.length);

    state = ScanReview(
      reviewDataFor(
        document: document,
        parsed: result.parsed,
        issues: result.issues,
        sourceImagePath: imagePath,
      ),
    );
  }

  /// Drops the current scan (also cancels a running one: its result is
  /// ignored when it arrives). A scan that reached review is saved or
  /// discarded by now, so the scanner's temporary photo is deleted too.
  void reset() {
    final hadReview = state is ScanReview;
    _run++;
    state = const ScanIdle();
    if (hadReview) _cleanScannerCache();
  }

  /// Deletes the scanner's temporary files in the background, so the photo
  /// doesn't linger in the app's external storage
  /// (`Android/data/<id>/files/Pictures/DOCUMENT_SCAN_*`). Best effort.
  void _cleanScannerCache() {
    try {
      final scanner = ref.read(documentScannerProvider);
      unawaited(
        scanner.cleanCache().catchError((Object error, StackTrace stack) {
          _log('Could not clean the scanner cache', error, stack);
        }),
      );
    } on Object catch (error, stackTrace) {
      _log('Could not clean the scanner cache', error, stackTrace);
    }
  }

  /// Saves [draft] as a new receipt (the repository copies the photo into
  /// app storage), clears the scan and its temporary photo, and returns the
  /// new id. On error the state is left alone so the user can try again.
  Future<String> save(ReceiptDraft draft) async {
    final id = await ref.read(receiptRepositoryProvider).createFromDraft(draft);
    if (ref.mounted) reset();
    return id;
  }
}

Duration? _noRetry(int retryCount, Object error) => null;

/// For QA: "review shown < 3 s after the scan" (PLAN M8.5). debugPrint, so
/// it shows in `flutter logs` and logcat.
void _logTiming(int ocrMs, int parseMs, int lines) => debugPrint(
  'ReceiptMind scan: ocr $ocrMs ms, parse $parseMs ms, $lines lines',
);

void _log(String message, Object error, StackTrace stackTrace) =>
    developer.log(message, name: 'scan', error: error, stackTrace: stackTrace);

/// The parser's output for one document.
typedef ParseResult = ({ParsedReceipt parsed, List<ValidationIssue> issues});

/// Parses and validates one OCR document.
typedef ReceiptParseFn = Future<ParseResult> Function(
  OcrDocument document,
  ParseOptions options,
);

/// How [ScanController] parses: [parseInBackground]. Tests override it, e.g.
/// to simulate a parser bug.
@Riverpod(keepAlive: true)
ReceiptParseFn receiptParse(Ref ref) => parseInBackground;

/// Parses and validates [document] on a background isolate, so a long
/// receipt can't drop frames. Both sides are plain Dart objects.
Future<ParseResult> parseInBackground(
  OcrDocument document,
  ParseOptions options,
) => Isolate.run(() => parseNow(document, options));

/// Parses and validates [document] on the current isolate.
ParseResult parseNow(OcrDocument document, ParseOptions options) {
  final parsed = const RuleReceiptParser().parse(document, options);
  return (
    parsed: parsed,
    issues: const ReceiptValidator().validate(parsed, options),
  );
}

/// Builds the review screen's pre-filled draft and ⚠️ flags from the parser
/// output: low-confidence values and every validator issue, by field.
ReviewData reviewDataFor({
  required OcrDocument document,
  required ParsedReceipt parsed,
  required List<ValidationIssue> issues,
  required String sourceImagePath,
}) {
  final warnings = <ReceiptField, List<IssueCode>>{};
  void flag(ReceiptField field, IssueCode code) {
    final codes = warnings.putIfAbsent(field, () => []);
    if (!codes.contains(code)) codes.add(code);
  }

  final fields = <ReceiptField, ParsedField<Object>?>{
    ReceiptField.merchant: parsed.merchant,
    ReceiptField.date: parsed.date,
    ReceiptField.total: parsed.total,
    ReceiptField.subtotal: parsed.subtotal,
    ReceiptField.tax: parsed.tax,
    ReceiptField.tip: parsed.tip,
    ReceiptField.currency: parsed.currency,
    ReceiptField.paymentMethod: parsed.paymentMethod,
  };
  fields.forEach((field, value) {
    if (value != null && value.confidence < ReceiptValidator.lowConfidence) {
      flag(field, IssueCode.lowConfidence);
    }
  });
  for (final issue in issues) {
    flag(issue.field, issue.code);
  }

  return ReviewData(
    document: document,
    parsed: parsed,
    issues: List.unmodifiable(issues),
    warnings: Map.unmodifiable({
      for (final MapEntry(:key, :value) in warnings.entries)
        key: List<IssueCode>.unmodifiable(value),
    }),
    draft: ReceiptDraft(
      merchant: parsed.merchant?.value ?? '',
      date: parsed.date?.value,
      totalMinor: parsed.total?.value,
      subtotalMinor: parsed.subtotal?.value,
      taxMinor: parsed.tax?.value,
      tipMinor: parsed.tip?.value,
      currency: parsed.currency.value,
      paymentMethod: switch (parsed.paymentMethod?.value) {
        parser.PaymentMethod.card => PaymentMethod.card,
        parser.PaymentMethod.cash => PaymentMethod.cash,
        null => null,
      },
      rawOcrText: document.text,
      confidence: parsed.overallConfidence,
      extractionMethod: ExtractionMethod.rules,
      sourceImagePath: sourceImagePath,
    ),
  );
}
