import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:receipt_mind/app/theme.dart';
import 'package:receipt_mind/core/date/local_date.dart';
import 'package:receipt_mind/core/db/app_database.dart';
import 'package:receipt_mind/core/db/daos/categories_dao.dart';
import 'package:receipt_mind/core/db/db_providers.dart';
import 'package:receipt_mind/core/widgets/category_icons.dart';
import 'package:receipt_mind/features/categories/presentation/categories_screen.dart';
import 'package:receipt_mind/l10n/generated/app_localizations.dart';

import '../../helpers/test_app.dart';

/// A DAO whose deletes fail (e.g. a locked database).
final class _FailingDeleteDao extends CategoriesDao {
  _FailingDeleteDao(super.attachedDatabase);

  @override
  Future<int> deleteCategory(int id) async =>
      throw StateError('database is locked');
}

/// A DAO that can't count a category's receipts (e.g. a locked database).
final class _FailingCountDao extends CategoriesDao {
  _FailingCountDao(super.attachedDatabase);

  @override
  Future<int> countReceipts(int categoryId) async =>
      throw StateError('database is locked');
}

void main() {
  late AppDatabase db;

  setUp(() => db = inMemoryDatabase());
  tearDown(() => db.close());

  // Database calls from the test body run outside the fake clock; drift's
  // futures would otherwise never complete inside testWidgets.
  late WidgetTester t;
  Future<T> real<T>(Future<T> Function() body) async =>
      (await t.runAsync(body)) as T;

  Future<CategoryRow> category(String name) => real(
    () async => (await db.categoriesDao.watchAll().first).firstWhere(
      (c) => c.name == name,
    ),
  );

  Future<int> categoryCount() =>
      real(() => db.categoriesDao.watchCount().first);

  Future<void> addReceipts(int categoryId, int count) => real(() async {
    for (var i = 0; i < count; i++) {
      await db.receiptsDao.insertReceipt(
        ReceiptsCompanion.insert(
          id: 'r-$categoryId-$i',
          merchant: 'Shop $i',
          purchaseDate: LocalDate(2026, 11, 1),
          totalMinor: 1000 + i,
          currency: 'AUD',
          categoryId: Value(categoryId),
          extractionMethod: ExtractionMethod.manual,
          createdAt: DateTime(2026, 11, 1),
          updatedAt: DateTime(2026, 11, 1),
        ),
      );
    }
  });

  Future<void> pumpScreen(
    WidgetTester tester, {
    ThemeMode themeMode = ThemeMode.light,
    List<Override> overrides = const [],
  }) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [appDatabaseProvider.overrideWithValue(db), ...overrides],
        child: MaterialApp(
          theme: AppTheme.light,
          darkTheme: AppTheme.dark,
          themeMode: themeMode,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const CategoriesScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Finder tile(String name) =>
      find.ancestor(of: find.text(name), matching: find.byType(ListTile));

  Future<void> tapOption(WidgetTester tester, String label) async {
    final finder = find.bySemanticsLabel(label);
    await tester.ensureVisible(finder);
    await tester.pumpAndSettle();
    await tester.tap(finder);
    await tester.pumpAndSettle();
  }

  testWidgets('lists the seeded categories in order with receipt counts', (
    tester,
  ) async {
    t = tester;
    await addReceipts((await category('Groceries')).id, 3);
    await addReceipts((await category('Bills')).id, 1);
    await pumpScreen(tester);

    expect(find.text('Categories'), findsOneWidget);
    expect(find.byType(CategoryAvatar), findsNWidgets(7));
    final names = ['Groceries', 'Dining', 'Transport', 'Shopping', 'Bills'];
    final tops = [for (final n in names) tester.getTopLeft(find.text(n)).dy];
    expect(tops, orderedEquals([...tops]..sort()));
    expect(
      find.descendant(of: tile('Groceries'), matching: find.text('3 receipts')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: tile('Bills'), matching: find.text('1 receipt')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: tile('Dining'), matching: find.text('No receipts')),
      findsOneWidget,
    );
  });

  testWidgets('adds a category with an icon and colour', (tester) async {
    t = tester;
    await pumpScreen(tester);

    await tester.tap(find.text('Add category'));
    await tester.pumpAndSettle();
    expect(find.text('New category'), findsOneWidget);

    await tester.enterText(find.byType(TextField), '  Pet care ');
    await tapOption(tester, 'Pets');
    await tapOption(tester, 'Colour 10 of 12');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(find.text('New category'), findsNothing);
    expect(find.text('Pet care'), findsOneWidget);
    final saved = await category('Pet care');
    expect(saved.iconKey, 'pets');
    expect(saved.color, categoryPalette[9].toARGB32());
    expect(saved.sortOrder, 7);
  });

  testWidgets('requires a name', (tester) async {
    t = tester;
    await pumpScreen(tester);
    await tester.tap(find.text('Add category'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), '   ');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(find.text('Enter a name'), findsOneWidget);
    expect(await categoryCount(), 7);
  });

  testWidgets('shows a friendly error for a duplicate name', (tester) async {
    t = tester;
    await pumpScreen(tester);
    await tester.tap(find.text('Add category'));
    await tester.pumpAndSettle();

    // Caught before saving, ignoring case.
    await tester.enterText(find.byType(TextField), 'groceries');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(
      find.text('A category with this name already exists'),
      findsOneWidget,
    );

    // Typing clears the error.
    await tester.enterText(find.byType(TextField), 'Coffee');
    await tester.pumpAndSettle();
    expect(find.text('A category with this name already exists'), findsNothing);

    // Created elsewhere while the dialog is open: the database's unique
    // constraint rejects it and the dialog shows the same message.
    await real(
      () => db.categoriesDao.insertCategory(
        CategoriesCompanion.insert(
          name: 'Coffee',
          iconKey: 'coffee',
          color: 0xFF5D4037,
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(
      find.text('A category with this name already exists'),
      findsOneWidget,
    );
    expect(find.text('New category'), findsOneWidget);
    expect(await categoryCount(), 8);
  });

  testWidgets('edits a category', (tester) async {
    t = tester;
    await pumpScreen(tester);

    await tester.tap(find.text('Dining'));
    await tester.pumpAndSettle();
    expect(find.text('Edit category'), findsOneWidget);
    expect(
      tester.widget<TextField>(find.byType(TextField)).controller!.text,
      'Dining',
    );

    // Its own name (another case) is not a duplicate.
    await tester.enterText(find.byType(TextField), 'DINING');
    await tapOption(tester, 'Coffee');
    await tapOption(tester, 'Colour 8 of 12');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(find.text('DINING'), findsOneWidget);
    final edited = await category('DINING');
    expect(edited.iconKey, 'coffee');
    expect(edited.color, categoryPalette[7].toARGB32());
    expect(edited.sortOrder, 1);
  });

  testWidgets('deleting says how many receipts become uncategorised', (
    tester,
  ) async {
    t = tester;
    final groceries = await category('Groceries');
    await addReceipts(groceries.id, 3);
    await pumpScreen(tester);

    await tester.tap(find.byTooltip('More options for Groceries'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();

    expect(find.text('Delete “Groceries”?'), findsOneWidget);
    expect(find.text('3 receipts will become uncategorised.'), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, 'Delete'));
    await tester.pumpAndSettle();

    expect(find.text('Groceries'), findsNothing);
    expect(find.text('Deleted “Groceries”'), findsOneWidget);
    expect(await categoryCount(), 6);

    // The receipts are kept, without a category (FK ON DELETE SET NULL).
    final receipts = await real(() => db.receiptsDao.watchReceipts().first);
    expect(receipts, hasLength(3));
    expect(receipts.map((r) => r.categoryId), everyElement(isNull));
  });

  testWidgets('delete from the edit dialog can be cancelled', (tester) async {
    t = tester;
    await addReceipts((await category('Health')).id, 1);
    await pumpScreen(tester);

    await tester.tap(find.text('Health'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();

    expect(find.text('1 receipt will become uncategorised.'), findsOneWidget);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    expect(find.text('Health'), findsOneWidget);
    expect(await categoryCount(), 7);
  });

  testWidgets('deleting an unused category says no receipts are affected', (
    tester,
  ) async {
    t = tester;
    await pumpScreen(tester);

    await tester.tap(find.byTooltip('More options for Transport'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();

    expect(find.text('No receipts use this category.'), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, 'Delete'));
    await tester.pumpAndSettle();
    expect(find.text('Transport'), findsNothing);
  });

  testWidgets('a failed delete keeps the category and says so', (tester) async {
    t = tester;
    await pumpScreen(
      tester,
      overrides: [
        categoriesDaoProvider.overrideWithValue(_FailingDeleteDao(db)),
      ],
    );

    await tester.tap(find.byTooltip('More options for Transport'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Delete'));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(
      find.text("Couldn't delete the category. Please try again."),
      findsOneWidget,
    );
    expect(find.text('Transport'), findsOneWidget);
    expect(await categoryCount(), 7);
  });

  testWidgets('a failed receipt count keeps the category and says so', (
    tester,
  ) async {
    t = tester;
    await pumpScreen(
      tester,
      overrides: [
        categoriesDaoProvider.overrideWithValue(_FailingCountDao(db)),
      ],
    );

    await tester.tap(find.byTooltip('More options for Transport'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.byType(AlertDialog), findsNothing);
    expect(
      find.text("Couldn't delete the category. Please try again."),
      findsOneWidget,
    );
    expect(find.text('Transport'), findsOneWidget);
    expect(await categoryCount(), 7);
  });

  testWidgets('duplicate names are caught ignoring case and spaces', (
    tester,
  ) async {
    t = tester;
    await pumpScreen(tester);
    await tester.tap(find.text('Add category'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), '  gROCERIES ');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(
      find.text('A category with this name already exists'),
      findsOneWidget,
    );
    expect(await categoryCount(), 7);
  });

  group('accessibility', () {
    for (final mode in [ThemeMode.light, ThemeMode.dark]) {
      testWidgets('the list meets the guidelines in ${mode.name} mode', (
        tester,
      ) async {
        t = tester;
        final handle = tester.ensureSemantics();
        await pumpScreen(tester, themeMode: mode);

        await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
        await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
        await expectLater(tester, meetsGuideline(textContrastGuideline));
        handle.dispose();
      });

      testWidgets('the editor meets the guidelines in ${mode.name} mode', (
        tester,
      ) async {
        t = tester;
        final handle = tester.ensureSemantics();
        await pumpScreen(tester, themeMode: mode);
        await tester.tap(find.text('Dining'));
        await tester.pumpAndSettle();

        await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
        await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
        await expectLater(tester, meetsGuideline(textContrastGuideline));
        handle.dispose();
      });
    }

    testWidgets('list, editor and delete dialog fit at 200 % text', (
      tester,
    ) async {
      t = tester;
      tester.view.physicalSize = const Size(1080, 1920);
      tester.view.devicePixelRatio = 2.625;
      tester.platformDispatcher.textScaleFactorTestValue = 2.0;
      addTearDown(tester.view.reset);
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      await addReceipts((await category('Groceries')).id, 2);
      await pumpScreen(tester, themeMode: ThemeMode.dark);
      expect(tester.takeException(), isNull);

      await tester.tap(find.text('Groceries'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.drag(find.text('Icon'), const Offset(0, -2000));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.tap(find.text('Delete'));
      await tester.pumpAndSettle();
      expect(
        find.text('2 receipts will become uncategorised.'),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    });
  });
}
