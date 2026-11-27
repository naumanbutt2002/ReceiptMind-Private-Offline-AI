// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'categories_providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Number of receipts per category id, updated live. Categories without
/// receipts are missing from the map.
// TODO(lead): move into CategoriesDao as `watchReceiptCounts()`.

@ProviderFor(categoryReceiptCounts)
final categoryReceiptCountsProvider = CategoryReceiptCountsProvider._();

/// Number of receipts per category id, updated live. Categories without
/// receipts are missing from the map.
// TODO(lead): move into CategoriesDao as `watchReceiptCounts()`.

final class CategoryReceiptCountsProvider
    extends
        $FunctionalProvider<
          AsyncValue<Map<int, int>>,
          Map<int, int>,
          Stream<Map<int, int>>
        >
    with $FutureModifier<Map<int, int>>, $StreamProvider<Map<int, int>> {
  /// Number of receipts per category id, updated live. Categories without
  /// receipts are missing from the map.
  // TODO(lead): move into CategoriesDao as `watchReceiptCounts()`.
  CategoryReceiptCountsProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'categoryReceiptCountsProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$categoryReceiptCountsHash();

  @$internal
  @override
  $StreamProviderElement<Map<int, int>> $createElement(
    $ProviderPointer pointer,
  ) => $StreamProviderElement(pointer);

  @override
  Stream<Map<int, int>> create(Ref ref) {
    return categoryReceiptCounts(ref);
  }
}

String _$categoryReceiptCountsHash() =>
    r'391746223ef31d686dd0c02d8b64e4d58b7ada46';
