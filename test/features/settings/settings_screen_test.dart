import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:receipt_mind/core/db/app_database.dart';
import 'package:receipt_mind/core/settings/settings_repository.dart';

import '../../helpers/test_app.dart';

void main() {
  late AppDatabase db;

  setUpAll(initializeDateFormatting);
  setUp(() => db = inMemoryDatabase());
  tearDown(() => db.close());

  Future<void> openSettings(WidgetTester tester) async {
    await tester.tap(
      find.descendant(
        of: find.byType(NavigationBar),
        matching: find.text('Settings'),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('shows locale defaults for Australia', (tester) async {
    final prefs = await inMemoryPrefs();
    await tester.pumpWidget(testApp(prefs: prefs, db: db, locale: 'en_AU'));
    await tester.pumpAndSettle();
    await openSettings(tester);

    expect(find.text(r'AUD · for example $1,234.56'), findsOneWidget);
    expect(find.textContaining('Day / month / year'), findsOneWidget);
    expect(find.text('7 categories'), findsOneWidget);
  });

  testWidgets('shows locale defaults for the United States', (tester) async {
    final prefs = await inMemoryPrefs();
    await tester.pumpWidget(testApp(prefs: prefs, db: db, locale: 'en_US'));
    await tester.pumpAndSettle();
    await openSettings(tester);

    expect(find.text(r'USD · for example $1,234.56'), findsOneWidget);
    expect(find.textContaining('Month / day / year'), findsOneWidget);
  });

  testWidgets('stored preferences override the locale', (tester) async {
    final prefs = await inMemoryPrefs({
      SettingsRepository.keyDefaultCurrency: 'EUR',
      SettingsRepository.keyDateOrder: 'ymd',
    });
    await tester.pumpWidget(testApp(prefs: prefs, db: db, locale: 'en_US'));
    await tester.pumpAndSettle();
    await openSettings(tester);

    expect(find.textContaining('EUR · for example'), findsOneWidget);
    expect(find.textContaining('Year / month / day'), findsOneWidget);
  });
}
