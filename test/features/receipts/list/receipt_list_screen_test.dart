// Fail fast instead of blocking the shared test lock if something hangs.
@Timeout(Duration(minutes: 2))
library;

import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:receipt_mind/core/date/local_date.dart';
import 'package:receipt_mind/core/db/app_database.dart';
import 'package:receipt_mind/core/money/money.dart';
import 'package:receipt_mind/features/receipts/presentation/list/receipt_list_parts.dart';

import 'receipt_screens_harness.dart';

Finder _monthTotal(String currency) =>
    find.byKey(ValueKey('list-month-total-$currency'));

String _text(WidgetTester tester, Finder finder) => tester
    .widget<Text>(find.descendant(of: finder, matching: find.byType(Text)))
    .data!;

void main() {
  setUpAll(initializeDateFormatting);

  late ReceiptScreensHarness h;

  setUp(() async => h = await createHarness());

  group('list', () {
    testWidgets('groups receipts by month, newest first', (tester) async {
      tester.view.physicalSize = const Size(800, 2400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await addReceipt(
        h.db,
        merchant: 'Sept Two',
        date: LocalDate(2026, 9, 20),
      );
      await addReceipt(h.db, merchant: 'Sept One', date: LocalDate(2026, 9, 2));
      await addReceipt(h.db, merchant: 'August', date: LocalDate(2026, 8, 31));
      await addReceipt(
        h.db,
        merchant: 'Last Year',
        date: LocalDate(2025, 12, 1),
      );

      await h.pump(tester);

      // September 2026 is also the summary card's title.
      expect(find.text('September 2026'), findsNWidgets(2));
      expect(find.text('August 2026'), findsOneWidget);
      expect(find.text('December 2025'), findsOneWidget);
      double y(String text) => tester.getTopLeft(find.text(text).last).dy;
      expect(y('Sept Two'), lessThan(y('Sept One')));
      expect(y('Sept One'), lessThan(y('August 2026')));
      expect(y('August 2026'), lessThan(y('August')));
      expect(y('August'), lessThan(y('December 2025')));
      expect(y('December 2025'), lessThan(y('Last Year')));
    });

    testWidgets('rows show date in the user order, category and amount', (
      tester,
    ) async {
      final ids = await categoryIds(h.db);
      await addReceipt(
        h.db,
        merchant: 'Freshway',
        date: LocalDate(2026, 9, 3),
        totalMinor: 4560,
        categoryId: ids['Groceries'],
      );
      await addReceipt(
        h.db,
        merchant: 'Corner Shop',
        date: LocalDate(2026, 9, 2),
      );

      await h.pump(tester);

      // en_US → month/day/year.
      expect(find.text('09/03/2026 · Groceries'), findsOneWidget);
      expect(find.text('09/02/2026 · Uncategorised'), findsOneWidget);
      expect(find.text(r'$45.60'), findsOneWidget);
      expect(
        find.bySemanticsLabel(r'Freshway, 09/03/2026, $45.60, Groceries'),
        findsOneWidget,
      );
    });

    testWidgets('month card sums the current month per currency', (
      tester,
    ) async {
      await addReceipt(h.db, totalMinor: 1250, currency: 'USD');
      await addReceipt(h.db, totalMinor: 750, currency: 'USD');
      await addReceipt(h.db, totalMinor: 1000, currency: 'EUR');
      // Not this month.
      await addReceipt(
        h.db,
        totalMinor: 99900,
        currency: 'USD',
        date: LocalDate(2026, 8, 31),
      );
      await addReceipt(
        h.db,
        totalMinor: 99900,
        currency: 'GBP',
        date: LocalDate(2026, 10, 1),
      );

      await h.pump(tester);

      expect(
        _text(tester, _monthTotal('USD')),
        const Money(2000, 'USD').format('en_US'),
      );
      expect(
        _text(tester, _monthTotal('EUR')),
        const Money(1000, 'EUR').format('en_US'),
      );
      expect(_monthTotal('GBP'), findsNothing);
      // The default currency (USD for en_US) comes first.
      expect(
        tester.getTopLeft(_monthTotal('USD')).dy,
        lessThan(tester.getTopLeft(_monthTotal('EUR')).dy),
      );
    });

    testWidgets('month card says so when this month has no receipts', (
      tester,
    ) async {
      await addReceipt(h.db, date: LocalDate(2026, 8, 10));

      await h.pump(tester);

      expect(find.text('No receipts this month'), findsOneWidget);
    });

    testWidgets('formats totals for the device locale', (tester) async {
      await addReceipt(h.db, totalMinor: 123456, currency: 'EUR');

      await h.pump(tester, locale: 'de_DE');

      expect(
        _text(tester, _monthTotal('EUR')),
        const Money(123456, 'EUR').format('de_DE'),
      );
      expect(const Money(123456, 'EUR').format('de_DE'), contains('1.234,56'));
    });
  });

  group('search', () {
    testWidgets('is debounced and matches merchant, notes and OCR text', (
      tester,
    ) async {
      await addReceipt(h.db, merchant: 'Bean Bar');
      await addReceipt(h.db, merchant: 'Hardware Hut', notes: 'new hammer');
      await addReceipt(
        h.db,
        merchant: 'Corner Cafe',
        rawOcrText: 'FLAT WHITE 4.50\nTOTAL 4.50',
      );
      await h.pump(tester);

      await tester.enterText(find.byType(TextField), 'hammer');
      await tester.pump(const Duration(milliseconds: 100));
      // Not applied yet.
      expect(find.text('Bean Bar'), findsOneWidget);

      await tester.pump(searchDebounce);
      await tester.pumpAndSettle();
      expect(find.text('Hardware Hut'), findsOneWidget);
      expect(find.text('Bean Bar'), findsNothing);

      await tester.enterText(find.byType(TextField), 'flat white');
      await tester.pump(searchDebounce);
      await tester.pumpAndSettle();
      expect(find.text('Corner Cafe'), findsOneWidget);
      expect(find.text('Hardware Hut'), findsNothing);

      await tester.tap(find.byKey(const Key('list-search-clear')));
      await tester.pumpAndSettle();
      expect(find.text('Bean Bar'), findsOneWidget);
      expect(find.text('Hardware Hut'), findsOneWidget);
      expect(find.text('Corner Cafe'), findsOneWidget);
    });

    testWidgets('no matches shows a message that clears the filters', (
      tester,
    ) async {
      await addReceipt(h.db, merchant: 'Bean Bar');
      await h.pump(tester);

      await tester.enterText(find.byType(TextField), 'zzz');
      await tester.pump(searchDebounce);
      await tester.pumpAndSettle();

      expect(find.text('No matching receipts'), findsOneWidget);
      expect(find.text('No receipts yet'), findsNothing);
      // The search bar stays so the search can be changed.
      expect(find.byType(SearchBar), findsOneWidget);

      await tester.tap(find.byKey(const Key('list-clear-filters')));
      await tester.pumpAndSettle();
      expect(find.text('Bean Bar'), findsOneWidget);
      expect(
        tester.widget<TextField>(find.byType(TextField)).controller!.text,
        isEmpty,
      );
    });
  });

  group('category filter', () {
    testWidgets('shows one category at a time', (tester) async {
      final ids = await categoryIds(h.db);
      await addReceipt(
        h.db,
        merchant: 'Freshway',
        categoryId: ids['Groceries'],
      );
      await addReceipt(
        h.db,
        merchant: 'Pizza Place',
        categoryId: ids['Dining'],
      );
      await addReceipt(h.db, merchant: 'Loose Receipt');
      await h.pump(tester);

      expect(find.byKey(const Key('list-filter-all')), findsOneWidget);
      await tester.tap(find.byKey(ValueKey('list-filter-${ids['Dining']}')));
      await tester.pumpAndSettle();
      expect(find.text('Pizza Place'), findsOneWidget);
      expect(find.text('Freshway'), findsNothing);
      expect(find.text('Loose Receipt'), findsNothing);

      await tester.tap(find.byKey(ValueKey('list-filter-${ids['Groceries']}')));
      await tester.pumpAndSettle();
      expect(find.text('Freshway'), findsOneWidget);
      expect(find.text('Pizza Place'), findsNothing);

      await tester.tap(find.byKey(const Key('list-filter-all')));
      await tester.pumpAndSettle();
      expect(find.text('Freshway'), findsOneWidget);
      expect(find.text('Pizza Place'), findsOneWidget);
      expect(find.text('Loose Receipt'), findsOneWidget);
    });

    testWidgets('a category without receipts shows "No matching receipts"', (
      tester,
    ) async {
      final ids = await categoryIds(h.db);
      await addReceipt(
        h.db,
        merchant: 'Freshway',
        categoryId: ids['Groceries'],
      );
      await h.pump(tester);

      final health = find.byKey(ValueKey('list-filter-${ids['Health']}'));
      // The chip row scrolls sideways; Health starts off screen.
      await tester.ensureVisible(health);
      await tester.pumpAndSettle();
      await tester.tap(health);
      await tester.pumpAndSettle();

      expect(find.text('No matching receipts'), findsOneWidget);
    });
  });

  group('swipe to delete', () {
    testWidgets('removes the row and Undo restores it', (tester) async {
      final id = await addReceipt(h.db, merchant: 'Bean Bar');
      await addReceipt(h.db, merchant: 'Keep Me');
      await h.pump(tester);

      await tester.drag(find.text('Bean Bar'), const Offset(-600, 0));
      await tester.pumpAndSettle();

      expect(find.text('Bean Bar'), findsNothing);
      expect(find.text('Deleted Bean Bar'), findsOneWidget);
      expect(await h.db.receiptsDao.getReceipt(id), isNull);

      await tester.tap(find.text('Undo'));
      await tester.pumpAndSettle();

      expect(find.text('Bean Bar'), findsOneWidget);
      expect(await h.db.receiptsDao.getReceipt(id), isNotNull);
      await ReceiptScreensHarness.finishSnackBars(tester);
    });

    testWidgets('deleting the last receipt shows the empty state', (
      tester,
    ) async {
      await addReceipt(h.db, merchant: 'Only One');
      await h.pump(tester);

      await tester.drag(find.text('Only One'), const Offset(-600, 0));
      await tester.pumpAndSettle();

      expect(find.text('No receipts yet'), findsOneWidget);
      await ReceiptScreensHarness.finishSnackBars(tester);
      expect(find.text('Deleted Only One'), findsNothing);
    });

    testWidgets('a month header disappears with its last receipt', (
      tester,
    ) async {
      await addReceipt(
        h.db,
        merchant: 'September',
        date: LocalDate(2026, 9, 1),
      );
      await addReceipt(h.db, merchant: 'August', date: LocalDate(2026, 8, 1));
      await h.pump(tester);

      await tester.drag(find.text('August'), const Offset(-600, 0));
      await tester.pumpAndSettle();

      expect(find.text('August 2026'), findsNothing);
      await ReceiptScreensHarness.finishSnackBars(tester);
    });
  });

  group('empty state', () {
    testWidgets('offers to scan the first receipt', (tester) async {
      await h.pump(tester);

      expect(find.text('No receipts yet'), findsOneWidget);
      expect(find.byType(SearchBar), findsNothing);

      await tester.tap(find.text('Scan your first receipt'));
      await tester.pumpAndSettle();
      expect(find.text('scan:camera'), findsOneWidget);
    });

    testWidgets('offers manual entry', (tester) async {
      await h.pump(tester);

      await tester.tap(find.byKey(const Key('list-empty-manual')));
      await tester.pumpAndSettle();
      expect(find.text('manual'), findsOneWidget);
    });
  });

  group('add sheet', () {
    for (final (key, target) in [
      ('fab-scan', 'scan:camera'),
      ('fab-import', 'scan:gallery'),
      ('fab-manual', 'manual'),
    ]) {
      testWidgets('$key opens $target', (tester) async {
        await h.pump(tester);

        await tester.tap(find.byKey(const Key('list-fab')));
        await tester.pumpAndSettle();
        expect(find.text('Scan'), findsOneWidget);
        expect(find.text('Import from photos'), findsOneWidget);
        expect(find.text('Enter manually'), findsOneWidget);

        await tester.tap(find.byKey(Key(key)));
        await tester.pumpAndSettle();
        expect(find.text(target), findsOneWidget);
        expect(find.byKey(Key(key)), findsNothing);
      });
    }

    testWidgets('the FAB has a tooltip', (tester) async {
      await h.pump(tester);
      expect(find.byTooltip('Add receipt'), findsOneWidget);
    });
  });

  group('rows', () {
    testWidgets('tapping a row opens its detail', (tester) async {
      final id = await addReceipt(h.db, merchant: 'Bean Bar');
      await h.pump(tester);

      await tester.tap(find.text('Bean Bar'));
      await tester.pumpAndSettle();

      expect(h.router.state.uri.path, '/receipts/$id');
      expect(find.byKey(const Key('detail-merchant')), findsOneWidget);
    });

    testWidgets('thumbnails are decoded small; no photo shows a placeholder', (
      tester,
    ) async {
      await addReceipt(
        h.db,
        id: 'with-photo',
        merchant: 'With Photo',
        imagePath: 'receipts/with-photo.jpg',
      );
      await addReceipt(h.db, merchant: 'No Photo');
      await h.pump(tester);

      final image = tester.widget<Image>(find.byType(Image));
      expect(image.image, isA<ResizeImage>());
      final resize = image.image as ResizeImage;
      expect(resize.width, lessThanOrEqualTo(56 * 3));
      expect(
        (resize.imageProvider as FileImage).file.path,
        endsWith('receipts/thumbs/with-photo.jpg'),
      );
      expect(h.images.resolved, ['receipts/thumbs/with-photo.jpg']);
      expect(find.byIcon(Icons.receipt_long_outlined), findsOneWidget);
    });
  });

  group('layout', () {
    testWidgets('fits a landscape phone at 200 % text size in dark mode', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(2400, 1080);
      tester.view.devicePixelRatio = 2.625;
      tester.platformDispatcher.textScaleFactorTestValue = 2.0;
      addTearDown(tester.view.reset);
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      final ids = await categoryIds(h.db);
      await addReceipt(
        h.db,
        merchant: 'A merchant with a rather long name indeed',
        totalMinor: 123456789,
        categoryId: ids['Transport'],
      );
      await addReceipt(h.db, currency: 'EUR', totalMinor: 5000);

      await h.pump(tester, themeMode: ThemeMode.dark);

      expect(tester.takeException(), isNull);
      await tester.drag(find.byType(CustomScrollView), const Offset(0, -2000));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });

    testWidgets('empty state fits at 200 % text size', (tester) async {
      tester.view.physicalSize = const Size(2400, 1080);
      tester.view.devicePixelRatio = 2.625;
      tester.platformDispatcher.textScaleFactorTestValue = 2.0;
      addTearDown(tester.view.reset);
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

      await h.pump(tester);

      expect(tester.takeException(), isNull);
      expect(find.text('No receipts yet'), findsOneWidget);
    });
  });

  group('performance', () {
    testWidgets('1,000 receipts build lazily and fling without errors', (
      tester,
    ) async {
      final ids = (await categoryIds(h.db)).values.toList();
      await h.db.batch((batch) {
        batch.insertAll(h.db.receipts, [
          for (var i = 0; i < 1000; i++)
            ReceiptsCompanion.insert(
              id: 'bulk-${i.toString().padLeft(4, '0')}',
              merchant: 'Merchant $i',
              purchaseDate: LocalDate(2026, 9, 24).addDays(-i),
              totalMinor: 100 + i * 37,
              currency: i.isEven ? 'USD' : 'EUR',
              categoryId: Value(i % 3 == 0 ? null : ids[i % ids.length]),
              imagePath: Value(i % 4 == 0 ? 'receipts/bulk-$i.jpg' : null),
              extractionMethod: ExtractionMethod.rules,
              createdAt: DateTime(2026, 9, 24),
              updatedAt: DateTime(2026, 9, 24),
            ),
        ]);
      });

      await h.pump(tester);

      expect(find.text('Merchant 0'), findsOneWidget);
      // Only what is on screen (plus the cache extent) is built.
      expect(find.byType(ReceiptListTile).evaluate().length, lessThan(40));

      for (var i = 0; i < 8; i++) {
        await tester.fling(
          find.byType(CustomScrollView),
          const Offset(0, -3000),
          4000,
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      }
      expect(find.text('Merchant 0'), findsNothing);
      expect(find.byType(ReceiptListTile).evaluate().length, lessThan(40));

      // A stream update (a new receipt) keeps the scroll position.
      final before = find.byType(ReceiptListTile).evaluate().length;
      await addReceipt(
        h.db,
        merchant: 'Brand New',
        date: LocalDate(2026, 9, 24),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.text('Brand New'), findsNothing);
      expect(
        find.byType(ReceiptListTile).evaluate().length,
        closeTo(before, 2),
      );
    });
  });
}
