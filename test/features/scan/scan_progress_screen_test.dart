import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:receipt_mind/core/clock.dart';
import 'package:receipt_mind/core/db/tables/enums.dart';
import 'package:receipt_mind/core/settings/settings_providers.dart';
import 'package:receipt_mind/features/receipts/data/receipts_providers.dart';
import 'package:receipt_mind/features/scan/application/receipt_draft.dart';
import 'package:receipt_mind/features/scan/application/scan_controller.dart';
import 'package:receipt_mind/features/scan/application/scan_state.dart';
import 'package:receipt_mind/features/scan/capture/document_scanner.dart';
import 'package:receipt_mind/features/scan/presentation/scan_progress_screen.dart';
import 'package:receipt_mind/features/scan/scan_providers.dart';
import 'package:receipt_mind/features/scan/scan_routes.dart';
import 'package:receipt_mind/l10n/generated/app_localizations.dart';

import '../../helpers/scan_fakes.dart';
import '../../helpers/test_app.dart';

/// Records [start] calls and lets the test set any state.
class _FakeScanController extends ScanController {
  final List<ScanSource> starts = [];
  int resets = 0;

  @override
  ScanState build() => const ScanIdle();

  @override
  Future<void> start(ScanSource source) async {
    starts.add(source);
    state = ScanCapturing(source);
  }

  @override
  void reset() {
    resets++;
    state = const ScanIdle();
  }

  void emit(ScanState next) => state = next;

  ScanState get current => state;
}

const _review = ScanReview(
  ReviewData(
    draft: ReceiptDraft(
      currency: 'AUD',
      extractionMethod: ExtractionMethod.manual,
    ),
  ),
);

GoRouter _router() => GoRouter(
  initialLocation: '/receipts',
  routes: [
    GoRoute(
      path: '/receipts',
      builder: (_, _) => const Scaffold(body: Text('receipts page')),
      routes: [
        GoRoute(
          path: 'new',
          builder: (_, _) => const Scaffold(body: Text('manual page')),
        ),
      ],
    ),
    ...scanRoutes,
    GoRoute(
      path: ScanRoutes.review,
      builder: (_, _) => const Scaffold(body: Text('review page')),
    ),
  ],
);

Widget _app(
  GoRouter router,
  _FakeScanController controller, {
  double textScale = 1,
}) => ProviderScope(
  overrides: [scanControllerProvider.overrideWith(() => controller)],
  child: _material(router, textScale),
);

Widget _material(GoRouter router, [double textScale = 1]) => MaterialApp.router(
  routerConfig: router,
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  builder: (context, child) => MediaQuery(
    data: MediaQuery.of(context)
        .copyWith(textScaler: TextScaler.linear(textScale)),
    child: child!,
  ),
);

/// Opens the receipts page, then pushes the scan screen for [source].
Future<(GoRouter, _FakeScanController)> _openScan(
  WidgetTester tester, {
  ScanSource source = ScanSource.camera,
  double textScale = 1,
}) async {
  final router = _router();
  addTearDown(router.dispose);
  final controller = _FakeScanController();
  await tester.pumpWidget(_app(router, controller, textScale: textScale));
  unawaited(router.push(ScanRoutes.scanFrom(source)));
  await _pumpRoute(tester);
  return (router, controller);
}

/// Finishes a route transition. The scan screen's progress indicator never
/// stops, so `pumpAndSettle` can't be used while it is visible.
Future<void> _pumpRoute(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(seconds: 1));
}

