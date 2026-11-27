import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/clock.dart';
import '../../../core/db/db_providers.dart';
import 'file_receipt_image_store.dart';
import 'receipt_image_store.dart';
import 'receipt_repository.dart';

part 'receipts_providers.g.dart';

/// The app support directory: private storage for the database and receipt
/// images. Tests override it with a temporary directory.
@Riverpod(keepAlive: true)
Future<Directory> appSupportDirectory(Ref ref) =>
    getApplicationSupportDirectory();

@Riverpod(keepAlive: true)
ReceiptImageStore receiptImageStore(Ref ref) => FileReceiptImageStore(
  baseDirectory: () => ref.read(appSupportDirectoryProvider.future),
  compressor: const FlutterImageCompressor(),
);

@Riverpod(keepAlive: true)
ReceiptRepository receiptRepository(Ref ref) => ReceiptRepository(
  ref.watch(receiptsDaoProvider),
  ref.watch(receiptImageStoreProvider),
  clock: ref.watch(clockProvider),
);
