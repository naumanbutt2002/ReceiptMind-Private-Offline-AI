// M8 hardening: regressions for edge cases in the receipt list, plus the
// accessibility guidelines.
@Timeout(Duration(minutes: 2))
library;

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:receipt_mind/core/date/local_date.dart';
import 'package:receipt_mind/core/db/app_database.dart';
import 'package:receipt_mind/core/money/money.dart';
import 'package:receipt_mind/core/settings/settings_providers.dart';
import 'package:receipt_mind/core/settings/settings_repository.dart';
import 'package:receipt_mind/features/receipts/data/receipt_image_store.dart';
import 'package:receipt_mind/features/receipts/data/receipt_repository.dart';
import 'package:receipt_mind/features/receipts/data/receipts_providers.dart';
import 'package:receipt_mind/features/receipts/presentation/list/receipt_list_parts.dart';
import 'package:receipt_mind/features/receipts/presentation/receipt_list_screen.dart';

import 'receipt_screens_harness.dart';

/// A repository whose deletes always fail (e.g. a full or locked database).
final class _FailingDeleteRepository extends ReceiptRepository {
  _FailingDeleteRepository(AppDatabase db, ReceiptImageStore images)
    : super(db.receiptsDao, images);

  @override
  Future<ReceiptRow?> delete(String id) async =>
      throw StateError('database is locked');
}

/// [androidTapTargetGuideline], except for the text inside Material's
/// `SearchBar`: the field is a dense 24 dp line by design, but the whole
/// 56 dp bar around it focuses it when tapped.
final class _TapTargetGuideline extends MinimumTapTargetGuideline {
  const _TapTargetGuideline()
    : super(
        size: const Size(48, 48),
        link: 'https://support.google.com/accessibility/android/answer/7101858',
      );

  @override
  bool shouldSkipNode(SemanticsNode node) {
    final data = node.getSemanticsData();
    return super.shouldSkipNode(node) ||
        (data.flagsCollection.isTextField &&
            data.label == 'Search merchant, notes or receipt text');
  }
}

Finder _row(String merchant) => find.ancestor(
  of: find.text(merchant),
  matching: find.byType(ReceiptListTile),
);

/// Runs the row's "Delete" accessibility action, as TalkBack would.
void _deleteBySemantics(WidgetTester tester, String merchant) {
  final node = tester.getSemantics(_row(merchant));
  final id = CustomSemanticsAction.getIdentifier(
    const CustomSemanticsAction(label: 'Delete'),
  );
  expect(node.getSemanticsData().customSemanticsActionIds, contains(id));
  node.owner!.performAction(node.id, SemanticsAction.customAction, id);
}

