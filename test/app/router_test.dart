import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:receipt_mind/app/router.dart';
import 'package:receipt_mind/core/db/app_database.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../helpers/test_app.dart';

void main() {
  late SharedPreferencesWithCache prefs;
  late AppDatabase db;

  setUpAll(initializeDateFormatting);

  setUp(() async {
    prefs = await inMemoryPrefs();
    db = inMemoryDatabase();
    addTearDown(db.close);
  });

  Future<void> pumpApp(WidgetTester tester) async {
    await tester.pumpWidget(testApp(prefs: prefs, db: db));
    // Unmount before the database closes, so no query is left waiting.
    addTearDown(() => tester.pumpWidget(const SizedBox()));
    await tester.pumpAndSettle();
  }

  Future<void> go(WidgetTester tester, String location) async {
    final context = tester.element(find.byType(Navigator).first);
    ProviderScope.containerOf(context).read(routerProvider).go(location);
    await tester.pumpAndSettle();
  }

  testWidgets('an unknown location falls back to the receipt list', (
    tester,
  ) async {
    await pumpApp(tester);
    await go(tester, '/settings');
    expect(find.text('No receipts yet'), findsNothing);

    await go(tester, '/no/such/page');

    expect(tester.takeException(), isNull);
    expect(find.text('No receipts yet'), findsOneWidget);
    expect(find.textContaining('Page Not Found'), findsNothing);
  });

  testWidgets('/receipts/new opens the manual form, not a detail for "new"', (
    tester,
  ) async {
    await pumpApp(tester);
    await go(tester, '/receipts/new');

    expect(find.text('Receipt not found'), findsNothing);
    // Full screen: the bottom navigation is covered.
    expect(find.byType(NavigationBar).hitTestable(), findsNothing);
  });

  testWidgets('a deep link to an unknown receipt shows "not found"', (
    tester,
  ) async {
    await pumpApp(tester);
    await go(tester, '/receipts/unknown-id');

    expect(tester.takeException(), isNull);
    expect(find.text('Receipt not found'), findsOneWidget);
  });

  testWidgets('/dev/ocr explains that developer mode is off', (tester) async {
    await pumpApp(tester);
    await go(tester, '/dev/ocr');

    expect(tester.takeException(), isNull);
    expect(
      find.text('Turn on developer mode to use this screen.'),
      findsOneWidget,
    );
  });
}