void main() {
  testWidgets('starts the scan once with the source from the route', (
    tester,
  ) async {
    final (_, controller) = await _openScan(tester, source: ScanSource.gallery);

    expect(controller.starts, [ScanSource.gallery]);
    expect(find.text('Opening scanner…'), findsOneWidget);

    await tester.pump(const Duration(seconds: 1));
    expect(controller.starts, hasLength(1));
  });

  testWidgets('the source defaults to the camera', (tester) async {
    final router = _router();
    addTearDown(router.dispose);
    final controller = _FakeScanController();
    await tester.pumpWidget(_app(router, controller));
    unawaited(router.push('/scan'));
    await _pumpRoute(tester);

    expect(controller.starts, [ScanSource.camera]);
  });

  testWidgets('shows progress while reading', (tester) async {
    final (_, controller) = await _openScan(tester);

    controller.emit(const ScanReading('/tmp/scan.jpg'));
    await tester.pump();

    expect(find.text('Reading receipt…'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });

  testWidgets('replaces itself with the review screen', (tester) async {
    final (router, controller) = await _openScan(tester);

    controller
      ..emit(const ScanReading('/tmp/scan.jpg'))
      ..emit(_review);
    await tester.pumpAndSettle();

    expect(find.text('review page'), findsOneWidget);
    expect(find.byType(ScanProgressScreen), findsNothing);
    expect(controller.resets, 0);

    // Back from review skips the progress screen.
    router.pop();
    await tester.pumpAndSettle();
    expect(find.text('receipts page'), findsOneWidget);
  });

  testWidgets('a cancelled scan goes back', (tester) async {
    final (_, controller) = await _openScan(tester);

    controller.emit(const ScanIdle());
    await tester.pumpAndSettle();

    expect(find.text('receipts page'), findsOneWidget);
    expect(find.byType(ScanProgressScreen), findsNothing);
  });

  testWidgets('a cancelled scan opened with go() lands on the receipts', (
    tester,
  ) async {
    final router = _router();
    addTearDown(router.dispose);
    final controller = _FakeScanController();
    await tester.pumpWidget(_app(router, controller));
    router.go(ScanRoutes.scanFrom(ScanSource.camera));
    await _pumpRoute(tester);

    controller.emit(const ScanIdle());
    await tester.pumpAndSettle();

    expect(find.text('receipts page'), findsOneWidget);
  });

  testWidgets('the close button cancels the scan', (tester) async {
    final (_, controller) = await _openScan(tester);
    controller.emit(const ScanReading('/tmp/scan.jpg'));
    await tester.pump();

    await tester.tap(find.byTooltip('Cancel scan'));
    await tester.pumpAndSettle();

    expect(controller.resets, greaterThanOrEqualTo(1));
    expect(controller.current, isA<ScanIdle>());
    expect(find.text('receipts page'), findsOneWidget);
  });

  testWidgets('Back while reading drops the scan', (tester) async {
    final (_, controller) = await _openScan(tester);
    controller.emit(const ScanReading('/tmp/scan.jpg'));
    await tester.pump();

    final navigator = tester.state<NavigatorState>(
      find.byType(Navigator).first,
    );
    await navigator.maybePop();
    await tester.pumpAndSettle();

    expect(controller.current, isA<ScanIdle>());
    expect(find.text('receipts page'), findsOneWidget);
  });

  testWidgets('permission denied explains and offers Try again', (
    tester,
  ) async {
    final (_, controller) = await _openScan(tester);

    controller.emit(
      const ScanFailed(ScanFailure(ScanFailureReason.permissionDenied)),
    );
    await tester.pump();

    expect(find.text('Camera access is off'), findsOneWidget);
    expect(find.textContaining("phone's settings"), findsOneWidget);

    await tester.tap(find.text('Try again'));
    await tester.pump();
    expect(controller.starts, [ScanSource.camera, ScanSource.camera]);
    expect(find.text('Opening scanner…'), findsOneWidget);
  });

  testWidgets('a double tap on Try again opens the scanner once', (
    tester,
  ) async {
    final (_, controller) = await _openScan(tester);
    controller.emit(const ScanFailed(ScanFailure(ScanFailureReason.other)));
    await tester.pump();

    // Two taps before the next frame: the second sees a running scan.
    final tryAgain = find.text('Try again');
    await tester.tap(tryAgain);
    await tester.tap(tryAgain, warnIfMissed: false);
    await tester.pump();

    expect(controller.starts, [ScanSource.camera, ScanSource.camera]);
  });

  testWidgets('permission denied for the gallery talks about photos', (
    tester,
  ) async {
    final (_, controller) = await _openScan(tester, source: ScanSource.gallery);

    controller.emit(
      const ScanFailed(ScanFailure(ScanFailureReason.permissionDenied)),
    );
    await tester.pump();

    expect(find.text('Photo access is off'), findsOneWidget);
  });

  testWidgets('an unavailable scanner suggests entering it manually', (
    tester,
  ) async {
    final (router, controller) = await _openScan(tester);

    controller.emit(
      const ScanFailed(ScanFailure(ScanFailureReason.unavailable)),
    );
    await tester.pump();

    expect(find.text('Scanner not available'), findsOneWidget);
    expect(find.widgetWithText(FilledButton, 'Enter manually'), findsOneWidget);

    await tester.tap(find.text('Enter manually'));
    await tester.pumpAndSettle();

    expect(find.text('manual page'), findsOneWidget);
    expect(controller.current, isA<ScanIdle>());
    // The failed scan screen is not left behind the form.
    router.pop();
    await tester.pumpAndSettle();
    expect(find.text('receipts page'), findsOneWidget);
  });

  testWidgets('other errors show a generic message', (tester) async {
    final (_, controller) = await _openScan(tester);

    controller.emit(
      const ScanFailed(ScanFailure(ScanFailureReason.other, 'ERROR')),
    );
    await tester.pump();

    expect(find.text("Couldn't open the scanner"), findsOneWidget);
    expect(find.widgetWithText(FilledButton, 'Try again'), findsOneWidget);
    expect(
      find.widgetWithText(OutlinedButton, 'Enter manually'),
      findsOneWidget,
    );
  });

  testWidgets('fits a small phone at 200 % text', (tester) async {
    tester.view
      ..physicalSize = const Size(320 * 3, 568 * 3)
      ..devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    final (_, controller) = await _openScan(tester, textScale: 2);

    for (final state in [
      const ScanReading('/tmp/scan.jpg'),
      for (final reason in ScanFailureReason.values)
        ScanFailed(ScanFailure(reason)),
    ]) {
      controller.emit(state);
      await tester.pump();
      expect(tester.takeException(), isNull, reason: '$state');
    }
    await tester.scrollUntilVisible(find.text('Enter manually'), 100);
    expect(find.text('Enter manually'), findsOneWidget);
  });

  testWidgets('meets tap target and label guidelines', (tester) async {
    final handle = tester.ensureSemantics();
    final (_, controller) = await _openScan(tester);
    controller.emit(
      const ScanFailed(ScanFailure(ScanFailureReason.permissionDenied)),
    );
    await tester.pump();

    await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
    await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
    await expectLater(tester, meetsGuideline(textContrastGuideline));
    handle.dispose();
  });

  testWidgets('with the real controller: scan → review', (tester) async {
    final prefs = await inMemoryPrefs();
    final router = _router();
    addTearDown(router.dispose);
    final scanner = FakeDocumentScanner(path: '/tmp/scan.jpg');
    final container = ProviderContainer.test(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        deviceLocaleProvider.overrideWithValue('en_AU'),
        documentScannerProvider.overrideWithValue(scanner),
        ocrEngineProvider.overrideWithValue(FakeOcrEngine()),
        receiptRepositoryProvider.overrideWithValue(FakeReceiptRepository()),
        clockProvider.overrideWithValue(() => DateTime(2026, 11, 16)),
      ],
    );
    await tester.pumpWidget(
      UncontrolledProviderScope(container: container, child: _material(router)),
    );
    unawaited(router.push(ScanRoutes.scanFrom(ScanSource.camera)));
    await tester.pump();
    await tester.pump();

    // Parsing runs on a real background isolate.
    await tester.runAsync(() async {
      for (var i = 0; i < 100; i++) {
        if (container.read(scanControllerProvider) is ScanReview) break;
        await Future<void>.delayed(const Duration(milliseconds: 20));
      }
    });
    await tester.pumpAndSettle();

    expect(scanner.calls, [ScanSource.camera]);
    expect(find.text('review page'), findsOneWidget);
    final state = container.read(scanControllerProvider) as ScanReview;
    expect(state.data.draft.totalMinor, 10870);
  });
}
