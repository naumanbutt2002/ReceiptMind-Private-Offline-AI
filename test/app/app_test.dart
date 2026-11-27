import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:receipt_mind/core/date/local_date.dart';
import 'package:receipt_mind/core/db/app_database.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../helpers/test_app.dart';

Finder navItem(String label) =>
    find.descendant(of: find.byType(NavigationBar), matching: find.text(label));

void main() {
  late SharedPreferencesWithCache prefs;
  late AppDatabase db;

  setUpAll(initializeDateFormatting);

  setUp(() async {
    prefs = await inMemoryPrefs();
    db = inMemoryDatabase();
    addTearDown(db.close);
    PackageInfo.setMockInitialValues(
      appName: 'ReceiptMind',
      packageName: 'io.github.naumanbutt2002.receiptmind',
      version: '0.1.0',
      buildNumber: '1',
      buildSignature: '',
    );
  });

  Future<void> pumpApp(WidgetTester tester) async {
    await tester.pumpWidget(testApp(prefs: prefs, db: db));
    // Unmount before the database closes, so no query is left waiting.
    addTearDown(() => tester.pumpWidget(const SizedBox()));
    await tester.pumpAndSettle();
  }

  testWidgets('starts on the receipt list with the empty state', (
    tester,
  ) async {
    await pumpApp(tester);

    expect(find.text('ReceiptMind'), findsOneWidget);
    expect(find.text('No receipts yet'), findsOneWidget);
  });

  testWidgets('bottom navigation switches to settings and back', (
    tester,
  ) async {
    await pumpApp(tester);

    await tester.tap(navItem('Settings'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('About & privacy'), 200);
    expect(find.text('About & privacy'), findsOneWidget);

    await tester.tap(navItem('Receipts'));
    await tester.pumpAndSettle();
    expect(find.text('No receipts yet'), findsOneWidget);
  });

  testWidgets('system back on settings returns to receipts', (tester) async {
    await pumpApp(tester);
    await tester.tap(navItem('Settings'));
    await tester.pumpAndSettle();

    final handled = await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();

    expect(handled, isTrue);
    expect(find.text('No receipts yet'), findsOneWidget);
  });

  testWidgets('about & privacy shows the license line and version', (
    tester,
  ) async {
    await pumpApp(tester);
    await tester.tap(navItem('Settings'));
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(find.text('About & privacy'), 200);
    await tester.tap(find.text('About & privacy'));
    await tester.pumpAndSettle();

    expect(find.textContaining('0.1.0'), findsWidgets);
    await tester.scrollUntilVisible(
      find.textContaining('Apache License 2.0'),
      200,
      scrollable: find.byType(Scrollable).last,
    );
    expect(find.textContaining('Apache License 2.0'), findsWidgets);
  });

  testWidgets('empty state fits a landscape phone at 200 % text size', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(2400, 1080);
    tester.view.devicePixelRatio = 2.625;
    tester.platformDispatcher.textScaleFactorTestValue = 2.0;
    addTearDown(tester.view.reset);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

    await pumpApp(tester);

    expect(tester.takeException(), isNull);
    expect(find.text('No receipts yet'), findsOneWidget);
  });

  testWidgets('follows the platform dark mode', (tester) async {
    tester.platformDispatcher.platformBrightnessTestValue = Brightness.dark;
    addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);

    await pumpApp(tester);

    final context = tester.element(find.text('No receipts yet'));
    expect(Theme.of(context).brightness, Brightness.dark);
  });

  testWidgets('deleting the filtered category in Settings resets the list '
      'filter to All', (tester) async {
    final dining = (await db.select(db.categories).get()).firstWhere(
      (c) => c.name == 'Dining',
    );
    for (final (id, merchant, categoryId) in [
      ('a', 'Pizza Place', dining.id),
      ('b', 'Hardware Hut', null),
    ]) {
      await db.receiptsDao.insertReceipt(
        ReceiptsCompanion.insert(
          id: id,
          merchant: merchant,
          purchaseDate: LocalDate(2026, 9, 20),
          totalMinor: 1000,
          currency: 'USD',
          categoryId: Value(categoryId),
          extractionMethod: ExtractionMethod.manual,
          createdAt: DateTime(2026, 9, 20),
          updatedAt: DateTime(2026, 9, 20),
        ),
      );
    }
    await pumpApp(tester);

    await tester.tap(find.byKey(ValueKey('list-filter-${dining.id}')));
    await tester.pumpAndSettle();
    expect(find.text('Hardware Hut'), findsNothing);

    await tester.tap(navItem('Settings'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Categories'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('More options for Dining'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Delete'));
    await tester.pumpAndSettle();

    await tester.tap(navItem('Receipts'));
    await tester.pumpAndSettle();
    expect(find.text('Pizza Place'), findsOneWidget);
    expect(find.text('Hardware Hut'), findsOneWidget);
    expect(find.text('No matching receipts'), findsNothing);
    expect(
      tester
          .widget<ChoiceChip>(find.byKey(const Key('list-filter-all')))
          .selected,
      isTrue,
    );
    // Let the "Deleted" snack bar time out.
    await tester.pump(const Duration(seconds: 10));
    await tester.pumpAndSettle();
  });

  for (final brightness in Brightness.values) {
    testWidgets('the app shell meets the accessibility guidelines '
        '(${brightness.name})', (tester) async {
      tester.platformDispatcher.platformBrightnessTestValue = brightness;
      addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);
      final handle = tester.ensureSemantics();
      await pumpApp(tester);

      await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
      await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
      await expectLater(tester, meetsGuideline(textContrastGuideline));

      await tester.tap(navItem('Settings'));
      await tester.pumpAndSettle();
      await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
      await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
      await expectLater(tester, meetsGuideline(textContrastGuideline));
      handle.dispose();
    });
  }
}
