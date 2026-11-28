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
///
/// A photo is rarely perfectly level: on a receipt turned by 1.5°, a price at
/// the right edge sits 15 px above or below its label, and a long line's box
/// is taller than its text. So the boxes are first de-skewed by the
/// receipt's dominant text angle ([skewDegrees]): each box moves vertically
/// by `tan(skew) · x` and loses the height the slant added, before rows are
/// grouped and measured.
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

    final slope = math.tan(skewDegrees(lines) * math.pi / 180);
    final placed = [for (final l in lines) _Placed(l, _deskew(l.box!, slope))]
      ..sort((a, b) => a.box.centerY.compareTo(b.box.centerY));
    final rows = <_Row>[];
    for (final line in placed) {
      final box = line.box;
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

  /// Skews smaller than this are treated as level.
  static const _minSkew = 0.2;

  /// Skews larger than this are not corrected: the scanner straightens real
  /// receipts, so a bigger angle is more likely rotated text (a vertical
  /// side note) than a turned receipt.
  static const _maxSkew = 10.0;

  /// The receipt's dominant text angle in degrees (positive: text runs down
  /// to the right, in image coordinates), or 0 when it can't be told or is
  /// negligible. Uses the engine's line angles when at least three lines
  /// have one (ML Kit on Android); otherwise the slope between the first and
  /// last word of lines that have several words with boxes.
  static double skewDegrees(List<OcrLine> lines) {
    final angles = [for (final l in lines) ?l.angle];
    if (angles.length < 3) {
      angles
        ..clear()
        ..addAll(lines.map(_wordSlopeDegrees).nonNulls);
    }
    if (angles.length < 3) return 0;
    angles.sort();
    final median = angles[angles.length ~/ 2];
    final size = median.abs();
    return size < _minSkew || size > _maxSkew ? 0 : median;
  }

  static double? _wordSlopeDegrees(OcrLine line) {
    final words = [for (final w in line.words) ?w.box];
    if (words.length < 2) return null;
    final first = words.first;
    final last = words.last;
    final dx = (last.left + last.right) / 2 - (first.left + first.right) / 2;
    // A short baseline gives a noisy angle.
    if (dx < 4 * first.height) return null;
    return math.atan2(last.centerY - first.centerY, dx) * 180 / math.pi;
  }

  /// [box] moved onto a level baseline: shifted by the skew at its centre
  /// and shrunk by the height the slant adds over its width (never below
  /// half its height).
  static BoxRect _deskew(BoxRect box, double slope) {
    if (slope == 0) return box;
    final centerX = (box.left + box.right) / 2;
    final centerY = box.centerY - slope * centerX;
    final height = math.max(
      box.height - box.width * slope.abs(),
      box.height / 2,
    );
    return BoxRect(
      box.left,
      centerY - height / 2,
      box.right,
      centerY + height / 2,
    );
  }
}

/// An OCR line with its de-skewed box.
final class _Placed {
  const _Placed(this.line, this.box);

  final OcrLine line;
  final BoxRect box;
}

final class _Row {
  _Row(_Placed first) {
    add(first);
  }

  final List<_Placed> _lines = [];
  double _topSum = 0;
  double _bottomSum = 0;

  double get top => _topSum / _lines.length;
  double get bottom => _bottomSum / _lines.length;

  void add(_Placed line) {
    _lines.add(line);
    _topSum += line.box.top;
    _bottomSum += line.box.bottom;
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
      ..sort((a, b) => a.box.left.compareTo(b.box.left));
    final heights = [for (final l in _lines) l.box.height]..sort();
    return ReceiptRowText(
      index,
      ordered.map((l) => l.line.text.trim()).join('  '),
      height: heights.last,
    );
  }
}
