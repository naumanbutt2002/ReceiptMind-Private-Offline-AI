import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter/widgets.dart' show StringCharacters;
import 'package:flutter_test/flutter_test.dart';
import 'package:receipt_mind/core/db/app_database.dart';
import 'package:receipt_mind/core/db/tables/categories.dart';

import '../../helpers/test_app.dart';

/// 40 visible characters: flags, a ZWJ family, a skin tone and plain emoji.
final fortyEmoji = [
  '🇦🇺', '👨‍👩‍👧', '🇯🇵', '👍🏽', //
  for (var i = 0; i < 36; i++) '🛒',
].join();

void main() {
  late AppDatabase db;

  setUp(() => db = inMemoryDatabase());
  tearDown(() => db.close());

  CategoriesCompanion named(String name) =>
      CategoriesCompanion.insert(name: name, iconKey: 'other', color: 0);

  Future<CategoryRow> byId(int id) =>
      (db.select(db.categories)..where((c) => c.id.equals(id))).getSingle();

  group('category name length', () {
    test('40 emoji (flags, ZWJ family) save and round-trip', () async {
      expect(fortyEmoji.characters.length, 40);
      expect(fortyEmoji.length, greaterThan(40), reason: 'UTF-16 code units');

      final id = await db.categoriesDao.insertCategory(named(fortyEmoji));
      expect((await byId(id)).name, fortyEmoji);
    });

    test('a category can be renamed to 40 emoji', () async {
      final id = await db.categoriesDao.insertCategory(named('Coffee'));
      final row = await byId(id);
      expect(
        await db.categoriesDao.updateCategory(row.copyWith(name: fortyEmoji)),
        isTrue,
      );
      expect((await byId(id)).name, fortyEmoji);
    });

    test('40 of the longest family emoji still fit under the cap', () async {
      const family = '👨🏻‍👩🏻‍👧🏻‍👦🏻';
      final name = List.filled(40, family).join();
      expect(name.characters.length, 40);
      expect(name.length, lessThanOrEqualTo(categoryNameMaxCodeUnits));

      final id = await db.categoriesDao.insertCategory(named(name));
      expect((await byId(id)).name, name);
    });

    test('the code-unit cap and the empty name are rejected', () async {
      await db.categoriesDao.insertCategory(
        named('a' * categoryNameMaxCodeUnits),
      );
      await expectLater(
        db.categoriesDao.insertCategory(
          named('b' * (categoryNameMaxCodeUnits + 1)),
        ),
        throwsA(isA<InvalidDataException>()),
      );
      await expectLater(
        db.categoriesDao.insertCategory(named('')),
        throwsA(isA<InvalidDataException>()),
      );
    });

    test('the SQL schema has no length CHECK (limit is Dart-side)', () async {
      final sql = await db
          .customSelect(
            "SELECT sql FROM sqlite_master WHERE type = 'table' "
            "AND name = 'categories'",
          )
          .getSingle();
      final create = sql.read<String>('sql').toUpperCase();
      expect(create, isNot(contains('CHECK')));
      expect(create, isNot(contains('LENGTH')));
    });
  });
}
