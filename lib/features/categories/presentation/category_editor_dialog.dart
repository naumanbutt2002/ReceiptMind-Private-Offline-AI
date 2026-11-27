import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/db/app_database.dart';
import '../../../core/db/db_providers.dart';
import '../../../core/widgets/category_icons.dart';
import '../../../l10n/generated/app_localizations.dart';

/// Longest category name the database accepts.
const categoryNameMaxLength = 40;

/// What the category editor dialog ended with.
enum CategoryEditorResult {
  /// The category was created or updated.
  saved,

  /// The user tapped Delete; the caller asks for confirmation.
  deleteRequested,
}

/// Opens the add (when [category] is `null`) or edit dialog. [existing] is
/// the current category list, used to catch duplicate names early and to put
/// a new category last. Returns `null` when the dialog was cancelled.
Future<CategoryEditorResult?> showCategoryEditor(
  BuildContext context, {
  CategoryRow? category,
  required List<CategoryRow> existing,
}) => showDialog<CategoryEditorResult>(
  context: context,
  builder: (_) => CategoryEditorDialog(category: category, existing: existing),
);

/// Add/edit dialog: name, icon from [categoryIconKeys], colour from
/// [categoryPalette]. Saves through [categoriesDaoProvider] itself, so a
/// duplicate name can be shown inline without closing the dialog.
class CategoryEditorDialog extends ConsumerStatefulWidget {
  const CategoryEditorDialog({
    super.key,
    this.category,
    required this.existing,
  });

  final CategoryRow? category;
  final List<CategoryRow> existing;

  @override
  ConsumerState<CategoryEditorDialog> createState() =>
      _CategoryEditorDialogState();
}

class _CategoryEditorDialogState extends ConsumerState<CategoryEditorDialog> {
  late final TextEditingController _name;
  late String _iconKey;
  late int _color;
  String? _nameError;
  bool _saving = false;

  bool get _isNew => widget.category == null;

  @override
  void initState() {
    super.initState();
    final category = widget.category;
    _name = TextEditingController(text: category?.name ?? '');
    _iconKey = category?.iconKey ?? 'other';
    _color =
        category?.color ??
        categoryPalette[widget.existing.length % categoryPalette.length]
            .toARGB32();
  }

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  String? _validate(AppLocalizations l10n, String name) {
    if (name.isEmpty) return l10n.categoriesNameRequired;
    if (name.length > categoryNameMaxLength) {
      return l10n.categoriesNameTooLong(categoryNameMaxLength);
    }
    final lower = name.toLowerCase();
    final taken = widget.existing.any(
      (c) => c.id != widget.category?.id && c.name.toLowerCase() == lower,
    );
    return taken ? l10n.categoriesNameDuplicate : null;
  }

  Future<void> _save() async {
    final l10n = AppLocalizations.of(context);
    final name = _name.text.trim();
    final error = _validate(l10n, name);
    if (error != null) {
      setState(() => _nameError = error);
      return;
    }
    setState(() => _saving = true);
    final dao = ref.read(categoriesDaoProvider);
    try {
      final category = widget.category;
      if (category == null) {
        final lastOrder = widget.existing.fold<int>(
          -1,
          (max, c) => c.sortOrder > max ? c.sortOrder : max,
        );
        await dao.insertCategory(
          CategoriesCompanion.insert(
            name: name,
            iconKey: _iconKey,
            color: _color,
            sortOrder: Value(lastOrder + 1),
          ),
        );
      } else {
        await dao.updateCategory(
          category.copyWith(name: name, iconKey: _iconKey, color: _color),
        );
      }
    } on Object catch (e) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _nameError = _isUniqueViolation(e)
            ? l10n.categoriesNameDuplicate
            : l10n.categoriesSaveError;
      });
      return;
    }
    if (mounted) Navigator.of(context).pop(CategoryEditorResult.saved);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    return AlertDialog(
      scrollable: true,
      title: Text(_isNew ? l10n.categoriesNewTitle : l10n.categoriesEditTitle),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: _name,
            autofocus: _isNew,
            maxLength: categoryNameMaxLength,
            textCapitalization: TextCapitalization.sentences,
            textInputAction: TextInputAction.done,
            decoration: InputDecoration(
              labelText: l10n.categoriesNameLabel,
              errorText: _nameError,
              errorMaxLines: 3,
            ),
            onChanged: (_) {
              if (_nameError != null) setState(() => _nameError = null);
            },
            onSubmitted: (_) => _saving ? null : _save(),
          ),
          const SizedBox(height: 12),
          Text(l10n.categoriesIconLabel, style: theme.textTheme.labelLarge),
          const SizedBox(height: 4),
          Wrap(
            children: [
              for (final key in categoryIconKeys)
                _IconOption(
                  iconKey: key,
                  label: categoryIconLabel(l10n, key),
                  color: Color(_color),
                  selected: key == _iconKey,
                  onTap: () => setState(() => _iconKey = key),
                ),
            ],
          ),
          const SizedBox(height: 12),
          Text(l10n.categoriesColourLabel, style: theme.textTheme.labelLarge),
          const SizedBox(height: 4),
          Wrap(
            children: [
              for (final (index, color) in categoryPalette.indexed)
                _ColourOption(
                  color: color,
                  label: l10n.categoriesColourOption(
                    index + 1,
                    categoryPalette.length,
                  ),
                  selected: color.toARGB32() == _color,
                  onTap: () => setState(() => _color = color.toARGB32()),
                ),
            ],
          ),
        ],
      ),
      actions: [
        if (!_isNew)
          TextButton(
            style: TextButton.styleFrom(
              foregroundColor: theme.colorScheme.error,
            ),
            onPressed: _saving
                ? null
                : () =>
                      Navigator.of(context)
                          .pop(CategoryEditorResult.deleteRequested),
            child: Text(l10n.categoriesDelete),
          ),
        TextButton(
          onPressed: _saving ? null : () => Navigator.of(context).pop(),
          child: Text(l10n.categoriesCancel),
        ),
        FilledButton(
          onPressed: _saving ? null : _save,
          child: Text(l10n.categoriesSave),
        ),
      ],
    );
  }
}

