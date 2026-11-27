import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:receipt_mind/app/theme.dart';
import 'package:receipt_mind/core/clock.dart';
import 'package:receipt_mind/core/date/local_date.dart';
import 'package:receipt_mind/core/db/app_database.dart';
import 'package:receipt_mind/core/db/db_providers.dart';
import 'package:receipt_mind/core/settings/settings_providers.dart';
import 'package:receipt_mind/core/settings/settings_repository.dart';
import 'package:receipt_mind/features/receipts/data/receipt_image_store.dart';
import 'package:receipt_mind/features/receipts/data/receipt_repository.dart';
import 'package:receipt_mind/features/receipts/data/receipts_providers.dart';
import 'package:receipt_mind/features/receipts/presentation/receipt_routes_review.dart';
import 'package:receipt_mind/features/scan/application/receipt_draft.dart';
import 'package:receipt_mind/features/scan/application/scan_controller.dart';
import 'package:receipt_mind/features/scan/application/scan_state.dart';
import 'package:receipt_mind/l10n/generated/app_localizations.dart';
import 'package:receipt_parser/receipt_parser.dart'
    show IssueCode, ReceiptField;

import '../../../helpers/test_app.dart';

/// "Today" in every review test.
final reviewToday = DateTime(2026, 11, 16, 10);

/// Text on the stand-in receipt list, where the review screen returns to.
const receiptsHomeText = 'receipts-home';

const scanPhotoPath = '/tmp/scan.jpg';
const recognisedText = 'FRESHWAY MARKET\nTOTAL \$108.70\nVISA CREDIT 108.70';

/// A parsed scan of an Australian supermarket receipt.
ReviewData sampleReview({
  Map<ReceiptField, List<IssueCode>> warnings = const {},
  String photoPath = scanPhotoPath,
}) => ReviewData(
  warnings: warnings,
  draft: ReceiptDraft(
    merchant: 'Freshway Market',
    totalMinor: 10870,
    subtotalMinor: 10870,
    taxMinor: 988,
    currency: 'AUD',
    paymentMethod: PaymentMethod.card,
    rawOcrText: recognisedText,
    extractionMethod: ExtractionMethod.rules,
    sourceImagePath: photoPath,
    confidence: 0.9,
  ).copyWith(date: LocalDate(2026, 9, 12)),
);

/// OCR found nothing: an empty draft that still has the photo.
const ocrFailedReview = ReviewData(
  ocrFailed: true,
  draft: ReceiptDraft(
    currency: 'AUD',
    extractionMethod: ExtractionMethod.manual,
    sourceImagePath: scanPhotoPath,
  ),
);

/// [ScanController] that starts in [initial] and records [save]/[reset].
class FakeScanController extends ScanController {
  FakeScanController(this.initial);

  final ScanState initial;
  final List<ReceiptDraft> saved = [];
  int resets = 0;

  /// Thrown by [save] when set.
  Object? error;

  @override
  ScanState build() => initial;

  @override
  Future<String> save(ReceiptDraft draft) async {
    if (error case final error?) throw error;
    saved.add(draft);
    state = const ScanIdle();
    return 'scan-receipt';
  }

  @override
  void reset() {
    resets++;
    state = const ScanIdle();
  }
}

/// The real repository on an in-memory database, recording what the review
/// screen saves instead of writing it.
class RecordingReceiptRepository extends ReceiptRepository {
  RecordingReceiptRepository(AppDatabase db, ReceiptImageStore images)
    : super(db.receiptsDao, images);

  final List<ReceiptDraft> created = [];
  final List<ReceiptDraft> updated = [];

  /// Thrown by [createFromDraft] and [update] when set.
  Object? error;

  @override
  Future<String> createFromDraft(ReceiptDraft draft) async {
    if (error case final error?) throw error;
    created.add(draft);
    return 'new-receipt';
  }

  @override
  Future<void> update(ReceiptDraft draft) async {
    if (error case final error?) throw error;
    updated.add(draft);
  }
}

/// Resolves relative paths under `/support`; nothing else is used.
class FakeImageStore implements ReceiptImageStore {
  @override
  Future<String> resolve(String relativePath) async => '/support/$relativePath';

  @override
  Object? noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('FakeImageStore.${invocation.memberName}');
}

