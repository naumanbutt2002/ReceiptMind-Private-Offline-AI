// M8 hardening: regressions for edge cases in the receipt detail screen,
// plus the accessibility guidelines.
@Timeout(Duration(minutes: 2))
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:receipt_mind/core/date/local_date.dart';
import 'package:receipt_mind/core/db/app_database.dart';
import 'package:receipt_mind/features/receipts/data/receipt_image_store.dart';
import 'package:receipt_mind/features/receipts/data/receipt_repository.dart';
import 'package:receipt_mind/features/receipts/data/receipts_providers.dart';

import '../list/receipt_screens_harness.dart';

/// A repository whose deletes always fail (e.g. a full or locked database).
final class _FailingDeleteRepository extends ReceiptRepository {
  _FailingDeleteRepository(AppDatabase db, ReceiptImageStore images)
    : super(db.receiptsDao, images);

  @override
  Future<ReceiptRow?> delete(String id) async =>
      throw StateError('database is locked');
}

void main() {
  setUpAll(initializeDateFormatting);

  late ReceiptScreensHarness h;

  setUp(() async => h = await createHarness());

  Future<String> addFullReceipt() async {
    final ids = await categoryIds(h.db);
    return addReceipt(
      h.db,
      id: 'full',
      merchant: 'Freshway Market',
      date: LocalDate(2026, 9, 12),
      totalMinor: 10870,
      taxMinor: 988,
      categoryId: ids['Groceries'],
      paymentMethod: PaymentMethod.card,
      notes: 'Weekly shop',
      imagePath: 'receipts/full.jpg',
      confidence: 0.874,
    );
  }

  testWidgets('a failed delete keeps the receipt and says so', (tester) async {
    final id = await addFullReceipt();
    await h.pump(
      tester,
      location: '/receipts/$id',
      overrides: [
        receiptRepositoryProvider.overrideWithValue(
          _FailingDeleteRepository(h.db, h.images),
        ),
      ],
    );

    await tester.tap(find.byKey(const Key('detail-delete')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('detail-delete-confirm')));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(
      find.text("Couldn't delete the receipt. Please try again."),
      findsOneWidget,
    );
    expect(find.text('Freshway Market'), findsOneWidget);
    expect(await h.db.receiptsDao.getReceipt(id), isNotNull);
    await ReceiptScreensHarness.finishSnackBars(tester);
  });

  testWidgets('a second tap on Share while the sheet opens is ignored', (
    tester,
  ) async {
    final id = await addFullReceipt();
    final sheet = Completer<void>();
    h.sharer.openSheet = sheet;
    await h.pump(tester, location: '/receipts/$id');

    await tester.tap(find.byKey(const Key('detail-share')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('detail-share')));
    await tester.pump();
    expect(h.sharer.shared, hasLength(1));

    sheet.complete();
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('detail-share')));
    await tester.pumpAndSettle();
    expect(h.sharer.shared, hasLength(2));
  });

  testWidgets('deleting from the detail, then Undo on the list, after the '
      'category was deleted, restores it uncategorised', (tester) async {
    final ids = await categoryIds(h.db);
    final id = await addFullReceipt();
    await h.pump(tester, location: '/receipts/$id');

    await tester.tap(find.byKey(const Key('detail-delete')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('detail-delete-confirm')));
    await tester.pumpAndSettle();
    await h.db.categoriesDao.deleteCategory(ids['Groceries']!);
    await tester.pumpAndSettle();

    await tester.tap(find.text('Undo'));
    await tester.pumpAndSettle();

    final restored = await h.db.receiptsDao.getReceipt(id);
    expect(restored, isNotNull);
    expect(restored!.categoryId, isNull);
    expect(find.text('Freshway Market'), findsOneWidget);
    await ReceiptScreensHarness.finishSnackBars(tester);
  });

  group('accessibility guidelines', () {
    for (final mode in [ThemeMode.light, ThemeMode.dark]) {
      testWidgets('detail meets them in ${mode.name} mode', (tester) async {
        final handle = tester.ensureSemantics();
        final id = await addFullReceipt();
        await h.pump(tester, location: '/receipts/$id', themeMode: mode);

        await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
        await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
        await expectLater(tester, meetsGuideline(textContrastGuideline));
        handle.dispose();
      });
    }

    testWidgets('"Receipt not found" meets them', (tester) async {
      final handle = tester.ensureSemantics();
      await h.pump(tester, location: '/receipts/missing');

      await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
      await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
      await expectLater(tester, meetsGuideline(textContrastGuideline));
      handle.dispose();
    });

    testWidgets('the full-screen photo meets them', (tester) async {
      final handle = tester.ensureSemantics();
      final id = await addFullReceipt();
      await h.pump(tester, location: '/receipts/$id');
      await tester.tap(find.byKey(const Key('detail-photo')));
      await tester.pumpAndSettle();

      await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
      await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
      handle.dispose();
    });
  });
}
