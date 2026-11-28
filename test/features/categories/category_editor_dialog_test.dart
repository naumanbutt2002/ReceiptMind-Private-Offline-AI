import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:receipt_mind/app/theme.dart';
import 'package:receipt_mind/core/db/app_database.dart';
import 'package:receipt_mind/core/db/db_providers.dart';
import 'package:receipt_mind/features/categories/presentation/categories_screen.dart';
import 'package:receipt_mind/l10n/generated/app_localizations.dart';

import '../../helpers/test_app.dart';

/// [count] visible characters: a flag, a ZWJ family, then shopping carts.
String emojiName(int count) =>
    ['🇦🇺', '👨‍👩‍👧', for (var i = 2; i < count; i++) '🛒'].join();

void main() {
  late AppDatabase db;

  setUp(() => db = inMemoryDatabase());
  tearDown(() => db.close());

  // Database calls from the test body run outside the fake clock.
  late WidgetTester t;
  Future<T> real<T>(Future<T> Function() body) async =>
      (await t.runAsync(body)) as T;

  Future<List<String>> names() => real(
    () async => [
      for (final c in await db.categoriesDao.watchAll().first) c.name,
    ],
  );

  Future<void> pumpScreen(WidgetTester tester) async {
    t = tester;
    addTearDown(() => tester.pumpWidget(const SizedBox()));
    await tester.pumpWidget(
      ProviderScope(
        overrides: [appDatabaseProvider.overrideWithValue(db)],
        child: MaterialApp(
          theme: AppTheme.light,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const CategoriesScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> openNew(WidgetTester tester) async {
    await tester.tap(find.text('Add category'));
    await tester.pumpAndSettle();
  }

  String fieldText(WidgetTester tester) =>
      tester.widget<TextField>(find.byType(TextField)).controller!.text;

  // QA M8 (B-3): excludeSemantics dropped the options' tap action, so
  // TalkBack could read the icon and colour options but not pick them (and
  // the tap-target guideline skipped them).
  testWidgets('icon and colour options can be picked with a screen reader', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    await pumpScreen(tester);
    await openNew(tester);

    for (final label in ['Coffee', 'Colour 3 of 12']) {
      final option = find.bySemanticsLabel(label);
      expect(
        tester.getSemantics(option),
        isSemantics(isButton: true, hasTapAction: true),
        reason: label,
      );
      tester.semantics.tap(find.semantics.byLabel(label));
      await tester.pumpAndSettle();
      expect(
        tester.getSemantics(option),
        isSemantics(isSelected: true),
        reason: label,
      );
    }
    handle.dispose();
  });

  testWidgets('the counter counts emoji, flags and ZWJ families as one', (
    tester,
  ) async {
    await pumpScreen(tester);
    await openNew(tester);

    await tester.enterText(find.byType(TextField), '🇦🇺👨‍👩‍👧');
    await tester.pump();
    expect(find.text('2/40'), findsOneWidget);
  });

  testWidgets('a name of 40 emoji saves and round-trips', (tester) async {
    await pumpScreen(tester);
    await openNew(tester);

    final name = emojiName(40);
    await tester.enterText(find.byType(TextField), name);
    await tester.pump();
    expect(find.text('40/40'), findsOneWidget);
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(find.text('New category'), findsNothing);
    expect(find.text('Use at most 40 characters'), findsNothing);
    expect(await names(), contains(name));
  });

  testWidgets('typing stops at 40 visible characters', (tester) async {
    await pumpScreen(tester);
    await openNew(tester);

    await tester.enterText(find.byType(TextField), emojiName(41));
    await tester.pump();
    expect(fieldText(tester), emojiName(40));
    expect(find.text('40/40'), findsOneWidget);
  });

  testWidgets('a 41-character name is rejected with the length message', (
    tester,
  ) async {
    t = tester;
    // Only reachable for a name stored before the editor's limit applied.
    final long = emojiName(41);
    await real(
      () => db.categoriesDao.insertCategory(
        CategoriesCompanion.insert(name: long, iconKey: 'other', color: 0),
      ),
    );
    await pumpScreen(tester);
    await tester.tap(find.text(long));
    await tester.pumpAndSettle();
    expect(find.text('41/40'), findsOneWidget);

    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(find.text('Use at most 40 characters'), findsOneWidget);
    expect(find.text('Edit category'), findsOneWidget);
  });

  testWidgets('a name over the database code-unit cap is rejected early', (
    tester,
  ) async {
    await pumpScreen(tester);
    await openNew(tester);

    // 40 graphemes, each a letter with 30 stacked combining accents.
    final zalgo = List.filled(40, 'a${'́' * 30}').join();
    await tester.enterText(find.byType(TextField), zalgo);
    await tester.pump();
    expect(find.text('40/40'), findsOneWidget);
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(find.text('Use at most 40 characters'), findsOneWidget);
    expect(
      find.text("Couldn't save the category. Please try again."),
      findsNothing,
    );
    expect(await names(), hasLength(7));
  });
}
