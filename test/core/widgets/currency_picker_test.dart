import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:receipt_mind/app/theme.dart';
import 'package:receipt_mind/core/widgets/currency_picker.dart';
import 'package:receipt_mind/l10n/generated/app_localizations.dart';

/// A button that opens the picker; the picker's result goes to [onResult].
Widget host(
  Future<Object?> Function(BuildContext) open,
  void Function(Object?) onResult, {
  ThemeMode themeMode = ThemeMode.light,
}) => MaterialApp(
  theme: AppTheme.light,
  darkTheme: AppTheme.dark,
  themeMode: themeMode,
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  home: Builder(
    builder: (context) => Scaffold(
      body: Center(
        child: FilledButton(
          onPressed: () async => onResult(await open(context)),
          child: const Text('open'),
        ),
      ),
    ),
  ),
);

void main() {
  Object? result;
  var resultSet = false;
  void record(Object? value) {
    result = value;
    resultSet = true;
  }

  setUp(() {
    result = null;
    resultSet = false;
  });

  Future<void> openPicker(
    WidgetTester tester, {
    String selected = 'USD',
    String locale = 'en_US',
  }) async {
    await tester.pumpWidget(
      host(
        (context) =>
            showCurrencyPicker(context, selected: selected, locale: locale),
        record,
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
  }

  for (final mode in [ThemeMode.light, ThemeMode.dark]) {
    testWidgets('the settings picker meets the accessibility guidelines in '
        '${mode.name} mode', (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(
        host(
          (context) => showDefaultCurrencyPicker(
            context,
            selected: 'AUD',
            locale: 'en_AU',
            deviceDefault: 'AUD',
            followsDevice: true,
          ),
          record,
          themeMode: mode,
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'a');
      await tester.pumpAndSettle();

      await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
      await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
      await expectLater(tester, meetsGuideline(textContrastGuideline));
      handle.dispose();
    });
  }

  testWidgets('lists currencies with a localised example amount', (
    tester,
  ) async {
    await openPicker(tester, locale: 'en_AU', selected: 'AUD');

    expect(find.text('Choose currency'), findsOneWidget);
    expect(find.text('AED'), findsOneWidget);
    // The region's own currency uses the local symbol.
    final aud = find.byKey(const ValueKey('currency-AUD'));
    expect(
      find.descendant(of: aud, matching: find.text(r'$1,234.56')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: aud, matching: find.byIcon(Icons.check)),
      findsOneWidget,
    );
    expect(find.byIcon(Icons.check), findsOneWidget);
  });

  testWidgets('filters by code, ignoring case, and returns the code', (
    tester,
  ) async {
    await openPicker(tester);

    await tester.enterText(find.byType(TextField), 'kw');
    await tester.pumpAndSettle();
    expect(find.text('KWD'), findsOneWidget);
    expect(find.text('USD'), findsNothing);
    // 3 decimals for the Kuwaiti dinar: 123456 fils.
    expect(find.textContaining('123.456'), findsOneWidget);

    await tester.tap(find.text('KWD'));
    await tester.pumpAndSettle();
    expect(result, 'KWD');
    expect(find.text('Choose currency'), findsNothing);
  });

  testWidgets('filters by symbol', (tester) async {
    await openPicker(tester);

    await tester.enterText(find.byType(TextField), '€');
    await tester.pumpAndSettle();
    expect(find.text('EUR'), findsOneWidget);
    expect(find.byType(ListTile), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'rs');
    await tester.pumpAndSettle();
    expect(find.text('LKR'), findsOneWidget);
    expect(find.text('PKR'), findsOneWidget);
  });

  testWidgets('shows a message when nothing matches; clear restores', (
    tester,
  ) async {
    await openPicker(tester);

    await tester.enterText(find.byType(TextField), 'zzz');
    await tester.pumpAndSettle();
    expect(find.text('No matching currency'), findsOneWidget);

    await tester.tap(find.byTooltip('Clear search'));
    await tester.pumpAndSettle();
    expect(find.text('No matching currency'), findsNothing);
    expect(find.text('AED'), findsOneWidget);
  });

  testWidgets('closing the sheet returns null', (tester) async {
    await openPicker(tester);

    await tester.tapAt(const Offset(400, 10));
    await tester.pumpAndSettle();
    expect(resultSet, isTrue);
    expect(result, isNull);
  });

  testWidgets('a code without data still shows as selected', (tester) async {
    await openPicker(tester, selected: 'XAF');

    final xaf = find.byKey(const ValueKey('currency-XAF'));
    expect(xaf, findsOneWidget);
    expect(
      find.descendant(of: xaf, matching: find.byIcon(Icons.check)),
      findsOneWidget,
    );
  });

  group('showDefaultCurrencyPicker', () {
    Future<void> openDefault(
      WidgetTester tester, {
      required bool followsDevice,
    }) async {
      await tester.pumpWidget(
        host(
          (context) => showDefaultCurrencyPicker(
            context,
            selected: followsDevice ? 'AUD' : 'EUR',
            locale: 'en_AU',
            deviceDefault: 'AUD',
            followsDevice: followsDevice,
          ),
          record,
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
    }

    testWidgets('offers the device default first', (tester) async {
      await openDefault(tester, followsDevice: false);

      expect(find.text('Use device default'), findsOneWidget);
      expect(find.text(r'AUD · for example $1,234.56'), findsOneWidget);
      // EUR is the current choice, not the device default.
      final eur = find.byKey(const ValueKey('currency-EUR'));
      await tester.scrollUntilVisible(
        eur,
        200,
        scrollable: find
            .descendant(
              of: find.byType(ListView),
              matching: find.byType(Scrollable),
            )
            .first,
      );
      expect(
        find.descendant(of: eur, matching: find.byIcon(Icons.check)),
        findsOneWidget,
      );

      await tester.scrollUntilVisible(
        find.text('Use device default'),
        -200,
        scrollable: find
            .descendant(
              of: find.byType(ListView),
              matching: find.byType(Scrollable),
            )
            .first,
      );
      await tester.tap(find.text('Use device default'));
      await tester.pumpAndSettle();
      expect((result! as CurrencyChoice).isDeviceDefault, isTrue);
    });

    testWidgets('ticks the device default when it is in use', (tester) async {
      await openDefault(tester, followsDevice: true);

      final tile = find.ancestor(
        of: find.text('Use device default'),
        matching: find.byType(ListTile),
      );
      expect(
        find.descendant(of: tile, matching: find.byIcon(Icons.check)),
        findsOneWidget,
      );
      expect(find.byIcon(Icons.check), findsOneWidget);
    });

    testWidgets('hides the device default while searching', (tester) async {
      await openDefault(tester, followsDevice: true);

      await tester.enterText(find.byType(TextField), 'nzd');
      await tester.pumpAndSettle();
      expect(find.text('Use device default'), findsNothing);

      await tester.tap(find.text('NZD'));
      await tester.pumpAndSettle();
      expect((result! as CurrencyChoice).code, 'NZD');
    });
  });
}
