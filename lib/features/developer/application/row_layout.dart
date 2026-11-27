import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:receipt_parser/receipt_parser.dart';

/// One visual row as the parser's `RowBuilder` groups it, with the boxes of
/// the OCR lines it was built from. [index] matches
/// [ParsedReceipt.rows] and [ParsedField.rowIndex].
@immutable
final class RowLayout {
  const RowLayout({
    required this.index,
    required this.text,
    required this.box,
    required this.lines,
  });

  final int index;

  /// The parts joined left to right with two spaces, as the parser sees it.
  final String text;

  /// Union of the line boxes, in image pixels.
  final BoxRect box;

  /// The OCR lines in this row, left to right.
  final List<OcrLine> lines;
}

/// Groups the lines of [document] into rows the same way the parser's
/// `RowBuilder` does (which only returns the row text), so the OCR debug
/// screen can draw each row's box. Returns an empty list when the document
/// has no boxes.
///
/// Keep in sync with `packages/receipt_parser/lib/src/layout/row_builder.dart`;
/// a test compares both on the layout fixtures.
List<RowLayout> buildRowLayout(OcrDocument document) {
  final lines = [
    for (final l in document.lines)
      if (l.text.trim().isNotEmpty) l,
  ];
  if (!document.hasLayout || lines.isEmpty) return const [];

  final sorted = [...lines]
    ..sort((a, b) => a.box!.centerY.compareTo(b.box!.centerY));
  final rows = <_Row>[];
  for (final line in sorted) {
    final box = line.box!;
    _Row? best;
    var bestOverlap = 0.0;
    for (final row in rows.reversed.take(3)) {
      final overlap = row.overlapRatio(box);
      if (overlap > 0.5 && overlap > bestOverlap) {
        best = row;
        bestOverlap = overlap;
      }
    }
    if (best != null) {
      best.add(line);
    } else {
      rows.add(_Row(line));
    }
  }
  rows.sort((a, b) => a.top.compareTo(b.top));
  return [for (final (i, r) in rows.indexed) r.toLayout(i)];
}

final class _Row {
  _Row(OcrLine first) {
    add(first);
  }

  final List<OcrLine> _lines = [];
  double _topSum = 0;
  double _bottomSum = 0;

  double get top => _topSum / _lines.length;
  double get bottom => _bottomSum / _lines.length;

  void add(OcrLine line) {
    _lines.add(line);
    _topSum += line.box!.top;
    _bottomSum += line.box!.bottom;
  }

  double overlapRatio(BoxRect box) {
    final overlap = math.min(bottom, box.bottom) - math.max(top, box.top);
    final smaller = math.min(bottom - top, box.height);
    if (overlap <= 0 || smaller <= 0) return 0;
    return overlap / smaller;
  }

  RowLayout toLayout(int index) {
    final ordered = [..._lines]
      ..sort((a, b) => a.box!.left.compareTo(b.box!.left));
    final boxes = [for (final l in ordered) l.box!];
    return RowLayout(
      index: index,
      text: ordered.map((l) => l.text.trim()).join('  '),
      box: BoxRect(
        boxes.map((b) => b.left).reduce(math.min),
        boxes.map((b) => b.top).reduce(math.min),
        boxes.map((b) => b.right).reduce(math.max),
        boxes.map((b) => b.bottom).reduce(math.max),
      ),
      lines: List.unmodifiable(ordered),
    );
  }
}
