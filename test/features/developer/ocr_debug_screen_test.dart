import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:receipt_mind/core/db/tables/enums.dart';
import 'package:receipt_mind/features/developer/presentation/ocr_debug_screen.dart';
import 'package:receipt_mind/features/developer/presentation/ocr_overlay_painter.dart';
import 'package:receipt_mind/features/scan/application/receipt_draft.dart';
import 'package:receipt_mind/features/scan/application/scan_state.dart';
import 'package:receipt_parser/receipt_parser.dart' hide PaymentMethod;

import 'dev_test_helpers.dart';

OcrOverlayPainter painterOf(WidgetTester tester) => tester
    .widgetList<CustomPaint>(find.byType(CustomPaint))
    .map((c) => c.painter)
    .whereType<OcrOverlayPainter>()
    .single;

void main() {
  testWidgets('with boxes: overlay, toggles, fields, trace and rows', (
    tester,
  ) async {
    final data = debugReviewData(layoutFixture('au/au_fuel_01'));
    await tester.pumpWidget(localizedApp(OcrDebugScreen(data: data)));
    await tester.pumpAndSettle();

    expect(find.text('OCR debug'), findsOneWidget);
    expect(find.text('Overlay'), findsOneWidget);
    expect(find.byType(InteractiveViewer), findsOneWidget);
    expect(find.byType(FilterChip), findsNWidgets(4));

    var painter = painterOf(tester);
    expect(painter.imageSize, const Size(1000, 1500));
    expect(painter.layers, {OverlayLayer.rows, OverlayLayer.fields});
    expect(painter.rows.length, data.parsed!.rows.length);
    expect(painter.fieldRows[ReceiptField.total], data.parsed!.total!.rowIndex);
    // The legend names the row each field came from.
    expect(
      find.text('total · row ${data.parsed!.total!.rowIndex}'),
      findsOneWidget,
    );

    await tester.tap(find.widgetWithText(FilterChip, 'Words'));
    await tester.tap(find.widgetWithText(FilterChip, 'Rows'));
    await tester.pump();
    painter = painterOf(tester);
    expect(painter.layers, {OverlayLayer.words, OverlayLayer.fields});

    await tester.tap(find.text('Parser'));
    await tester.pumpAndSettle();
    expect(find.text('mlkit-latin'), findsOneWidget);
    expect(find.text('1000 × 1500'), findsOneWidget);
    expect(find.textContaining('86.49'), findsWidgets);
    expect(find.textContaining('confidence '), findsWidgets);
    final trace = data.parsed!.trace.join('\n');
    await tester.scrollUntilVisible(
      find.text('Parser trace'),
      300,
      scrollable: find.byType(Scrollable).last,
    );
    expect(find.text(trace), findsOneWidget);

    await tester.tap(find.text('Text'));
    await tester.pumpAndSettle();
    final rowsText = [
      for (final r in data.parsed!.rows) '${r.index}: ${r.text}',
    ].join('\n');
    expect(find.text(rowsText), findsOneWidget);
  });

  testWidgets('without boxes: only the text tabs', (tester) async {
    final data = debugReviewData(
      OcrDocument.fromPlainText(
        'CORNER CAFE\n12/09/2026\nFlat white  4.50\nTOTAL  4.50\nVISA',
      ),
    );
    await tester.pumpWidget(
      localizedApp(OcrDebugScreen(data: data, imagePath: '/nope.jpg')),
    );
    await tester.pumpAndSettle();

    expect(find.text('Overlay'), findsNothing);
    expect(find.byType(InteractiveViewer), findsNothing);
    expect(find.text('Parser'), findsOneWidget);
    expect(find.text('Summary'), findsOneWidget);
    expect(find.text('unknown'), findsOneWidget); // image size
    expect(find.textContaining('4.50'), findsWidgets);

    await tester.tap(find.text('Text'));
    await tester.pumpAndSettle();
    expect(find.textContaining('0: CORNER CAFE'), findsOneWidget);
  });

  testWidgets('without OCR or parser output', (tester) async {
    const data = ReviewData(
      ocrFailed: true,
      draft: ReceiptDraft(
        currency: 'AUD',
        extractionMethod: ExtractionMethod.manual,
      ),
    );
    await tester.pumpWidget(localizedApp(const OcrDebugScreen(data: data)));
    await tester.pumpAndSettle();

    expect(find.text('The parser did not run on this scan.'), findsOneWidget);
    expect(find.text('No issues'), findsOneWidget);
    await tester.tap(find.text('Text'));
    await tester.pumpAndSettle();
    expect(find.text('OCR found no text.'), findsNWidgets(2));
  });

  test('formatFieldValue', () {
    expect(formatFieldValue(4560, 'AUD'), '45.60');
    expect(formatFieldValue(1500, 'JPY'), '1500');
    expect(formatFieldValue(LocalDate(2026, 9, 12), 'AUD'), '2026-09-12');
    expect(formatFieldValue(PaymentMethod.card, 'AUD'), 'card');
    expect(formatFieldValue('Shell', 'AUD'), 'Shell');
  });
}
