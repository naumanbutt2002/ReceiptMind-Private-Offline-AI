// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'receipts_providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// The app support directory: private storage for the database and receipt
/// images. Tests override it with a temporary directory.

@ProviderFor(appSupportDirectory)
final appSupportDirectoryProvider = AppSupportDirectoryProvider._();

/// The app support directory: private storage for the database and receipt
/// images. Tests override it with a temporary directory.

final class AppSupportDirectoryProvider
    extends
        $FunctionalProvider<
          AsyncValue<Directory>,
          Directory,
          FutureOr<Directory>
        >
    with $FutureModifier<Directory>, $FutureProvider<Directory> {
  /// The app support directory: private storage for the database and receipt
  /// images. Tests override it with a temporary directory.
  AppSupportDirectoryProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'appSupportDirectoryProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$appSupportDirectoryHash();

  @$internal
  @override
  $FutureProviderElement<Directory> $createElement($ProviderPointer pointer) =>
      $FutureProviderElement(pointer);

  @override
  FutureOr<Directory> create(Ref ref) {
    return appSupportDirectory(ref);
  }
}

String _$appSupportDirectoryHash() =>
    r'6bd47f5887148d00c61ee7e80d0632e5d74b1eb2';

@ProviderFor(receiptImageStore)
final receiptImageStoreProvider = ReceiptImageStoreProvider._();

final class ReceiptImageStoreProvider
    extends
        $FunctionalProvider<
          ReceiptImageStore,
          ReceiptImageStore,
          ReceiptImageStore
        >
    with $Provider<ReceiptImageStore> {
  ReceiptImageStoreProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'receiptImageStoreProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$receiptImageStoreHash();

  @$internal
  @override
  $ProviderElement<ReceiptImageStore> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  ReceiptImageStore create(Ref ref) {
    return receiptImageStore(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(ReceiptImageStore value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<ReceiptImageStore>(value),
    );
  }
}

String _$receiptImageStoreHash() => r'e636da4274da1716efe3744e0c7d0c511a29f6ee';

@ProviderFor(receiptRepository)
final receiptRepositoryProvider = ReceiptRepositoryProvider._();

final class ReceiptRepositoryProvider
    extends
        $FunctionalProvider<
          ReceiptRepository,
          ReceiptRepository,
          ReceiptRepository
        >
    with $Provider<ReceiptRepository> {
  ReceiptRepositoryProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'receiptRepositoryProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$receiptRepositoryHash();

  @$internal
  @override
  $ProviderElement<ReceiptRepository> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  ReceiptRepository create(Ref ref) {
    return receiptRepository(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(ReceiptRepository value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<ReceiptRepository>(value),
    );
  }
}

String _$receiptRepositoryHash() => r'd22167888fbf44c738953de101437f82e4756167';
