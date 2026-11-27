import 'dart:io';
import 'dart:math';
import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:receipt_mind/features/scan/ocr/mlkit_ocr_engine.dart';
import 'package:receipt_parser/receipt_parser.dart';

/// Builds a [TextLine] whose words are spread evenly over [box].
TextLine _line(
  String text,
  ui.Rect box, {
  double? angle,
  double? confidence = 0.9,
}) {
  final words = text.split(' ');
  final step = box.width / words.length;
  return TextLine(
    text: text,
    boundingBox: box,
    recognizedLanguages: const ['en'],
    cornerPoints: _corners(box),
    confidence: confidence,
    angle: angle,
    elements: [
      for (final (i, word) in words.indexed)
        TextElement(
          text: word,
          symbols: const [],
          boundingBox: ui.Rect.fromLTRB(
            box.left + i * step,
            box.top,
            box.left + (i + 1) * step,
            box.bottom,
          ),
          recognizedLanguages: const ['en'],
          cornerPoints: const [],
          confidence: confidence,
          angle: angle,
        ),
    ],
  );
}

TextBlock _block(List<TextLine> lines) {
  final box = lines
      .map((l) => l.boundingBox)
      .reduce((a, b) => a.expandToInclude(b));
  return TextBlock(
    text: lines.map((l) => l.text).join('\n'),
    lines: lines,
    boundingBox: box,
    recognizedLanguages: const ['en'],
    cornerPoints: _corners(box),
  );
}

RecognizedText _recognized(List<TextBlock> blocks) =>
    RecognizedText(text: blocks.map((b) => b.text).join('\n'), blocks: blocks);

List<Point<int>> _corners(ui.Rect r) => [
  Point(r.left.round(), r.top.round()),
  Point(r.right.round(), r.top.round()),
  Point(r.right.round(), r.bottom.round()),
  Point(r.left.round(), r.bottom.round()),
];

/// A small café receipt as ML Kit typically returns it: the item names and
/// the prices come back as separate blocks.
RecognizedText _cafeReceipt() => _recognized([
  _block([_line('BEAN & LEAF CAFE', const ui.Rect.fromLTRB(150, 20, 450, 52))]),
  _block([
    _line('12 King St, Sydney NSW', const ui.Rect.fromLTRB(140, 60, 460, 80)),
  ]),
  _block([
    _line('12/09/2026 14:32', const ui.Rect.fromLTRB(20, 100, 260, 120)),
  ]),
  _block([
    _line('Flat White', const ui.Rect.fromLTRB(20, 140, 180, 160)),
    _line('Banana Bread', const ui.Rect.fromLTRB(20, 170, 200, 190)),
  ]),
  _block([
    _line('5.50', const ui.Rect.fromLTRB(500, 140, 560, 160)),
    _line('6.00', const ui.Rect.fromLTRB(500, 170, 560, 190)),
  ]),
  _block([_line('TOTAL', const ui.Rect.fromLTRB(20, 220, 120, 245))]),
  _block([_line('11.50', const ui.Rect.fromLTRB(480, 220, 560, 245))]),
  _block([_line('VISA ****1234', const ui.Rect.fromLTRB(20, 270, 220, 290))]),
]);

