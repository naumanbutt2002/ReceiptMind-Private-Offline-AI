// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'receipt_photo_sharer.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(receiptPhotoSharer)
final receiptPhotoSharerProvider = ReceiptPhotoSharerProvider._();

final class ReceiptPhotoSharerProvider
    extends
        $FunctionalProvider<
          ReceiptPhotoSharer,
          ReceiptPhotoSharer,
          ReceiptPhotoSharer
        >
    with $Provider<ReceiptPhotoSharer> {
  ReceiptPhotoSharerProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'receiptPhotoSharerProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$receiptPhotoSharerHash();

  @$internal
  @override
  $ProviderElement<ReceiptPhotoSharer> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  ReceiptPhotoSharer create(Ref ref) {
    return receiptPhotoSharer(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(ReceiptPhotoSharer value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<ReceiptPhotoSharer>(value),
    );
  }
}

String _$receiptPhotoSharerHash() =>
    r'2ed07e2414636f8128d682734bd5c2cda5bdbe27';
