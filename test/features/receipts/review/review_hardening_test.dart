import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:receipt_mind/core/db/app_database.dart';
import 'package:receipt_mind/core/settings/settings_providers.dart';
import 'package:receipt_mind/features/receipts/presentation/review/review_keys.dart';
import 'package:receipt_mind/features/receipts/presentation/review/review_messages.dart';
import 'package:receipt_mind/features/receipts/presentation/review/review_photo.dart';
import 'package:receipt_mind/features/scan/application/receipt_draft.dart';
import 'package:receipt_mind/features/scan/application/scan_controller.dart';
import 'package:receipt_mind/features/scan/application/scan_state.dart';
import 'package:receipt_mind/l10n/generated/app_localizations.dart';
import 'package:receipt_parser/receipt_parser.dart'
    show
        DateOrder,
        IssueCode,
        LocalDate,
        OcrDocument,
        ParseOptions,
        ReceiptField;

import 'review_harness.dart';

/// M8 hardening: regressions for bugs fixed in the review screen, edge cases
/// (nonsense scans, missing photo, full disk, long receipts) and the
/// accessibility checks.
void main() {
  setUpAll(initializeDateFormatting);

  Future<void> tapSave(WidgetTester tester) async {
    await tester.tap(find.byKey(ReviewKeys.saveButton));
    await tester.pumpAndSettle();
  }

  FocusNode focusOf(WidgetTester tester, Key field) => tester
      .widget<EditableText>(
        find.descendant(
          of: find.byKey(field),
          matching: find.byType(EditableText),
        ),
      )
      .focusNode;

  /// Whether the field with [key] is inside the form's visible area.
  bool onScreen(WidgetTester tester, Key key) {
    final rect = tester.getRect(find.byKey(key));
    final viewport = tester.getRect(find.byKey(ReviewKeys.form));
    return rect.top >= viewport.top && rect.bottom <= viewport.bottom;
  }

  group('a failed save reveals the first invalid field', () {
    testWidgets('scrolls up to an empty merchant and focuses it', (
      tester,
    ) async {
      final harness = await pumpReview(
        tester,
        location: '/scan/review',
        scanState: ScanReview(sampleReview()),
        size: const Size(360, 640),
      );
      await tester.enterText(find.byKey(ReviewKeys.merchantField), '');
      await tester.enterText(find.byKey(ReviewKeys.totalField), 'abc');
      await tester.ensureVisible(find.byKey(ReviewKeys.notesField));
      await tester.pumpAndSettle();
      expect(onScreen(tester, ReviewKeys.merchantField), isFalse);

      await tapSave(tester);

      expect(harness.scan.saved, isEmpty);
      expect(onScreen(tester, ReviewKeys.merchantField), isTrue);
      expect(focusOf(tester, ReviewKeys.merchantField).hasFocus, isTrue);
      expect(focusOf(tester, ReviewKeys.totalField).hasFocus, isFalse);
    });

    testWidgets('focuses the total when it is the only problem', (
      tester,
    ) async {
      await pumpReview(
        tester,
        location: '/scan/review',
        scanState: ScanReview(sampleReview()),
        size: const Size(360, 640),
      );
      await tester.enterText(find.byKey(ReviewKeys.totalField), '');
      await tester.ensureVisible(find.byKey(ReviewKeys.notesField));
      await tester.pumpAndSettle();

      await tapSave(tester);

      expect(find.text('Enter the total'), findsOneWidget);
      expect(onScreen(tester, ReviewKeys.totalField), isTrue);
      expect(focusOf(tester, ReviewKeys.totalField).hasFocus, isTrue);
    });

    testWidgets('opens "More details" and focuses an invalid tip', (
      tester,
    ) async {
      await pumpReview(tester, location: '/receipts/new');
      await tester.enterText(find.byKey(ReviewKeys.merchantField), 'Kiosk');
      await tester.enterText(find.byKey(ReviewKeys.totalField), '5');
      await tester.tap(find.byKey(ReviewKeys.moreToggle));
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(ReviewKeys.tipField), 'abc');
      await tester.tap(find.byKey(ReviewKeys.moreToggle));
      await tester.pumpAndSettle();

      await tapSave(tester);

      expect(focusOf(tester, ReviewKeys.tipField).hasFocus, isTrue);
      expect(onScreen(tester, ReviewKeys.tipField), isTrue);
    });
  });

  group('changing the currency keeps the amounts', () {
    Future<void> pickCurrency(WidgetTester tester, String code) async {
      await tester.tap(find.byKey(ReviewKeys.currencyField));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).last, code);
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(ValueKey('currency-$code')));
      await tester.pumpAndSettle();
    }

    ReviewData review(String currency, int total, {int? tax}) => ReviewData(
      draft: ReceiptDraft(
        merchant: 'Souq',
        date: LocalDate(2026, 11, 1),
        totalMinor: total,
        taxMinor: tax,
        currency: currency,
        extractionMethod: ExtractionMethod.rules,
        sourceImagePath: scanPhotoPath,
      ),
    );

    testWidgets('KWD 12.500 becomes AUD 12.50, not 12,500', (tester) async {
      final harness = await pumpReview(
        tester,
        location: '/scan/review',
        scanState: ScanReview(review('KWD', 12500, tax: 1250)),
      );
      expect(fieldText(tester, ReviewKeys.totalField), '12.500');

      await pickCurrency(tester, 'AUD');
      expect(fieldText(tester, ReviewKeys.totalField), '12.50');
      expect(fieldText(tester, ReviewKeys.taxField), '1.25');

      await tapSave(tester);
      final draft = harness.scan.saved.single;
      expect(draft.currency, 'AUD');
      expect(draft.totalMinor, 1250);
      expect(draft.taxMinor, 125);
    });

    testWidgets('JPY 1500 becomes KWD 1500.000', (tester) async {
      final harness = await pumpReview(
        tester,
        location: '/scan/review',
        scanState: ScanReview(review('JPY', 1500)),
      );
      expect(fieldText(tester, ReviewKeys.totalField), '1500');

      await pickCurrency(tester, 'KWD');
      expect(fieldText(tester, ReviewKeys.totalField), '1500.000');
      await tapSave(tester);
      expect(harness.scan.saved.single.totalMinor, 1500000);
    });

    testWidgets('AUD 12.50 → JPY keeps the text and asks for a fix', (
      tester,
    ) async {
      final harness = await pumpReview(
        tester,
        location: '/scan/review',
        scanState: ScanReview(review('AUD', 1250)),
      );

      await pickCurrency(tester, 'JPY');
      expect(fieldText(tester, ReviewKeys.totalField), '12.50');
      await tapSave(tester);
      expect(find.text('Enter an amount like 12'), findsOneWidget);
      expect(harness.scan.saved, isEmpty);
    });

    test('convertAmountFieldText', () {
      String? convert(String text, String from, String to, [String l = 'en']) =>
          convertAmountFieldText(text, from: from, to: to, locale: l);
      expect(convert('12.500', 'KWD', 'AUD'), '12.50');
      expect(convert('12,500', 'KWD', 'EUR', 'de_DE'), '12,50');
      expect(convert('12.50', 'AUD', 'KWD'), '12.500');
      expect(convert('12.00', 'AUD', 'JPY'), '12');
      expect(convert('12.50', 'AUD', 'JPY'), isNull);
      expect(convert('12.50', 'AUD', 'EUR'), isNull);
      expect(convert('', 'AUD', 'JPY'), isNull);
      expect(convert('abc', 'AUD', 'JPY'), isNull);
      expect(convert('-3.20', 'AUD', 'KWD'), '-3.200');
    });
  });

  group('save errors', () {
    testWidgets('a scan whose photo is gone can be saved without it', (
      tester,
    ) async {
      // scanPhotoPath doesn't exist, as if the system cleared the cache.
      final harness = await pumpReview(
        tester,
        location: '/scan/review',
        scanState: ScanReview(sampleReview()),
      );
      harness.scan.error = const PathNotFoundException(
        scanPhotoPath,
        OSError('No such file or directory', 2),
      );

      await tapSave(tester);
      expect(find.byKey(ReviewKeys.photoMissingDialog), findsOneWidget);
      expect(find.text('Photo no longer available'), findsOneWidget);
      expect(tester.takeException(), isNull);

      harness.scan.error = null;
      await tester.tap(find.byKey(ReviewKeys.saveWithoutPhoto));
      await tester.pumpAndSettle();

      final draft = harness.scan.saved.single;
      expect(draft.sourceImagePath, isNull);
      expect(draft.merchant, 'Freshway Market');
      expect(draft.totalMinor, 10870);
      expect(draft.rawOcrText, recognisedText);
      expect(find.text(receiptsHomeText), findsOneWidget);
    });

    testWidgets('"Keep editing" in the missing-photo dialog keeps the form', (
      tester,
    ) async {
      final harness = await pumpReview(
        tester,
        location: '/scan/review',
        scanState: ScanReview(sampleReview()),
      );
      harness.scan.error = Exception('cannot read the photo');

      await tapSave(tester);
      await tester.tap(find.text('Keep editing'));
      await tester.pumpAndSettle();

      expect(harness.scan.saved, isEmpty);
      expect(find.byKey(ReviewKeys.form), findsOneWidget);
      final save = tester.widget<TextButton>(find.byKey(ReviewKeys.saveButton));
      expect(save.onPressed, isNotNull);
    });

    testWidgets('a full disk gets its own message', (tester) async {
      final harness = await pumpReview(
        tester,
        location: '/scan/review',
        scanState: ScanReview(sampleReview(photoPath: createScanPhotoFile())),
      );
      harness.scan.error = const FileSystemException(
        'Cannot write file',
        '/support/receipts/x.jpg.tmp',
        OSError('No space left on device', 28),
      );

      await tapSave(tester);

      expect(
        find.text(
          'Not enough storage space to save the receipt. '
          'Free up some space and try again.',
        ),
        findsOneWidget,
      );
      expect(find.byKey(ReviewKeys.form), findsOneWidget);
    });

    test('isStorageFullError', () {
      expect(
        isStorageFullError(
          const FileSystemException('x', 'y', OSError('No space', 28)),
        ),
        isTrue,
      );
      expect(
        isStorageFullError(
          Exception(
            'SqliteException(13): database or disk '
            'is full, SQLITE_FULL',
          ),
        ),
        isTrue,
      );
      expect(
        isStorageFullError(
          const FileSystemException('x', 'y', OSError('Denied', 13)),
        ),
        isFalse,
      );
      expect(isStorageFullError(StateError('boom')), isFalse);
    });

    testWidgets('saving an edit of a receipt deleted meanwhile leaves', (
      tester,
    ) async {
      final harness = await pumpReview(
        tester,
        location: '/receipts/r1/edit',
        rows: [sampleRow()],
      );
      harness.repository.error = StateError('Receipt r1 does not exist');
      await tester.enterText(find.byKey(ReviewKeys.merchantField), 'Changed');

      await tapSave(tester);

      expect(find.text('This receipt no longer exists.'), findsOneWidget);
      expect(find.text(receiptsHomeText), findsOneWidget);
      expect(find.byKey(ReviewKeys.discardDialog), findsNothing);
    });
  });

  group('nonsense scans', () {
    /// What ML Kit might read from an upside-down receipt or a holiday photo.
    const texts = {
      'upside down': '0Ɩ˙8 ꞀⱯꞱOꞱ\nʇǝʞɹɐɯ ʎɐʍɥsǝɹℲ\n9ᘔ0ᘔ/60/ᘔƖ',
      'holiday photo': 'SUNSET BEACH\nIMG 4032\n2019\nKEEP LEFT\n50',
      'symbols': r'$$$ ... ,,, 1.2.3.4 -- // 99/99/9999 TOTAL',
    };

    for (final MapEntry(key: name, value: text) in texts.entries) {
      testWidgets('$name: the form opens with flags and stays usable', (
        tester,
      ) async {
        final document = OcrDocument.fromPlainText(text);
        final result = parseNow(
          document,
          ParseOptions(
            defaultCurrency: 'AUD',
            dateOrder: DateOrder.dmy,
            today: LocalDate(2026, 11, 16),
          ),
        );
        final data = reviewDataFor(
          document: document,
          parsed: result.parsed,
          issues: result.issues,
          sourceImagePath: scanPhotoPath,
        );
        final harness = await pumpReview(
          tester,
          location: '/scan/review',
          scanState: ScanReview(data),
          size: const Size(360, 640),
          textScale: 2,
        );
        expect(tester.takeException(), isNull);
        expect(find.byKey(ReviewKeys.form), findsOneWidget);
        expect(find.byKey(ReviewKeys.recognisedTextButton), findsOneWidget);

        // Whatever was (or wasn't) found, the user can fix it and save.
        await tester.enterText(find.byKey(ReviewKeys.merchantField), 'Shop');
        await tester.enterText(find.byKey(ReviewKeys.totalField), '4.20');
        for (final key in [
          ReviewKeys.subtotalField,
          ReviewKeys.taxField,
          ReviewKeys.tipField,
        ]) {
          if (find.byKey(key).evaluate().isNotEmpty) {
            await tester.enterText(find.byKey(key), '');
          }
        }
        if (fieldText(tester, ReviewKeys.dateField).isEmpty) {
          await tester.ensureVisible(find.byKey(ReviewKeys.datePickerButton));
          await tester.pumpAndSettle();
          await tester.tap(find.byKey(ReviewKeys.datePickerButton));
          await tester.pumpAndSettle();
          await tester.tap(find.text('OK'));
          await tester.pumpAndSettle();
        }
        await tapSave(tester);
        expect(tester.takeException(), isNull);
        expect(harness.scan.saved.single.totalMinor, 420);
      });
    }

    testWidgets('a missing total and date are flagged', (tester) async {
      final document = OcrDocument.fromPlainText(texts['holiday photo']!);
      final result = parseNow(
        document,
        ParseOptions(
          defaultCurrency: 'AUD',
          dateOrder: DateOrder.dmy,
          today: LocalDate(2026, 11, 16),
        ),
      );
      final data = reviewDataFor(
        document: document,
        parsed: result.parsed,
        issues: result.issues,
        sourceImagePath: scanPhotoPath,
      );
      expect(data.isFlagged(ReceiptField.date), isTrue);
      await pumpReview(
        tester,
        location: '/scan/review',
        scanState: ScanReview(data),
      );
      expect(find.byKey(ReviewKeys.warning(ReceiptField.date)), findsOneWidget);
    });
  });

  group('long receipt photos', () {
    test('receiptImageExtent', () {
      const box = Size(360, 240);
      // A normal photo fits the box.
      expect(
        receiptImageExtent(box, const Size(600, 400), minWidthFactor: 0.5),
        const Size(360, 240),
      );
      // 1000 × 6000 would be 40 px wide; it's drawn 180 px wide instead.
      expect(
        receiptImageExtent(box, const Size(1000, 6000), minWidthFactor: 0.5),
        const Size(180, 1080),
      );
      // Full screen, 60 % of the width.
      expect(
        receiptImageExtent(
          const Size(400, 800),
          const Size(1000, 6000),
          minWidthFactor: 0.6,
        ),
        const Size(240, 1440),
      );
      // A receipt that already fits wide enough is left alone.
      expect(
        receiptImageExtent(
          const Size(400, 800),
          const Size(1000, 2500),
          minWidthFactor: 0.6,
        ),
        const Size(320, 800),
      );
      // Degenerate sizes don't crash.
      expect(receiptImageExtent(box, Size.zero, minWidthFactor: 0.5), box);
    });

    Future<Uint8List> png(int width, int height) async {
      final recorder = ui.PictureRecorder();
      Canvas(recorder).drawRect(
        Rect.fromLTWH(0, 0, width.toDouble(), height.toDouble()),
        Paint()..color = const Color(0xFFFFFFFF),
      );
      final image = await recorder.endRecording().toImage(width, height);
      final data = await image.toByteData(format: ui.ImageByteFormat.png);
      image.dispose();
      return data!.buffer.asUint8List();
    }

    Future<void> pumpImage(
      WidgetTester tester,
      ImageProvider image,
      Size box, {
      double minWidthFactor = previewMinWidthFactor,
    }) async {
      // Decode first, outside fake async, so the view gets its size at once.
      await tester.pumpWidget(const SizedBox());
      await tester.runAsync(
        () => precacheImage(image, tester.element(find.byType(SizedBox))),
      );
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Center(
            child: SizedBox.fromSize(
              size: box,
              child: ReceiptImageView(
                image: image,
                maxScale: 5,
                minWidthFactor: minWidthFactor,
              ),
            ),
          ),
        ),
      );
      await tester.pump();
    }

    testWidgets('a 1000 × 6000 photo starts at the top, wide enough to read', (
      tester,
    ) async {
      final bytes = (await tester.runAsync(() => png(100, 600)))!;
      await pumpImage(tester, MemoryImage(bytes), const Size(360, 240));

      final viewer = tester.widget<InteractiveViewer>(
        find.byType(InteractiveViewer),
      );
      expect(viewer.constrained, isFalse);
      final image = find.byType(Image);
      expect(tester.getSize(image), const Size(360, 1080));
      // The top of the receipt is at the top of the box.
      final box = tester.getRect(find.byType(ReceiptImageView));
      expect(tester.getRect(image).top, box.top);
      expect(tester.takeException(), isNull);
    });

    testWidgets('full screen a long photo pans; a normal one fits', (
      tester,
    ) async {
      final tall = (await tester.runAsync(() => png(100, 600)))!;
      await pumpImage(
        tester,
        MemoryImage(tall),
        const Size(400, 560),
        minWidthFactor: viewerMinWidthFactor,
      );
      expect(
        tester
            .widget<InteractiveViewer>(find.byType(InteractiveViewer))
            .constrained,
        isFalse,
      );
      expect(tester.getSize(find.byType(Image)), const Size(400, 1440));

      final normal = (await tester.runAsync(() => png(400, 300)))!;
      await pumpImage(
        tester,
        MemoryImage(normal),
        const Size(400, 560),
        minWidthFactor: viewerMinWidthFactor,
      );
      expect(
        tester
            .widget<InteractiveViewer>(find.byType(InteractiveViewer))
            .constrained,
        isTrue,
      );
      expect(tester.getSize(find.byType(Image)), const Size(400, 560));
    });
  });

  group('accessibility', () {
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

    for (final theme in [ThemeMode.light, ThemeMode.dark]) {
      testWidgets('flagged form meets the guidelines (${theme.name})', (
        tester,
      ) async {
        final handle = tester.ensureSemantics();
        await pumpReview(
          tester,
          location: '/scan/review',
          scanState: flagged,
          themeMode: theme,
        );
        await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
        await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
        await expectLater(tester, meetsGuideline(textContrastGuideline));

        await tester.ensureVisible(find.byKey(ReviewKeys.notesField));
        await tester.pumpAndSettle();
        await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
        await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
        await expectLater(tester, meetsGuideline(textContrastGuideline));
        handle.dispose();
      });

      testWidgets('OCR-failed form and errors meet the guidelines '
          '(${theme.name})', (tester) async {
        final handle = tester.ensureSemantics();
        await pumpReview(
          tester,
          location: '/scan/review',
          scanState: const ScanReview(ocrFailedReview),
          themeMode: theme,
        );
        await tapSave(tester);
        await tester.ensureVisible(find.byKey(ReviewKeys.ocrFailedBanner));
        await tester.pumpAndSettle();
        await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
        await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
        await expectLater(tester, meetsGuideline(textContrastGuideline));
        handle.dispose();
      });
    }

    testWidgets('edit mode and the full-screen photo meet the guidelines', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await pumpReview(
        tester,
        location: '/receipts/r1/edit',
        rows: [sampleRow()],
      );
      await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
      await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));

      await tester.tap(find.byKey(ReviewKeys.photoFullScreenButton));
      await tester.pumpAndSettle();
      expect(find.byKey(ReviewKeys.photoViewer), findsOneWidget);
      expect(find.bySemanticsLabel('Receipt photo'), findsWidgets);
      await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
      await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
      await expectLater(tester, meetsGuideline(textContrastGuideline));
      handle.dispose();
    });

    testWidgets('the ⚠️ flag is announced with the field', (tester) async {
      final handle = tester.ensureSemantics();
      await pumpReview(tester, location: '/scan/review', scanState: flagged);
      expect(find.bySemanticsLabel(RegExp('Needs checking')), findsWidgets);
      handle.dispose();
    });

    testWidgets('focus moves merchant → date → total → currency → more → '
        'category → payment → notes', (tester) async {
      await pumpReview(tester, location: '/receipts/new');
      await tester.runAsync(() => Future<void>.delayed(Duration.zero));
      await tester.pumpAndSettle();
      final order = [
        ReviewKeys.merchantField,
        ReviewKeys.dateField,
        ReviewKeys.totalField,
        ReviewKeys.currencyField,
        ReviewKeys.moreToggle,
        const ValueKey('category'),
        ReviewKeys.paymentMethod,
        ReviewKeys.notesField,
      ];

      /// The form field the focused widget belongs to.
      Key? focusedField() {
        Key? found;
        final context = FocusManager.instance.primaryFocus?.context;
        if (context == null) return null;
        void check(Element element) {
          final key = element.widget.key;
          if (key is ValueKey<String> &&
              key.value.startsWith('review.category.')) {
            found = const ValueKey('category');
          } else if (order.contains(key)) {
            found = key;
          }
        }

        check(context as Element);
        if (found != null) return found;
        context.visitAncestorElements((element) {
          check(element);
          return found == null;
        });
        return found;
      }

      focusOf(tester, ReviewKeys.merchantField).requestFocus();
      await tester.pump();
      final visited = <Key>[];
      for (var i = 0; i < 40; i++) {
        final field = focusedField();
        if (field != null && (visited.isEmpty || visited.last != field)) {
          visited.add(field);
        }
        if (field == ReviewKeys.notesField) break;
        FocusManager.instance.primaryFocus!.nextFocus();
        await tester.pump();
      }
      expect(visited, order);
    });
  });

  testWidgets('settings are read once, not watched, by the form', (
    tester,
  ) async {
    // Changing the date order while the form is open must not reformat or
    // lose what the user typed.
    await pumpReview(
      tester,
      location: '/scan/review',
      scanState: ScanReview(sampleReview()),
    );
    await tester.enterText(find.byKey(ReviewKeys.merchantField), 'Typed');
    final container = ProviderScope.containerOf(
      tester.element(find.byKey(ReviewKeys.form)),
    );
    await tester.runAsync(
      () => container
          .read(settingsControllerProvider.notifier)
          .setDateOrder(DateOrder.mdy),
    );
    await tester.pumpAndSettle();
    expect(fieldText(tester, ReviewKeys.merchantField), 'Typed');
    expect(fieldText(tester, ReviewKeys.dateField), '12/09/2026');
  });
}
