import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:package_info_plus/package_info_plus.dart';
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
    expect(find.text('About ReceiptMind'), findsOneWidget);

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

  testWidgets('about dialog shows the license line', (tester) async {
    await pumpApp(tester);
    await tester.tap(navItem('Settings'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('About ReceiptMind'));
    await tester.pumpAndSettle();

    expect(find.textContaining('Apache License 2.0'), findsOneWidget);
    expect(find.text('0.1.0'), findsOneWidget);
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
}
