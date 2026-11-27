// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'scan_providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// The document scanner. Tests override it with a fake.

@ProviderFor(documentScanner)
final documentScannerProvider = DocumentScannerProvider._();

/// The document scanner. Tests override it with a fake.

final class DocumentScannerProvider
    extends
        $FunctionalProvider<DocumentScanner, DocumentScanner, DocumentScanner>
    with $Provider<DocumentScanner> {
  /// The document scanner. Tests override it with a fake.
  DocumentScannerProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'documentScannerProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$documentScannerHash();

  @$internal
  @override
  $ProviderElement<DocumentScanner> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  DocumentScanner create(Ref ref) {
    return documentScanner(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(DocumentScanner value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<DocumentScanner>(value),
    );
  }
}

String _$documentScannerHash() => r'ca95aceec18519e6059477afbe4eb39e200d445b';

/// The OCR engine. Kept alive so ML Kit's recognizer is created once and
/// reused for every scan; closed when the container is disposed.

@ProviderFor(ocrEngine)
final ocrEngineProvider = OcrEngineProvider._();

/// The OCR engine. Kept alive so ML Kit's recognizer is created once and
/// reused for every scan; closed when the container is disposed.

final class OcrEngineProvider
    extends $FunctionalProvider<OcrEngine, OcrEngine, OcrEngine>
    with $Provider<OcrEngine> {
  /// The OCR engine. Kept alive so ML Kit's recognizer is created once and
  /// reused for every scan; closed when the container is disposed.
  OcrEngineProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'ocrEngineProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$ocrEngineHash();

  @$internal
  @override
  $ProviderElement<OcrEngine> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  OcrEngine create(Ref ref) {
    return ocrEngine(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(OcrEngine value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<OcrEngine>(value),
    );
  }
}

String _$ocrEngineHash() => r'cc07bcc5e30d068292bcb20249b79d7bff9cef82';
