import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:path/path.dart' as p;
import 'package:receipt_mind/core/db/tables/enums.dart';
import 'package:receipt_mind/features/developer/application/fixture_exporter.dart';
import 'package:receipt_mind/features/developer/developer_providers.dart';
import 'package:receipt_mind/features/developer/developer_routes.dart';
import 'package:receipt_mind/features/developer/presentation/developer_menu_button.dart';
import 'package:receipt_mind/features/developer/presentation/fixture_export_flow.dart';
import 'package:receipt_mind/features/developer/presentation/ocr_debug_screen.dart';
import 'package:receipt_mind/features/scan/application/receipt_draft.dart';
import 'package:receipt_mind/features/scan/application/scan_controller.dart';
import 'package:receipt_mind/features/scan/application/scan_state.dart';
import 'package:receipt_mind/l10n/generated/app_localizations.dart';

import 'dev_test_helpers.dart';

class FakeSharer implements FixtureSharer {
  final calls = <List<String>>[];

  @override
  Future<void> shareFiles(List<String> paths, {String? subject}) async {
    calls.add(paths);
  }
}

void main() {
  setUpAll(initializeDateFormatting);

  late Directory temp;
  late FakeSharer sharer;
  late ReviewData data;

  setUp(() {
    temp = Directory.systemTemp.createTempSync('dev_menu_test');
    sharer = FakeSharer();
    data = debugReviewData(layoutFixture('au/au_fuel_01'));
  });
  tearDown(() => temp.deleteSync(recursive: true));

  ReceiptDraft corrected() => data.draft.copyWith(
    merchant: 'Shell Parramatta',
    paymentMethod: PaymentMethod.other,
  );

  /// A review-like screen with the button in its app bar, plus the
  /// developer routes, in a localised router app.
  Future<void> pumpReview(
    WidgetTester tester, {
    bool developerMode = true,
    ScanState? scan,
  }) async {
    final overrides = [
      ...await settingsOverrides(developerMode: developerMode),
      scanControllerProvider.overrideWithValue(scan ?? ScanReview(data)),
      fixtureExporterProvider.overrideWithValue(
        FixtureExporter(tempDirectory: () async => temp, sharer: sharer),
      ),
    ];
    final router = GoRouter(
      routes: [
        GoRoute(
          path: '/',
          builder: (context, state) => Scaffold(
            appBar: AppBar(
              title: const Text('Review'),
              actions: [
                DeveloperMenuButton(
                  data: data,
                  corrected: corrected,
                  options: auOptions,
                ),
              ],
            ),
          ),
        ),
        ...developerRoutes,
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(
      ProviderScope(
        overrides: overrides,
        child: MaterialApp.router(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          routerConfig: router,
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> openMenu(WidgetTester tester) async {
    await tester.tap(find.byTooltip('Developer tools'));
    await tester.pumpAndSettle();
  }

  testWidgets('hidden when developer mode is off', (tester) async {
    await pumpReview(tester, developerMode: false);
    expect(find.byTooltip('Developer tools'), findsNothing);
    expect(find.byIcon(Icons.bug_report_outlined), findsNothing);
  });

  testWidgets('menu offers Inspect OCR and Export as fixture', (tester) async {
    await pumpReview(tester);
    expect(find.byIcon(Icons.bug_report_outlined), findsOneWidget);
    await openMenu(tester);
    expect(find.text('Inspect OCR'), findsOneWidget);
    expect(find.text('Export as fixture'), findsOneWidget);
  });

  testWidgets('Inspect OCR opens the debug screen for the scan', (
    tester,
  ) async {
    await pumpReview(tester);
    await openMenu(tester);
    await tester.tap(find.text('Inspect OCR'));
    await tester.pumpAndSettle();

    final screen = tester.widget<OcrDebugScreen>(find.byType(OcrDebugScreen));
    expect(screen.data, same(data));
    expect(screen.imagePath, data.draft.sourceImagePath);
  });

  testWidgets('the route shows a message without a scan in review', (
    tester,
  ) async {
    await pumpReview(tester, scan: const ScanIdle());
    await openMenu(tester);
    await tester.tap(find.text('Inspect OCR'));
    await tester.pumpAndSettle();
    expect(find.byType(OcrDebugScreen), findsNothing);
    expect(find.text('No scan to inspect'), findsOneWidget);
  });

  testWidgets('the route asks for developer mode when it is off', (
    tester,
  ) async {
    await tester.pumpWidget(
      scopedApp(const OcrDebugRouteScreen(), [
        ...await settingsOverrides(developerMode: false),
        scanControllerProvider.overrideWithValue(ScanReview(data)),
      ]),
    );
    await tester.pumpAndSettle();
    expect(find.byType(OcrDebugScreen), findsNothing);
    expect(
      find.text('Turn on developer mode to use this screen.'),
      findsOneWidget,
    );
  });

  testWidgets('export: Cancel in the reminder exports nothing', (tester) async {
    await pumpReview(tester);
    await openMenu(tester);
    await tester.tap(find.text('Export as fixture'));
    await tester.pumpAndSettle();

    expect(find.text('Before you share'), findsOneWidget);
    expect(find.textContaining('card numbers, names, loyalty'), findsOneWidget);
    expect(
      find.textContaining('Nothing is uploaded automatically'),
      findsOneWidget,
    );
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    expect(find.text('Before you share'), findsNothing);
    expect(sharer.calls, isEmpty);
    expect(
      Directory(p.join(temp.path, FixtureExporter.folderName)).existsSync(),
      isFalse,
    );
  });

  testWidgets('export: Continue writes and shares the corrected values', (
    tester,
  ) async {
    await pumpReview(tester);
    await openMenu(tester);
    await tester.tap(find.text('Export as fixture'));
    await tester.pumpAndSettle();

    // Default name: device region, merchant and date.
    final field = tester.widget<TextField>(find.byType(TextField));
    expect(field.controller!.text, 'au_shell_parramatta_20260721');
    await tester.enterText(find.byType(TextField), 'AU Fuel 02');

    await tester.tap(find.text('Continue'));
    // The export does real file I/O: let it run, then flush its callbacks.
    for (var i = 0; i < 100 && sharer.calls.isEmpty; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 10)),
      );
      await tester.pump();
    }
    await tester.pumpAndSettle();

    expect(find.text('Before you share'), findsNothing);
    expect(sharer.calls, hasLength(1));
    expect(
      [for (final path in sharer.calls.single) p.basename(path)],
      ['au_fuel_02.ocr.json', 'au_fuel_02.txt', 'au_fuel_02.expected.json'],
    );
    final expected = File(sharer.calls.single.last).readAsStringSync();
    expect(expected, contains('"merchant": "Shell Parramatta"'));
    expect(expected, isNot(contains('paymentMethod')));
  });

  testWidgets('export without OCR shows a message', (tester) async {
    data = const ReviewData(
      ocrFailed: true,
      draft: ReceiptDraft(
        currency: 'AUD',
        extractionMethod: ExtractionMethod.manual,
      ),
    );
    await tester.pumpWidget(
      scopedApp(
        Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () => exportFixtureWithReminder(
                context,
                data: data,
                corrected: data.draft,
                options: auOptions,
              ),
              child: const Text('go'),
            ),
          ),
        ),
        await settingsOverrides(),
      ),
    );
    await tester.tap(find.text('go'));
    await tester.pump();
    expect(find.text('This scan has no OCR result to export.'), findsOneWidget);
    expect(find.text('Before you share'), findsNothing);
  });
}
