import 'dart:math' as math;

import '../model/ocr_document.dart';
import '../model/parsed_receipt.dart';

/// Rebuilds the printed rows of a receipt from OCR lines.
///
/// OCR engines often return a row in pieces (the item name in one block, its
/// price in another) and in block order rather than row order. With boxes,
/// lines whose vertical extent overlaps a row by more than half of the smaller
/// height join that row; each row is then sorted left to right and its parts
/// are joined with two spaces. Without boxes, every line is a row.
final class RowBuilder {
  const RowBuilder();

  List<ReceiptRowText> build(OcrDocument document) {
    final lines = [
      for (final l in document.lines)
        if (l.text.trim().isNotEmpty) l,
    ];
    if (!document.hasLayout || lines.isEmpty) {
      return [
        for (final (i, l) in lines.indexed) ReceiptRowText(i, l.text.trim()),
      ];
    }

    final sorted = [...lines]
      ..sort((a, b) => a.box!.centerY.compareTo(b.box!.centerY));
    final rows = <_Row>[];
    for (final line in sorted) {
      final box = line.box!;
      _Row? best;
      var bestOverlap = 0.0;
      // Only the last few rows can overlap: lines are sorted by centre.
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
    return [for (final (i, r) in rows.indexed) r.toRowText(i)];
  }
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

  /// Overlap of [box] with this row's running baseline, as a share of the
  /// smaller height. Comparing against the running mean (not the union)
  /// tolerates slight skew without swallowing the next row.
  double overlapRatio(BoxRect box) {
    final overlap = math.min(bottom, box.bottom) - math.max(top, box.top);
    final smaller = math.min(bottom - top, box.height);
    if (overlap <= 0 || smaller <= 0) return 0;
    return overlap / smaller;
  }

  ReceiptRowText toRowText(int index) {
    final ordered = [..._lines]
      ..sort((a, b) => a.box!.left.compareTo(b.box!.left));
    final heights = [for (final l in _lines) l.box!.height]..sort();
    return ReceiptRowText(
      index,
      ordered.map((l) => l.text.trim()).join('  '),
      height: heights.last,
    );
  }
}