/// SQLite reports `UNIQUE constraint failed: categories.name`. Matching the
/// message also works when the error comes from drift's background isolate
/// (wrapped in a `DriftRemoteException`).
bool _isUniqueViolation(Object error) =>
    error.toString().contains('UNIQUE constraint failed');

class _IconOption extends StatelessWidget {
  const _IconOption({
    required this.iconKey,
    required this.label,
    required this.color,
    required this.selected,
    required this.onTap,
  });

  final String iconKey;
  final String label;
  final Color color;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Semantics(
      button: true,
      selected: selected,
      label: label,
      excludeSemantics: true,
      child: Tooltip(
        message: label,
        child: InkResponse(
          onTap: onTap,
          radius: 24,
          child: SizedBox.square(
            dimension: 48,
            child: Center(
              child: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: selected ? color : null,
                ),
                child: Icon(
                  categoryIcon(iconKey),
                  size: 22,
                  color: selected ? Colors.white : scheme.onSurfaceVariant,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ColourOption extends StatelessWidget {
  const _ColourOption({
    required this.color,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final Color color;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Semantics(
      button: true,
      selected: selected,
      label: label,
      excludeSemantics: true,
      child: InkResponse(
        onTap: onTap,
        radius: 24,
        child: SizedBox.square(
          dimension: 48,
          child: Center(
            child: Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: color,
                border: selected
                    ? Border.all(color: scheme.onSurface, width: 3)
                    : null,
              ),
              child: selected
                  ? const Icon(Icons.check, size: 20, color: Colors.white)
                  : null,
            ),
          ),
        ),
      ),
    );
  }
}

/// Screen reader name of a curated category icon.
String categoryIconLabel(AppLocalizations l10n, String iconKey) =>
    switch (iconKey) {
      'groceries' => l10n.categoriesIconGroceries,
      'dining' => l10n.categoriesIconDining,
      'transport' => l10n.categoriesIconTransport,
      'shopping' => l10n.categoriesIconShopping,
      'bills' => l10n.categoriesIconBills,
      'health' => l10n.categoriesIconHealth,
      'other' => l10n.categoriesIconOther,
      'coffee' => l10n.categoriesIconCoffee,
      'drinks' => l10n.categoriesIconDrinks,
      'fuel' => l10n.categoriesIconFuel,
      'parking' => l10n.categoriesIconParking,
      'travel' => l10n.categoriesIconTravel,
      'home' => l10n.categoriesIconHome,
      'utilities' => l10n.categoriesIconUtilities,
      'phone' => l10n.categoriesIconPhone,
      'electronics' => l10n.categoriesIconElectronics,
      'subscriptions' => l10n.categoriesIconSubscriptions,
      'entertainment' => l10n.categoriesIconEntertainment,
      'games' => l10n.categoriesIconGames,
      'education' => l10n.categoriesIconEducation,
      'books' => l10n.categoriesIconBooks,
      'fitness' => l10n.categoriesIconFitness,
      'pharmacy' => l10n.categoriesIconPharmacy,
      'beauty' => l10n.categoriesIconBeauty,
      'clothing' => l10n.categoriesIconClothing,
      'kids' => l10n.categoriesIconKids,
      'pets' => l10n.categoriesIconPets,
      'gifts' => l10n.categoriesIconGifts,
      'work' => l10n.categoriesIconWork,
      'repairs' => l10n.categoriesIconRepairs,
      'insurance' => l10n.categoriesIconInsurance,
      _ => iconKey,
    };
