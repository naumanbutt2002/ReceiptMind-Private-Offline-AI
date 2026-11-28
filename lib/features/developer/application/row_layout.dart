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

/// The rows of [document] as the parser's [RowBuilder] groups them (it
/// de-skews tilted photos first), with each row's box, so the OCR debug
/// screen can draw them and its row numbers match [ParsedField.rowIndex].
/// Returns an empty list when the document has no boxes.
List<RowLayout> buildRowLayout(OcrDocument document) => [
  for (final (i, lines) in const RowBuilder().rowLines(document).indexed)
    _layout(i, lines),
];

/// [lines] (left to right) as row [index]; the box is the union of the
/// lines' original boxes, as drawn on the photo.
RowLayout _layout(int index, List<OcrLine> lines) {
  final boxes = [for (final l in lines) l.box!];
  return RowLayout(
    index: index,
    text: lines.map((l) => l.text.trim()).join('  '),
    box: BoxRect(
      boxes.map((b) => b.left).reduce(math.min),
      boxes.map((b) => b.top).reduce(math.min),
      boxes.map((b) => b.right).reduce(math.max),
      boxes.map((b) => b.bottom).reduce(math.max),
    ),
    lines: List.unmodifiable(lines),
  );
}
