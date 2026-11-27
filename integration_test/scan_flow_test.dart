// M4 on-device test: the whole scan flow in the real app with the real
// ML Kit OCR engine. Only the document scanner is faked: it returns a receipt
// drawn with dart:ui. Scan → "Reading receipt…" → review screen pre-filled →
// Save → the row is in the database and its photo is in app storage.
//
//   flutter test integration_test/scan_flow_test.dart -d emulator-5554
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:path_provider/path_provider.dart';
import 'package:receipt_mind/app/app.dart';
import 'package:receipt_mind/app/router.dart';
import 'package:receipt_mind/core/clock.dart';
import 'package:receipt_mind/core/db/app_database.dart';
import 'package:receipt_mind/core/db/db_providers.dart';
import 'package:receipt_mind/core/settings/settings_providers.dart';
import 'package:receipt_mind/core/settings/settings_repository.dart';
import 'package:receipt_mind/features/receipts/data/receipts_providers.dart';
import 'package:receipt_mind/features/receipts/presentation/review/review_keys.dart';
import 'package:receipt_mind/features/scan/application/scan_controller.dart';
import 'package:receipt_mind/features/scan/application/scan_state.dart';
import 'package:receipt_mind/features/scan/capture/document_scanner.dart';
import 'package:receipt_mind/features/scan/scan_providers.dart';
import 'package:receipt_mind/features/scan/scan_routes.dart';
import 'package:receipt_parser/receipt_parser.dart' show LocalDate;

import '../test/helpers/scan_fakes.dart';
import '../test/helpers/test_app.dart';

/// Lines of a GST-inclusive Australian receipt: `[left, right]`, a lone
/// string is centred. Same content as `auReceiptText`.
const _receipt = <List<String>>[
  ['FRESHWAY MARKET'],
  ['123 George St, Sydney NSW 2000'],
  ['Ph (02) 9555 0123'],
  ['ABN 12 345 678 901'],
  ['TAX INVOICE'],
  ['12/09/2026 14:32', 'Reg 3 Trn 4821'],
  ['Bananas 1kg', '3.90'],
  ['Full Cream Milk 2L', '3.60'],
  ['Sourdough Loaf', '6.50'],
  ['Coffee Beans 1kg', '24.00'],
  ['Olive Oil 750ml', '11.00'],
  ['Chicken Thigh Fillet 1kg', '12.90'],
  ['Cheddar Block 500g', '8.00'],
  ['Greek Yoghurt 1kg', '6.80'],
  ['Free Range Eggs 12pk', '7.20'],
  ['Basmati Rice 2kg', '6.40'],
  ['Penne Pasta 500g', '2.20'],
  ['Tomato Passata 700g', '3.00'],
  ['Baby Spinach 120g', '3.50'],
  ['Dishwashing Liquid', '4.50'],
  ['Paper Towel 2pk', '5.20'],
  ['SUBTOTAL', '108.70'],
  ['Total includes GST', '9.88'],
  ['TOTAL', r'$108.70'],
  ['VISA CREDIT', '108.70'],
  ['CARD NO: **** **** **** 4821'],
  ['APPROVED AUTH: 482915'],
  ['Thank you for shopping with us'],
];

ui.Paragraph _paragraph(String text, double width, ui.TextAlign align) {
  final builder =
      ui.ParagraphBuilder(
          ui.ParagraphStyle(
            textAlign: align,
            fontFamily: 'monospace',
            fontSize: 14,
          ),
        )
        ..pushStyle(ui.TextStyle(color: const ui.Color(0xFF000000)))
        ..addText(text);
  return builder.build()..layout(ui.ParagraphConstraints(width: width));
}

