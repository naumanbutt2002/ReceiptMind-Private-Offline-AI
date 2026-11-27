// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'scan_controller.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Runs one scan: scanner → OCR → rule parser → validator → [ScanReview].
///
/// Kept alive so the draft survives navigation to the review screen and
/// back. Automatic retry is off: a failed scan or OCR run must never be
/// started again without the user asking.

@ProviderFor(ScanController)
final scanControllerProvider = ScanControllerProvider._();

/// Runs one scan: scanner → OCR → rule parser → validator → [ScanReview].
///
/// Kept alive so the draft survives navigation to the review screen and
/// back. Automatic retry is off: a failed scan or OCR run must never be
/// started again without the user asking.
final class ScanControllerProvider
    extends $NotifierProvider<ScanController, ScanState> {
  /// Runs one scan: scanner → OCR → rule parser → validator → [ScanReview].
  ///
  /// Kept alive so the draft survives navigation to the review screen and
  /// back. Automatic retry is off: a failed scan or OCR run must never be
  /// started again without the user asking.
  ScanControllerProvider._()
    : super(
        from: null,
        argument: null,
        retry: _noRetry,
        name: r'scanControllerProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$scanControllerHash();

  @$internal
  @override
  ScanController create() => ScanController();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(ScanState value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<ScanState>(value),
    );
  }
}

String _$scanControllerHash() => r'6c4bc106e8f0fa58a55ac23dac4c9c83b76c92c3';

/// Runs one scan: scanner → OCR → rule parser → validator → [ScanReview].
///
/// Kept alive so the draft survives navigation to the review screen and
/// back. Automatic retry is off: a failed scan or OCR run must never be
/// started again without the user asking.

abstract class _$ScanController extends $Notifier<ScanState> {
  ScanState build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<ScanState, ScanState>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<ScanState, ScanState>,
              ScanState,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}

/// How [ScanController] parses: [parseInBackground]. Tests override it, e.g.
/// to simulate a parser bug.

@ProviderFor(receiptParse)
final receiptParseProvider = ReceiptParseProvider._();

/// How [ScanController] parses: [parseInBackground]. Tests override it, e.g.
/// to simulate a parser bug.

final class ReceiptParseProvider
    extends $FunctionalProvider<ReceiptParseFn, ReceiptParseFn, ReceiptParseFn>
    with $Provider<ReceiptParseFn> {
  /// How [ScanController] parses: [parseInBackground]. Tests override it, e.g.
  /// to simulate a parser bug.
  ReceiptParseProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'receiptParseProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$receiptParseHash();

  @$internal
  @override
  $ProviderElement<ReceiptParseFn> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  ReceiptParseFn create(Ref ref) {
    return receiptParse(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(ReceiptParseFn value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<ReceiptParseFn>(value),
    );
  }
}

String _$receiptParseHash() => r'f812ed69098bdd7c971516ed6255b671152e18ff';
