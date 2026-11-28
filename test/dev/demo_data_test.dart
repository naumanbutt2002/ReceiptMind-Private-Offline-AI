import 'package:flutter_test/flutter_test.dart';
import 'package:receipt_mind/core/date/local_date.dart';
import 'package:receipt_mind/core/db/app_database.dart';
import 'package:receipt_mind/dev/demo_data.dart';

import '../helpers/test_app.dart';

void main() {
  final now = DateTime(2026, 11, 16, 9, 30);
  final today = LocalDate.fromDateTime(now);
  const categoryIds = [1, 2, 3, 4, 5, 6, 7];

  List<ReceiptsCompanion> generate({int count = 1000, int seed = 42}) =>
      demoReceipts(
        count: count,
        categoryIds: categoryIds,
        now: now,
        seed: seed,
      );

  test('generates the requested number of receipts', () {
    expect(generate(count: 0), isEmpty);
    expect(generate(count: 1), hasLength(1));
    expect(generate(), hasLength(1000));
  });

  test('is deterministic for a seed and differs between seeds', () {
    final a = generate(count: 50);
    final b = generate(count: 50);
    final c = generate(count: 50, seed: 7);
    expect(a.map((r) => r.toString()), b.map((r) => r.toString()));
    expect(a.map((r) => r.id.value), isNot(c.map((r) => r.id.value)));
  });

  test('produces valid fields', () {
    final receipts = generate();
    final earliest = today.addDays(-(demoDaySpan - 1));
    final uuidV7 = RegExp(
      r'^[0-9a-f]{8}-[0-9a-f]{4}-7[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
    );

    expect(receipts.map((r) => r.id.value).toSet(), hasLength(1000));
    for (final r in receipts) {
      expect(r.id.value, matches(uuidV7));
      expect(r.merchant.value, isNotEmpty);
      final date = r.purchaseDate.value;
      expect(date.isAfter(today), isFalse, reason: '$date');
      expect(date.isBefore(earliest), isFalse, reason: '$date');
      expect(r.totalMinor.value, greaterThan(0));
      expect(demoCurrencies, contains(r.currency.value));
      final tax = r.taxMinor.value;
      if (tax != null) expect(tax, lessThan(r.totalMinor.value));
      final category = r.categoryId.value;
      if (category != null) expect(categoryIds, contains(category));
      expect(r.imagePath.present, isFalse);
      expect(
        r.extractionMethod.value,
        isIn([ExtractionMethod.rules, ExtractionMethod.manual]),
      );
      final confidence = r.confidence.value;
      if (r.extractionMethod.value == ExtractionMethod.rules) {
        expect(confidence, inInclusiveRange(0.0, 1.0));
        expect(r.rawOcrText.value, contains('TOTAL'));
      } else {
        expect(confidence, isNull);
      }
      expect(r.createdAt.value, r.updatedAt.value);
      expect(r.createdAt.value.isAfter(now), isFalse, reason: 'saved later');
    }
  });

  test('receipts dated today are never saved after now', () {
    // At 07:00 almost every random time of day (07:00–22:59) is later.
    final early = DateTime(2026, 11, 16, 7);
    final receipts = demoReceipts(
      count: 5000,
      categoryIds: categoryIds,
      now: early,
    );
    final todays = [
      for (final r in receipts)
        if (r.purchaseDate.value == LocalDate.fromDateTime(early)) r,
    ];
    expect(todays, isNotEmpty);
    for (final r in todays) {
      expect(r.createdAt.value.isAfter(early), isFalse);
    }
  });

  test('has a realistic mix', () {
    final receipts = generate();
    int share(bool Function(ReceiptsCompanion) test) =>
        receipts.where(test).length;

    final aud = share((r) => r.currency.value == 'AUD');
    expect(aud, inInclusiveRange(700, 900));
    expect(share((r) => r.currency.value == 'USD'), greaterThan(50));
    expect(share((r) => r.currency.value == 'EUR'), greaterThan(30));
    expect(share((r) => r.categoryId.value == null), inInclusiveRange(50, 150));
    expect(
      share((r) => r.extractionMethod.value == ExtractionMethod.manual),
      inInclusiveRange(150, 350),
    );
    // Spread over many months, not bunched on a few days.
    final months = {
      for (final r in receipts) r.purchaseDate.value.firstOfMonth,
    };
    expect(months.length, greaterThanOrEqualTo(18));
  });

  test('without categories every receipt is uncategorised', () {
    final receipts = demoReceipts(count: 100, categoryIds: const [], now: now);
    expect(receipts.every((r) => r.categoryId.value == null), isTrue);
  });

  test('inserts into the database', () async {
    final db = inMemoryDatabase();
    addTearDown(db.close);
    final categories = await db.categoriesDao.watchAll().first;
    final receipts = demoReceipts(
      count: 1000,
      categoryIds: [for (final c in categories) c.id],
      now: now,
    );
    await db.batch((b) => b.insertAll(db.receipts, receipts));

    expect(await db.select(db.receipts).get(), hasLength(1000));
    final groceries = categories.firstWhere((c) => c.iconKey == 'groceries');
    final rows = await db.receiptsDao
        .watchReceipts(categoryId: groceries.id)
        .first;
    expect(rows, isNotEmpty);
    expect(
      rows.map((r) => r.merchant),
      everyElement(
        isIn([
          'Woolworths',
          'Coles',
          'ALDI',
          'IGA Fresh',
          'Harris Farm Markets',
          'Whole Foods Market',
          "Trader Joe's",
          'Lidl',
          'REWE',
        ]),
      ),
    );
  });
}
