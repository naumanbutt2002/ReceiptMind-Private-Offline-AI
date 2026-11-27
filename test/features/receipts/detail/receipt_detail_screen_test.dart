// Fail fast instead of blocking the shared test lock if something hangs.
@Timeout(Duration(minutes: 2))
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:path/path.dart' as p;
import 'package:receipt_mind/core/date/local_date.dart';
import 'package:receipt_mind/core/db/app_database.dart';

import '../list/receipt_screens_harness.dart';

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
      subtotalMinor: 9882,
      taxMinor: 988,
      tipMinor: 500,
      currency: 'USD',
      categoryId: ids['Groceries'],
      paymentMethod: PaymentMethod.card,
      notes: 'Weekly shop',
      imagePath: 'receipts/full.jpg',
      extractionMethod: ExtractionMethod.rules,
      confidence: 0.874,
    );
  }

  testWidgets('shows every field', (tester) async {
    // Tall enough that the lazy ListView builds every field.
    tester.view.physicalSize = const Size(800, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final id = await addFullReceipt();

    await h.pump(tester, location: '/receipts/$id');

    expect(find.text('Freshway Market'), findsOneWidget);
    expect(find.text(r'$108.70'), findsOneWidget);
    expect(find.text('09/12/2026'), findsOneWidget);
    expect(find.text(r'$98.82'), findsOneWidget);
    expect(find.text(r'$9.88'), findsOneWidget);
    expect(find.text(r'$5.00'), findsOneWidget);
    expect(find.text(r'USD ($)'), findsOneWidget);
    expect(find.text('Groceries'), findsOneWidget);
    expect(find.text('Card'), findsOneWidget);
    expect(find.text('Weekly shop'), findsOneWidget);
    expect(
      find.text('Read from the photo by the rule parser · 87% confidence'),
      findsOneWidget,
    );
    for (final label in ['Date', 'Subtotal', 'Tax', 'Tip', 'Currency']) {
      expect(find.text(label), findsOneWidget, reason: label);
    }
    expect(find.byTooltip('Edit'), findsOneWidget);
    expect(find.byTooltip('Delete'), findsOneWidget);
    expect(find.byTooltip('Share photo'), findsOneWidget);
  });

  testWidgets('a manual receipt has no photo, optional fields or share', (
    tester,
  ) async {
    final id = await addReceipt(
      h.db,
      merchant: 'Market Stall',
      totalMinor: 500,
      extractionMethod: ExtractionMethod.manual,
    );

    await h.pump(tester, location: '/receipts/$id');

    expect(find.byKey(const Key('detail-no-photo')), findsOneWidget);
    expect(find.text('Entered manually'), findsOneWidget);
    expect(find.text('Uncategorised'), findsOneWidget);
    expect(find.text('Subtotal'), findsNothing);
    expect(find.text('Payment method'), findsNothing);
    expect(find.text('Notes'), findsNothing);
    expect(find.byTooltip('Share photo'), findsNothing);
  });

  testWidgets('Edit opens the edit route', (tester) async {
    final id = await addFullReceipt();
    await h.pump(tester, location: '/receipts/$id');

    await tester.tap(find.byKey(const Key('detail-edit')));
    await tester.pumpAndSettle();

    expect(find.text('edit:$id'), findsOneWidget);
  });

  testWidgets('Delete asks first; Cancel keeps the receipt', (tester) async {
    final id = await addFullReceipt();
    await h.pump(tester, location: '/receipts/$id');

    await tester.tap(find.byKey(const Key('detail-delete')));
    await tester.pumpAndSettle();
    expect(find.text('Delete this receipt?'), findsOneWidget);

    await tester.tap(find.byKey(const Key('detail-delete-cancel')));
    await tester.pumpAndSettle();

    expect(find.text('Delete this receipt?'), findsNothing);
    expect(await h.db.receiptsDao.getReceipt(id), isNotNull);
    expect(find.byKey(const Key('detail-merchant')), findsOneWidget);
  });

  testWidgets('Delete returns to the list with Undo', (tester) async {
    final id = await addFullReceipt();
    await addReceipt(h.db, merchant: 'Other Shop');
    await h.pump(tester, location: '/receipts/$id');

    await tester.tap(find.byKey(const Key('detail-delete')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('detail-delete-confirm')));
    await tester.pumpAndSettle();

    expect(h.router.state.uri.path, '/receipts');
    expect(find.text('Receipt not found'), findsNothing);
    expect(find.text('Deleted Freshway Market'), findsOneWidget);
    expect(find.text('Other Shop'), findsOneWidget);
    expect(find.text('Freshway Market'), findsNothing);
    expect(await h.db.receiptsDao.getReceipt(id), isNull);

    await tester.tap(find.text('Undo'));
    await tester.pumpAndSettle();

    expect(find.text('Freshway Market'), findsOneWidget);
    expect(await h.db.receiptsDao.getReceipt(id), isNotNull);
    await ReceiptScreensHarness.finishSnackBars(tester);
  });

  testWidgets('Share photo hands the resolved file to the sharer', (
    tester,
  ) async {
    final id = await addFullReceipt();
    await h.pump(tester, location: '/receipts/$id');

    await tester.tap(find.byKey(const Key('detail-share')));
    await tester.pumpAndSettle();

    expect(h.sharer.shared, [p.join(fakeSupportDir, 'receipts/full.jpg')]);
  });

  testWidgets('a failed share shows a message', (tester) async {
    final id = await addFullReceipt();
    h.sharer.error = Exception('no share sheet');
    await h.pump(tester, location: '/receipts/$id');

    await tester.tap(find.byKey(const Key('detail-share')));
    await tester.pumpAndSettle();

    expect(find.text("Couldn't share the photo."), findsOneWidget);
    await ReceiptScreensHarness.finishSnackBars(tester);
  });

  testWidgets('tapping the photo opens a zoomable full-screen view', (
    tester,
  ) async {
    final id = await addFullReceipt();
    await h.pump(tester, location: '/receipts/$id');

    final photo = tester.widget<Image>(
      find.descendant(
        of: find.byKey(const Key('detail-photo')),
        matching: find.byType(Image),
      ),
    );
    expect(
      ((photo.image as ResizeImage).imageProvider as FileImage).file.path,
      p.join(fakeSupportDir, 'receipts/full.jpg'),
    );

    await tester.tap(find.byKey(const Key('detail-photo')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('detail-fullscreen')), findsOneWidget);
    expect(find.byType(InteractiveViewer), findsOneWidget);

    await tester.tap(find.byTooltip('Close'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('detail-fullscreen')), findsNothing);
  });

  testWidgets('an unknown id shows "Receipt not found"', (tester) async {
    await h.pump(tester, location: '/receipts/does-not-exist');

    expect(find.text('Receipt not found'), findsOneWidget);
    expect(find.byTooltip('Edit'), findsNothing);

    await tester.tap(find.text('Back to receipts'));
    await tester.pumpAndSettle();
    expect(h.router.state.uri.path, '/receipts');
  });

  testWidgets('shows "Receipt not found" when deleted elsewhere', (
    tester,
  ) async {
    final id = await addFullReceipt();
    await h.pump(tester, location: '/receipts/$id');

    await h.db.receiptsDao.deleteReceipt(id);
    await tester.pumpAndSettle();

    expect(find.text('Receipt not found'), findsOneWidget);
  });

  testWidgets('fits at 200 % text size in dark mode', (tester) async {
    tester.platformDispatcher.textScaleFactorTestValue = 2.0;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    final id = await addFullReceipt();

    await h.pump(tester, location: '/receipts/$id', themeMode: ThemeMode.dark);

    expect(tester.takeException(), isNull);
    await tester.drag(
      find.byKey(const Key('detail-body')),
      const Offset(0, -2000),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}
