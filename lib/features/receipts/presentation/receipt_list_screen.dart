import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/db/app_database.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../application/receipt_list_entries.dart';
import '../application/receipt_list_providers.dart';
import '../data/receipts_providers.dart';
import 'list/add_receipt_sheet.dart';
import 'list/receipt_deleted_snack_bar.dart';
import 'list/receipt_list_parts.dart';
import 'receipt_routes_detail.dart';

/// The Receipts tab: search, category filter, this month's totals and the
/// receipts grouped by month. Swipe a row to delete it (with Undo).
class ReceiptListScreen extends ConsumerStatefulWidget {
  const ReceiptListScreen({super.key});

  @override
  ConsumerState<ReceiptListScreen> createState() => _ReceiptListScreenState();
}

class _ReceiptListScreenState extends ConsumerState<ReceiptListScreen> {
  /// Rows swiped away whose deletion hasn't reached the stream yet. A
  /// dismissed [Dismissible] must leave the tree in the same frame.
  final Set<String> _hiddenIds = {};

  /// Refreshes "this month" when the app returns to the foreground, in case
  /// a new month started while it was in the background.
  late final AppLifecycleListener _lifecycle;

  List<ReceiptRow>? _lastRows;
  int _hiddenVersion = 0;
  int _lastHiddenVersion = -1;
  List<ReceiptListEntry> _entries = const [];

  @override
  void initState() {
    super.initState();
    _lifecycle = AppLifecycleListener(
      onResume: () => ref.invalidate(currentMonthProvider),
    );
  }

  @override
  void dispose() {
    _lifecycle.dispose();
    super.dispose();
  }

  /// Groups the rows by month, only when the rows or [_hiddenIds] changed.
  List<ReceiptListEntry> _entriesFor(List<ReceiptRow> rows) {
    if (identical(rows, _lastRows) && _hiddenVersion == _lastHiddenVersion) {
      return _entries;
    }
    if (!identical(rows, _lastRows) && _hiddenIds.isNotEmpty) {
      // Forget hidden rows the database no longer returns.
      final ids = {for (final row in rows) row.id};
      _hiddenIds.retainAll(ids);
    }
    _lastRows = rows;
    _lastHiddenVersion = _hiddenVersion;
    _entries = groupReceiptsByMonth(
      _hiddenIds.isEmpty
          ? rows
          : rows.where((row) => !_hiddenIds.contains(row.id)),
    );
    return _entries;
  }

  Future<void> _delete(ReceiptRow row) async {
    if (!_hiddenIds.add(row.id)) return;
    setState(() => _hiddenVersion++);
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final repository = ref.read(receiptRepositoryProvider);
    final ReceiptRow? deleted;
    try {
      deleted = await repository.delete(row.id);
    } on Object catch (error) {
      debugPrint('ReceiptListScreen: delete failed: $error');
      // Let a frame without the row pass first: the swiped-away Dismissible
      // must leave the tree before the row can come back.
      await WidgetsBinding.instance.endOfFrame;
      _unhide(row.id);
      showReceiptDeleteFailedSnackBar(messenger: messenger, l10n: l10n);
      return;
    }
    if (deleted == null) return;
    showReceiptDeletedSnackBar(
      messenger: messenger,
      l10n: l10n,
      repository: repository,
      deleted: deleted,
      onUndo: () => _unhide(row.id),
    );
  }

  /// Shows a row hidden by [_delete] again (Undo, or the delete failed).
  void _unhide(String id) {
    if (mounted && _hiddenIds.remove(id)) {
      setState(() => _hiddenVersion++);
    }
  }

