import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:receipt_mind/core/date/local_date.dart';
import 'package:receipt_mind/core/db/app_database.dart';

import '../../helpers/test_app.dart';

void main() {
  late AppDatabase db;

  setUp(() => db = inMemoryDatabase());
  tearDown(() => db.close());

  var nextId = 0;
  ReceiptsCompanion receipt({
    String merchant = 'Woolworths',
    required LocalDate date,
    int total = 1000,
    String currency = 'AUD',
    int? categoryId,
    String? notes,
    String? ocr,
    String? imagePath,
    DateTime? createdAt,
  }) {
    final now = createdAt ?? DateTime.utc(2026, 9, 24, 12);
    return ReceiptsCompanion.insert(
      id: 'r${nextId++}',
      merchant: merchant,
      purchaseDate: date,
      totalMinor: total,
      currency: currency,
      categoryId: Value(categoryId),
      notes: Value(notes),
      rawOcrText: Value(ocr),
      imagePath: Value(imagePath),
      extractionMethod: ExtractionMethod.rules,
      createdAt: now,
      updatedAt: now,
    );
  }

  test('seeds the seven default categories once', () async {
    final categories = await db.categoriesDao.watchAll().first;
    expect(categories.map((c) => c.name), [
      'Groceries',
      'Dining',
      'Transport',
      'Shopping',
      'Bills',
      'Health',
      'Other',
    ]);
  });

  test('round-trips every field', () async {
    final date = LocalDate(2026, 9, 12);
    await db.receiptsDao.insertReceipt(
      receipt(date: date, total: 4560, notes: 'Team lunch').copyWith(
        subtotalMinor: const Value(4145),
        taxMinor: const Value(415),
        paymentMethod: const Value(PaymentMethod.card),
        confidence: const Value(0.87),
      ),
    );
    final row = (await db.receiptsDao.watchReceipts().first).single;
    expect(row.purchaseDate, date);
    expect(row.totalMinor, 4560);
    expect(row.subtotalMinor, 4145);
    expect(row.taxMinor, 415);
    expect(row.tipMinor, isNull);
    expect(row.paymentMethod, PaymentMethod.card);
    expect(row.extractionMethod, ExtractionMethod.rules);
    expect(row.notes, 'Team lunch');
  });

  test('lists newest purchase first, then newest created', () async {
    await db.receiptsDao.insertReceipt(
      receipt(merchant: 'Old', date: LocalDate(2026, 8, 1)),
    );
    await db.receiptsDao.insertReceipt(
      receipt(
        merchant: 'New A',
        date: LocalDate(2026, 9, 1),
        createdAt: DateTime.utc(2026, 9, 1, 8),
      ),
    );
    await db.receiptsDao.insertReceipt(
      receipt(
        merchant: 'New B',
        date: LocalDate(2026, 9, 1),
        createdAt: DateTime.utc(2026, 9, 1, 9),
      ),
    );
    final rows = await db.receiptsDao.watchReceipts().first;
    expect(rows.map((r) => r.merchant), ['New B', 'New A', 'Old']);
  });

  group('search', () {
    setUp(() async {
      await db.receiptsDao.insertReceipt(
        receipt(
          merchant: 'Bunnings Warehouse',
          date: LocalDate(2026, 9, 1),
          ocr: 'AA BATTERIES 4PK 9.98',
        ),
      );
      await db.receiptsDao.insertReceipt(
        receipt(
          merchant: 'Cafe 100%',
          date: LocalDate(2026, 9, 2),
          notes: 'client_meeting',
        ),
      );
    });

    Future<List<String>> search(String q) async =>
        (await db.receiptsDao.watchReceipts(query: q).first)
            .map((r) => r.merchant)
            .toList();

    test('matches merchant case-insensitively', () async {
      expect(await search('bunnings'), ['Bunnings Warehouse']);
    });

    test('matches recognised text and notes', () async {
      expect(await search('batteries'), ['Bunnings Warehouse']);
      expect(await search('client'), ['Cafe 100%']);
    });

    test('treats % and _ literally', () async {
      expect(await search('100%'), ['Cafe 100%']);
      expect(await search('%'), ['Cafe 100%']);
      expect(await search('Cafe_100'), isEmpty); // _ is not a wildcard
      expect(await search('client_m'), ['Cafe 100%']);
    });

    test('blank query returns everything', () async {
      expect(await search('   '), hasLength(2));
    });
  });

  test('filters by category', () async {
    final groceries = (await db.categoriesDao.watchAll().first).first;
    await db.receiptsDao.insertReceipt(
      receipt(
        merchant: 'Aldi',
        date: LocalDate(2026, 9, 1),
        categoryId: groceries.id,
      ),
    );
    await db.receiptsDao.insertReceipt(
      receipt(merchant: 'Uber', date: LocalDate(2026, 9, 1)),
    );
    final rows = await db.receiptsDao
        .watchReceipts(categoryId: groceries.id)
        .first;
    expect(rows.map((r) => r.merchant), ['Aldi']);
  });

  test('month totals are per currency and bounded to the month', () async {
    for (final (date, total, currency) in [
      (LocalDate(2026, 8, 31), 999, 'AUD'), // previous month
      (LocalDate(2026, 9, 1), 1000, 'AUD'),
      (LocalDate(2026, 9, 30), 2550, 'AUD'),
      (LocalDate(2026, 9, 15), 1200, 'USD'),
      (LocalDate(2026, 10, 1), 777, 'AUD'), // next month
    ]) {
      await db.receiptsDao.insertReceipt(
        receipt(date: date, total: total, currency: currency),
      );
    }
    final totals = await db.receiptsDao
        .watchMonthTotals(LocalDate(2026, 9, 24))
        .first;
    expect(totals, {'AUD': 3550, 'USD': 1200});
  });

  test('month totals are empty for a month without receipts', () async {
    expect(
      await db.receiptsDao.watchMonthTotals(LocalDate(2026, 1, 1)).first,
      isEmpty,
    );
  });

  test('delete returns the row and restore brings it back', () async {
    await db.receiptsDao.insertReceipt(
      receipt(merchant: 'Kmart', date: LocalDate(2026, 9, 3)),
    );
    final id = (await db.receiptsDao.watchReceipts().first).single.id;

    final deleted = await db.receiptsDao.deleteReceipt(id);
    expect(deleted?.merchant, 'Kmart');
    expect(await db.receiptsDao.watchReceipts().first, isEmpty);
    expect(await db.receiptsDao.deleteReceipt(id), isNull);

    await db.receiptsDao.restoreReceipt(deleted!);
    expect((await db.receiptsDao.getReceipt(id))?.merchant, 'Kmart');
  });

  test('deleting a category un-categorises its receipts', () async {
    final dining = (await db.categoriesDao.watchAll().first)[1];
    await db.receiptsDao.insertReceipt(
      receipt(
        merchant: 'Nando\'s',
        date: LocalDate(2026, 9, 5),
        categoryId: dining.id,
      ),
    );
    expect(await db.categoriesDao.countReceipts(dining.id), 1);

    await db.categoriesDao.deleteCategory(dining.id);

    final row = (await db.receiptsDao.watchReceipts().first).single;
    expect(row.categoryId, isNull);
    expect(await db.categoriesDao.watchCount().first, 6);
  });

  test('rejects a receipt pointing at a missing category', () async {
    expect(
      db.receiptsDao.insertReceipt(
        receipt(date: LocalDate(2026, 9, 5), categoryId: 9999),
      ),
      throwsA(anything),
    );
  });

  test('collects image paths for orphan cleanup', () async {
    await db.receiptsDao.insertReceipt(
      receipt(date: LocalDate(2026, 9, 5), imagePath: 'receipts/a.jpg'),
    );
    await db.receiptsDao.insertReceipt(receipt(date: LocalDate(2026, 9, 6)));
    expect(await db.receiptsDao.allImagePaths(), {'receipts/a.jpg'});
  });

  test('category names are unique', () async {
    expect(
      db.categoriesDao.insertCategory(
        CategoriesCompanion.insert(
          name: 'Groceries',
          iconKey: 'groceries',
          color: 0xFF000000,
        ),
      ),
      throwsA(anything),
    );
  });
}
