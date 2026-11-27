import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:receipt_mind/core/clock.dart';
import 'package:receipt_mind/core/db/tables/enums.dart';
import 'package:receipt_mind/core/settings/settings_providers.dart';
import 'package:receipt_mind/core/settings/settings_repository.dart';
import 'package:receipt_mind/features/receipts/data/receipts_providers.dart';
import 'package:receipt_mind/features/scan/application/receipt_draft.dart';
import 'package:receipt_mind/features/scan/application/scan_controller.dart';
import 'package:receipt_mind/features/scan/application/scan_state.dart';
import 'package:receipt_mind/features/scan/capture/document_scanner.dart';
import 'package:receipt_mind/features/scan/scan_providers.dart';
import 'package:receipt_parser/receipt_parser.dart' hide PaymentMethod;

import '../../helpers/scan_fakes.dart';
import '../../helpers/test_app.dart';

const _imagePath = '/tmp/scan.jpg';

/// The parts of a test: fakes plus a container wired to them.
final class _Harness {
  _Harness(this.container, this.scanner, this.ocr, this.repository);

  final ProviderContainer container;
  final FakeDocumentScanner scanner;
  final FakeOcrEngine ocr;
  final FakeReceiptRepository repository;

  /// Every state the controller went through, starting with the current one.
  final List<ScanState> states = [];
  late final ProviderSubscription<ScanState> subscription;

  ScanController get controller =>
      container.read(scanControllerProvider.notifier);
  ScanState get state => container.read(scanControllerProvider);

  ReviewData get review => switch (state) {
    ScanReview(:final data) => data,
    final other => throw StateError('Not in review: $other'),
  };
}

Future<_Harness> _harness({
  FakeDocumentScanner? scanner,
  FakeOcrEngine? ocr,
  ReceiptParseFn? parse,
  String currency = 'AUD',
  DateOrder dateOrder = DateOrder.dmy,
  DateTime? now,
}) async {
  final prefs = await inMemoryPrefs({
    SettingsRepository.keyDefaultCurrency: currency,
    SettingsRepository.keyDateOrder: dateOrder.name,
  });
  final fakeScanner = scanner ?? FakeDocumentScanner(path: _imagePath);
  final fakeOcr = ocr ?? FakeOcrEngine();
  final repository = FakeReceiptRepository();
  final container = ProviderContainer.test(
    overrides: [
      sharedPreferencesProvider.overrideWithValue(prefs),
      deviceLocaleProvider.overrideWithValue('en_AU'),
      documentScannerProvider.overrideWithValue(fakeScanner),
      ocrEngineProvider.overrideWithValue(fakeOcr),
      receiptRepositoryProvider.overrideWithValue(repository),
      if (parse != null) receiptParseProvider.overrideWithValue(parse),
      clockProvider.overrideWithValue(
        () => now ?? DateTime(2026, 11, 16, 10, 30),
      ),
    ],
  );
  final harness = _Harness(container, fakeScanner, fakeOcr, repository);
  harness.subscription = container.listen(
    scanControllerProvider,
    (_, next) => harness.states.add(next),
    fireImmediately: true,
  );
  return harness;
}

/// The AU receipt with a total that doesn't match subtotal + GST.
final _mismatchedText = auReceiptText
    .replaceAll('Total includes GST 9.88', 'GST 9.88')
    .replaceAll(r'TOTAL $108.70', r'TOTAL $120.00');