  void _clearFilters() {
    ref.read(receiptListFilterControllerProvider.notifier).clear();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final filter = ref.watch(receiptListFilterControllerProvider);
    final receipts = ref.watch(filteredReceiptsProvider);
    final rows = receipts.value;
    var entries = rows == null ? null : _entriesFor(rows);
    // After the filter changes, the previous (possibly empty) result is kept
    // while the new one loads. Don't take it for "no receipts at all" or
    // "no matches": show the spinner until the new result arrives.
    if (entries != null && entries.isEmpty && receipts.isLoading) {
      entries = null;
    }
    final noReceiptsAtAll =
        entries != null && entries.isEmpty && !filter.isActive;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.appTitle)),
      floatingActionButton: FloatingActionButton(
        key: const Key('list-fab'),
        tooltip: l10n.fabAddReceipt,
        onPressed: () => showAddReceiptSheet(context),
        child: const Icon(Icons.add),
      ),
      body: CustomScrollView(
        key: const Key('receipt-list'),
        slivers: [
          if (!noReceiptsAtAll) ...[
            const SliverPadding(
              padding: EdgeInsets.fromLTRB(16, 8, 16, 12),
              sliver: SliverToBoxAdapter(child: ReceiptSearchBar()),
            ),
            const SliverToBoxAdapter(child: CategoryFilterChips()),
            const SliverPadding(
              padding: EdgeInsets.only(top: 12),
              sliver: SliverToBoxAdapter(child: MonthSummaryCard()),
            ),
          ],
          if (entries == null)
            SliverFillRemaining(
              hasScrollBody: false,
              child: receipts.hasError
                  ? ListMessage(
                      icon: Icons.error_outline,
                      title: l10n.listLoadError,
                    )
                  : const Center(child: CircularProgressIndicator()),
            )
          else if (noReceiptsAtAll)
            SliverFillRemaining(
              hasScrollBody: false,
              child: ListMessage(
                key: const Key('list-empty'),
                icon: Icons.receipt_long_outlined,
                title: l10n.receiptsEmptyTitle,
                body: l10n.receiptsEmptyBody,
                actions: [
                  FilledButton.icon(
                    key: const Key('list-empty-scan'),
                    onPressed: () =>
                        context.push(ReceiptPaths.scanCamera).ignore(),
                    icon: const Icon(Icons.document_scanner_outlined),
                    label: Text(l10n.receiptsScanFirst),
                  ),
                  const SizedBox(height: 8),
                  TextButton(
                    key: const Key('list-empty-manual'),
                    onPressed: () =>
                        context.push(ReceiptPaths.newManual).ignore(),
                    child: Text(l10n.receiptsAddManually),
                  ),
                ],
              ),
            )
          else if (entries.isEmpty)
            SliverFillRemaining(
              hasScrollBody: false,
              child: ListMessage(
                key: const Key('list-no-matches'),
                icon: Icons.search_off,
                title: l10n.listNoMatchesTitle,
                body: l10n.listNoMatchesBody,
                actions: [
                  OutlinedButton(
                    key: const Key('list-clear-filters'),
                    onPressed: _clearFilters,
                    child: Text(l10n.listClearFilters),
                  ),
                ],
              ),
            )
          else
            SliverPadding(
              // Room for the FAB below the last row.
              padding: const EdgeInsets.only(bottom: 88),
              sliver: _ReceiptSliverList(entries: entries, onDelete: _delete),
            ),
        ],
      ),
    );
  }
}

class _ReceiptSliverList extends ConsumerWidget {
  const _ReceiptSliverList({required this.entries, required this.onDelete});

  final List<ReceiptListEntry> entries;
  final void Function(ReceiptRow row) onDelete;

  static String _keyOf(ReceiptListEntry entry) => switch (entry) {
    ReceiptEntry(:final receipt) => receipt.id,
    MonthHeaderEntry(:final month) => month.toIso(),
  };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final categories = ref.watch(categoriesByIdProvider);
    // Built on first use, so finding where each kept row went after a
    // stream update is one lookup instead of a scan of every entry.
    Map<String, int>? indexByKey;
    return SliverList.builder(
      itemCount: entries.length,
      // Lets rows keep their state when rows above them are added or removed.
      findChildIndexCallback: (key) {
        if (key is! ValueKey<String>) return null;
        indexByKey ??= {
          for (final (index, entry) in entries.indexed) _keyOf(entry): index,
        };
        return indexByKey![key.value];
      },
      itemBuilder: (context, index) => switch (entries[index]) {
        MonthHeaderEntry(:final month) => MonthHeader(
          key: ValueKey(month.toIso()),
          month: month,
        ),
        ReceiptEntry(:final receipt) => Dismissible(
          key: ValueKey(receipt.id),
          direction: DismissDirection.endToStart,
          background: const DeleteSwipeBackground(),
          onDismissed: (_) => onDelete(receipt),
          child: ReceiptListTile(
            receipt: receipt,
            category: receipt.categoryId == null
                ? null
                : categories[receipt.categoryId],
            onTap: () => context.push(ReceiptPaths.detail(receipt.id)).ignore(),
            // Screen reader users can't swipe a row away; they get a
            // "Delete" action on the row instead.
            onDelete: () => onDelete(receipt),
          ),
        ),
      },
    );
  }
}
