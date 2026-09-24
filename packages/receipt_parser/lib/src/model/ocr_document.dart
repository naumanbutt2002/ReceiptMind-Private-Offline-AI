import 'dart:convert';
import 'dart:math' as math;

/// An axis-aligned box in image pixels (origin top-left).
final class BoxRect {
  const BoxRect(this.left, this.top, this.right, this.bottom);

  factory BoxRect.fromJson(Map<String, Object?> json) => BoxRect(
    _num(json['left']),
    _num(json['top']),
    _num(json['right']),
    _num(json['bottom']),
  );

  final double left;
  final double top;
  final double right;
  final double bottom;

  double get width => right - left;
  double get height => bottom - top;
  double get centerY => (top + bottom) / 2;

  /// Height of the vertical band that this box shares with [other] (0 when
  /// they don't overlap).
  double verticalOverlap(BoxRect other) =>
      math.max(0, math.min(bottom, other.bottom) - math.max(top, other.top));

  Map<String, Object?> toJson() => {
    'left': left,
    'top': top,
    'right': right,
    'bottom': bottom,
  };

  @override
  bool operator ==(Object other) =>
      other is BoxRect &&
      other.left == left &&
      other.top == top &&
      other.right == right &&
      other.bottom == bottom;

  @override
  int get hashCode => Object.hash(left, top, right, bottom);

  @override
  String toString() => 'BoxRect($left, $top, $right, $bottom)';
}

/// One recognised word, when the OCR engine reports words.
final class OcrWord {
  const OcrWord(this.text, {this.box, this.confidence});

  factory OcrWord.fromJson(Map<String, Object?> json) => OcrWord(
    json['text']! as String,
    box: _box(json['box']),
    confidence: (json['confidence'] as num?)?.toDouble(),
  );

  final String text;
  final BoxRect? box;
  final double? confidence;

  Map<String, Object?> toJson() => {
    'text': text,
    if (box != null) 'box': box!.toJson(),
    if (confidence != null) 'confidence': confidence,
  };
}

/// One line of text as the OCR engine returned it. A printed receipt row is
/// often split into several lines (item on the left, price on the right).
final class OcrLine {
  const OcrLine(this.text, {this.box, this.words = const [], this.angle});

  factory OcrLine.fromJson(Map<String, Object?> json) => OcrLine(
    json['text']! as String,
    box: _box(json['box']),
    words: [
      for (final w in (json['words'] as List<Object?>?) ?? const <Object?>[])
        OcrWord.fromJson(w! as Map<String, Object?>),
    ],
    angle: (json['angle'] as num?)?.toDouble(),
  );

  final String text;
  final BoxRect? box;
  final List<OcrWord> words;
  final double? angle;

  Map<String, Object?> toJson() => {
    'text': text,
    if (box != null) 'box': box!.toJson(),
    if (words.isNotEmpty) 'words': [for (final w in words) w.toJson()],
    if (angle != null) 'angle': angle,
  };
}

/// The OCR result for one receipt image, independent of the OCR engine.
final class OcrDocument {
  const OcrDocument({
    required this.lines,
    this.imageWidth,
    this.imageHeight,
    this.engineId = 'unknown',
  });

  /// One line per text line, without layout. Used for `.txt` fixtures and
  /// pasted text.
  factory OcrDocument.fromPlainText(String text, {String engineId = 'text'}) =>
      OcrDocument(
        lines: [
          for (final line in const LineSplitter().convert(text))
            if (line.trim().isNotEmpty) OcrLine(line),
        ],
        engineId: engineId,
      );

  factory OcrDocument.fromJson(Map<String, Object?> json) => OcrDocument(
    lines: [
      for (final l in json['lines']! as List<Object?>)
        OcrLine.fromJson(l! as Map<String, Object?>),
    ],
    imageWidth: json['imageWidth'] as int?,
    imageHeight: json['imageHeight'] as int?,
    engineId: (json['engineId'] as String?) ?? 'unknown',
  );

  /// Lines in the engine's reading order.
  final List<OcrLine> lines;
  final int? imageWidth;
  final int? imageHeight;

  /// Which engine produced this, e.g. `mlkit-latin`.
  final String engineId;

  /// Whether every line has a bounding box, so the layout can be rebuilt.
  bool get hasLayout => lines.isNotEmpty && lines.every((l) => l.box != null);

  /// All text in reading order, one line per [OcrLine].
  String get text => lines.map((l) => l.text).join('\n');

  Map<String, Object?> toJson() => {
    'engineId': engineId,
    if (imageWidth != null) 'imageWidth': imageWidth,
    if (imageHeight != null) 'imageHeight': imageHeight,
    'lines': [for (final l in lines) l.toJson()],
  };
}

BoxRect? _box(Object? json) =>
    json == null ? null : BoxRect.fromJson(json as Map<String, Object?>);

double _num(Object? value) => (value! as num).toDouble();
