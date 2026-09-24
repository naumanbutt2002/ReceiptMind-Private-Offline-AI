import 'package:receipt_parser/receipt_parser.dart';
import 'package:test/test.dart';

void main() {
  test('fromPlainText keeps one line per non-blank text line', () {
    final doc = OcrDocument.fromPlainText('COLES\n\n  \nTOTAL 12.50\r\nVISA');
    expect(doc.lines.map((l) => l.text), ['COLES', 'TOTAL 12.50', 'VISA']);
    expect(doc.hasLayout, isFalse);
    expect(doc.engineId, 'text');
  });

  test('JSON round trip keeps boxes, words and image size', () {
    const doc = OcrDocument(
      engineId: 'mlkit-latin',
      imageWidth: 1000,
      imageHeight: 2000,
      lines: [
        OcrLine(
          'TOTAL',
          box: BoxRect(10, 20, 110, 60),
          words: [
            OcrWord('TOTAL', box: BoxRect(10, 20, 110, 60), confidence: 0.9),
          ],
        ),
        OcrLine('12.50', box: BoxRect(800, 22, 900, 62), angle: 1.5),
      ],
    );
    final copy = OcrDocument.fromJson(doc.toJson());
    expect(copy.engineId, 'mlkit-latin');
    expect(copy.imageWidth, 1000);
    expect(copy.hasLayout, isTrue);
    expect(copy.lines.first.box, const BoxRect(10, 20, 110, 60));
    expect(copy.lines.first.words.single.confidence, 0.9);
    expect(copy.lines.last.angle, 1.5);
    expect(copy.text, 'TOTAL\n12.50');
  });

  test('BoxRect geometry', () {
    const a = BoxRect(0, 10, 100, 50);
    const b = BoxRect(200, 30, 300, 70);
    expect(a.height, 40);
    expect(a.width, 100);
    expect(a.centerY, 30);
    expect(a.verticalOverlap(b), 20);
    expect(a.verticalOverlap(const BoxRect(0, 60, 10, 80)), 0);
  });
}
