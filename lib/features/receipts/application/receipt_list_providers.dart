import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/clock.dart';
import '../../../core/date/local_date.dart';
import '../../../core/db/app_database.dart';
import '../../../core/db/db_providers.dart';
import '../data/receipts_providers.dart';

part 'receipt_list_providers.g.dart';

/// What the receipt list shows: a search text and an optional category.
@immutable
final class ReceiptListFilter {
  const ReceiptListFilter({this.query = '', this.categoryId});

  /// Matched against merchant, notes and the recognised text.
  final String query;

  /// Only receipts in this category, or every receipt when `null`.
  final int? categoryId;

  /// True when the search or the category narrows the list.
  bool get isActive => query.trim().isNotEmpty || categoryId != null;

  @override
  bool operator ==(Object other) =>
      other is ReceiptListFilter &&
      other.query == query &&
      other.categoryId == categoryId;

  @override
  int get hashCode => Object.hash(query, categoryId);
}

/// The list's current search and category filter.
@riverpod
class ReceiptListFilterController extends _$ReceiptListFilterController {
  @override
  ReceiptListFilter build() {
    // A deleted category can't stay selected: the list would show nothing
    // and no chip would look selected, so fall back to "All".
    ref.listen(receiptCategoriesProvider, (_, next) {
      final selected = state.categoryId;
      final categories = next.value;
      if (selected != null &&
          categories != null &&
          !categories.any((c) => c.id == selected)) {
        setCategory(null);
      }
    });
    return const ReceiptListFilter();
  }

  void setQuery(String query) {
    final text = query.trim();
    if (text == state.query) return;
    state = ReceiptListFilter(query: text, categoryId: state.categoryId);
  }

  /// Shows only [categoryId], or every category for `null`.
  void setCategory(int? categoryId) {
    if (categoryId == state.categoryId) return;
    state = ReceiptListFilter(query: state.query, categoryId: categoryId);
  }

  void clear() => state = const ReceiptListFilter();
}

// Providers whose types are Drift rows are written by hand:
// riverpod_generator runs before Drift's generated part (app_database.g.dart)
// exists in the build, so it can't name `ReceiptRow` or `CategoryRow`.

/// Receipts matching the current filter, newest first.
final filteredReceiptsProvider = StreamProvider.autoDispose<List<ReceiptRow>>((
  ref,
) {
  final filter = ref.watch(receiptListFilterControllerProvider);
  return ref
      .watch(receiptRepositoryProvider)
      .watchReceipts(query: filter.query, categoryId: filter.categoryId);
});

/// All categories in display order, for the filter chips and row dots.
final receiptCategoriesProvider = StreamProvider.autoDispose<List<CategoryRow>>(
  (ref) => ref.watch(categoriesDaoProvider).watchAll(),
);

/// Categories by id; empty until they have loaded.
final categoriesByIdProvider = Provider.autoDispose<Map<int, CategoryRow>>((
  ref,
) {
  final categories = ref.watch(receiptCategoriesProvider).value ?? const [];
  return {for (final c in categories) c.id: c};
});

/// One receipt for the detail screen; `null` once it is deleted.
final receiptDetailProvider = StreamProvider.autoDispose
    .family<ReceiptRow?, String>(
      (ref, id) => ref.watch(receiptRepositoryProvider).watchReceipt(id),
    );

/// The first day of the current month (from [clockProvider]). The list
/// invalidates it when the app comes back to the foreground, so the month
/// card moves on after midnight at the end of a month.
@riverpod
LocalDate currentMonth(Ref ref) =>
    LocalDate.fromDateTime(ref.watch(clockProvider)()).firstOfMonth;

/// Totals per currency (minor units) of every receipt in the current month,
/// whatever the list filter is.
@riverpod
Stream<Map<String, int>> currentMonthTotals(Ref ref) => ref
    .watch(receiptRepositoryProvider)
    .watchMonthTotals(ref.watch(currentMonthProvider));

/// Absolute path of a stored image (or thumbnail) path. Kept for the app's
/// lifetime, so scrolling back to a row never resolves its path again.
@Riverpod(keepAlive: true)
Future<String> resolvedImagePath(Ref ref, String relativePath) =>
    ref.watch(receiptImageStoreProvider).resolve(relativePath);
