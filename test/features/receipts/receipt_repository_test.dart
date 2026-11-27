import 'package:drift/drift.dart' show Value;
import 'package:flutter_test/flutter_test.dart';
import 'package:receipt_mind/core/date/local_date.dart';
import 'package:receipt_mind/core/db/app_database.dart';
import 'package:receipt_mind/features/receipts/data/receipt_image_store.dart';
import 'package:receipt_mind/features/receipts/data/receipt_repository.dart';
import 'package:receipt_mind/features/receipts/data/receipt_storage_exception.dart';
import 'package:receipt_mind/features/scan/application/receipt_draft.dart';

import '../../helpers/test_app.dart';

/// Keeps "files" as a set of relative paths.
class FakeImageStore implements ReceiptImageStore {
  final files = <String>{};
  final imports = <({String source, String id})>[];
  bool failImport = false;
  Object importError = StateError('import failed');

  @override
  Future<StoredImage> importScan(
    String sourcePath, {
    required String id,
  }) async {
    if (failImport) throw importError;
    imports.add((source: sourcePath, id: id));
    final image = 'receipts/$id.jpg';
    final stored = (image: image, thumbnail: thumbnailFor(image));
    files.addAll([stored.image, stored.thumbnail]);
    return stored;
  }

  @override
  Future<String> resolve(String relativePath) async => '/base/$relativePath';

  @override
  String thumbnailFor(String relativeImagePath) =>
      relativeImagePath.replaceFirst('receipts/', 'receipts/thumbs/');

  @override
  Future<void> delete(String relativeImagePath) async {
    files
      ..remove(relativeImagePath)
      ..remove(thumbnailFor(relativeImagePath));
  }

  @override
  Future<int> deleteOrphans(Set<String> referencedImagePaths) async => 0;
}

