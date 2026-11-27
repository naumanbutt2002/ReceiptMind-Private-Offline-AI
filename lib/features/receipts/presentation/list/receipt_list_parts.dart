import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/date/date_display.dart';
import '../../../../core/date/local_date.dart';
import '../../../../core/db/app_database.dart';
import '../../../../core/money/money.dart';
import '../../../../core/settings/settings_providers.dart';
import '../../../../core/widgets/amount_text.dart';
import '../../../../core/widgets/category_icons.dart';
import '../../../../l10n/generated/app_localizations.dart';
import '../../application/receipt_list_providers.dart';
import 'month_label.dart';
import 'receipt_thumbnail.dart';

/// How long the search waits after the last keystroke before it queries.
const searchDebounce = Duration(milliseconds: 250);

/// The search bar. Typing updates the list filter after [searchDebounce];
/// clearing applies at once.
class ReceiptSearchBar extends ConsumerStatefulWidget {
  const ReceiptSearchBar({super.key});

  @override
  ConsumerState<ReceiptSearchBar> createState() => _ReceiptSearchBarState();
}

class _ReceiptSearchBarState extends ConsumerState<ReceiptSearchBar> {
  late final TextEditingController _controller;
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(
      text: ref.read(receiptListFilterControllerProvider).query,
    );
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _onChanged(String text) {
    _debounce?.cancel();
    _debounce = Timer(searchDebounce, () {
      if (mounted) {
        ref.read(receiptListFilterControllerProvider.notifier).setQuery(text);
      }
    });
  }

  void _clear() {
    _debounce?.cancel();
    _controller.clear();
    ref.read(receiptListFilterControllerProvider.notifier).setQuery('');
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    // Keep the field in sync when the filter is cleared from elsewhere.
    ref.listen(receiptListFilterControllerProvider.select((f) => f.query), (
      _,
      query,
    ) {
      if (query.isEmpty && _controller.text.trim().isNotEmpty) {
        _debounce?.cancel();
        _controller.clear();
      }
    });
    // SearchBar's outer tap area (it focuses the field) is its own
    // semantics node without a label; name it after the field.
    return Semantics(
      label: l10n.listSearchHint,
      child: SearchBar(
        key: const Key('list-search'),
        controller: _controller,
        hintText: l10n.listSearchHint,
        leading: const Icon(Icons.search),
        elevation: const WidgetStatePropertyAll(0),
        textInputAction: TextInputAction.search,
        onChanged: _onChanged,
        onSubmitted: (text) {
          _debounce?.cancel();
          ref.read(receiptListFilterControllerProvider.notifier).setQuery(text);
        },
        trailing: [
          ValueListenableBuilder(
            valueListenable: _controller,
            builder: (context, value, _) => value.text.isEmpty
                ? const SizedBox.shrink()
                : IconButton(
                    key: const Key('list-search-clear'),
                    tooltip: l10n.listClearSearch,
                    icon: const Icon(Icons.close),
                    onPressed: _clear,
                  ),
          ),
        ],
      ),
    );
  }
}

/// "All" plus one chip per category; one can be selected at a time.
class CategoryFilterChips extends ConsumerWidget {
  const CategoryFilterChips({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final categories = ref.watch(receiptCategoriesProvider).value ?? const [];
    final selected = ref.watch(
      receiptListFilterControllerProvider.select((f) => f.categoryId),
    );
    final filter = ref.read(receiptListFilterControllerProvider.notifier);
    return SingleChildScrollView(
      key: const Key('list-filter-chips'),
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          ChoiceChip(
            key: const Key('list-filter-all'),
            label: Text(l10n.listFilterAll),
            selected: selected == null,
            onSelected: (_) => filter.setCategory(null),
          ),
          for (final category in categories) ...[
            const SizedBox(width: 8),
            ChoiceChip(
              key: ValueKey('list-filter-${category.id}'),
              avatar: Icon(
                categoryIcon(category.iconKey),
                color: Color(category.color),
              ),
              label: Text(category.name),
              selected: selected == category.id,
              onSelected: (on) => filter.setCategory(on ? category.id : null),
            ),
          ],
        ],
      ),
    );
  }
}