void main() {
  setUpAll(initializeDateFormatting);

  test('starts idle', () async {
    final h = await _harness();
    expect(h.state, isA<ScanIdle>());
  });

  test('a parser crash keeps the photo and opens an empty form with the '
      'banner', () async {
    final h = await _harness(
      parse: (_, _) async => throw StateError('parser bug'),
    );

    await h.controller.start(ScanSource.camera);

    final review = h.review;
    expect(review.ocrFailed, isTrue);
    expect(review.draft.sourceImagePath, _imagePath);
    expect(review.draft.rawOcrText, auReceiptText);
    expect(review.draft.merchant, isEmpty);
    expect(review.draft.totalMinor, isNull);
    expect(review.draft.currency, 'AUD');
    expect(review.draft.extractionMethod, ExtractionMethod.manual);
    expect(review.warnings, isEmpty);
  });

  test('a non-receipt photo still ends in review, with flags', () async {
    final h = await _harness(
      ocr: FakeOcrEngine(
        document: OcrDocument.fromPlainText(
          'SUNSET BEACH\nIMG 4032\n2019\nKEEP LEFT\n50',
        ),
      ),
    );

    await h.controller.start(ScanSource.gallery);

    final review = h.review;
    expect(review.ocrFailed, isFalse);
    expect(review.draft.extractionMethod, ExtractionMethod.rules);
    expect(review.draft.date, isNull);
    expect(review.isFlagged(ReceiptField.date), isTrue);
  });

  test('a cancelled scan goes back to idle without OCR', () async {
    final h = await _harness(scanner: FakeDocumentScanner(path: null));

    await h.controller.start(ScanSource.gallery);

    expect(h.scanner.calls, [ScanSource.gallery]);
    expect(h.states.map((s) => s.runtimeType), [
      ScanIdle,
      ScanCapturing,
      ScanIdle,
    ]);
    expect((h.states[1] as ScanCapturing).source, ScanSource.gallery);
    expect(h.ocr.calls, isEmpty);
  });

  for (final reason in ScanFailureReason.values) {
    test('a scanner failure (${reason.name}) ends in ScanFailed', () async {
      final failure = ScanFailure(reason, 'details');
      final h = await _harness(scanner: FakeDocumentScanner(failure: failure));

      await h.controller.start(ScanSource.camera);

      expect(h.state, isA<ScanFailed>());
      expect((h.state as ScanFailed).failure, same(failure));
      expect(h.ocr.calls, isEmpty);
    });
  }

  test('an unexpected scanner error becomes a ScanFailed(other)', () async {
    final h = await _harness(
      scanner: FakeDocumentScanner(failure: StateError('boom')),
    );

    await h.controller.start(ScanSource.camera);

    final failure = (h.state as ScanFailed).failure;
    expect(failure.reason, ScanFailureReason.other);
    expect(failure.message, contains('boom'));
  });

  test('a failure is not retried automatically', () async {
    final h = await _harness(
      scanner: FakeDocumentScanner(
        failure: const ScanFailure(ScanFailureReason.other),
      ),
    );

    await h.controller.start(ScanSource.camera);
    await Future<void>.delayed(const Duration(milliseconds: 300));

    expect(h.scanner.calls, hasLength(1));
    expect(h.state, isA<ScanFailed>());
  });

  test('when OCR throws, review opens empty with the photo kept', () async {
    final h = await _harness(ocr: FakeOcrEngine(error: Exception('ML Kit')));

    await h.controller.start(ScanSource.camera);

    expect(h.states.map((s) => s.runtimeType), [
      ScanIdle,
      ScanCapturing,
      ScanReading,
      ScanReview,
    ]);
    expect((h.states[2] as ScanReading).imagePath, _imagePath);
    expect(h.ocr.calls, [_imagePath]);
    final review = h.review;
    expect(review.ocrFailed, isTrue);
    expect(review.document, isNull);
    expect(review.parsed, isNull);
    expect(review.warnings, isEmpty);
    expect(
      review.draft,
      const ReceiptDraft(
        currency: 'AUD',
        extractionMethod: ExtractionMethod.manual,
        sourceImagePath: _imagePath,
      ),
    );
    expect(review.draft.date, isNull);
  });

  test('when OCR finds no text, review opens empty', () async {
    final h = await _harness(
      ocr: FakeOcrEngine(document: OcrDocument.fromPlainText('  \n ')),
      currency: 'EUR',
    );

    await h.controller.start(ScanSource.camera);

    final review = h.review;
    expect(review.ocrFailed, isTrue);
    expect(review.draft.currency, 'EUR');
    expect(review.draft.merchant, isEmpty);
    expect(review.draft.totalMinor, isNull);
    expect(review.draft.sourceImagePath, _imagePath);
    expect(review.draft.extractionMethod, ExtractionMethod.manual);
  });

  test('a readable receipt is parsed into a pre-filled draft', () async {
    final h = await _harness();

    await h.controller.start(ScanSource.camera);

    final review = h.review;
    expect(review.ocrFailed, isFalse);
    expect(review.document?.text, auReceiptText);
    expect(review.parsed, isNotNull);
    expect(review.issues, isEmpty);
    expect(review.warnings, isEmpty);
    final draft = review.draft;
    expect(draft.merchant.toLowerCase(), 'freshway market');
    expect(draft.date, LocalDate(2026, 9, 12));
    expect(draft.totalMinor, 10870);
    expect(draft.subtotalMinor, 10870);
    expect(draft.taxMinor, 988);
    expect(draft.tipMinor, isNull);
    expect(draft.currency, 'AUD');
    expect(draft.paymentMethod, PaymentMethod.card);
    expect(draft.rawOcrText, auReceiptText);
    expect(draft.confidence, review.parsed!.overallConfidence);
    expect(draft.confidence, greaterThan(0.6));
    expect(draft.extractionMethod, ExtractionMethod.rules);
    expect(draft.sourceImagePath, _imagePath);
    expect(draft.id, isNull);
    expect(draft.categoryId, isNull);
    expect(draft.isComplete, isTrue);
  });

  test('flags low-confidence fields and validator issues', () async {
    // EUR is the default, so "$" reads as USD with low confidence; the total
    // doesn't add up.
    final h = await _harness(
      ocr: FakeOcrEngine(document: OcrDocument.fromPlainText(_mismatchedText)),
      currency: 'EUR',
    );

    await h.controller.start(ScanSource.camera);

    final review = h.review;
    expect(review.draft.currency, 'USD');
    expect(review.draft.totalMinor, 12000);
    expect(review.parsed!.currency.confidence, lessThan(0.6));
    expect(
      review.issues,
      containsAll([
        const ValidationIssue(
          ReceiptField.total,
          IssueCode.totalMismatch,
          IssueSeverity.warning,
        ),
        const ValidationIssue(
          ReceiptField.currency,
          IssueCode.lowConfidence,
          IssueSeverity.info,
        ),
      ]),
    );
    // The validator's own lowConfidence issue is not listed twice.
    expect(review.warnings, {
      ReceiptField.currency: [IssueCode.lowConfidence],
      ReceiptField.total: [IssueCode.totalMismatch],
    });
    expect(review.isFlagged(ReceiptField.total), isTrue);
    expect(review.isFlagged(ReceiptField.merchant), isFalse);
  });

  test('passes the date order and "today" from settings and clock', () async {
    // 12/09/2026 read month-first is 9 December 2026: after "today" here, so
    // the parser rejects it…
    final early = await _harness(dateOrder: DateOrder.mdy);
    await early.controller.start(ScanSource.camera);
    expect(early.review.draft.date, isNull);
    expect(early.review.warnings[ReceiptField.date], [IssueCode.missingDate]);

    // …and accepts it once the clock is past it.
    final late = await _harness(
      dateOrder: DateOrder.mdy,
      now: DateTime(2027, 1, 10),
    );
    await late.controller.start(ScanSource.camera);
    expect(late.review.draft.date, LocalDate(2026, 12, 9));
  });

  test('a reset while OCR is running drops the late result', () async {
    final gate = Completer<void>();
    final h = await _harness(ocr: FakeOcrEngine()..gate = gate);

    final running = h.controller.start(ScanSource.camera);
    await pumpEventQueue();
    expect(h.state, isA<ScanReading>());

    h.controller.reset();
    gate.complete();
    await running;

    expect(h.state, isA<ScanIdle>());
    expect(h.states.last, isA<ScanIdle>());
  });

  test('a new scan wins over an older one still reading', () async {
    final gate = Completer<void>();
    final h = await _harness(ocr: FakeOcrEngine()..gate = gate);

    final first = h.controller.start(ScanSource.camera);
    await pumpEventQueue();
    expect(h.state, isA<ScanReading>());

    h.ocr.gate = null;
    h.scanner.path = '/tmp/second.jpg';
    await h.controller.start(ScanSource.gallery);
    final review = h.state;
    expect(
      (review as ScanReview).data.draft.sourceImagePath,
      '/tmp/second.jpg',
    );

    gate.complete();
    await first;
    expect(h.state, same(review));
  });

  test('a reset while the scanner is open ignores its answer', () async {
    final gate = Completer<void>();
    final h = await _harness(scanner: FakeDocumentScanner()..gate = gate);

    final running = h.controller.start(ScanSource.camera);
    await pumpEventQueue();
    h.controller.reset();
    gate.complete();
    await running;

    expect(h.state, isA<ScanIdle>());
    expect(h.ocr.calls, isEmpty);
  });

  test('save creates the receipt and resets the scan', () async {
    final h = await _harness();
    await h.controller.start(ScanSource.camera);
    final draft = h.review.draft.copyWith(notes: 'Weekly shop');

    final id = await h.controller.save(draft);

    expect(id, 'receipt-1');
    expect(h.repository.created, [draft]);
    expect(h.state, isA<ScanIdle>());
    // The photo is in app storage now; the scanner's copy goes.
    await pumpEventQueue();
    expect(h.scanner.cleanCacheCalls, 1);
  });

  test('discarding a scan in review deletes the scanner photo', () async {
    final h = await _harness();
    await h.controller.start(ScanSource.camera);
    expect(h.scanner.cleanCacheCalls, 0);

    h.controller.reset();
    await pumpEventQueue();

    expect(h.state, isA<ScanIdle>());
    expect(h.scanner.cleanCacheCalls, 1);
  });

  test(
    'cancelling, failing or resetting before review cleans nothing',
    () async {
      final cancelled = await _harness(
        scanner: FakeDocumentScanner(path: null),
      );
      await cancelled.controller.start(ScanSource.camera);
      cancelled.controller.reset();

      final gate = Completer<void>();
      final reading = await _harness(ocr: FakeOcrEngine()..gate = gate);
      final running = reading.controller.start(ScanSource.camera);
      await pumpEventQueue();
      reading.controller.reset();
      gate.complete();
      await running;
      await pumpEventQueue();

      expect(cancelled.scanner.cleanCacheCalls, 0);
      expect(reading.scanner.cleanCacheCalls, 0);
    },
  );

  test('a cache clean-up error never reaches the caller', () async {
    final h = await _harness(
      scanner: FakeDocumentScanner()..cleanCacheError = StateError('plugin'),
    );
    await h.controller.start(ScanSource.camera);

    await h.controller.save(h.review.draft);
    await pumpEventQueue();

    expect(h.state, isA<ScanIdle>());
    expect(h.repository.created, hasLength(1));
  });

  test('logs OCR and parse timings for QA', () async {
    final logs = <String>[];
    final original = debugPrint;
    debugPrint = (message, {wrapWidth}) => logs.add(message ?? '');
    addTearDown(() => debugPrint = original);
    final h = await _harness();

    await h.controller.start(ScanSource.camera);

    expect(
      logs,
      contains(
        matches(
          RegExp(r'^ReceiptMind scan: ocr \d+ ms, parse \d+ ms, 28 lines$'),
        ),
      ),
    );
    expect(h.state, isA<ScanReview>());
  });

  test('a failed save keeps the review state', () async {
    final h = await _harness();
    await h.controller.start(ScanSource.camera);
    final review = h.state;
    h.repository.error = StateError('disk full');

    await expectLater(
      h.controller.save(h.review.draft),
      throwsA(isA<StateError>()),
    );
    expect(h.state, same(review));
  });

  test('the draft survives while nobody listens (keepAlive)', () async {
    final h = await _harness();
    await h.controller.start(ScanSource.camera);
    final review = h.state;

    // Nothing listens any more (as after leaving the review screen).
    h.subscription.close();
    await Future<void>.delayed(const Duration(milliseconds: 50));
    expect(h.container.read(scanControllerProvider), same(review));
  });

  test('parseNow matches the background parse', () async {
    final document = OcrDocument.fromPlainText(auReceiptText);
    final options = ParseOptions(
      defaultCurrency: 'AUD',
      dateOrder: DateOrder.dmy,
      today: LocalDate(2026, 11, 16),
    );
    final now = parseNow(document, options);
    final background = await parseInBackground(document, options);

    expect(background.parsed.total?.value, now.parsed.total?.value);
    expect(background.parsed.merchant?.value, now.parsed.merchant?.value);
    expect(background.issues, now.issues);
  });
}
