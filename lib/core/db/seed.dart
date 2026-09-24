import 'package:drift/drift.dart';

import 'app_database.dart';

/// Categories created on first launch. The names match the category list the
/// v0.2 AI prompt uses, so AI suggestions map onto them directly.
const defaultCategories = <({String name, String iconKey, int color})>[
  (name: 'Groceries', iconKey: 'groceries', color: 0xFF2E7D32),
  (name: 'Dining', iconKey: 'dining', color: 0xFFE65100),
  (name: 'Transport', iconKey: 'transport', color: 0xFF1565C0),
  (name: 'Shopping', iconKey: 'shopping', color: 0xFF6A1B9A),
  (name: 'Bills', iconKey: 'bills', color: 0xFF00838F),
  (name: 'Health', iconKey: 'health', color: 0xFFC62828),
  (name: 'Other', iconKey: 'other', color: 0xFF546E7A),
];

Future<void> seedDefaultCategories(AppDatabase db) async {
  await db.batch((batch) {
    batch.insertAll(db.categories, [
      for (final (index, c) in defaultCategories.indexed)
        CategoriesCompanion.insert(
          name: c.name,
          iconKey: c.iconKey,
          color: c.color,
          sortOrder: Value(index),
        ),
    ]);
  });
}
