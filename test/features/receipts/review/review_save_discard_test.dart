import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:receipt_mind/core/date/local_date.dart';
import 'package:receipt_mind/core/db/app_database.dart';
import 'package:receipt_mind/features/receipts/presentation/review/review_keys.dart';
import 'package:receipt_mind/features/receipts/presentation/review/review_photo.dart';
import 'package:receipt_mind/features/scan/application/scan_state.dart';

import 'review_harness.dart';

void main() {
  setUpAll(initializeDateFormatting);

  Future<void> tapSave(WidgetTester tester) async {
    await tester.tap(find.byKey(ReviewKeys.saveButton));
    await tester.pumpAndSettle();
  }

  Future<void> tapClose(WidgetTester tester) async {
    await tester.tap(find.byKey(ReviewKeys.closeButton));
    await tester.pumpAndSettle();
  }

  /// Android Back. Pump after typing first, as a real device would draw a
  /// frame in between (PopScope picks up `canPop` on rebuild).
  Future<void> systemBack(WidgetTester tester) async {
    await tester.pump();
    // ignore: invalid_use_of_protected_member
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
  }

  group('save', () {
    testWidgets('new scan saves through the scan controller', (tester) async {
      final harness = await pumpReview(
        tester,
        location: '/scan/review',
        scanState: ScanReview(sampleReview()),
      );

      await tester.enterText(find.byKey(ReviewKeys.merchantField), 'Freshway');
      await tester.ensureVisible(find.byKey(ReviewKeys.notesField));
      await tester.enterText(
        find.byKey(ReviewKeys.notesField),
        ' weekly shop ',
      );
      await tapSave(tester);

      final draft = harness.scan.saved.single;
      expect(draft.merchant, 'Freshway');
      expect(draft.date, LocalDate(2026, 9, 12));
      expect(draft.totalMinor, 10870);
      expect(draft.subtotalMinor, 10870);
      expect(draft.taxMinor, 988);
      expect(draft.tipMinor, isNull);
      expect(draft.currency, 'AUD');
      expect(draft.paymentMethod, PaymentMethod.card);
      expect(draft.notes, 'weekly shop');
      expect(draft.sourceImagePath, scanPhotoPath);
      expect(draft.rawOcrText, recognisedText);
      expect(draft.extractionMethod, ExtractionMethod.rules);
      expect(harness.repository.created, isEmpty);

      expect(find.text(receiptsHomeText), findsOneWidget);
      expect(harness.location, '/receipts');
      expect(find.text('Receipt saved'), findsOneWidget);
    });

    testWidgets('manual entry starts empty and creates a receipt', (
      tester,
    ) async {
      final harness = await pumpReview(tester, location: '/receipts/new');

      expect(find.text('New receipt'), findsOneWidget);
      expect(find.byType(ReviewPhoto), findsNothing);
      expect(find.byKey(ReviewKeys.recognisedTextButton), findsNothing);
      expect(fieldText(tester, ReviewKeys.merchantField), '');
      expect(fieldText(tester, ReviewKeys.dateField), '16/11/2026');

      await tester.enterText(find.byKey(ReviewKeys.merchantField), 'Kiosk');
      await tester.enterText(find.byKey(ReviewKeys.totalField), '4.5');
      // Pick a category and then a payment method.
      final firstChip = find.byType(ChoiceChip).first;
      await tester.ensureVisible(firstChip);
      await tester.tap(firstChip);
      await tester.pump();
      await tester.ensureVisible(find.text('Cash'));
      await tester.tap(find.text('Cash'));
      await tester.pump();
      await tapSave(tester);

      final draft = harness.repository.created.single;
      expect(draft.id, isNull);
      expect(draft.merchant, 'Kiosk');
      expect(draft.date, LocalDate(2026, 11, 16));
      expect(draft.totalMinor, 450);
      expect(draft.currency, 'AUD');
      expect(draft.extractionMethod, ExtractionMethod.manual);
      expect(draft.paymentMethod, PaymentMethod.cash);
      expect(draft.categoryId, isNotNull);
      expect(draft.sourceImagePath, isNull);
      expect(harness.scan.saved, isEmpty);
      expect(harness.location, '/receipts');
      expect(find.text('Receipt saved'), findsOneWidget);
    });

    testWidgets('a category chip can be selected and cleared', (tester) async {
      final harness = await pumpReview(tester, location: '/receipts/new');
      await tester.enterText(find.byKey(ReviewKeys.merchantField), 'Kiosk');
      await tester.enterText(find.byKey(ReviewKeys.totalField), '1');
      final chip = find.byType(ChoiceChip).first;
      await tester.ensureVisible(chip);
      await tester.tap(chip);
      await tester.pump();
      expect(tester.widget<ChoiceChip>(chip).selected, isTrue);
      await tester.tap(chip);
      await tester.pump();
      expect(tester.widget<ChoiceChip>(chip).selected, isFalse);

      await tapSave(tester);
      expect(harness.repository.created.single.categoryId, isNull);
    });

    testWidgets('edit loads the receipt and its photo, updates and pops', (
      tester,
    ) async {
      final harness = await pumpReview(
        tester,
        location: '/receipts/r1/edit',
        rows: [sampleRow()],
      );

      expect(find.text('Edit receipt'), findsOneWidget);
      expect(fieldText(tester, ReviewKeys.merchantField), 'Corner Café');
      expect(fieldText(tester, ReviewKeys.dateField), '03/10/2026');
      expect(fieldText(tester, ReviewKeys.totalField), '14.50');
      expect(fieldText(tester, ReviewKeys.tipField), '2.00');
      expect(
        tester.widget<ReviewPhoto>(find.byType(ReviewPhoto)).path,
        '/support/receipts/r1.jpg',
      );
      expect(find.byKey(ReviewKeys.recognisedTextButton), findsOneWidget);

      await tester.enterText(find.byKey(ReviewKeys.totalField), '15.00');
      await tapSave(tester);

      final draft = harness.repository.updated.single;
      expect(draft.id, 'r1');
      expect(draft.totalMinor, 1500);
      expect(draft.tipMinor, 200);
      expect(draft.notes, 'Team lunch');
      expect(draft.imagePath, 'receipts/r1.jpg');
      expect(draft.sourceImagePath, isNull);
      expect(harness.repository.created, isEmpty);
      // Popped back to where it was opened from.
      expect(find.text(receiptsHomeText), findsOneWidget);
      expect(find.text('Receipt saved'), findsOneWidget);
    });

    testWidgets('edit of a missing receipt says so and leaves', (tester) async {
      await pumpReview(tester, location: '/receipts/gone/edit');

      expect(find.text(receiptsHomeText), findsOneWidget);
      expect(find.text('This receipt no longer exists.'), findsOneWidget);
    });

    testWidgets('a failed save shows an error and keeps the form', (
      tester,
    ) async {
      final harness = await pumpReview(
        tester,
        location: '/scan/review',
        scanState: ScanReview(sampleReview(photoPath: createScanPhotoFile())),
      );
      harness.scan.error = StateError('disk full');

      await tapSave(tester);

      expect(
        find.text("Couldn't save the receipt. Please try again."),
        findsOneWidget,
      );
      expect(find.byKey(ReviewKeys.form), findsOneWidget);
      final save = tester.widget<TextButton>(find.byKey(ReviewKeys.saveButton));
      expect(save.onPressed, isNotNull);

      harness.scan.error = null;
      await tapSave(tester);
      expect(harness.scan.saved, hasLength(1));
    });
  });

  group('discard', () {
    testWidgets('closing a clean manual entry leaves without asking', (
      tester,
    ) async {
      await pumpReview(tester, location: '/receipts/new');

      await tapClose(tester);

      expect(find.byKey(ReviewKeys.discardDialog), findsNothing);
      expect(find.text(receiptsHomeText), findsOneWidget);
    });

    testWidgets('closing with changes asks first', (tester) async {
      final harness = await pumpReview(tester, location: '/receipts/new');
      await tester.enterText(find.byKey(ReviewKeys.merchantField), 'Kiosk');

      await tapClose(tester);
      expect(find.byKey(ReviewKeys.discardDialog), findsOneWidget);
      expect(find.text('Discard this receipt?'), findsOneWidget);

      await tester.tap(find.byKey(ReviewKeys.discardCancel));
      await tester.pumpAndSettle();
      expect(find.byKey(ReviewKeys.discardDialog), findsNothing);
      expect(fieldText(tester, ReviewKeys.merchantField), 'Kiosk');

      await tapClose(tester);
      await tester.tap(find.byKey(ReviewKeys.discardConfirm));
      await tester.pumpAndSettle();
      expect(find.text(receiptsHomeText), findsOneWidget);
      expect(harness.repository.created, isEmpty);
    });

    testWidgets('system Back with changes asks too', (tester) async {
      await pumpReview(
        tester,
        location: '/receipts/r1/edit',
        rows: [sampleRow()],
      );
      await tester.enterText(find.byKey(ReviewKeys.merchantField), 'Café');

      await systemBack(tester);
      expect(find.text('Discard changes?'), findsOneWidget);
      await tester.tap(find.byKey(ReviewKeys.discardConfirm));
      await tester.pumpAndSettle();
      expect(find.text(receiptsHomeText), findsOneWidget);
    });

    testWidgets('system Back on a clean edit leaves without asking', (
      tester,
    ) async {
      await pumpReview(
        tester,
        location: '/receipts/r1/edit',
        rows: [sampleRow()],
      );

      await systemBack(tester);
      expect(find.byKey(ReviewKeys.discardDialog), findsNothing);
      expect(find.text(receiptsHomeText), findsOneWidget);
    });

    testWidgets('discarding a new scan resets the scan controller', (
      tester,
    ) async {
      final harness = await pumpReview(
        tester,
        location: '/scan/review',
        scanState: ScanReview(sampleReview()),
      );
      await tester.enterText(find.byKey(ReviewKeys.totalField), '1.00');

      await systemBack(tester);
      expect(find.text('Discard this receipt?'), findsOneWidget);
      await tester.tap(find.byKey(ReviewKeys.discardConfirm));
      await tester.pumpAndSettle();

      expect(harness.scan.resets, 1);
      expect(harness.scan.saved, isEmpty);
      expect(find.text(receiptsHomeText), findsOneWidget);
    });

    testWidgets('closing an untouched new scan resets it without asking', (
      tester,
    ) async {
      final harness = await pumpReview(
        tester,
        location: '/scan/review',
        scanState: ScanReview(sampleReview()),
      );

      await tapClose(tester);

      expect(find.byKey(ReviewKeys.discardDialog), findsNothing);
      expect(harness.scan.resets, 1);
      expect(find.text(receiptsHomeText), findsOneWidget);
    });
  });
}
