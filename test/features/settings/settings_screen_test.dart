import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:receipt_mind/app/theme.dart';
import 'package:receipt_mind/core/clock.dart';
import 'package:receipt_mind/core/date/date_display.dart';
import 'package:receipt_mind/core/date/local_date.dart';
import 'package:receipt_mind/core/db/app_database.dart';
import 'package:receipt_mind/core/db/db_providers.dart';
import 'package:receipt_mind/core/settings/settings_providers.dart';
import 'package:receipt_mind/core/settings/settings_repository.dart';
import 'package:receipt_mind/features/export/export_service.dart';
import 'package:receipt_mind/features/settings/presentation/about_screen.dart';
import 'package:receipt_mind/features/settings/presentation/app_info_provider.dart';
import 'package:receipt_mind/features/settings/presentation/settings_routes.dart';
import 'package:receipt_mind/features/settings/presentation/settings_screen.dart';
import 'package:receipt_mind/l10n/generated/app_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../helpers/test_app.dart';

class FakeFileSharer implements FileSharer {
  final paths = <String>[];

  @override
  Future<void> shareFile(
    String path, {
    required String mimeType,
    String? subject,
  }) async => paths.add(path);
}

/// Settings with its child routes in a local router, themed like the app.
class _SettingsApp extends ConsumerWidget {
  const _SettingsApp({required this.router});

  final GoRouter router;

  @override
  Widget build(BuildContext context, WidgetRef ref) => MaterialApp.router(
    theme: AppTheme.light,
    darkTheme: AppTheme.dark,
    themeMode: ref.watch(settingsControllerProvider.select((s) => s.themeMode)),
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    routerConfig: router,
  );
}