/// Draws the receipt black on white at 2× and returns PNG bytes.
Future<Uint8List> _renderReceipt() async {
  const width = 500.0;
  const scale = 2.0;
  const padding = 24.0;
  const content = width - 2 * padding;
  final recorder = ui.PictureRecorder();
  final canvas = ui.Canvas(recorder)..scale(scale);
  var y = padding;
  for (final row in _receipt) {
    final left = _paragraph(
      row.first,
      content,
      row.length == 1 ? ui.TextAlign.center : ui.TextAlign.left,
    );
    canvas.drawParagraph(left, ui.Offset(padding, y));
    if (row.length > 1) {
      canvas.drawParagraph(
        _paragraph(row[1], content, ui.TextAlign.right),
        ui.Offset(padding, y),
      );
    }
    y += left.height + 4;
  }
  y += padding;
  canvas.drawColor(const ui.Color(0xFFFFFFFF), ui.BlendMode.dstOver);
  final image = await recorder.endRecording().toImage(
    (width * scale).round(),
    (y * scale).round(),
  );
  try {
    final png = await image.toByteData(format: ui.ImageByteFormat.png);
    return png!.buffer.asUint8List();
  } finally {
    image.dispose();
  }
}

/// Pumps frames until [finder] shows up, letting real async work (OCR,
/// isolates, file I/O) run in between.
Future<void> _pumpUntilFound(
  WidgetTester tester,
  Finder finder, {
  Duration timeout = const Duration(seconds: 30),
}) async {
  final end = DateTime.now().add(timeout);
  while (finder.evaluate().isEmpty) {
    if (DateTime.now().isAfter(end)) {
      throw TestFailure('Timed out waiting for $finder');
    }
    await tester.pump(const Duration(milliseconds: 100));
  }
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('scan → OCR → review → save stores the receipt and photo', (
    tester,
  ) async {
    final temp = await getTemporaryDirectory();
    final root = await Directory(
      '${temp.path}/m4_scan_flow_${DateTime.now().microsecondsSinceEpoch}',
    ).create(recursive: true);
    addTearDown(() => root.delete(recursive: true));
    final support = await Directory('${root.path}/support').create();
    final scanFile = File('${root.path}/scan.png');
    await scanFile.writeAsBytes(await _renderReceipt(), flush: true);

    final prefs = await inMemoryPrefs({
      SettingsRepository.keyDefaultCurrency: 'AUD',
      SettingsRepository.keyDateOrder: 'dmy',
    });
    final db = inMemoryDatabase();
    addTearDown(db.close);
    final scanner = FakeDocumentScanner(path: scanFile.path);

    final container = ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        deviceLocaleProvider.overrideWithValue('en_AU'),
        appDatabaseProvider.overrideWithValue(db),
        appSupportDirectoryProvider.overrideWith((ref) async => support),
        documentScannerProvider.overrideWithValue(scanner),
        clockProvider.overrideWithValue(() => DateTime(2026, 11, 16, 9)),
        // ocrEngineProvider is the real ML Kit engine.
      ],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const ReceiptMindApp(),
      ),
    );
    await tester.pumpAndSettle();

    final watch = Stopwatch()..start();
    container
        .read(routerProvider)
        .push(ScanRoutes.scanFrom(ScanSource.camera))
        .ignore();
    await _pumpUntilFound(tester, find.byKey(ReviewKeys.form));
    debugPrint(
      'M4 scan flow: scan → review in ${watch.elapsedMilliseconds} ms',
    );

    expect(scanner.calls, [ScanSource.camera]);
    final state = container.read(scanControllerProvider);
    expect(state, isA<ScanReview>());
    final draft = (state as ScanReview).data.draft;
    debugPrint(
      'M4 scan flow draft: ${draft.merchant}, ${draft.date}, '
      '${draft.totalMinor} ${draft.currency}, ${draft.paymentMethod}, '
      'confidence ${draft.confidence}',
    );
    expect(state.data.ocrFailed, isFalse);
    expect(draft.totalMinor, 10870);
    expect(draft.merchant.toLowerCase(), 'freshway market');

    // The form is pre-filled.
    expect(
      _fieldText(tester, ReviewKeys.merchantField).toLowerCase(),
      'freshway market',
    );
    expect(_fieldText(tester, ReviewKeys.totalField), contains('108.70'));

    await tester.ensureVisible(find.byKey(ReviewKeys.saveButton));
    await tester.tap(find.byKey(ReviewKeys.saveButton));
    final saved = await _waitForRow(tester, container);
    debugPrint('M4 scan flow: saved after ${watch.elapsedMilliseconds} ms');
    await tester.pumpAndSettle();

    expect(container.read(scanControllerProvider), isA<ScanIdle>());
    expect(saved.merchant.toLowerCase(), 'freshway market');
    expect(saved.totalMinor, 10870);
    expect(saved.currency, 'AUD');
    expect(saved.purchaseDate, LocalDate(2026, 9, 12));
    expect(saved.paymentMethod, PaymentMethod.card);
    expect(saved.extractionMethod, ExtractionMethod.rules);
    expect(saved.rawOcrText, contains('FRESHWAY'));
    final imagePath = saved.imagePath;
    expect(imagePath, isNotNull);
    expect(imagePath, isNot(startsWith('/')));
    final stored = File('${support.path}/$imagePath');
    expect(stored.existsSync(), isTrue);
    debugPrint(
      'M4 scan flow saved ${saved.id}: $imagePath, '
      '${stored.lengthSync()} bytes',
    );
  });

  testWidgets('a scan whose temp file vanished saves without its photo', (
    tester,
  ) async {
    final temp = await getTemporaryDirectory();
    final root = await Directory(
      '${temp.path}/m8_lost_scan_${DateTime.now().microsecondsSinceEpoch}',
    ).create(recursive: true);
    addTearDown(() => root.delete(recursive: true));
    final support = await Directory('${root.path}/support').create();
    final scanFile = File('${root.path}/scan.png');
    await scanFile.writeAsBytes(await _renderReceipt(), flush: true);

    final prefs = await inMemoryPrefs({
      SettingsRepository.keyDefaultCurrency: 'AUD',
      SettingsRepository.keyDateOrder: 'dmy',
    });
    final db = inMemoryDatabase();
    addTearDown(db.close);
    final container = ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        deviceLocaleProvider.overrideWithValue('en_AU'),
        appDatabaseProvider.overrideWithValue(db),
        appSupportDirectoryProvider.overrideWith((ref) async => support),
        documentScannerProvider.overrideWithValue(
          FakeDocumentScanner(path: scanFile.path),
        ),
        clockProvider.overrideWithValue(() => DateTime(2026, 11, 16, 9)),
      ],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const ReceiptMindApp(),
      ),
    );
    await tester.pumpAndSettle();
    container
        .read(routerProvider)
        .push(ScanRoutes.scanFrom(ScanSource.camera))
        .ignore();
    await _pumpUntilFound(tester, find.byKey(ReviewKeys.form));

    // The system clears the scanner's cache while the user reviews.
    await scanFile.delete();
    await tester.tap(find.byKey(ReviewKeys.saveButton));
    await _pumpUntilFound(tester, find.byKey(ReviewKeys.saveWithoutPhoto));
    await tester.tap(find.byKey(ReviewKeys.saveWithoutPhoto));
    final saved = await _waitForRow(tester, container);
    await tester.pumpAndSettle();

    expect(saved.totalMinor, 10870);
    expect(saved.imagePath, isNull);
    expect(saved.rawOcrText, contains('FRESHWAY'));
    expect(container.read(scanControllerProvider), isA<ScanIdle>());
  });
}

/// Text of the text field inside the review form widget with [key].
String _fieldText(WidgetTester tester, Key key) => tester
    .widget<TextField>(
      find.descendant(of: find.byKey(key), matching: find.byType(TextField)),
    )
    .controller!
    .text;

/// Waits (with real time passing) until the database has one receipt.
Future<ReceiptRow> _waitForRow(
  WidgetTester tester,
  ProviderContainer container,
) async {
  final repository = container.read(receiptRepositoryProvider);
  for (var i = 0; i < 300; i++) {
    final rows = await repository.watchReceipts().first;
    if (rows.isNotEmpty) return rows.single;
    await tester.pump(const Duration(milliseconds: 100));
  }
  throw TestFailure('The receipt was not saved');
}
