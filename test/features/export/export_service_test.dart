import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:receipt_mind/core/date/local_date.dart';
import 'package:receipt_mind/core/db/app_database.dart';
import 'package:receipt_mind/features/export/export_service.dart';

import '../../helpers/test_app.dart';

/// Records what would have gone to the share sheet.
class FakeFileSharer implements FileSharer {
  final shared = <({String path, String mimeType, String? subject})>[];
  Object? error;

  @override
  Future<void> shareFile(
    String path, {
    required String mimeType,
    String? subject,
  }) async {
    if (error != null) throw error!;
    shared.add((path: path, mimeType: mimeType, subject: subject));
  }
}

ReceiptRow receipt(String id, {int? categoryId}) => ReceiptRow(
  id: id,
  merchant: 'Shop $id',
  purchaseDate: LocalDate(2026, 11, 2),
  totalMinor: 999,
  currency: 'USD',
  categoryId: categoryId,
  extractionMethod: ExtractionMethod.manual,
  createdAt: DateTime.utc(2026, 11, 2, 8),
  updatedAt: DateTime.utc(2026, 11, 2, 8),
);

void main() {
  late Directory temp;
  late FakeFileSharer sharer;
  late List<({LocalDate? from, LocalDate? to})> loads;

  setUp(() {
    temp = Directory.systemTemp.createTempSync('export_test');
    sharer = FakeFileSharer();
    loads = [];
  });
  tearDown(() => temp.deleteSync(recursive: true));

  ExportService service(List<ReceiptRow> rows) => ExportService(
    loadReceipts: ({from, to}) async {
      loads.add((from: from, to: to));
      return rows;
    },
    loadCategoryNames: () async => {1: 'Dining'},
    tempDirectory: () async => temp,
    sharer: sharer,
    clock: () => DateTime(2026, 11, 16, 21, 5),
  );

  test('writes a dated CSV to the temp directory and shares it', () async {
    final result = await service([receipt('a', categoryId: 1), receipt('b')])
        .exportCsv(shareSubject: 'My receipts');

    expect(result.isEmpty, isFalse);
    expect(result.receiptCount, 2);
    final file = result.file!;
    expect(file.path, p.join(temp.path, 'receiptmind-export-20261116.csv'));

    final bytes = file.readAsBytesSync();
    expect(bytes.take(3), [0xEF, 0xBB, 0xBF]);
    final text = file.readAsStringSync();
    expect(text, contains('a,2026-11-02,Shop a,Dining,9.99,'));
    expect(text, contains('b,2026-11-02,Shop b,,9.99,'));

    expect(sharer.shared, [
      (path: file.path, mimeType: 'text/csv', subject: 'My receipts'),
    ]);
    expect(loads, [(from: null, to: null)]);
  });

  test('passes the date range to the loader', () async {
    final from = LocalDate(2026, 10, 1);
    final to = LocalDate(2026, 10, 31);
    await service([receipt('a')]).exportCsv(from: from, to: to);
    expect(loads, [(from: from, to: to)]);
  });

  test('nothing to export: no file, no share sheet', () async {
    final result = await service([]).exportCsv();

    expect(result.isEmpty, isTrue);
    expect(result.file, isNull);
    expect(sharer.shared, isEmpty);
    expect(temp.listSync(), isEmpty);
  });

  test('share errors reach the caller', () async {
    sharer.error = StateError('no share sheet');
    expect(
      () => service([receipt('a')]).exportCsv(),
      throwsA(isA<StateError>()),
    );
  });

  test('a second export the same day never overwrites the first', () async {
    final first = await service([receipt('a')]).exportCsv();
    final second = await service([receipt('a'), receipt('b')]).exportCsv();
    final third = await service([receipt('c')]).exportCsv();

    expect(
      first.file!.path,
      p.join(temp.path, 'receiptmind-export-20261116.csv'),
    );
    expect(
      second.file!.path,
      p.join(temp.path, 'receiptmind-export-20261116-2.csv'),
    );
    expect(
      third.file!.path,
      p.join(temp.path, 'receiptmind-export-20261116-3.csv'),
    );
    // The first file (maybe still being read by a share target) is intact.
    expect(first.file!.readAsStringSync(), isNot(contains('Shop b')));
    expect(second.file!.readAsStringSync(), contains('Shop b'));
    expect(sharer.shared.map((s) => s.path), [
      first.file!.path,
      second.file!.path,
      third.file!.path,
    ]);
  });

  test('exports of 0, 1 and many receipts', () async {
    expect((await service([]).exportCsv()).receiptCount, 0);

    final one = await service([receipt('a')]).exportCsv();
    expect(one.receiptCount, 1);
    // Header plus one row, each ending in CRLF.
    expect('\r\n'.allMatches(one.file!.readAsStringSync()).length, 2);

    final many = await service([for (var i = 0; i < 250; i++) receipt('m$i')])
        .exportCsv();
    expect(many.receiptCount, 250);
    expect('\r\n'.allMatches(many.file!.readAsStringSync()).length, 251);
  });

  test(
    'date ranges include both ends; an empty range exports nothing',
    () async {
      final db = inMemoryDatabase();
      addTearDown(db.close);
      for (final (id, date) in [
        ('sep30', LocalDate(2026, 9, 30)),
        ('oct01', LocalDate(2026, 10, 1)),
        ('oct31', LocalDate(2026, 10, 31)),
        ('nov01', LocalDate(2026, 11, 1)),
      ]) {
        await db.receiptsDao.insertReceipt(
          ReceiptsCompanion.insert(
            id: id,
            merchant: 'Shop $id',
            purchaseDate: date,
            totalMinor: 100,
            currency: 'USD',
            extractionMethod: ExtractionMethod.manual,
            createdAt: DateTime.utc(2026, 11, 2),
            updatedAt: DateTime.utc(2026, 11, 2),
          ),
        );
      }
      final export = ExportService(
        loadReceipts: db.receiptsDao.receiptsBetween,
        loadCategoryNames: () async => {},
        tempDirectory: () async => temp,
        sharer: sharer,
        clock: () => DateTime(2026, 11, 16),
      );

      final october = await export.exportCsv(
        from: LocalDate(2026, 10, 1),
        to: LocalDate(2026, 10, 31),
      );
      expect(october.receiptCount, 2);
      final text = october.file!.readAsStringSync();
      expect(text, contains('oct01,2026-10-01,'));
      expect(text, contains('oct31,2026-10-31,'));
      expect(text, isNot(contains('sep30')));
      expect(text, isNot(contains('nov01')));

      final oneDay = await export.exportCsv(
        from: LocalDate(2026, 11, 1),
        to: LocalDate(2026, 11, 1),
      );
      expect(oneDay.receiptCount, 1);

      final december = await export.exportCsv(
        from: LocalDate(2026, 12, 1),
        to: LocalDate(2026, 12, 31),
      );
      expect(december.isEmpty, isTrue);
      expect(sharer.shared, hasLength(2));
    },
  );

  test('file name pads the date', () {
    expect(
      ExportService.fileNameFor(DateTime(2027, 1, 5)),
      'receiptmind-export-20270105.csv',
    );
  });
}