void main() {
  group('ocrDocumentFromRecognizedText', () {
    test('maps blocks → lines → words in ML Kit order', () {
      final doc = ocrDocumentFromRecognizedText(
        _recognized([
          _block([
            _line('Hello world', const ui.Rect.fromLTRB(10, 20, 110, 40)),
            _line('Second', const ui.Rect.fromLTRB(10, 50, 70, 70)),
          ]),
          _block([
            _line(
              '4.50',
              const ui.Rect.fromLTRB(300, 20, 340, 40),
              angle: 1.5,
              confidence: 0.8,
            ),
          ]),
        ]),
        imageWidth: 400,
        imageHeight: 100,
      );

      expect(doc.engineId, 'mlkit-latin');
      expect(doc.imageWidth, 400);
      expect(doc.imageHeight, 100);
      expect(doc.lines.map((l) => l.text), ['Hello world', 'Second', '4.50']);
      expect(doc.hasLayout, isTrue);

      final first = doc.lines.first;
      expect(first.box, const BoxRect(10, 20, 110, 40));
      expect(first.words.map((w) => w.text), ['Hello', 'world']);
      expect(first.words.first.box, const BoxRect(10, 20, 60, 40));
      expect(first.words.last.box, const BoxRect(60, 20, 110, 40));
      expect(first.words.first.confidence, 0.9);
      expect(first.angle, isNull);

      final price = doc.lines.last;
      expect(price.angle, 1.5);
      expect(price.words.single.confidence, 0.8);
      expect(price.box, const BoxRect(300, 20, 340, 40));
    });

    test('keeps iOS output without confidence or angle', () {
      final doc = ocrDocumentFromRecognizedText(
        _recognized([
          _block([
            _line(
              'TOTAL 9.00',
              const ui.Rect.fromLTRB(0, 0, 100, 20),
              confidence: null,
            ),
          ]),
        ]),
      );
      expect(doc.lines.single.angle, isNull);
      expect(doc.lines.single.words.map((w) => w.confidence), [null, null]);
      expect(doc.imageWidth, isNull);
      expect(doc.imageHeight, isNull);
    });

    test('empty text → no lines', () {
      final doc = ocrDocumentFromRecognizedText(
        RecognizedText(text: '', blocks: const []),
      );
      expect(doc.lines, isEmpty);
      expect(doc.text, '');
      expect(doc.hasLayout, isFalse);
    });

    test('blank lines are dropped', () {
      final doc = ocrDocumentFromRecognizedText(
        _recognized([
          _block([
            _line('  ', const ui.Rect.fromLTRB(0, 0, 10, 10)),
            _line('Milk', const ui.Rect.fromLTRB(0, 20, 40, 30)),
          ]),
        ]),
      );
      expect(doc.lines.map((l) => l.text), ['Milk']);
    });

    test('the mapped document survives a JSON round trip', () {
      final doc = ocrDocumentFromRecognizedText(
        _cafeReceipt(),
        imageWidth: 600,
        imageHeight: 320,
      );
      final copy = OcrDocument.fromJson(doc.toJson());
      expect(copy.toJson(), doc.toJson());
    });

    test('the rule parser reads the mapped document', () {
      final doc = ocrDocumentFromRecognizedText(
        _cafeReceipt(),
        imageWidth: 600,
        imageHeight: 320,
      );
      final receipt = const RuleReceiptParser().parse(
        doc,
        ParseOptions(
          defaultCurrency: 'AUD',
          dateOrder: DateOrder.dmy,
          today: LocalDate(2026, 11, 16),
        ),
      );

      expect(receipt.total?.value, 1150);
      expect(receipt.date?.value, LocalDate(2026, 9, 12));
      expect(receipt.merchant?.value.toLowerCase(), 'bean & leaf cafe');
      expect(receipt.currency.value, 'AUD');
    });
  });

  group('readImageSize', () {
    late Directory dir;

    setUp(() => dir = Directory.systemTemp.createTempSync('ocr_size_test'));
    tearDown(() => dir.deleteSync(recursive: true));

    test('reads width and height from a PNG header', () async {
      final recorder = ui.PictureRecorder();
      ui.Canvas(recorder).drawRect(
        const ui.Rect.fromLTWH(0, 0, 37, 21),
        ui.Paint()..color = const ui.Color(0xFFFFFFFF),
      );
      final image = await recorder.endRecording().toImage(37, 21);
      final png = await image.toByteData(format: ui.ImageByteFormat.png);
      image.dispose();
      final file = File('${dir.path}/a.png')
        ..writeAsBytesSync(png!.buffer.asUint8List());

      expect(await readImageSize(file.path), (width: 37, height: 21));
    });

    test('returns null for a missing or non-image file', () async {
      expect(await readImageSize('${dir.path}/missing.jpg'), isNull);
      final junk = File('${dir.path}/junk.jpg')..writeAsStringSync('not jpeg');
      expect(await readImageSize(junk.path), isNull);
    });
  });
}
