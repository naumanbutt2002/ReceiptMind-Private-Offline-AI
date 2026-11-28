import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:receipt_mind/core/db/app_database.dart';
import 'package:receipt_mind/features/receipts/presentation/review/review_keys.dart';
import 'package:receipt_mind/features/receipts/presentation/review/review_photo.dart';
import 'package:receipt_mind/features/scan/application/scan_state.dart';
import 'package:receipt_parser/receipt_parser.dart'
    show IssueCode, ReceiptField;

import 'review_harness.dart';

void main() {
  setUpAll(initializeDateFormatting);

  Future<void> tapSave(WidgetTester tester) async {
    await tester.tap(find.byKey(ReviewKeys.saveButton));
    await tester.pumpAndSettle();
  }

  group('new scan', () {
    testWidgets('pre-fills every field from the ReviewData', (tester) async {
      await pumpReview(
        tester,
        location: '/scan/review',
        scanState: ScanReview(sampleReview()),
      );

      expect(find.text('Review receipt'), findsOneWidget);
      expect(fieldText(tester, ReviewKeys.merchantField), 'Freshway Market');
      expect(fieldText(tester, ReviewKeys.dateField), '12/09/2026');
      expect(fieldText(tester, ReviewKeys.totalField), '108.70');
      expect(
        find.descendant(
          of: find.byKey(ReviewKeys.currencyField),
          matching: find.text(r'AUD · $'),
        ),
        findsOneWidget,
      );
      // "More details" opens by itself because subtotal and tax are set.
      expect(fieldText(tester, ReviewKeys.subtotalField), '108.70');
      expect(fieldText(tester, ReviewKeys.taxField), '9.88');
      expect(fieldText(tester, ReviewKeys.tipField), '');
      final payment = tester.widget<SegmentedButton<PaymentMethod>>(
        find.byKey(ReviewKeys.paymentMethod),
      );
      expect(payment.selected, {PaymentMethod.card});
      expect(find.byType(ReviewPhoto), findsOneWidget);
      expect(find.byKey(ReviewKeys.ocrFailedBanner), findsNothing);
    });

    testWidgets('amounts use the locale decimal separator', (tester) async {
      await pumpReview(
        tester,
        location: '/scan/review',
        scanState: ScanReview(sampleReview()),
        locale: 'de_DE',
      );

      expect(fieldText(tester, ReviewKeys.totalField), '108,70');
      expect(fieldText(tester, ReviewKeys.taxField), '9,88');
    });

    testWidgets('flags warned fields and clears a flag once edited', (
      tester,
    ) async {
      await pumpReview(
        tester,
        location: '/scan/review',
        scanState: ScanReview(
          sampleReview(
            warnings: {
              ReceiptField.merchant: [IssueCode.lowConfidence],
              ReceiptField.total: [
                IssueCode.lowConfidence,
                IssueCode.totalMismatch,
              ],
              ReceiptField.date: [IssueCode.futureDate],
              ReceiptField.paymentMethod: [IssueCode.lowConfidence],
            },
          ),
        ),
      );

      for (final field in [
        ReceiptField.merchant,
        ReceiptField.total,
        ReceiptField.date,
        ReceiptField.paymentMethod,
      ]) {
        expect(find.byKey(ReviewKeys.warning(field)), findsOneWidget);
      }
      expect(find.byKey(ReviewKeys.warning(ReceiptField.tax)), findsNothing);
      // The concrete issue wins over "check this value".
      expect(
        find.text("Total doesn't match subtotal + tax + tip"),
        findsOneWidget,
      );
      expect(find.text('This date is in the future'), findsOneWidget);
      expect(find.text('Check this value'), findsNWidgets(2));

      await tester.enterText(find.byKey(ReviewKeys.totalField), '110.00');
      await tester.pump();
      expect(find.byKey(ReviewKeys.warning(ReceiptField.total)), findsNothing);
      expect(
        find.text("Total doesn't match subtotal + tax + tip"),
        findsNothing,
      );
      expect(
        find.byKey(ReviewKeys.warning(ReceiptField.merchant)),
        findsOneWidget,
      );

      await tester.enterText(find.byKey(ReviewKeys.merchantField), 'Freshway');
      await tester.pump();
      expect(
        find.byKey(ReviewKeys.warning(ReceiptField.merchant)),
        findsNothing,
      );

      await tester.ensureVisible(find.text('Cash'));
      await tester.tap(find.text('Cash'));
      await tester.pump();
      expect(
        find.byKey(ReviewKeys.warning(ReceiptField.paymentMethod)),
        findsNothing,
      );
      expect(find.byKey(ReviewKeys.warning(ReceiptField.date)), findsOneWidget);
    });

    testWidgets('OCR failure shows the banner, empty fields and the photo', (
      tester,
    ) async {
      await pumpReview(
        tester,
        location: '/scan/review',
        scanState: const ScanReview(ocrFailedReview),
      );

      expect(find.byKey(ReviewKeys.ocrFailedBanner), findsOneWidget);
      expect(
        find.text("Couldn't read this receipt — fill it in manually"),
        findsOneWidget,
      );
      expect(fieldText(tester, ReviewKeys.merchantField), '');
      expect(fieldText(tester, ReviewKeys.dateField), '');
      expect(fieldText(tester, ReviewKeys.totalField), '');
      expect(find.byType(ReviewPhoto), findsOneWidget);
      expect(find.byKey(ReviewKeys.recognisedTextButton), findsNothing);
    });

    testWidgets('"View recognised text" opens a sheet with selectable text', (
      tester,
    ) async {
      await pumpReview(
        tester,
        location: '/scan/review',
        scanState: ScanReview(sampleReview()),
      );

      await tester.tap(find.byKey(ReviewKeys.recognisedTextButton));
      await tester.pumpAndSettle();

      expect(find.byKey(ReviewKeys.recognisedTextSheet), findsOneWidget);
      expect(find.text('Recognised text'), findsOneWidget);
      final text = tester.widget<SelectableText>(
        find.descendant(
          of: find.byKey(ReviewKeys.recognisedTextSheet),
          matching: find.byType(SelectableText),
        ),
      );
      expect(text.data, recognisedText);
    });

    testWidgets('tapping the photo opens it full screen', (tester) async {
      await pumpReview(
        tester,
        location: '/scan/review',
        scanState: ScanReview(sampleReview()),
      );

      await tester.tap(find.byKey(ReviewKeys.photoFullScreenButton));
      await tester.pumpAndSettle();
      expect(find.byKey(ReviewKeys.photoViewer), findsOneWidget);

      await tester.tap(find.byType(CloseButton));
      await tester.pumpAndSettle();
      expect(find.byKey(ReviewKeys.photoViewer), findsNothing);
      expect(find.byKey(ReviewKeys.form), findsOneWidget);
    });

    testWidgets('without a scan it says so and returns to the list', (
      tester,
    ) async {
      final harness = await pumpReview(tester, location: '/scan/review');

      expect(find.text(receiptsHomeText), findsOneWidget);
      expect(harness.location, '/receipts');
      expect(
        find.text(
          'This scan is no longer available. Please scan the receipt again.',
        ),
        findsOneWidget,
      );
    });
    // QA M6 (B-1): the picker's text field used US order on an en-AU device.
    testWidgets('a date typed in the picker follows the date order', (
      tester,
    ) async {
      await pumpReview(
        tester,
        location: '/scan/review',
        scanState: ScanReview(sampleReview()),
      );

      await tester.tap(find.byKey(ReviewKeys.datePickerButton));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Switch to input'));
      await tester.pumpAndSettle();
      final field = find.descendant(
        of: find.byType(DatePickerDialog),
        matching: find.byType(TextField),
      );
      expect(tester.widget<TextField>(field).controller!.text, '12/09/2026');
      await tester.enterText(field, '01/11/2026');
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();

      expect(fieldText(tester, ReviewKeys.dateField), '01/11/2026');
    });
  });

  group('validation', () {
    testWidgets('merchant, date and total are required', (tester) async {
      final harness = await pumpReview(
        tester,
        location: '/scan/review',
        scanState: const ScanReview(ocrFailedReview),
      );

      await tapSave(tester);
      expect(find.text('Enter the merchant'), findsOneWidget);
      expect(find.text('Pick the purchase date'), findsOneWidget);
      expect(find.text('Enter the total'), findsOneWidget);
      expect(harness.scan.saved, isEmpty);

      await tester.enterText(find.byKey(ReviewKeys.merchantField), 'Bakery');
      await tester.pump();
      expect(find.text('Enter the merchant'), findsNothing);
      await tapSave(tester);
      expect(find.text('Pick the purchase date'), findsOneWidget);
      expect(find.text('Enter the total'), findsOneWidget);

      // The picker opens on today; accept it.
      await tester.tap(find.byKey(ReviewKeys.datePickerButton));
      await tester.pumpAndSettle();
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();
      expect(fieldText(tester, ReviewKeys.dateField), '16/11/2026');
      await tapSave(tester);
      expect(find.text('Pick the purchase date'), findsNothing);
      expect(find.text('Enter the total'), findsOneWidget);
      expect(harness.scan.saved, isEmpty);

      await tester.enterText(find.byKey(ReviewKeys.totalField), '7.40');
      await tapSave(tester);
      expect(harness.scan.saved, hasLength(1));
      expect(harness.scan.saved.single.totalMinor, 740);
    });

    testWidgets('an empty merchant alone blocks saving', (tester) async {
      final harness = await pumpReview(
        tester,
        location: '/scan/review',
        scanState: ScanReview(sampleReview()),
      );

      await tester.enterText(find.byKey(ReviewKeys.merchantField), '   ');
      await tapSave(tester);
      expect(find.text('Enter the merchant'), findsOneWidget);
      expect(harness.scan.saved, isEmpty);
    });

    testWidgets('an empty total alone blocks saving', (tester) async {
      final harness = await pumpReview(
        tester,
        location: '/scan/review',
        scanState: ScanReview(sampleReview()),
      );

      await tester.enterText(find.byKey(ReviewKeys.totalField), '');
      await tapSave(tester);
      expect(find.text('Enter the total'), findsOneWidget);
      expect(harness.scan.saved, isEmpty);
    });

    testWidgets('rejects an amount that cannot be read', (tester) async {
      final harness = await pumpReview(
        tester,
        location: '/scan/review',
        scanState: ScanReview(sampleReview()),
      );

      await tester.enterText(find.byKey(ReviewKeys.totalField), '12.3.4x');
      await tapSave(tester);
      expect(find.text('Enter an amount like 12.50'), findsOneWidget);
      expect(harness.scan.saved, isEmpty);
    });

    testWidgets('an invalid tip under a closed "More details" opens it', (
      tester,
    ) async {
      final harness = await pumpReview(tester, location: '/receipts/new');
      await tester.enterText(find.byKey(ReviewKeys.merchantField), 'Kiosk');
      await tester.enterText(find.byKey(ReviewKeys.totalField), '5');
      await tester.tap(find.byKey(ReviewKeys.moreToggle));
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(ReviewKeys.tipField), 'abc');
      await tester.tap(find.byKey(ReviewKeys.moreToggle));
      await tester.pumpAndSettle();
      expect(find.byKey(ReviewKeys.tipField), findsNothing);

      await tapSave(tester);
      expect(find.byKey(ReviewKeys.tipField), findsOneWidget);
      expect(find.text('Enter an amount like 12.50'), findsOneWidget);
      expect(harness.repository.created, isEmpty);
    });
  });
}