/// This month's spending: one line per currency.
class MonthSummaryCard extends ConsumerWidget {
  const MonthSummaryCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final month = ref.watch(currentMonthProvider);
    final totals = ref.watch(currentMonthTotalsProvider).value;
    final defaultCurrency = ref.watch(
      settingsControllerProvider.select((s) => s.defaultCurrency),
    );
    final entries = (totals?.entries.toList() ?? [])
      ..sort((a, b) {
        // The default currency first, then by code.
        if (a.key == defaultCurrency) return -1;
        if (b.key == defaultCurrency) return 1;
        return a.key.compareTo(b.key);
      });
    return Card.filled(
      key: const Key('list-month-summary'),
      margin: const EdgeInsets.symmetric(horizontal: 16),
      // Read as one item: "This month, September 2026, $12.50, €3.00".
      child: MergeSemantics(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                l10n.listThisMonth,
                style: theme.textTheme.labelMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              Text(
                formatMonthYear(month, l10n.localeName),
                style: theme.textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              if (totals != null && entries.isEmpty)
                Text(l10n.listNoReceiptsThisMonth)
              else
                for (final entry in entries)
                  AmountText(
                    Money(entry.value, entry.key),
                    key: ValueKey('list-month-total-${entry.key}'),
                    style: theme.textTheme.headlineSmall,
                  ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Section header above one month's receipts.
class MonthHeader extends StatelessWidget {
  const MonthHeader({super.key, required this.month});

  final LocalDate month;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Semantics(
      header: true,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 4),
        child: Text(
          formatMonthYear(month, AppLocalizations.of(context).localeName),
          style: theme.textTheme.titleSmall?.copyWith(
            color: theme.colorScheme.primary,
          ),
        ),
      ),
    );
  }
}

/// One receipt: thumbnail, merchant, date and category, amount.
///
/// Screen readers read it as one item ("merchant, date, amount, category").
/// [onDelete], when set, is offered as a "Delete" accessibility action, the
/// screen reader alternative to swiping the row away.
class ReceiptListTile extends ConsumerWidget {
  const ReceiptListTile({
    super.key,
    required this.receipt,
    required this.category,
    required this.onTap,
    this.onDelete,
  });

  final ReceiptRow receipt;
  final CategoryRow? category;
  final VoidCallback onTap;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final locale = ref.watch(deviceLocaleProvider);
    final dateOrder = ref.watch(
      settingsControllerProvider.select((s) => s.dateOrder),
    );
    final date = formatNumericDate(receipt.purchaseDate, dateOrder);
    final money = Money(receipt.totalMinor, receipt.currency);
    final categoryName = category?.name ?? l10n.listUncategorised;
    final thumbnail = ReceiptThumbnail(imagePath: receipt.imagePath);
    return Semantics(
      label: l10n.listRowSemantics(
        receipt.merchant,
        date,
        money.format(locale),
        categoryName,
      ),
      button: true,
      excludeSemantics: true,
      onTap: onTap,
      customSemanticsActions: onDelete == null
          ? null
          : {CustomSemanticsAction(label: l10n.listDelete): onDelete!},
      child: ListTile(
        onTap: onTap,
        leading: receipt.imagePath == null
            ? thumbnail
            : Hero(tag: receiptHeroTag(receipt.id), child: thumbnail),
        title: Text(
          receipt.merchant,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Row(
          children: [
            CategoryDot(color: category?.color, size: 10),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                '$date · $categoryName',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        trailing: AmountText(money, style: theme.textTheme.titleMedium),
      ),
    );
  }
}

/// Red background revealed while a row is swiped away.
class DeleteSwipeBackground extends StatelessWidget {
  const DeleteSwipeBackground({super.key});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return ColoredBox(
      color: scheme.errorContainer,
      child: Align(
        alignment: AlignmentDirectional.centerEnd,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                AppLocalizations.of(context).listDelete,
                style: TextStyle(color: scheme.onErrorContainer),
              ),
              const SizedBox(width: 8),
              Icon(Icons.delete_outline, color: scheme.onErrorContainer),
            ],
          ),
        ),
      ),
    );
  }
}

/// A centred icon, title, body and buttons, for empty and error states.
class ListMessage extends StatelessWidget {
  const ListMessage({
    super.key,
    required this.icon,
    required this.title,
    this.body,
    this.actions = const [],
  });

  final IconData icon;
  final String title;
  final String? body;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final body = this.body;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 72, color: theme.colorScheme.primary),
            const SizedBox(height: 16),
            Text(
              title,
              textAlign: TextAlign.center,
              style: theme.textTheme.titleLarge,
            ),
            if (body != null) ...[
              const SizedBox(height: 8),
              Text(
                body,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium,
              ),
            ],
            if (actions.isNotEmpty) const SizedBox(height: 24),
            ...actions,
          ],
        ),
      ),
    );
  }
}