void main() {
  late AppDatabase db;
  late FakeImageStore images;
  late ReceiptRepository repository;
  late DateTime now;
  late int nextId;

  setUp(() {
    db = inMemoryDatabase();
    images = FakeImageStore();
    now = DateTime.utc(2026, 11, 16, 9);
    nextId = 0;
    repository = ReceiptRepository(
      db.receiptsDao,
      images,
      clock: () => now,
      newId: () => 'id${nextId++}',
    );
  });
  tearDown(() => db.close());

  ReceiptDraft draft({
    String merchant = '  Woolworths  ',
    String currency = 'AUD',
    String? sourceImagePath = '/cache/scan.jpg',
    int? categoryId,
    String rawOcrText = 'WOOLWORTHS\nTOTAL 45.60',
  }) => ReceiptDraft(
    currency: currency,
    extractionMethod: ExtractionMethod.rules,
    merchant: merchant,
    date: LocalDate(2026, 11, 14),
    totalMinor: 4560,
    taxMinor: 415,
    paymentMethod: PaymentMethod.card,
    categoryId: categoryId,
    notes: ' lunch ',
    sourceImagePath: sourceImagePath,
    rawOcrText: rawOcrText,
    confidence: 0.9,
  );

  group('createFromDraft', () {
    test('imports the scan and inserts the row', () async {
      final id = await repository.createFromDraft(draft());

      expect(id, 'id0');
      expect(images.imports, [(source: '/cache/scan.jpg', id: 'id0')]);
      final row = (await repository.getReceipt(id))!;
      expect(row.merchant, 'Woolworths');
      expect(row.purchaseDate, LocalDate(2026, 11, 14));
      expect(row.totalMinor, 4560);
      expect(row.taxMinor, 415);
      expect(row.subtotalMinor, isNull);
      expect(row.currency, 'AUD');
      expect(row.paymentMethod, PaymentMethod.card);
      expect(row.notes, 'lunch');
      expect(row.imagePath, 'receipts/id0.jpg');
      expect(row.rawOcrText, 'WOOLWORTHS\nTOTAL 45.60');
      expect(row.extractionMethod, ExtractionMethod.rules);
      expect(row.confidence, 0.9);
      expect(row.createdAt.toUtc(), now);
      expect(row.updatedAt.toUtc(), now);
    });

    test('saves a manual entry without an image', () async {
      final id = await repository.createFromDraft(
        draft(sourceImagePath: null).copyWith(notes: '   '),
      );
      final row = (await repository.getReceipt(id))!;
      expect(row.imagePath, isNull);
      expect(row.notes, isNull);
      expect(images.imports, isEmpty);
    });

    test('rejects an incomplete draft before importing', () async {
      final incomplete = ReceiptDraft(
        currency: 'AUD',
        extractionMethod: ExtractionMethod.manual,
        merchant: '   ',
        date: LocalDate(2026, 11, 14),
        totalMinor: 100,
        sourceImagePath: '/cache/scan.jpg',
      );
      await expectLater(
        repository.createFromDraft(incomplete),
        throwsArgumentError,
      );
      await expectLater(
        repository.createFromDraft(
          ReceiptDraft(
            currency: 'AUD',
            extractionMethod: ExtractionMethod.manual,
            merchant: 'Aldi',
            totalMinor: 100,
          ),
        ),
        throwsArgumentError,
      );
      expect(images.imports, isEmpty);
      expect(await repository.watchReceipts().first, isEmpty);
    });

    test('rejects a draft that already has an id', () async {
      final id = await repository.createFromDraft(draft());
      final existing = repository.draftFromRow(
        (await repository.getReceipt(id))!,
      );
      await expectLater(
        repository.createFromDraft(existing),
        throwsArgumentError,
      );
    });

    test('deletes the imported files when the insert fails', () async {
      // Currency must be 3 letters.
      await expectLater(
        repository.createFromDraft(draft(currency: 'AU')),
        throwsA(anything),
      );
      expect(images.imports, hasLength(1));
      expect(images.files, isEmpty);

      // A missing category fails the foreign key in SQLite.
      await expectLater(
        repository.createFromDraft(draft(categoryId: 9999)),
        throwsA(anything),
      );
      expect(images.imports, hasLength(2));
      expect(images.files, isEmpty);
      expect(await repository.watchReceipts().first, isEmpty);
    });

    test('a duplicate id fails and keeps the first receipt intact', () async {
      final repeating = ReceiptRepository(
        db.receiptsDao,
        images,
        clock: () => now,
        newId: () => 'same',
      );
      // Without an image, so both inserts target the same row only.
      await repeating.createFromDraft(draft(sourceImagePath: null));
      await expectLater(
        repeating.createFromDraft(draft(sourceImagePath: null)),
        throwsA(anything),
      );
      expect(await repository.watchReceipts().first, hasLength(1));
    });

    test('nothing is inserted when the import fails', () async {
      images.failImport = true;
      await expectLater(repository.createFromDraft(draft()), throwsStateError);
      expect(await repository.watchReceipts().first, isEmpty);
    });

    test('a typed import failure reaches the caller unchanged', () async {
      const error = ReceiptStorageException(ReceiptStorageFailure.storageFull);
      images
        ..failImport = true
        ..importError = error;
      await expectLater(
        repository.createFromDraft(draft()),
        throwsA(same(error)),
      );
    });

    test(
      'a full database is reported as storageFull and drops the files',
      () async {
        // Cap the in-memory database at its current size, so the next insert
        // fails with SQLITE_FULL like a full disk would.
        final pages = await db
            .customSelect('PRAGMA page_count')
            .map((row) => row.read<int>('page_count'))
            .getSingle();
        await db.customStatement('PRAGMA max_page_count = $pages');

        await expectLater(
          repository.createFromDraft(draft(rawOcrText: 'x' * 200000)),
          throwsA(
            isA<ReceiptStorageException>().having(
              (e) => e.reason,
              'reason',
              ReceiptStorageFailure.storageFull,
            ),
          ),
        );
        expect(images.imports, hasLength(1));
        expect(images.files, isEmpty);
      },
    );

    test(
      'a merchant longer than the column allows is cut, not rejected',
      () async {
        final long = '${'a' * 199}😀 more text';
        final id = await repository.createFromDraft(draft(merchant: long));
        final merchant = (await repository.getReceipt(id))!.merchant;
        // 199 + the emoji's two code units would be 201: the emoji is dropped
        // whole rather than split.
        expect(merchant, 'a' * 199);

        final id2 = await repository.createFromDraft(
          draft(merchant: 'b' * 250),
        );
        expect((await repository.getReceipt(id2))!.merchant, 'b' * 200);
      },
    );
  });

  group('update', () {
    late String id;
    late DateTime created;

    setUp(() async {
      id = await repository.createFromDraft(draft());
      created = now;
      now = now.add(const Duration(hours: 2));
    });

    test('updates fields and keeps createdAt and the image', () async {
      final edit = repository
          .draftFromRow((await repository.getReceipt(id))!)
          .copyWith(merchant: ' Coles ', totalMinor: 5000, clearTax: true);

      await repository.update(edit);

      final row = (await repository.getReceipt(id))!;
      expect(row.merchant, 'Coles');
      expect(row.totalMinor, 5000);
      expect(row.taxMinor, isNull);
      expect(row.imagePath, 'receipts/id0.jpg');
      expect(row.createdAt.toUtc(), created);
      expect(row.updatedAt.toUtc(), now);
      expect(images.imports, hasLength(1));
      expect(images.files, {'receipts/id0.jpg', 'receipts/thumbs/id0.jpg'});
    });

    test('a new scan replaces the image and deletes the old files', () async {
      final row = (await repository.getReceipt(id))!;
      final edit = ReceiptDraft(
        id: id,
        currency: 'AUD',
        extractionMethod: ExtractionMethod.rules,
        merchant: 'Woolworths',
        date: row.purchaseDate,
        totalMinor: 4560,
        sourceImagePath: '/cache/rescan.jpg',
      );

      await repository.update(edit);

      final updated = (await repository.getReceipt(id))!;
      expect(images.imports.last, (source: '/cache/rescan.jpg', id: 'id1'));
      expect(updated.imagePath, 'receipts/id1.jpg');
      expect(images.files, {'receipts/id1.jpg', 'receipts/thumbs/id1.jpg'});
    });

    test('a failed update keeps the old image and drops the new one', () async {
      final edit = repository
          .draftFromRow((await repository.getReceipt(id))!)
          .copyWith(currency: 'TOOLONG');
      final withScan = ReceiptDraft(
        id: edit.id,
        currency: edit.currency,
        extractionMethod: edit.extractionMethod,
        merchant: edit.merchant,
        date: edit.date,
        totalMinor: edit.totalMinor,
        sourceImagePath: '/cache/rescan.jpg',
      );

      await expectLater(repository.update(withScan), throwsA(anything));

      final row = (await repository.getReceipt(id))!;
      expect(row.imagePath, 'receipts/id0.jpg');
      expect(row.currency, 'AUD');
      expect(images.files, {'receipts/id0.jpg', 'receipts/thumbs/id0.jpg'});
    });

    test('fails for a missing receipt or a draft without an id', () async {
      await repository.delete(id);
      final edit = draft(sourceImagePath: '/cache/rescan.jpg');
      await expectLater(
        repository.update(
          ReceiptDraft(
            id: id,
            currency: edit.currency,
            extractionMethod: edit.extractionMethod,
            merchant: edit.merchant,
            date: edit.date,
            totalMinor: edit.totalMinor,
            sourceImagePath: edit.sourceImagePath,
          ),
        ),
        throwsStateError,
      );
      expect(images.files, {'receipts/id0.jpg', 'receipts/thumbs/id0.jpg'});
      await expectLater(repository.update(edit), throwsArgumentError);
    });
  });

  test('delete keeps the files and restore brings the row back', () async {
    final id = await repository.createFromDraft(draft());

    final deleted = await repository.delete(id);
    expect(deleted?.merchant, 'Woolworths');
    expect(await repository.getReceipt(id), isNull);
    expect(images.files, contains('receipts/id0.jpg'));
    expect(await repository.delete(id), isNull);

    await repository.restore(deleted!);
    expect(await repository.getReceipt(id), deleted);
  });

  test(
    'restore brings a receipt back uncategorised if its category is gone',
    () async {
      final categoryId = await db.categoriesDao.insertCategory(
        CategoriesCompanion.insert(name: 'Temp', iconKey: 'other', color: 0),
      );
      final id = await repository.createFromDraft(
        draft(categoryId: categoryId),
      );
      final deleted = (await repository.delete(id))!;
      await db.categoriesDao.deleteCategory(categoryId);

      await repository.restore(deleted);

      final row = (await repository.getReceipt(id))!;
      expect(row.categoryId, isNull);
      expect(row.copyWith(categoryId: Value(categoryId)), deleted);
    },
  );

  test('watchReceipt follows changes and deletion', () async {
    final id = await repository.createFromDraft(draft());
    final stream = repository.watchReceipt(id);
    expect((await stream.first)?.merchant, 'Woolworths');

    final values = <String?>[];
    final sub = stream.listen((row) => values.add(row?.merchant));
    await pumpEventQueue();
    await repository.delete(id);
    await pumpEventQueue();
    await sub.cancel();
    expect(values, ['Woolworths', null]);
  });

  test('read API passes through to the DAO', () async {
    await repository.createFromDraft(draft());
    await repository.createFromDraft(draft(merchant: 'Bunnings'));
    expect(
      (await repository.watchReceipts(query: 'bunn').first).map(
        (r) => r.merchant,
      ),
      ['Bunnings'],
    );
    expect(await repository.watchMonthTotals(LocalDate(2026, 11, 1)).first, {
      'AUD': 9120,
    });
    expect(
      await repository.receiptsBetween(from: LocalDate(2026, 11, 14)),
      hasLength(2),
    );
  });

  test('draftFromRow round-trips through update unchanged', () async {
    final id = await repository.createFromDraft(draft(categoryId: 1));
    final row = (await repository.getReceipt(id))!;
    final edit = repository.draftFromRow(row);

    expect(edit.id, id);
    expect(edit.isNew, isFalse);
    expect(edit.merchant, 'Woolworths');
    expect(edit.date, row.purchaseDate);
    expect(edit.totalMinor, 4560);
    expect(edit.taxMinor, 415);
    expect(edit.categoryId, 1);
    expect(edit.notes, 'lunch');
    expect(edit.imagePath, 'receipts/id0.jpg');
    expect(edit.sourceImagePath, isNull);
    expect(edit.rawOcrText, row.rawOcrText);
    expect(edit.extractionMethod, ExtractionMethod.rules);
    expect(edit.confidence, 0.9);

    await repository.update(edit);
    final after = (await repository.getReceipt(id))!;
    expect(after.copyWith(updatedAt: row.updatedAt), row);
  });
}
