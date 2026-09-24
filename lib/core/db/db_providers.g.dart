// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'db_providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(appDatabase)
final appDatabaseProvider = AppDatabaseProvider._();

final class AppDatabaseProvider
    extends $FunctionalProvider<AppDatabase, AppDatabase, AppDatabase>
    with $Provider<AppDatabase> {
  AppDatabaseProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'appDatabaseProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$appDatabaseHash();

  @$internal
  @override
  $ProviderElement<AppDatabase> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  AppDatabase create(Ref ref) {
    return appDatabase(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(AppDatabase value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<AppDatabase>(value),
    );
  }
}

String _$appDatabaseHash() => r'365ef3f215d780c29a21b6328f0b547a8363c6a6';

@ProviderFor(receiptsDao)
final receiptsDaoProvider = ReceiptsDaoProvider._();

final class ReceiptsDaoProvider
    extends $FunctionalProvider<ReceiptsDao, ReceiptsDao, ReceiptsDao>
    with $Provider<ReceiptsDao> {
  ReceiptsDaoProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'receiptsDaoProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$receiptsDaoHash();

  @$internal
  @override
  $ProviderElement<ReceiptsDao> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  ReceiptsDao create(Ref ref) {
    return receiptsDao(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(ReceiptsDao value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<ReceiptsDao>(value),
    );
  }
}

String _$receiptsDaoHash() => r'7ee446eacc3de5220b5ed3241578c1b12d187482';

@ProviderFor(categoriesDao)
final categoriesDaoProvider = CategoriesDaoProvider._();

final class CategoriesDaoProvider
    extends $FunctionalProvider<CategoriesDao, CategoriesDao, CategoriesDao>
    with $Provider<CategoriesDao> {
  CategoriesDaoProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'categoriesDaoProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$categoriesDaoHash();

  @$internal
  @override
  $ProviderElement<CategoriesDao> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  CategoriesDao create(Ref ref) {
    return categoriesDao(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(CategoriesDao value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<CategoriesDao>(value),
    );
  }
}

String _$categoriesDaoHash() => r'6f72140ca78feaf8e1a0407822e2bbe870a39e92';

/// Number of categories, shown in Settings.

@ProviderFor(categoryCount)
final categoryCountProvider = CategoryCountProvider._();

/// Number of categories, shown in Settings.

final class CategoryCountProvider
    extends $FunctionalProvider<AsyncValue<int>, int, Stream<int>>
    with $FutureModifier<int>, $StreamProvider<int> {
  /// Number of categories, shown in Settings.
  CategoryCountProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'categoryCountProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$categoryCountHash();

  @$internal
  @override
  $StreamProviderElement<int> $createElement($ProviderPointer pointer) =>
      $StreamProviderElement(pointer);

  @override
  Stream<int> create(Ref ref) {
    return categoryCount(ref);
  }
}

String _$categoryCountHash() => r'e5ee4fc66b9ee109d79fc83235c8a4f8c487f20a';
