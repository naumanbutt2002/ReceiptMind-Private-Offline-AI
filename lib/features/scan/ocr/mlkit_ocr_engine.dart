import 'dart:developer' as developer;
import 'dart:ui' as ui;

import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:receipt_parser/receipt_parser.dart';

import 'ocr_engine.dart';

/// [OcrEngine] backed by Google ML Kit's on-device Latin text recognizer.
/// The model ships inside the app, so nothing is downloaded.
final class MlKitOcrEngine implements OcrEngine {
  MlKitOcrEngine();

  static const engineId = 'mlkit-latin';

  TextRecognizer? _recognizer;

  @override
  String get id => engineId;

  @override
  Future<OcrDocument> recognize(String imagePath) async {
    final recognizer = _recognizer ??= TextRecognizer(
      script: TextRecognitionScript.latin,
    );
    final (text, size) = await (
      recognizer.processImage(InputImage.fromFilePath(imagePath)),
      readImageSize(imagePath),
    ).wait;
    return ocrDocumentFromRecognizedText(
      text,
      imageWidth: size?.width,
      imageHeight: size?.height,
    );
  }

  @override
  Future<void> dispose() async {
    final recognizer = _recognizer;
    _recognizer = null;
    await recognizer?.close();
  }
}

/// Converts ML Kit's result into an [OcrDocument]: every [TextLine] becomes an
/// [OcrLine] and every [TextElement] an [OcrWord], keeping ML Kit's reading
/// order (blocks in order, lines in order). Boxes are in image pixels. Line
/// angles and word confidences are only reported on Android. Blank lines are
/// dropped, so an image without text gives a document with no lines.
OcrDocument ocrDocumentFromRecognizedText(
  RecognizedText text, {
  int? imageWidth,
  int? imageHeight,
  String engineId = MlKitOcrEngine.engineId,
}) => OcrDocument(
  lines: [
    for (final block in text.blocks)
      for (final line in block.lines)
        if (line.text.trim().isNotEmpty)
          OcrLine(
            line.text,
            box: _box(line.boundingBox),
            angle: line.angle,
            words: [
              for (final element in line.elements)
                if (element.text.trim().isNotEmpty)
                  OcrWord(
                    element.text,
                    box: _box(element.boundingBox),
                    confidence: element.confidence,
                  ),
            ],
          ),
  ],
  imageWidth: imageWidth,
  imageHeight: imageHeight,
  engineId: engineId,
);

/// Width and height of the image at [path], read from the encoded header
/// without decoding the pixels. `null` when the file can't be read or isn't
/// an image format Flutter knows.
Future<({int width, int height})?> readImageSize(String path) async {
  ui.ImmutableBuffer? buffer;
  ui.ImageDescriptor? descriptor;
  try {
    buffer = await ui.ImmutableBuffer.fromFilePath(path);
    descriptor = await ui.ImageDescriptor.encoded(buffer);
    return (width: descriptor.width, height: descriptor.height);
  } on Object catch (e) {
    developer.log(
      'Could not read the image size of $path',
      name: 'ocr',
      error: e,
    );
    return null;
  } finally {
    descriptor?.dispose();
    buffer?.dispose();
  }
}

BoxRect _box(ui.Rect rect) =>
    BoxRect(rect.left, rect.top, rect.right, rect.bottom);
