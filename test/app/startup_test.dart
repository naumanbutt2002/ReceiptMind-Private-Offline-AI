import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:receipt_mind/app/startup.dart';
import 'package:receipt_mind/core/date/local_date.dart';
import 'package:receipt_mind/core/db/app_database.dart';
import 'package:receipt_mind/features/receipts/data/receipt_image_store.dart';

import '../helpers/test_app.dart';

class RecordingImageStore implements ReceiptImageStore {
  RecordingImageStore(this.log);

  final List<String> log;
  Set<String>? referenced;
  bool fail = false;

  @override
  Future<int> deleteOrphans(Set<String> referencedImagePaths) async {
    log.add('orphans');
    if (fail) throw StateError('disk error');
    referenced = referencedImagePaths;
    return 2;
  }

  @override
  Future<void> delete(String relativeImagePath) async {}

  @override
  Future<StoredImage> importScan(String sourcePath, {required String id}) =>
      throw UnimplementedError();

  @override
  Future<String> resolve(String relativePath) async => relativePath;

  @override
  String thumbnailFor(String relativeImagePath) => relativeImagePath;
}

void main() {
  late AppDatabase db;
  late RecordingImageStore images;
  late int cacheCleans;
  late List<String> log;

  setUp(() async {
    db = inMemoryDatabase();
    log = [];
    images = RecordingImageStore(log);
    cacheCleans = 0;
    final now = DateTime.utc(2026, 11, 16);
    await db.receiptsDao.insertReceipt(
      ReceiptsCompanion.insert(
        id: 'a',
        merchant: 'Aldi',
        purchaseDate: LocalDate(2026, 11, 15),
        totalMinor: 100,
        currency: 'AUD',
        imagePath: const Value('receipts/a.jpg'),
        extractionMethod: ExtractionMethod.rules,
        createdAt: now,
        updatedAt: now,
      ),
    );
  });
  tearDown(() => db.close());

  StartupHousekeeping housekeeping({bool failCache = false}) =>
      StartupHousekeeping(
        images: images,
        receipts: db.receiptsDao,
        cleanScannerCache: () async {
          log.add('cache');
          cacheCleans++;
          if (failCache) throw StateError('cache error');
        },
      );

  test(
    'cleans the scanner cache, then deletes orphans against stored paths',
    () async {
      await housekeeping().run();
      expect(images.referenced, {'receipts/a.jpg'});
      expect(cacheCleans, 1);
      // The quick cache clean runs first, so it can't race a scan the user
      // finishes while a long orphan cleanup is still running.
      expect(log, ['cache', 'orphans']);
    },
  );

  test('a failed orphan cleanup still cleans the cache', () async {
    images.fail = true;
    await housekeeping().run();
    expect(cacheCleans, 1);
  });

  test('a failed cache cleanup does not throw', () async {
    await expectLater(housekeeping(failCache: true).run(), completes);
    expect(images.referenced, isNotNull);
    expect(cacheCleans, 1);
  });

  test('a closed database does not throw', () async {
    await db.close();
    await expectLater(housekeeping().run(), completes);
    expect(images.referenced, isNull);
    expect(cacheCleans, 1);
  });
}
