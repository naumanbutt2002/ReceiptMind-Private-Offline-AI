import 'package:receipt_parser/receipt_parser.dart';

export 'package:receipt_parser/receipt_parser.dart' show OcrDocument;

/// Reads the text of a receipt image on the device. ML Kit in v0.1; a
/// Tesseract engine can be added for a FOSS build. Tests use a fake.
abstract interface class OcrEngine {
  /// Stable id stored with fixtures, e.g. `mlkit-latin`.
  String get id;

  /// Recognises text in the image at [imagePath] (JPEG or PNG). Returns a
  /// document with no lines when the image has no text. Throws on failure.
  Future<OcrDocument> recognize(String imagePath);

  Future<void> dispose();
}
