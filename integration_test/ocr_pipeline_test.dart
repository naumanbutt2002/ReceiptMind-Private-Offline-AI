// M3 on-device test: ML Kit reads a receipt image and the rule parser
// understands the result. The receipt is drawn with dart:ui at test time, so
// no asset files are needed.
//
//   flutter test integration_test/ocr_pipeline_test.dart -d emulator-5554
import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:path_provider/path_provider.dart';
import 'package:receipt_mind/features/scan/ocr/mlkit_ocr_engine.dart';
import 'package:receipt_parser/receipt_parser.dart';

/// Logical width of the receipt; the image is drawn at [_scale]×.
const _width = 500.0;
const _scale = 2.0;
const _padding = 24.0;

const _black = ui.Color(0xFF000000);
const _white = ui.Color(0xFFFFFFFF);

/// One printed row of the receipt.
sealed class _Row {
  const _Row();
}

final class _Center extends _Row {
  const _Center(this.text, {this.size = 14, this.bold = false});
  final String text;
  final double size;
  final bool bold;
}

final class _Split extends _Row {
  const _Split(this.left, [this.right = '', this.bold = false]);
  final String left;
  final String right;
  final bool bold;
}

final class _Gap extends _Row {
  const _Gap([this.height = 12]);
  final double height;
}

/// A GST-inclusive Australian supermarket receipt. The items add up to the
/// subtotal and the total.
const _receipt = <_Row>[
  _Center('FRESHWAY MARKET', size: 26, bold: true),
  _Gap(6),
  _Center('123 George St, Sydney NSW 2000'),
  _Center('Ph (02) 9555 0123'),
  _Center('ABN 12 345 678 901'),
  _Gap(),
  _Center('TAX INVOICE', bold: true),
  _Gap(),
  _Split('12/09/2026 14:32', 'Reg 3 Trn 4821'),
  _Split('----------------------------------------------'),
  _Split('Bananas 1kg', '3.90'),
  _Split('Full Cream Milk 2L', '3.60'),
  _Split('Sourdough Loaf', '6.50'),
  _Split('Free Range Eggs 12pk', '7.20'),
  _Split('Greek Yoghurt 1kg', '6.80'),
  _Split('Cheddar Block 500g', '8.00'),
  _Split('Baby Spinach 120g', '3.50'),
  _Split('Chicken Thigh Fillet 1kg', '12.90'),
  _Split('Basmati Rice 2kg', '6.40'),
  _Split('Olive Oil 750ml', '11.00'),
  _Split('Penne Pasta 500g', '2.20'),
  _Split('Tomato Passata 700g', '3.00'),
  _Split('Coffee Beans 1kg', '24.00'),
  _Split('Dishwashing Liquid', '4.50'),
  _Split('Paper Towel 2pk', '5.20'),
  _Split('----------------------------------------------'),
  _Split('SUBTOTAL', '108.70'),
  _Split('Total includes GST', '9.88'),
  _Gap(6),
  _Split('TOTAL', '\$108.70', true),
  _Gap(),
  _Split('VISA CREDIT', '108.70'),
  _Split('CARD NO: **** **** **** 4821'),
  _Split('APPROVED  AUTH: 482915'),
  _Gap(),
  _Center('Thank you for shopping with us'),
];

ui.Paragraph _paragraph(
  String text, {
  required double width,
  ui.TextAlign align = ui.TextAlign.left,
  double size = 14,
  bool bold = false,
}) {
  final builder =
      ui.ParagraphBuilder(
          ui.ParagraphStyle(
            textAlign: align,
            fontFamily: 'monospace',
            fontSize: size,
            fontWeight: bold ? ui.FontWeight.bold : ui.FontWeight.normal,
          ),
        )
        ..pushStyle(ui.TextStyle(color: _black))
        ..addText(text);
  return builder.build()..layout(ui.ParagraphConstraints(width: width));
}

/// Draws [rows] black on white and returns the PNG bytes and pixel size.
Future<(Uint8List, int, int)> _renderPng(List<_Row> rows) async {
  const contentWidth = _width - 2 * _padding;
  final recorder = ui.PictureRecorder();
  final canvas = ui.Canvas(recorder)..scale(_scale);
  var y = _padding;
  for (final row in rows) {
    switch (row) {
      case _Gap(:final height):
        y += height;
      case _Center(:final text, :final size, :final bold):
        final p = _paragraph(
          text,
          width: contentWidth,
          align: ui.TextAlign.center,
          size: size,
          bold: bold,
        );
        canvas.drawParagraph(p, ui.Offset(_padding, y));
        y += p.height + 2;
      case _Split(:final left, :final right, :final bold):
        final l = _paragraph(left, width: contentWidth, bold: bold);
        final r = _paragraph(
          right,
          width: contentWidth,
          align: ui.TextAlign.right,
          bold: bold,
        );
        canvas
          ..drawParagraph(l, ui.Offset(_padding, y))
          ..drawParagraph(r, ui.Offset(_padding, y));
        y += l.height + 2;
    }
  }
  y += _padding;
  // White paper behind everything drawn so far.
  canvas.drawColor(_white, ui.BlendMode.dstOver);

  final width = (_width * _scale).round();
  final height = (y * _scale).round();
  final image = await recorder.endRecording().toImage(width, height);
  try {
    final png = await image.toByteData(format: ui.ImageByteFormat.png);
    return (png!.buffer.asUint8List(), width, height);
  } finally {
    image.dispose();
  }
}