/// A saved receipt with a photo, for edit mode.
ReceiptRow sampleRow({String id = 'r1'}) => ReceiptRow(
  id: id,
  merchant: 'Corner Café',
  purchaseDate: LocalDate(2026, 10, 3),
  totalMinor: 1450,
  tipMinor: 200,
  currency: 'AUD',
  paymentMethod: PaymentMethod.cash,
  notes: 'Team lunch',
  imagePath: 'receipts/$id.jpg',
  rawOcrText: 'CORNER CAFE\nTOTAL 14.50',
  extractionMethod: ExtractionMethod.rules,
  createdAt: DateTime(2026, 10, 3, 12),
  updatedAt: DateTime(2026, 10, 3, 12),
);

/// What a test needs after [pumpReview].
class ReviewHarness {
  ReviewHarness(this.router, this.scan, this.repository, this.db);

  final GoRouter router;
  final FakeScanController scan;
  final RecordingReceiptRepository repository;
  final AppDatabase db;

  /// The location of the top-most page (pushed pages included).
  String get location => router.state.uri.toString();
}

/// Pumps the review screen at [location], pushed on top of a stand-in
/// receipt list (as the app does), and waits for it to settle.
///
/// [scanState] seeds the scan controller; [rows] are inserted into the
/// in-memory database first (for edit mode).
Future<ReviewHarness> pumpReview(
  WidgetTester tester, {
  required String location,
  ScanState scanState = const ScanIdle(),
  List<ReceiptRow> rows = const [],
  Size size = const Size(400, 800),
  double textScale = 1,
  ThemeMode themeMode = ThemeMode.light,
  String locale = 'en_AU',
}) async {
  tester.view
    ..physicalSize = size
    ..devicePixelRatio = 1;
  tester.platformDispatcher.textScaleFactorTestValue = textScale;
  addTearDown(tester.view.reset);
  addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

  final db = inMemoryDatabase();
  addTearDown(db.close);
  for (final row in rows) {
    await tester.runAsync(() => db.receiptsDao.restoreReceipt(row));
  }
  final prefs = await tester.runAsync(
    () => inMemoryPrefs({
      SettingsRepository.keyDefaultCurrency: 'AUD',
      SettingsRepository.keyDateOrder: 'dmy',
    }),
  );
  final scan = FakeScanController(scanState);
  final images = FakeImageStore();
  final repository = RecordingReceiptRepository(db, images);
  final router = GoRouter(
    initialLocation: '/receipts',
    routes: [
      GoRoute(
        path: '/receipts',
        builder: (context, state) =>
            const Scaffold(body: Center(child: Text(receiptsHomeText))),
        routes: reviewReceiptChildRoutes,
      ),
      ...reviewTopLevelRoutes,
    ],
  );
  addTearDown(router.dispose);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs!),
        deviceLocaleProvider.overrideWithValue(locale),
        appDatabaseProvider.overrideWithValue(db),
        clockProvider.overrideWithValue(() => reviewToday),
        scanControllerProvider.overrideWith(() => scan),
        receiptRepositoryProvider.overrideWithValue(repository),
        receiptImageStoreProvider.overrideWithValue(images),
      ],
      child: MaterialApp.router(
        routerConfig: router,
        theme: AppTheme.light,
        darkTheme: AppTheme.dark,
        themeMode: themeMode,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
      ),
    ),
  );
  await tester.pumpAndSettle();
  unawaited(router.push<void>(location));
  // Edit mode loads from the database outside fake async.
  await tester.runAsync(() => Future<void>.delayed(Duration.zero));
  await tester.pumpAndSettle();
  await tester.runAsync(() => Future<void>.delayed(Duration.zero));
  await tester.pumpAndSettle();
  return ReviewHarness(router, scan, repository, db);
}

/// A real (empty) file standing in for the scanner's temporary photo, for
/// tests where its existence matters. Deleted after the test.
String createScanPhotoFile() {
  final dir = Directory.systemTemp.createTempSync('review_test');
  addTearDown(() => dir.deleteSync(recursive: true));
  return (File('${dir.path}/scan.jpg')..writeAsBytesSync(const [0])).path;
}

/// The text currently in the field with [key].
String fieldText(WidgetTester tester, Key key) =>
    tester.widget<TextFormField>(find.byKey(key)).controller!.text;