void main() {
  late AppDatabase db;
  late FakeFileSharer sharer;
  late List<ReceiptRow> receipts;
  late Directory temp;
  late DateTime now;

  setUpAll(initializeDateFormatting);
  setUp(() {
    db = inMemoryDatabase();
    sharer = FakeFileSharer();
    receipts = [];
    now = DateTime(2026, 11, 16, 9);
    temp = Directory.systemTemp.createTempSync('settings_test');
  });
  tearDown(() async {
    await db.close();
    temp.deleteSync(recursive: true);
  });

  GoRouter router({bool withCategories = false}) => GoRouter(
    initialLocation: '/settings',
    routes: [
      GoRoute(
        path: '/settings',
        builder: (context, state) => const SettingsScreen(),
        routes: [
          ...settingsChildRoutes,
          if (withCategories)
            GoRoute(
              path: 'categories',
              builder: (context, state) =>
                  const Scaffold(body: Text('Categories screen')),
            ),
        ],
      ),
    ],
  );

  Future<SharedPreferencesWithCache> pumpSettings(
    WidgetTester tester, {
    String locale = 'en_US',
    Map<String, Object> stored = const {},
    bool withCategories = false,
    Size size = const Size(1080, 2400),
    double devicePixelRatio = 1,
  }) async {
    // Tall enough that every settings tile is built.
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = devicePixelRatio;
    addTearDown(tester.view.reset);
    final prefs = await inMemoryPrefs(stored);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          deviceLocaleProvider.overrideWithValue(locale),
          appDatabaseProvider.overrideWithValue(db),
          clockProvider.overrideWithValue(() => now),
          appVersionProvider.overrideWithValue(
            const AsyncData(AppVersion('0.1.0', '1')),
          ),
          exportServiceProvider.overrideWithValue(
            ExportService(
              loadReceipts: ({from, to}) async => receipts,
              loadCategoryNames: () async => {},
              tempDirectory: () async => temp,
              sharer: sharer,
            ),
          ),
        ],
        child: _SettingsApp(router: router(withCategories: withCategories)),
      ),
    );
    await tester.pumpAndSettle();
    return prefs;
  }

  Future<void> tapTile(WidgetTester tester, String title) async {
    final finder = find.text(title);
    await tester.ensureVisible(finder);
    await tester.pumpAndSettle();
    await tester.tap(finder);
    await tester.pumpAndSettle();
  }

  Finder inDialog(Finder finder) =>
      find.descendant(of: find.byType(Dialog), matching: finder);

  final today = LocalDate.fromDateTime(DateTime.now());

  group('locale defaults (real app)', () {
    Future<void> openSettings(WidgetTester tester) async {
      await tester.tap(
        find.descendant(
          of: find.byType(NavigationBar),
          matching: find.text('Settings'),
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('Australia', (tester) async {
      final prefs = await inMemoryPrefs();
      await tester.pumpWidget(testApp(prefs: prefs, db: db, locale: 'en_AU'));
      await tester.pumpAndSettle();
      await openSettings(tester);

      expect(
        find.text(r'Device default · AUD · for example $1,234.56'),
        findsOneWidget,
      );
      expect(
        find.text(
          'Auto (Day / month / year) · '
          '${formatNumericDate(today, DateOrder.dmy)}',
        ),
        findsOneWidget,
      );
      expect(find.text('7 categories'), findsOneWidget);
    });

    testWidgets('United States', (tester) async {
      final prefs = await inMemoryPrefs();
      await tester.pumpWidget(testApp(prefs: prefs, db: db, locale: 'en_US'));
      await tester.pumpAndSettle();
      await openSettings(tester);

      expect(
        find.text(r'Device default · USD · for example $1,234.56'),
        findsOneWidget,
      );
      expect(find.textContaining('Auto (Month / day / year)'), findsOneWidget);
    });
  });

  testWidgets('stored preferences override the locale', (tester) async {
    await pumpSettings(
      tester,
      stored: {
        SettingsRepository.keyDefaultCurrency: 'EUR',
        SettingsRepository.keyDateOrder: 'ymd',
      },
    );

    expect(find.text('EUR · for example €1,234.56'), findsOneWidget);
    expect(
      find.text(
        'Year / month / day · ${formatNumericDate(today, DateOrder.ymd)}',
      ),
      findsOneWidget,
    );
    expect(find.textContaining('Auto'), findsNothing);
  });

  testWidgets('theme switch applies at once and persists', (tester) async {
    final prefs = await pumpSettings(tester);
    BuildContext screen() => tester.element(find.byType(SettingsScreen));

    expect(find.text('System default'), findsOneWidget);
    expect(Theme.of(screen()).brightness, Brightness.light);

    await tapTile(tester, 'Theme');
    expect(inDialog(find.byType(RadioListTile<ThemeMode>)), findsNWidgets(3));
    await tester.tap(inDialog(find.text('Dark')));
    await tester.pumpAndSettle();

    expect(find.byType(Dialog), findsNothing);
    expect(find.text('Dark'), findsOneWidget);
    expect(Theme.of(screen()).brightness, Brightness.dark);
    expect(prefs.getString(SettingsRepository.keyThemeMode), 'dark');

    await tapTile(tester, 'Theme');
    await tester.tap(inDialog(find.text('Light')));
    await tester.pumpAndSettle();
    expect(Theme.of(screen()).brightness, Brightness.light);
    expect(prefs.getString(SettingsRepository.keyThemeMode), 'light');
  });

  testWidgets('currency picker sets and resets the default currency', (
    tester,
  ) async {
    final prefs = await pumpSettings(tester, locale: 'en_AU');

    await tapTile(tester, 'Default currency');
    await tester.enterText(find.byType(TextField), 'nzd');
    await tester.pumpAndSettle();
    await tester.tap(find.text('NZD'));
    await tester.pumpAndSettle();

    expect(find.text(r'NZD · for example NZ$1,234.56'), findsOneWidget);
    expect(prefs.getString(SettingsRepository.keyDefaultCurrency), 'NZD');

    await tapTile(tester, 'Default currency');
    await tester.tap(find.text('Use device default'));
    await tester.pumpAndSettle();

    expect(
      find.text(r'Device default · AUD · for example $1,234.56'),
      findsOneWidget,
    );
    expect(prefs.getString(SettingsRepository.keyDefaultCurrency), isNull);
  });

  testWidgets('date format: fixed order and back to Auto', (tester) async {
    final prefs = await pumpSettings(tester, locale: 'en_AU');

    await tapTile(tester, 'Date format');
    // Auto plus the three orders, each with today's date as an example.
    expect(
      inDialog(find.byWidgetPredicate((w) => w is RadioListTile)),
      findsNWidgets(4),
    );
    expect(
      inDialog(
        find.text(
          'Auto (Day / month / year) · '
          '${formatNumericDate(today, DateOrder.dmy)}',
        ),
      ),
      findsOneWidget,
    );
    final ymd =
        'Year / month / day · ${formatNumericDate(today, DateOrder.ymd)}';
    await tester.tap(inDialog(find.text(ymd)));
    await tester.pumpAndSettle();

    expect(find.text(ymd), findsOneWidget);
    expect(prefs.getString(SettingsRepository.keyDateOrder), 'ymd');

    await tapTile(tester, 'Date format');
    await tester.tap(inDialog(find.textContaining('Auto (')));
    await tester.pumpAndSettle();

    expect(find.textContaining('Auto (Day / month / year)'), findsOneWidget);
    expect(prefs.getString(SettingsRepository.keyDateOrder), isNull);
  });

  testWidgets('7 taps on the version turn developer mode on', (tester) async {
    final prefs = await pumpSettings(tester);
    final version = find.text('0.1.0 (1)');
    await tester.ensureVisible(version);
    await tester.pumpAndSettle();

    for (var i = 0; i < 6; i++) {
      await tester.tap(version);
      await tester.pump();
    }
    expect(find.text('Developer mode is on'), findsNothing);
    expect(find.byType(SwitchListTile), findsNothing);

    await tester.tap(version);
    await tester.pumpAndSettle();
    expect(find.text('Developer mode is on'), findsOneWidget);
    expect(prefs.getBool(SettingsRepository.keyDeveloperMode), isTrue);

    final toggle = find.widgetWithText(SwitchListTile, 'Developer mode');
    await tester.ensureVisible(toggle);
    await tester.pumpAndSettle();
    expect(toggle, findsOneWidget);

    await tester.tap(toggle);
    await tester.pumpAndSettle();
    expect(find.byType(SwitchListTile), findsNothing);
    expect(prefs.getBool(SettingsRepository.keyDeveloperMode), isFalse);
  });

  testWidgets('7 more taps while on say it is already on', (tester) async {
    await pumpSettings(
      tester,
      stored: {SettingsRepository.keyDeveloperMode: true},
    );
    final version = find.text('0.1.0 (1)');
    await tester.ensureVisible(version);
    await tester.pumpAndSettle();
    for (var i = 0; i < 7; i++) {
      await tester.tap(version);
      await tester.pump();
    }
    await tester.pumpAndSettle();
    expect(find.text('Developer mode is already on'), findsOneWidget);
  });

  testWidgets('a pause between version taps starts the count again', (
    tester,
  ) async {
    final prefs = await pumpSettings(tester);
    final version = find.text('0.1.0 (1)');
    await tester.ensureVisible(version);
    await tester.pumpAndSettle();

    for (var i = 0; i < 6; i++) {
      await tester.tap(version);
      await tester.pump();
    }
    // Back later: the six earlier taps no longer count.
    now = now.add(const Duration(minutes: 1));
    await tester.tap(version);
    await tester.pumpAndSettle();
    expect(find.text('Developer mode is on'), findsNothing);
    expect(prefs.getBool(SettingsRepository.keyDeveloperMode), isNot(isTrue));

    for (var i = 0; i < 6; i++) {
      now = now.add(const Duration(milliseconds: 400));
      await tester.tap(version);
      await tester.pump();
    }
    await tester.pumpAndSettle();
    expect(find.text('Developer mode is on'), findsOneWidget);
    expect(prefs.getBool(SettingsRepository.keyDeveloperMode), isTrue);
  });

  testWidgets('a date-order change reaches the date format tile at once', (
    tester,
  ) async {
    await pumpSettings(tester);
    await tapTile(tester, 'Date format');
    await tester.tap(inDialog(find.textContaining('Year / month / day')));
    await tester.pumpAndSettle();

    expect(
      find.textContaining(formatNumericDate(today, DateOrder.ymd)),
      findsOneWidget,
    );
  });

  group('accessibility', () {
    for (final mode in ['light', 'dark']) {
      testWidgets('settings meets the guidelines in $mode mode', (
        tester,
      ) async {
        final handle = tester.ensureSemantics();
        await pumpSettings(
          tester,
          stored: {
            SettingsRepository.keyThemeMode: mode,
            SettingsRepository.keyDeveloperMode: true,
          },
        );

        await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
        await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
        await expectLater(tester, meetsGuideline(textContrastGuideline));
        handle.dispose();
      });

      testWidgets('About meets the guidelines in $mode mode', (tester) async {
        final handle = tester.ensureSemantics();
        await pumpSettings(
          tester,
          stored: {SettingsRepository.keyThemeMode: mode},
        );
        await tapTile(tester, 'About & privacy');

        await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
        await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
        await expectLater(tester, meetsGuideline(textContrastGuideline));
        handle.dispose();
      });
    }

    testWidgets('settings, its dialogs and About fit a phone at 200 % text', (
      tester,
    ) async {
      tester.platformDispatcher.textScaleFactorTestValue = 2.0;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      await pumpSettings(
        tester,
        size: const Size(1080, 1920),
        devicePixelRatio: 2.625,
        stored: {SettingsRepository.keyDeveloperMode: true},
      );
      expect(tester.takeException(), isNull);
      await tester.drag(find.byType(ListView), const Offset(0, -3000));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.drag(find.byType(ListView), const Offset(0, 3000));
      await tester.pumpAndSettle();

      // The list is lazy and long at 200 %: scroll from the top to each tile.
      Future<void> open(String tile) async {
        await tester.drag(find.byType(ListView), const Offset(0, 3000));
        await tester.pumpAndSettle();
        await tester.scrollUntilVisible(
          find.text(tile),
          200,
          scrollable: find.byType(Scrollable).first,
        );
        await tester.pumpAndSettle();
        await tester.tap(find.text(tile));
        await tester.pumpAndSettle();
      }

      for (final tile in [
        'Theme',
        'Default currency',
        'Date format',
        'Export to CSV',
      ]) {
        await open(tile);
        expect(tester.takeException(), isNull, reason: tile);
        final popup = find.byWidgetPredicate(
          (w) => w is Dialog || w is BottomSheet,
        );
        expect(popup, findsOneWidget, reason: tile);
        // Close the dialog or sheet by tapping the barrier.
        await tester.tapAt(const Offset(4, 4));
        await tester.pumpAndSettle();
        expect(popup, findsNothing, reason: tile);
      }

      await open('About & privacy');
      expect(tester.takeException(), isNull);
      await tester.drag(find.byType(ListView), const Offset(0, -3000));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  });

  testWidgets('categories tile opens the categories route when it exists', (
    tester,
  ) async {
    await pumpSettings(tester, withCategories: true);
    await tapTile(tester, 'Categories');
    expect(find.text('Categories screen'), findsOneWidget);
  });

  testWidgets('categories tile is inert without the route', (tester) async {
    await pumpSettings(tester);
    final tile = tester.widget<ListTile>(
      find.widgetWithText(ListTile, 'Categories'),
    );
    expect(tile.onTap, isNull);
  });

  group('export', () {
    Future<void> exportAll(WidgetTester tester) async {
      await tapTile(tester, 'Export to CSV');
      expect(find.text('Export receipts'), findsOneWidget);
      await tester.tap(find.text('All receipts'));
      // Not pumpAndSettle: a spinner runs while the export is busy.
      await tester.pump();
      await tester.pump();
    }

    testWidgets('no receipts: a snack bar and no share sheet', (tester) async {
      await pumpSettings(tester);
      await exportAll(tester);
      await tester.pumpAndSettle();

      expect(find.text('No receipts to export'), findsOneWidget);
      expect(sharer.paths, isEmpty);
    });

    testWidgets('shares the CSV file', (tester) async {
      receipts = [
        ReceiptRow(
          id: 'r1',
          merchant: 'Coles',
          purchaseDate: LocalDate(2026, 11, 3),
          totalMinor: 1250,
          currency: 'AUD',
          extractionMethod: ExtractionMethod.rules,
          createdAt: DateTime.utc(2026, 11, 3),
          updatedAt: DateTime.utc(2026, 11, 3),
        ),
      ];
      await pumpSettings(tester);
      await exportAll(tester);
      // Writing the file is real I/O: let it run, then flush the UI.
      for (var i = 0; i < 50 && sharer.paths.isEmpty; i++) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 10)),
        );
        await tester.pump();
      }
      await tester.pumpAndSettle();

      expect(sharer.paths, hasLength(1));
      expect(sharer.paths.single, endsWith('.csv'));
      expect(find.text('No receipts to export'), findsNothing);
    });

    testWidgets('cancelling the date range exports nothing', (tester) async {
      await pumpSettings(tester);
      await tapTile(tester, 'Export to CSV');
      await tester.tap(find.text('Choose dates…'));
      await tester.pumpAndSettle();
      expect(find.byType(DateRangePickerDialog), findsOneWidget);

      await tester.tap(find.byType(CloseButton));
      await tester.pumpAndSettle();
      expect(find.byType(DateRangePickerDialog), findsNothing);
      expect(find.text('No receipts to export'), findsNothing);
      expect(sharer.paths, isEmpty);
    });
  });

  group('About & privacy', () {
    testWidgets('shows the privacy statement and the licenses', (tester) async {
      await pumpSettings(tester);
      await tapTile(tester, 'About & privacy');

      expect(find.byType(AboutScreen), findsOneWidget);
      expect(find.text('ReceiptMind'), findsOneWidget);
      expect(find.text('Version 0.1.0 (1)'), findsOneWidget);
      expect(
        find.text('Your receipts never leave this phone.'),
        findsOneWidget,
      );
      for (final fact in [
        'stored only on this device',
        'no internet permission',
        'cloud backup is turned off',
        'No analytics and no crash reporting',
        'Google ML Kit on this device',
      ]) {
        expect(find.textContaining(fact), findsOneWidget, reason: fact);
      }

      final licenses = find.text('Open-source licenses');
      await tester.ensureVisible(licenses);
      await tester.pumpAndSettle();
      expect(find.textContaining('Apache License 2.0'), findsOneWidget);
      await tester.tap(licenses);
      // The license list loads in the background (spinner), so don't settle.
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      expect(find.byType(LicensePage), findsOneWidget);
    });

    testWidgets('back returns to Settings', (tester) async {
      await pumpSettings(tester);
      await tapTile(tester, 'About & privacy');
      await tester.tap(find.byType(BackButton));
      await tester.pumpAndSettle();
      expect(find.byType(AboutScreen), findsNothing);
      expect(find.text('Theme'), findsOneWidget);
    });
  });
}
