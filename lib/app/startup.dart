import 'package:flutter/foundation.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../core/db/daos/receipts_dao.dart';
import '../core/db/db_providers.dart';
import '../features/receipts/data/receipt_image_store.dart';
import '../features/receipts/data/receipts_providers.dart';
import '../features/scan/scan_providers.dart';

part 'startup.g.dart';

/// Runs [StartupHousekeeping] once per app start (the app reads it after the
/// first frame).
@Riverpod(keepAlive: true)
Future<void> startupHousekeeping(Ref ref) => StartupHousekeeping(
  images: ref.read(receiptImageStoreProvider),
  receipts: ref.read(receiptsDaoProvider),
  cleanScannerCache: ref.read(documentScannerProvider).cleanCache,
).run();

/// Clean-up that runs once after the first frame: removes image files that no
/// receipt references any more (deleted receipts, imports interrupted by a
/// killed app) and the document scanner's temporary files.
///
/// Every step is best effort: failures are logged and never thrown.
class StartupHousekeeping {
  StartupHousekeeping({
    required this._images,
    required this._receipts,
    required this._cleanScannerCache,
  });

  final ReceiptImageStore _images;
  final ReceiptsDao _receipts;
  final Future<void> Function() _cleanScannerCache;

  Future<void> run() async {
    try {
      final referenced = await _receipts.allImagePaths();
      final removed = await _images.deleteOrphans(referenced);
      if (removed > 0) debugPrint('Housekeeping: removed $removed images');
    } catch (e, stack) {
      debugPrint('Housekeeping: orphan cleanup failed: $e\n$stack');
    }
    try {
      await _cleanScannerCache();
    } catch (e, stack) {
      debugPrint('Housekeeping: scanner cache cleanup failed: $e\n$stack');
    }
  }
}