Future<(Uint8List, int, int)> _blankPng(int width, int height) async {
  final recorder = ui.PictureRecorder();
  ui.Canvas(recorder).drawColor(_white, ui.BlendMode.src);
  final image = await recorder.endRecording().toImage(width, height);
  try {
    final png = await image.toByteData(format: ui.ImageByteFormat.png);
    return (png!.buffer.asUint8List(), width, height);
  } finally {
    image.dispose();
  }
}

Future<String> _writeTemp(String name, Uint8List bytes) async {
  final dir = await getTemporaryDirectory();
  final file = File('${dir.path}/$name');
  await file.writeAsBytes(bytes, flush: true);
  addTearDown(() async {
    if (file.existsSync()) await file.delete();
  });
  return file.path;
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('ML Kit reads a rendered receipt and the parser understands it', (
    tester,
  ) async {
    final engine = MlKitOcrEngine();
    addTearDown(engine.dispose);

    final watch = Stopwatch()..start();
    final (png, width, height) = await _renderPng(_receipt);
    final path = await _writeTemp('m3_ocr_receipt.png', png);
    final renderMs = watch.elapsedMilliseconds;

    watch.reset();
    final document = await engine.recognize(path);
    final firstOcrMs = watch.elapsedMilliseconds;

    watch.reset();
    final again = await engine.recognize(path);
    final warmOcrMs = watch.elapsedMilliseconds;

    final options = ParseOptions(
      defaultCurrency: 'AUD',
      dateOrder: DateOrder.dmy,
      today: LocalDate(2026, 11, 16),
    );
    watch.reset();
    final receipt = const RuleReceiptParser().parse(document, options);
    final parseUs = watch.elapsedMicroseconds;

    debugPrint(
      'M3 ocr receipt ${width}x$height px, ${png.length} bytes: '
      'render+write $renderMs ms, first OCR $firstOcrMs ms, '
      'warm OCR $warmOcrMs ms, parse $parseUs µs, '
      '${document.lines.length} lines',
    );
    debugPrint('M3 ocr text:\n${document.text}');
    // The layout dump, in chunks so long log lines aren't cut. Join the
    // `M3 ocr json` lines to get an `.ocr.json` fixture.
    final json = jsonEncode(document.toJson());
    for (var i = 0; i < json.length; i += 600) {
      debugPrint(
        'M3 ocr json ${i ~/ 600}: '
        '${json.substring(i, (i + 600).clamp(0, json.length))}',
      );
    }
    debugPrint(
      'M3 ocr parsed: total ${receipt.total}, date ${receipt.date}, '
      'merchant ${receipt.merchant}, tax ${receipt.tax}, '
      'payment ${receipt.paymentMethod}',
    );

    expect(document.engineId, 'mlkit-latin');
    expect(document.imageWidth, width);
    expect(document.imageHeight, height);
    expect(document.lines.length, greaterThanOrEqualTo(20));
    expect(document.hasLayout, isTrue);
    expect(again.lines.length, document.lines.length);
    for (final line in document.lines) {
      final box = line.box!;
      expect(box.left, greaterThanOrEqualTo(-2));
      expect(box.right, lessThanOrEqualTo(width + 2));
      expect(box.bottom, lessThanOrEqualTo(height + 2));
    }

    expect(receipt.total?.value, 10870);
    expect(receipt.date?.value, LocalDate(2026, 9, 12));
    expect(receipt.merchant?.value.toLowerCase(), 'freshway market');
    expect(receipt.currency.value, 'AUD');
  });

  testWidgets('OCR of a blank image returns no lines', (tester) async {
    final engine = MlKitOcrEngine();
    addTearDown(engine.dispose);

    final (png, width, height) = await _blankPng(800, 1200);
    final path = await _writeTemp('m3_ocr_blank.png', png);

    final watch = Stopwatch()..start();
    final document = await engine.recognize(path);
    debugPrint(
      'M3 ocr blank ${width}x$height px: ${watch.elapsedMilliseconds} ms, '
      '${document.lines.length} lines',
    );

    expect(document.lines, isEmpty);
    expect(document.imageWidth, width);
    expect(document.imageHeight, height);
  });
}
