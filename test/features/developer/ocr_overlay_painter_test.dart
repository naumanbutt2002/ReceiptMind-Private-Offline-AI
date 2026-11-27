import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:receipt_mind/features/developer/application/row_layout.dart';
import 'package:receipt_mind/features/developer/presentation/ocr_overlay_painter.dart';
import 'package:receipt_parser/receipt_parser.dart';

import 'dev_test_helpers.dart';

void main() {
  group('ContainMapping', () {
    test('a tall image in a wide view gets bars left and right', () {
      // 1000×2000 image in a 600×400 view: scale 0.2, image 200×400.
      final map = ContainMapping.fit(
        const Size(1000, 2000),
        const Size(600, 400),
      );
      expect(map.scale, 0.2);
      expect(map.offset, const Offset(200, 0));
      expect(map.imageRect, const Rect.fromLTWH(200, 0, 200, 400));
      expect(map.mapPoint(0, 0), const Offset(200, 0));
      expect(map.mapPoint(1000, 2000), const Offset(400, 400));
      expect(
        map.mapBox(const BoxRect(100, 500, 600, 750)),
        const Rect.fromLTRB(220, 100, 320, 150),
      );
    });

    test('a wide image in a tall view gets bars top and bottom', () {
      // 800×400 image in a 400×600 view: scale 0.5, image 400×200.
      final map = ContainMapping.fit(
        const Size(800, 400),
        const Size(400, 600),
      );
      expect(map.scale, 0.5);
      expect(map.offset, const Offset(0, 200));
      expect(
        map.mapBox(const BoxRect(0, 0, 800, 400)),
        const Rect.fromLTWH(0, 200, 400, 200),
      );
      expect(map.mapPoint(400, 200), const Offset(200, 300));
    });

    test('same aspect ratio fills the view', () {
      final map = ContainMapping.fit(
        const Size(100, 200),
        const Size(300, 600),
      );
      expect(map.scale, 3);
      expect(map.offset, Offset.zero);
    });

    test('an empty image or view maps nothing', () {
      expect(ContainMapping.fit(Size.zero, const Size(10, 10)).scale, 0);
      expect(ContainMapping.fit(const Size(10, 10), Size.zero).scale, 0);
    });
  });

  test('boxExtent covers every line box', () {
    const document = OcrDocument(
      lines: [
        OcrLine('A', box: BoxRect(10, 10, 300, 40)),
        OcrLine('B', box: BoxRect(50, 900, 120, 950)),
      ],
    );
    expect(boxExtent(document), const Size(300, 950));
  });

  test('paints every layer without throwing', () {
    final document = layoutFixture('au/au_fuel_01');
    final rows = buildRowLayout(document);
    final painter = OcrOverlayPainter(
      document: document,
      rows: rows,
      imageSize: const Size(1000, 1500),
      layers: OverlayLayer.values.toSet(),
      fieldRows: const {ReceiptField.total: 3, ReceiptField.date: 99},
    );
    final recorder = ui.PictureRecorder();
    painter.paint(Canvas(recorder), const Size(400, 800));
    recorder.endRecording().dispose();

    expect(
      painter.shouldRepaint(
        OcrOverlayPainter(
          document: document,
          rows: rows,
          imageSize: const Size(1000, 1500),
          layers: OverlayLayer.values.toSet(),
          fieldRows: const {ReceiptField.total: 3, ReceiptField.date: 99},
        ),
      ),
      isFalse,
    );
    expect(
      painter.shouldRepaint(
        OcrOverlayPainter(
          document: document,
          rows: rows,
          imageSize: const Size(1000, 1500),
          layers: {OverlayLayer.lines},
          fieldRows: const {ReceiptField.total: 3, ReceiptField.date: 99},
        ),
      ),
      isTrue,
    );
  });

  test('field colours: total is green', () {
    final total = fieldColor(ReceiptField.total);
    expect(total.g, greaterThan(total.r));
    expect(total.g, greaterThan(total.b));
    expect(rowColor(0), rowColor(8));
  });
}
