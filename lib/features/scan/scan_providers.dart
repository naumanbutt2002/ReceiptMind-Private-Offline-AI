import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'capture/cunning_document_scanner_impl.dart';
import 'capture/document_scanner.dart';
import 'ocr/mlkit_ocr_engine.dart';
import 'ocr/ocr_engine.dart';

part 'scan_providers.g.dart';

/// The document scanner. Tests override it with a fake.
@Riverpod(keepAlive: true)
DocumentScanner documentScanner(Ref ref) => CunningDocumentScannerImpl();

/// The OCR engine. Kept alive so ML Kit's recognizer is created once and
/// reused for every scan; closed when the container is disposed.
@Riverpod(keepAlive: true)
OcrEngine ocrEngine(Ref ref) {
  final engine = MlKitOcrEngine();
  ref.onDispose(engine.dispose);
  return engine;
}
