import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/db/app_database.dart';
import '../../../core/db/db_providers.dart';
import '../../../core/widgets/category_icons.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../application/categories_providers.dart';
import 'category_editor_dialog.dart';

/// Lists the categories and lets the user add, edit and delete them.
class CategoriesScreen extends ConsumerWidget {
  const CategoriesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final categories = ref.watch(categoryListProvider);
    final counts = ref.watch(categoryReceiptCountsProvider).value;
    final list = categories.value ?? const <CategoryRow>[];

    return Scaffold(
      appBar: AppBar(title: Text(l10n.categoriesTitle)),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: categories.hasValue
            ? () => showCategoryEditor(context, existing: list)
            : null,
        icon: const Icon(Icons.add),
        label: Text(l10n.categoriesAdd),
      ),
      body: switch (categories) {
        AsyncValue(:final value?) when value.isEmpty => _Message(
          l10n.categoriesEmpty,
        ),
        AsyncValue(:final value?) => ListView.builder(
          // Room for the FAB below the last row.
          padding: const EdgeInsets.only(bottom: 96),
          itemCount: value.length,
          itemBuilder: (context, index) => _CategoryTile(
            category: value[index],
            receiptCount: counts == null ? null : counts[value[index].id] ?? 0,
            all: value,
          ),
        ),
        AsyncValue(hasError: true) => _Message(l10n.categoriesLoadError),
        _ => const Center(child: CircularProgressIndicator()),
      },
    );
  }
}

enum _MenuAction { edit, delete }

class _CategoryTile extends ConsumerWidget {
  const _CategoryTile({
    required this.category,
    required this.receiptCount,
    required this.all,
  });

  final CategoryRow category;
  final int? receiptCount;
  final List<CategoryRow> all;

  Future<void> _edit(BuildContext context, WidgetRef ref) async {
    final result = await showCategoryEditor(
      context,
      category: category,
      existing: all,
    );
    if (result == CategoryEditorResult.deleteRequested && context.mounted) {
      await confirmDeleteCategory(context, ref, category);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final count = receiptCount;
    return ListTile(
      leading: CategoryAvatar(iconKey: category.iconKey, color: category.color),
      title: Text(category.name),
      subtitle: count == null ? null : Text(l10n.categoriesReceiptCount(count)),
      onTap: () => _edit(context, ref),
      trailing: PopupMenuButton<_MenuAction>(
        tooltip: l10n.categoriesMoreOptions(category.name),
        onSelected: (action) => switch (action) {
          _MenuAction.edit => _edit(context, ref),
          _MenuAction.delete => confirmDeleteCategory(context, ref, category),
        },
        itemBuilder: (context) => [
          PopupMenuItem(
            value: _MenuAction.edit,
            child: Text(l10n.categoriesEdit),
          ),
          PopupMenuItem(
            value: _MenuAction.delete,
            child: Text(l10n.categoriesDelete),
          ),
        ],
      ),
    );
  }
}

/// Asks before deleting [category], saying how many receipts will become
/// uncategorised, then deletes it (its receipts keep existing with no
/// category) and shows a snack bar.
Future<void> confirmDeleteCategory(
  BuildContext context,
  WidgetRef ref,
  CategoryRow category,
) async {
  final l10n = AppLocalizations.of(context);
  final dao = ref.read(categoriesDaoProvider);
  final int count;
  try {
    count = await dao.countReceipts(category.id);
  } on Object catch (error) {
    debugPrint('CategoriesScreen: counting receipts failed: $error');
    if (context.mounted) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(l10n.categoriesDeleteError)));
    }
    return;
  }
  if (!context.mounted) return;

  final confirmed = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(l10n.categoriesDeleteTitle(category.name)),
      content: Text(l10n.categoriesDeleteBody(count)),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: Text(l10n.categoriesCancel),
        ),
        FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: Theme.of(context).colorScheme.error,
            foregroundColor: Theme.of(context).colorScheme.onError,
          ),
          onPressed: () => Navigator.of(context).pop(true),
          child: Text(l10n.categoriesDelete),
        ),
      ],
    ),
  );
  if (confirmed != true) return;

  if (!context.mounted) return;
  final messenger = ScaffoldMessenger.of(context);
  String message;
  try {
    await dao.deleteCategory(category.id);
    message = l10n.categoriesDeleted(category.name);
  } on Object catch (error) {
    debugPrint('CategoriesScreen: delete failed: $error');
    message = l10n.categoriesDeleteError;
  }
  messenger
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(message)));
}

class _Message extends StatelessWidget {
  const _Message(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: Theme.of(context).textTheme.bodyLarge,
      ),
    ),
  );
}
