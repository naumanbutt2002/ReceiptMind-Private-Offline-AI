import 'dart:async';
import 'dart:io';

import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:path/path.dart' as p;
import 'package:receipt_mind/app/theme.dart';
import 'package:receipt_mind/core/clock.dart';
import 'package:receipt_mind/core/date/local_date.dart';
import 'package:receipt_mind/core/db/app_database.dart';
import 'package:receipt_mind/core/db/db_providers.dart';
import 'package:receipt_mind/core/settings/settings_providers.dart';
import 'package:receipt_mind/features/receipts/application/receipt_photo_sharer.dart';
import 'package:receipt_mind/features/receipts/data/receipt_image_store.dart';
import 'package:receipt_mind/features/receipts/data/receipts_providers.dart';
import 'package:receipt_mind/features/receipts/presentation/receipt_list_screen.dart';
import 'package:receipt_mind/features/receipts/presentation/receipt_routes_detail.dart';
import 'package:receipt_mind/l10n/generated/app_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../helpers/test_app.dart';

/// "Now" in these tests: September 2026.
final testNow = DateTime(2026, 9, 24, 10, 30);

/// Where [FakeImageStore] pretends the app support directory is.
final fakeSupportDir = p.join(Directory.systemTemp.path, 'receipt_mind_test');

/// Resolves paths under [fakeSupportDir]; no files are read or written.
final class FakeImageStore implements ReceiptImageStore {
  final List<String> resolved = [];

  @override
  Future<String> resolve(String relativePath) async {
    resolved.add(relativePath);
    return p.join(fakeSupportDir, relativePath);
  }

  @override
  String thumbnailFor(String relativeImagePath) => p.join(
    p.dirname(relativeImagePath),
    'thumbs',
    p.basename(relativeImagePath),
  );

  @override
  Future<StoredImage> importScan(String sourcePath, {required String id}) =>
      throw UnimplementedError();

  @override
  Future<void> delete(String relativeImagePath) async {}

  @override
  Future<int> deleteOrphans(Set<String> referencedImagePaths) async => 0;
}

/// Records what would have been shared.
final class FakePhotoSharer implements ReceiptPhotoSharer {
  final List<String> shared = [];
  Object? error;

  /// When set, a share stays "open" until this completes.
  Completer<void>? openSheet;

  @override
  Future<void> sharePhoto(String absolutePath, {Rect? origin}) async {
    if (error case final error?) throw error;
    shared.add(absolutePath);
    await openSheet?.future;
  }
}

/// Category ids by name, from the seeded defaults.
Future<Map<String, int>> categoryIds(AppDatabase db) async {
  // A plain query: a Drift stream's first event needs a real timer, which
  // never fires inside testWidgets' fake async zone.
  final rows = await db.select(db.categories).get();
  return {for (final c in rows) c.name: c.id};
}

var _seq = 0;

/// Inserts a receipt and returns its id.
Future<String> addReceipt(
  AppDatabase db, {
  String? id,
  String merchant = 'Bean Bar',
  LocalDate? date,
  int totalMinor = 1250,
  String currency = 'USD',
  int? subtotalMinor,
  int? taxMinor,
  int? tipMinor,
  int? categoryId,
  PaymentMethod? paymentMethod,
  String? notes,
  String? imagePath,
  String? rawOcrText,
  ExtractionMethod extractionMethod = ExtractionMethod.rules,
  double? confidence,
}) async {
  final receiptId = id ?? 'r${(_seq++).toString().padLeft(5, '0')}';
  final created = DateTime(2026, 9, 1).add(Duration(minutes: _seq));
  await db.receiptsDao.insertReceipt(
    ReceiptsCompanion.insert(
      id: receiptId,
      merchant: merchant,
      purchaseDate: date ?? LocalDate(2026, 9, 20),
      totalMinor: totalMinor,
      subtotalMinor: Value(subtotalMinor),
      taxMinor: Value(taxMinor),
      tipMinor: Value(tipMinor),
      currency: currency,
      paymentMethod: Value(paymentMethod),
      categoryId: Value(categoryId),
      notes: Value(notes),
      imagePath: Value(imagePath),
      rawOcrText: Value(rawOcrText),
      extractionMethod: extractionMethod,
      confidence: Value(confidence),
      createdAt: created,
      updatedAt: created,
    ),
  );
  return receiptId;
}

/// The list and detail screens in a local router. Other destinations
/// (`/scan`, `/receipts/new`, `/receipts/:id/edit`) are stubs that show
/// their location as text.
class ReceiptScreensHarness {
  ReceiptScreensHarness({required this.db, required this.prefs});

  final AppDatabase db;
  final SharedPreferencesWithCache prefs;
  final images = FakeImageStore();
  final sharer = FakePhotoSharer();
  late GoRouter router;

  /// What [clockProvider] returns; tests may move it forward.
  DateTime now = testNow;

  Future<void> pump(
    WidgetTester tester, {
    String location = ReceiptPaths.list,
    String locale = 'en_US',
    ThemeMode themeMode = ThemeMode.light,
    bool settle = true,
    List<Override> overrides = const [],
  }) async {
    router = GoRouter(
      initialLocation: location,
      routes: [
        GoRoute(
          path: ReceiptPaths.list,
          builder: (context, state) => const ReceiptListScreen(),
          routes: [
            GoRoute(
              path: 'new',
              builder: (context, state) => const _Stub('manual'),
            ),
            ...receiptDetailRoutes(
              detailRoutes: [
                GoRoute(
                  path: 'edit',
                  builder: (context, state) =>
                      _Stub('edit:${state.pathParameters['id']}'),
                ),
              ],
            ),
          ],
        ),
        GoRoute(
          path: '/scan',
          builder: (context, state) =>
              _Stub('scan:${state.uri.queryParameters['source']}'),
        ),
      ],
    );
    addTearDown(router.dispose);
    // Runs before the database closes (tear-downs run last-in first-out):
    // dispose the providers first, so closing never waits on a live query,
    // even when the test failed half-way.
    addTearDown(() => tester.pumpWidget(const SizedBox()));
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          deviceLocaleProvider.overrideWithValue(locale),
          appDatabaseProvider.overrideWithValue(db),
          clockProvider.overrideWithValue(() => now),
          receiptImageStoreProvider.overrideWithValue(images),
          receiptPhotoSharerProvider.overrideWithValue(sharer),
          ...overrides,
        ],
        child: MaterialApp.router(
          theme: AppTheme.light,
          darkTheme: AppTheme.dark,
          themeMode: themeMode,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          routerConfig: router,
        ),
      ),
    );
    if (settle) await tester.pumpAndSettle();
  }

  /// Lets any SnackBar time out, so no timer is left pending.
  static Future<void> finishSnackBars(WidgetTester tester) async {
    await tester.pump(const Duration(seconds: 10));
    await tester.pumpAndSettle();
  }
}

class _Stub extends StatelessWidget {
  const _Stub(this.label);

  final String label;

  @override
  Widget build(BuildContext context) => Scaffold(body: Text(label));
}

/// Fresh storage for one test; the database closes on tear-down.
Future<ReceiptScreensHarness> createHarness() async {
  final prefs = await inMemoryPrefs();
  final db = inMemoryDatabase();
  addTearDown(db.close);
  return ReceiptScreensHarness(db: db, prefs: prefs);
}
