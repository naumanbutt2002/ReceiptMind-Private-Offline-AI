import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:receipt_mind/features/receipts/presentation/review/review_keys.dart';
import 'package:receipt_mind/features/scan/application/scan_state.dart';
import 'package:receipt_parser/receipt_parser.dart'
    show IssueCode, ReceiptField;

import 'review_harness.dart';

void main() {
  setUpAll(initializeDateFormatting);

  final flagged = ScanReview(
    sampleReview(
      warnings: {
        ReceiptField.merchant: [IssueCode.lowConfidence],
        ReceiptField.date: [IssueCode.oldDate],
        ReceiptField.total: [IssueCode.totalMismatch],
        ReceiptField.tax: [IssueCode.taxNotLessThanTotal],
        ReceiptField.currency: [IssueCode.unknownCurrency],
        ReceiptField.paymentMethod: [IssueCode.lowConfidence],
      },
    ),
  );

  /// Scrolls the form to its end, so its last fields have been painted too.
  Future<void> scrollThroughForm(WidgetTester tester) async {
    await tester.ensureVisible(find.byKey(ReviewKeys.notesField));
    await tester.pumpAndSettle();
  }

  testWidgets('narrow screens put the photo above the form', (tester) async {
    await pumpReview(
      tester,
      location: '/scan/review',
      scanState: ScanReview(sampleReview()),
      size: const Size(400, 800),
    );

    final photo = tester.getRect(find.byKey(ReviewKeys.photo));
    final form = tester.getRect(find.byKey(ReviewKeys.form));
    expect(photo.bottom, lessThanOrEqualTo(form.top));
    expect(photo.width, greaterThan(300));
  });

  testWidgets('from 600 dp the photo and the form sit side by side', (
    tester,
  ) async {
    await pumpReview(
      tester,
      location: '/scan/review',
      scanState: ScanReview(sampleReview()),
      size: const Size(900, 700),
    );

    final photo = tester.getRect(find.byKey(ReviewKeys.photo));
    final form = tester.getRect(find.byKey(ReviewKeys.form));
    expect(photo.right, lessThanOrEqualTo(form.left));
    expect((photo.top - form.top).abs(), lessThan(24));
    expect(photo.height, greaterThan(500));
  });

  testWidgets('rotating keeps what the user typed', (tester) async {
    await pumpReview(
      tester,
      location: '/scan/review',
      scanState: ScanReview(sampleReview()),
      size: const Size(400, 800),
    );
    await tester.enterText(find.byKey(ReviewKeys.merchantField), 'Rotated');

    tester.view.physicalSize = const Size(800, 400);
    await tester.pumpAndSettle();
    expect(fieldText(tester, ReviewKeys.merchantField), 'Rotated');
    final photo = tester.getRect(find.byKey(ReviewKeys.photo));
    final form = tester.getRect(find.byKey(ReviewKeys.form));
    expect(photo.right, lessThanOrEqualTo(form.left));
  });

  for (final (name, size) in [
    ('phone', const Size(360, 780)),
    ('tablet', const Size(800, 1000)),
  ]) {
    testWidgets('200 % text on a $name has no overflow', (tester) async {
      await pumpReview(
        tester,
        location: '/scan/review',
        scanState: flagged,
        size: size,
        textScale: 2,
      );
      await scrollThroughForm(tester);
      expect(tester.takeException(), isNull);

      await tester.tap(find.byKey(ReviewKeys.saveButton));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('200 % text in dark mode, OCR failed and manual entry', (
    tester,
  ) async {
    await pumpReview(
      tester,
      location: '/scan/review',
      scanState: const ScanReview(ocrFailedReview),
      size: const Size(360, 780),
      textScale: 2,
      themeMode: ThemeMode.dark,
    );
    await tester.tap(find.byKey(ReviewKeys.saveButton));
    await tester.pumpAndSettle();
    await scrollThroughForm(tester);
    expect(tester.takeException(), isNull);
  });

  testWidgets('200 % text with a discard dialog and the text sheet', (
    tester,
  ) async {
    await pumpReview(
      tester,
      location: '/scan/review',
      scanState: ScanReview(sampleReview()),
      size: const Size(360, 780),
      textScale: 2,
    );
    await tester.tap(find.byKey(ReviewKeys.recognisedTextButton));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    Navigator.of(tester.element(find.byKey(ReviewKeys.recognisedTextSheet)))
        .pop();
    await tester.pumpAndSettle();

    await tester.enterText(find.byKey(ReviewKeys.merchantField), 'X');
    await tester.tap(find.byKey(ReviewKeys.closeButton));
    await tester.pumpAndSettle();
    expect(find.byKey(ReviewKeys.discardDialog), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('icon buttons and the photo have labels and 48 dp targets', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    await pumpReview(
      tester,
      location: '/scan/review',
      scanState: ScanReview(sampleReview()),
    );

    expect(find.bySemanticsLabel('Receipt photo'), findsOneWidget);
    expect(find.byTooltip('Close'), findsOneWidget);
    expect(find.byTooltip('View photo full screen'), findsOneWidget);
    expect(find.byTooltip('Pick a date'), findsOneWidget);
    await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
    await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
    handle.dispose();
  });
}
