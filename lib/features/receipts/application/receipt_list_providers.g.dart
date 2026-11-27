// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'receipt_list_providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// The list's current search and category filter.

@ProviderFor(ReceiptListFilterController)
final receiptListFilterControllerProvider =
    ReceiptListFilterControllerProvider._();

/// The list's current search and category filter.
final class ReceiptListFilterControllerProvider
    extends $NotifierProvider<ReceiptListFilterController, ReceiptListFilter> {
  /// The list's current search and category filter.
  ReceiptListFilterControllerProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'receiptListFilterControllerProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$receiptListFilterControllerHash();

  @$internal
  @override
  ReceiptListFilterController create() => ReceiptListFilterController();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(ReceiptListFilter value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<ReceiptListFilter>(value),
    );
  }
}

String _$receiptListFilterControllerHash() =>
    r'7fdd5319e4581241aac2ad1669b572c9781525b1';

/// The list's current search and category filter.

abstract class _$ReceiptListFilterController
    extends $Notifier<ReceiptListFilter> {
  ReceiptListFilter build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<ReceiptListFilter, ReceiptListFilter>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<ReceiptListFilter, ReceiptListFilter>,
              ReceiptListFilter,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}

/// The first day of the current month (from [clockProvider]). The list
/// invalidates it when the app comes back to the foreground, so the month
/// card moves on after midnight at the end of a month.

@ProviderFor(currentMonth)
final currentMonthProvider = CurrentMonthProvider._();

/// The first day of the current month (from [clockProvider]). The list
/// invalidates it when the app comes back to the foreground, so the month
/// card moves on after midnight at the end of a month.

final class CurrentMonthProvider
    extends $FunctionalProvider<LocalDate, LocalDate, LocalDate>
    with $Provider<LocalDate> {
  /// The first day of the current month (from [clockProvider]). The list
  /// invalidates it when the app comes back to the foreground, so the month
  /// card moves on after midnight at the end of a month.
  CurrentMonthProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'currentMonthProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$currentMonthHash();

  @$internal
  @override
  $ProviderElement<LocalDate> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  LocalDate create(Ref ref) {
    return currentMonth(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(LocalDate value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<LocalDate>(value),
    );
  }
}

String _$currentMonthHash() => r'7ff28ee89ecc6b174fc96a9545e9c57c35a1cad7';

/// Totals per currency (minor units) of every receipt in the current month,
/// whatever the list filter is.

@ProviderFor(currentMonthTotals)
final currentMonthTotalsProvider = CurrentMonthTotalsProvider._();

/// Totals per currency (minor units) of every receipt in the current month,
/// whatever the list filter is.

final class CurrentMonthTotalsProvider
    extends
        $FunctionalProvider<
          AsyncValue<Map<String, int>>,
          Map<String, int>,
          Stream<Map<String, int>>
        >
    with $FutureModifier<Map<String, int>>, $StreamProvider<Map<String, int>> {
  /// Totals per currency (minor units) of every receipt in the current month,
  /// whatever the list filter is.
  CurrentMonthTotalsProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'currentMonthTotalsProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$currentMonthTotalsHash();

  @$internal
  @override
  $StreamProviderElement<Map<String, int>> $createElement(
    $ProviderPointer pointer,
  ) => $StreamProviderElement(pointer);

  @override
  Stream<Map<String, int>> create(Ref ref) {
    return currentMonthTotals(ref);
  }
}

String _$currentMonthTotalsHash() =>
    r'efb0705c77fde4cdb7b210f544598570dbf1c7f0';

/// Absolute path of a stored image (or thumbnail) path. Kept for the app's
/// lifetime, so scrolling back to a row never resolves its path again.

@ProviderFor(resolvedImagePath)
final resolvedImagePathProvider = ResolvedImagePathFamily._();

/// Absolute path of a stored image (or thumbnail) path. Kept for the app's
/// lifetime, so scrolling back to a row never resolves its path again.

final class ResolvedImagePathProvider
    extends $FunctionalProvider<AsyncValue<String>, String, FutureOr<String>>
    with $FutureModifier<String>, $FutureProvider<String> {
  /// Absolute path of a stored image (or thumbnail) path. Kept for the app's
  /// lifetime, so scrolling back to a row never resolves its path again.
  ResolvedImagePathProvider._({
    required ResolvedImagePathFamily super.from,
    required String super.argument,
  }) : super(
         retry: null,
         name: r'resolvedImagePathProvider',
         isAutoDispose: false,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$resolvedImagePathHash();

  @override
  String toString() {
    return r'resolvedImagePathProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $FutureProviderElement<String> $createElement($ProviderPointer pointer) =>
      $FutureProviderElement(pointer);

  @override
  FutureOr<String> create(Ref ref) {
    final argument = this.argument as String;
    return resolvedImagePath(ref, argument);
  }

  @override
  bool operator ==(Object other) {
    return other is ResolvedImagePathProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$resolvedImagePathHash() => r'a9c0cc90f812ef72df40c90803137b6f778bb659';

/// Absolute path of a stored image (or thumbnail) path. Kept for the app's
/// lifetime, so scrolling back to a row never resolves its path again.

final class ResolvedImagePathFamily extends $Family
    with $FunctionalFamilyOverride<FutureOr<String>, String> {
  ResolvedImagePathFamily._()
    : super(
        retry: null,
        name: r'resolvedImagePathProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: false,
      );

  /// Absolute path of a stored image (or thumbnail) path. Kept for the app's
  /// lifetime, so scrolling back to a row never resolves its path again.

  ResolvedImagePathProvider call(String relativePath) =>
      ResolvedImagePathProvider._(argument: relativePath, from: this);

  @override
  String toString() => r'resolvedImagePathProvider';
}
