import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:receipt_parser/receipt_parser.dart';

import '../application/row_layout.dart';

/// Maps image pixels to a view that shows the whole image with
/// [BoxFit.contain]: scaled uniformly and centred, with letterbox bars on the
/// sides or at the top and bottom.
@immutable
final class ContainMapping {
  const ContainMapping._(this.scale, this.offset, this.imageSize);

  factory ContainMapping.fit(Size imageSize, Size viewSize) {
    if (imageSize.isEmpty || viewSize.isEmpty) {
      return ContainMapping._(0, Offset.zero, imageSize);
    }
    final scale = math.min(
      viewSize.width / imageSize.width,
      viewSize.height / imageSize.height,
    );
    return ContainMapping._(
      scale,
      Offset(
        (viewSize.width - imageSize.width * scale) / 2,
        (viewSize.height - imageSize.height * scale) / 2,
      ),
      imageSize,
    );
  }

  /// View pixels per image pixel.
  final double scale;

  /// Top-left corner of the image in the view.
  final Offset offset;
  final Size imageSize;

  Offset mapPoint(double x, double y) =>
      Offset(offset.dx + x * scale, offset.dy + y * scale);

  Rect mapBox(BoxRect box) => Rect.fromPoints(
    mapPoint(box.left, box.top),
    mapPoint(box.right, box.bottom),
  );

  /// Where the image itself sits in the view.
  Rect get imageRect => offset & imageSize * scale;

  @override
  bool operator ==(Object other) =>
      other is ContainMapping &&
      other.scale == scale &&
      other.offset == offset &&
      other.imageSize == imageSize;

  @override
  int get hashCode => Object.hash(scale, offset, imageSize);
}

/// What the overlay draws.
enum OverlayLayer { lines, words, rows, fields }

/// Colour used for [field] on the overlay and in the field list.
Color fieldColor(ReceiptField field) => switch (field) {
  ReceiptField.total => const Color(0xFF2E7D32),
  ReceiptField.date => const Color(0xFF1565C0),
  ReceiptField.merchant => const Color(0xFF6A1B9A),
  ReceiptField.subtotal => const Color(0xFF00838F),
  ReceiptField.tax => const Color(0xFFEF6C00),
  ReceiptField.tip => const Color(0xFFAD1457),
  ReceiptField.currency => const Color(0xFF5D4037),
  ReceiptField.paymentMethod => const Color(0xFF283593),
};

/// Colour of row [index]: a fixed cycle of distinct hues.
Color rowColor(int index) => _rowPalette[index % _rowPalette.length];

const _rowPalette = [
  Color(0xFFE53935),
  Color(0xFF1E88E5),
  Color(0xFF43A047),
  Color(0xFFFB8C00),
  Color(0xFF8E24AA),
  Color(0xFF00ACC1),
  Color(0xFFC0CA33),
  Color(0xFF6D4C41),
];

/// Draws OCR boxes over a receipt photo shown with [BoxFit.contain]. Boxes
/// are in image pixels ([imageSize]) and scaled to the paint size.
class OcrOverlayPainter extends CustomPainter {
  OcrOverlayPainter({
    required this.document,
    required this.rows,
    required this.imageSize,
    required this.layers,
    this.fieldRows = const {},
    this.textDirection = TextDirection.ltr,
  });

  final OcrDocument document;
  final List<RowLayout> rows;
  final Size imageSize;
  final Set<OverlayLayer> layers;

  /// Row index the parser read each field from.
  final Map<ReceiptField, int> fieldRows;
  final TextDirection textDirection;

  @override
  void paint(Canvas canvas, Size size) {
    final map = ContainMapping.fit(imageSize, size);
    if (map.scale == 0) return;
    canvas.save();
    canvas.clipRect(map.imageRect);

    if (layers.contains(OverlayLayer.rows)) {
      for (final row in rows) {
        final color = rowColor(row.index);
        final rect = map.mapBox(row.box);
        canvas
          ..drawRect(rect, Paint()..color = color.withValues(alpha: 0.15))
          ..drawRect(
            rect,
            Paint()
              ..color = color
              ..style = PaintingStyle.stroke
              ..strokeWidth = 1,
          );
        _label(canvas, '${row.index}', rect.topLeft, color);
      }
    }

    if (layers.contains(OverlayLayer.lines)) {
      final paint = Paint()
        ..color = const Color(0xCCFFC107)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5;
      for (final line in document.lines) {
        final box = line.box;
        if (box != null) canvas.drawRect(map.mapBox(box), paint);
      }
    }

    if (layers.contains(OverlayLayer.words)) {
      final paint = Paint()
        ..color = const Color(0xCC00BCD4)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.75;
      for (final line in document.lines) {
        for (final word in line.words) {
          final box = word.box;
          if (box != null) canvas.drawRect(map.mapBox(box), paint);
        }
      }
    }

    if (layers.contains(OverlayLayer.fields)) {
      final byIndex = {for (final r in rows) r.index: r};
      for (final MapEntry(key: field, value: index) in fieldRows.entries) {
        final row = byIndex[index];
        if (row == null) continue;
        final color = fieldColor(field);
        final rect = map.mapBox(row.box).inflate(2);
        canvas.drawRect(
          rect,
          Paint()
            ..color = color
            ..style = PaintingStyle.stroke
            ..strokeWidth = 3,
        );
        _label(canvas, field.name, rect.topRight, color, alignRight: true);
      }
    }
    canvas.restore();
  }

  /// A small filled tag with [text]; left of [anchor] when [alignRight].
  void _label(
    Canvas canvas,
    String text,
    Offset anchor,
    Color color, {
    bool alignRight = false,
  }) {
    final painter = TextPainter(
      text: TextSpan(
        text: text,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 9,
          fontWeight: FontWeight.w600,
        ),
      ),
      textDirection: textDirection,
    )..layout();
    final origin = alignRight
        ? anchor - Offset(painter.width + 4, 0)
        : anchor + const Offset(2, 0);
    canvas.drawRect(
      origin & Size(painter.width + 2, painter.height),
      Paint()..color = color,
    );
    painter
      ..paint(canvas, origin + const Offset(1, 0))
      ..dispose();
  }

  @override
  bool shouldRepaint(OcrOverlayPainter oldDelegate) =>
      oldDelegate.document != document ||
      oldDelegate.rows != rows ||
      oldDelegate.imageSize != imageSize ||
      !_sameSet(oldDelegate.layers, layers) ||
      !_sameMap(oldDelegate.fieldRows, fieldRows);

  static bool _sameSet<T>(Set<T> a, Set<T> b) =>
      a.length == b.length && a.containsAll(b);

  static bool _sameMap<K, V>(Map<K, V> a, Map<K, V> b) =>
      a.length == b.length && a.entries.every((e) => b[e.key] == e.value);
}

/// Pixel size of the area the boxes of [document] cover, used when the image
/// size is unknown.
Size boxExtent(OcrDocument document) {
  var right = 0.0;
  var bottom = 0.0;
  for (final line in document.lines) {
    final box = line.box;
    if (box == null) continue;
    right = math.max(right, box.right);
    bottom = math.max(bottom, box.bottom);
  }
  return Size(right, bottom);
}