Future<void> _search(WidgetTester tester, String text) async {
  await tester.enterText(find.byType(TextField), text);
  await tester.pump(searchDebounce);
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(initializeDateFormatting);

  late ReceiptScreensHarness h;

  setUp(() async => h = await createHarness());

  group('category filter', () {
    testWidgets('falls back to All when the selected category is deleted', (
      tester,
    ) async {
      final ids = await categoryIds(h.db);
      await addReceipt(
        h.db,
        merchant: 'Pizza Place',
        categoryId: ids['Dining'],
      );
      await addReceipt(
        h.db,
        merchant: 'Freshway',
        categoryId: ids['Groceries'],
      );
      await h.pump(tester);

      await tester.tap(find.byKey(ValueKey('list-filter-${ids['Dining']}')));
      await tester.pumpAndSettle();
      expect(find.text('Freshway'), findsNothing);

      // Deleted elsewhere (Settings › Categories): the receipt stays,
      // uncategorised.
      await h.db.categoriesDao.deleteCategory(ids['Dining']!);
      await tester.pumpAndSettle();

      expect(find.text('No matching receipts'), findsNothing);
      expect(find.text('Pizza Place'), findsOneWidget);
      expect(find.text('Freshway'), findsOneWidget);
      final all = tester.widget<ChoiceChip>(
        find.byKey(const Key('list-filter-all')),
      );
      expect(all.selected, isTrue);
      expect(find.textContaining('Uncategorised'), findsOneWidget);
    });
  });

  group('search', () {
    testWidgets('treats %, _, quotes and emoji as plain text', (tester) async {
      await addReceipt(h.db, merchant: '100% Juice');
      await addReceipt(h.db, merchant: 'Under_score');
      await addReceipt(h.db, merchant: "Bob's Diner");
      await addReceipt(h.db, merchant: 'Say "Cheese"');
      await addReceipt(h.db, merchant: 'Cafe', notes: 'Coffee ☕ to go');
      await addReceipt(h.db, merchant: 'Plain Shop');
      await h.pump(tester);

      Future<void> expectOnly(String query, String merchant) async {
        await _search(tester, query);
        expect(find.byType(ReceiptListTile), findsOneWidget, reason: query);
        expect(find.text(merchant), findsOneWidget, reason: query);
      }

      await expectOnly('%', '100% Juice');
      await expectOnly('_', 'Under_score');
      await expectOnly("'", "Bob's Diner");
      await expectOnly('"', 'Say "Cheese"');
      await expectOnly('☕', 'Cafe');
      await _search(tester, r'\');
      expect(find.text('No matching receipts'), findsOneWidget);
    });

    testWidgets('clearing the filters never flashes the empty state', (
      tester,
    ) async {
      await addReceipt(h.db, merchant: 'Bean Bar');
      await h.pump(tester);
      await _search(tester, 'zzz');
      expect(find.text('No matching receipts'), findsOneWidget);

      await tester.tap(find.byKey(const Key('list-clear-filters')));
      // The frame right after: the old (empty) result must not be read as
      // "no receipts at all".
      await tester.pump();
      expect(find.text('No receipts yet'), findsNothing);
      expect(find.text('No matching receipts'), findsNothing);
      expect(find.byType(SearchBar), findsOneWidget);

      await tester.pumpAndSettle();
      expect(find.text('Bean Bar'), findsOneWidget);
    });
  });

  group('delete', () {
    testWidgets('screen readers get a Delete action with Undo', (tester) async {
      final handle = tester.ensureSemantics();
      final id = await addReceipt(h.db, merchant: 'Bean Bar');
      await addReceipt(h.db, merchant: 'Keep Me');
      await h.pump(tester);

      _deleteBySemantics(tester, 'Bean Bar');
      await tester.pumpAndSettle();

      expect(find.text('Bean Bar'), findsNothing);
      expect(find.text('Deleted Bean Bar'), findsOneWidget);
      expect(await h.db.receiptsDao.getReceipt(id), isNull);

      await tester.tap(find.text('Undo'));
      await tester.pumpAndSettle();
      expect(find.text('Bean Bar'), findsOneWidget);
      await ReceiptScreensHarness.finishSnackBars(tester);
      handle.dispose();
    });

    testWidgets('two deletes in a row: Undo restores the last one', (
      tester,
    ) async {
      final first = await addReceipt(h.db, merchant: 'First');
      final second = await addReceipt(h.db, merchant: 'Second');
      await addReceipt(h.db, merchant: 'Keep Me');
      await h.pump(tester);

      await tester.drag(find.text('First'), const Offset(-600, 0));
      await tester.pumpAndSettle();
      await tester.drag(find.text('Second'), const Offset(-600, 0));
      await tester.pumpAndSettle();

      expect(find.text('Deleted First'), findsNothing);
      expect(find.text('Deleted Second'), findsOneWidget);
      await tester.tap(find.text('Undo'));
      await tester.pumpAndSettle();

      expect(find.text('Second'), findsOneWidget);
      expect(find.text('First'), findsNothing);
      expect(await h.db.receiptsDao.getReceipt(second), isNotNull);
      expect(await h.db.receiptsDao.getReceipt(first), isNull);
      await ReceiptScreensHarness.finishSnackBars(tester);
    });

    testWidgets('a failed delete brings the row back with a message', (
      tester,
    ) async {
      final id = await addReceipt(h.db, merchant: 'Bean Bar');
      await h.pump(
        tester,
        overrides: [
          receiptRepositoryProvider.overrideWithValue(
            _FailingDeleteRepository(h.db, h.images),
          ),
        ],
      );

      await tester.drag(find.text('Bean Bar'), const Offset(-600, 0));
      await tester.pumpAndSettle();

      expect(find.text('Bean Bar'), findsOneWidget);
      expect(
        find.text("Couldn't delete the receipt. Please try again."),
        findsOneWidget,
      );
      expect(await h.db.receiptsDao.getReceipt(id), isNotNull);
      await ReceiptScreensHarness.finishSnackBars(tester);
    });

    testWidgets('Undo after its category was deleted restores it '
        'uncategorised', (tester) async {
      final ids = await categoryIds(h.db);
      final id = await addReceipt(
        h.db,
        merchant: 'Pizza Place',
        categoryId: ids['Dining'],
      );
      await h.pump(tester);

      await tester.drag(find.text('Pizza Place'), const Offset(-600, 0));
      await tester.pumpAndSettle();
      await h.db.categoriesDao.deleteCategory(ids['Dining']!);
      await tester.pumpAndSettle();

      await tester.tap(find.text('Undo'));
      await tester.pumpAndSettle();

      final restored = await h.db.receiptsDao.getReceipt(id);
      expect(restored, isNotNull);
      expect(restored!.categoryId, isNull);
      expect(find.text('Pizza Place'), findsOneWidget);
      await ReceiptScreensHarness.finishSnackBars(tester);
    });
  });

  group('settings propagate', () {
    testWidgets('changing the date order reformats row dates at once', (
      tester,
    ) async {
      await addReceipt(h.db, merchant: 'Bean Bar', date: LocalDate(2026, 9, 3));
      await h.pump(tester);
      expect(find.textContaining('09/03/2026'), findsOneWidget);

      final container = ProviderScope.containerOf(
        tester.element(find.byType(ReceiptListScreen)),
      );
      await container
          .read(settingsControllerProvider.notifier)
          .setDateOrder(DateOrder.ymd);
      await tester.pumpAndSettle();

      expect(find.textContaining('09/03/2026'), findsNothing);
      expect(find.textContaining('2026-09-03'), findsOneWidget);
    });
  });

  group('month card', () {
    testWidgets('moves to the new month when the app is resumed', (
      tester,
    ) async {
      await addReceipt(h.db, merchant: 'Sept', date: LocalDate(2026, 9, 20));
      await addReceipt(
        h.db,
        merchant: 'Oct',
        date: LocalDate(2026, 10, 1),
        totalMinor: 700,
      );
      h.now = DateTime(2026, 9, 30, 23, 50);
      await h.pump(tester);
      final card = find.byKey(const Key('list-month-summary'));
      expect(
        find.descendant(of: card, matching: find.text('September 2026')),
        findsOneWidget,
      );

      // Overnight in the background.
      h.now = DateTime(2026, 10, 1, 8);
      for (final state in [
        AppLifecycleState.inactive,
        AppLifecycleState.hidden,
        AppLifecycleState.paused,
        AppLifecycleState.hidden,
        AppLifecycleState.inactive,
        AppLifecycleState.resumed,
      ]) {
        tester.binding.handleAppLifecycleStateChanged(state);
      }
      await tester.pumpAndSettle();

      expect(
        find.descendant(of: card, matching: find.text('October 2026')),
        findsOneWidget,
      );
      expect(
        find.descendant(of: card, matching: find.text(r'$7.00')),
        findsOneWidget,
      );
    });

    testWidgets('December sums only that December, per currency, with the '
        'default currency first', (tester) async {
      tester.view.physicalSize = const Size(800, 2400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await addReceipt(
        h.db,
        merchant: 'Last Year',
        date: LocalDate(2025, 12, 31),
        totalMinor: 9900,
      );
      await addReceipt(h.db, date: LocalDate(2026, 12, 1), totalMinor: 100);
      await addReceipt(h.db, date: LocalDate(2026, 12, 31), totalMinor: 250);
      await addReceipt(
        h.db,
        date: LocalDate(2026, 12, 31),
        currency: 'AUD',
        totalMinor: 1000,
      );
      await addReceipt(
        h.db,
        merchant: 'Next Year',
        date: LocalDate(2027, 1, 1),
        totalMinor: 5000,
      );
      await h.prefs.setString(SettingsRepository.keyDefaultCurrency, 'AUD');
      h.now = DateTime(2026, 12, 31, 23, 59);
      await h.pump(tester);

      final card = find.byKey(const Key('list-month-summary'));
      expect(
        find.descendant(of: card, matching: find.text('December 2026')),
        findsOneWidget,
      );
      final aud = find.byKey(const ValueKey('list-month-total-AUD'));
      final usd = find.byKey(const ValueKey('list-month-total-USD'));
      expect(
        find.descendant(
          of: aud,
          matching: find.text(const Money(1000, 'AUD').format('en_US')),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: usd,
          matching: find.text(const Money(350, 'USD').format('en_US')),
        ),
        findsOneWidget,
      );
      expect(tester.getTopLeft(aud).dy, lessThan(tester.getTopLeft(usd).dy));
      // Headers: January 2027, December 2026 and December 2025, in order.
      double y(String text) => tester.getTopLeft(find.text(text).last).dy;
      expect(y('January 2027'), lessThan(y('December 2026')));
      expect(y('December 2026'), lessThan(y('December 2025')));
    });

    testWidgets('screen readers read it as one item', (tester) async {
      final handle = tester.ensureSemantics();
      await addReceipt(h.db, totalMinor: 1250);
      await addReceipt(h.db, currency: 'EUR', totalMinor: 300);
      await h.pump(tester);

      expect(
        find.bySemanticsLabel(
          RegExp(r'^This month\nSeptember 2026\n\$12\.50\n€3\.00$'),
        ),
        findsOneWidget,
      );
      handle.dispose();
    });
  });

  group('thumbnails', () {
    testWidgets('a missing thumbnail file shows a placeholder, not an error', (
      tester,
    ) async {
      // A load of the same file from an earlier test may still be pending
      // in the shared cache, inside that test's finished fake-async zone.
      imageCache
        ..clear()
        ..clearLiveImages();
      await addReceipt(
        h.db,
        merchant: 'Lost Photo',
        imagePath: 'receipts/lost.jpg',
      );
      await h.pump(tester);

      // Let the file read fail for real (no such file under the fake dir).
      for (var i = 0; i < 20; i++) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 10)),
        );
        await tester.pump();
        if (find.byIcon(Icons.broken_image_outlined).evaluate().isNotEmpty) {
          break;
        }
      }

      expect(tester.takeException(), isNull);
      expect(find.byIcon(Icons.broken_image_outlined), findsOneWidget);
      expect(find.text('Lost Photo'), findsOneWidget);
      // The row still opens its detail.
      await tester.tap(find.text('Lost Photo'));
      await tester.pumpAndSettle();
      expect(h.router.state.uri.path, startsWith('/receipts/'));
    });
  });

  group('accessibility guidelines', () {
    for (final mode in [ThemeMode.light, ThemeMode.dark]) {
      testWidgets('list meets them in ${mode.name} mode', (tester) async {
        final handle = tester.ensureSemantics();
        final ids = await categoryIds(h.db);
        await addReceipt(
          h.db,
          merchant: 'Freshway',
          categoryId: ids['Groceries'],
          imagePath: 'receipts/a.jpg',
        );
        await addReceipt(h.db, merchant: 'Corner Shop', currency: 'EUR');
        await h.pump(tester, themeMode: mode);

        await expectLater(tester, meetsGuideline(const _TapTargetGuideline()));
        await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
        await expectLater(tester, meetsGuideline(textContrastGuideline));
        handle.dispose();
      });

      testWidgets('the add sheet meets them in ${mode.name} mode', (
        tester,
      ) async {
        final handle = tester.ensureSemantics();
        await addReceipt(h.db, merchant: 'Freshway');
        await h.pump(tester, themeMode: mode);
        await tester.tap(find.byKey(const Key('list-fab')));
        await tester.pumpAndSettle();

        await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
        await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
        await expectLater(tester, meetsGuideline(textContrastGuideline));
        handle.dispose();
      });

      testWidgets('empty list meets them in ${mode.name} mode', (tester) async {
        final handle = tester.ensureSemantics();
        await h.pump(tester, themeMode: mode);

        await expectLater(tester, meetsGuideline(const _TapTargetGuideline()));
        await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
        await expectLater(tester, meetsGuideline(textContrastGuideline));
        handle.dispose();
      });
    }

    testWidgets('a row is one labelled button', (tester) async {
      final handle = tester.ensureSemantics();
      final ids = await categoryIds(h.db);
      await addReceipt(
        h.db,
        merchant: 'Freshway',
        date: LocalDate(2026, 9, 3),
        totalMinor: 4560,
        categoryId: ids['Groceries'],
      );
      await h.pump(tester);

      expect(
        tester.getSemantics(_row('Freshway')),
        isSemantics(
          label: r'Freshway, 09/03/2026, $45.60, Groceries',
          isButton: true,
          hasTapAction: true,
          customActions: [const CustomSemanticsAction(label: 'Delete')],
        ),
      );
      handle.dispose();
    });
  });
}
