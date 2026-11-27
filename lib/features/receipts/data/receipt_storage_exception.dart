import 'dart:io';

import 'package:drift/native.dart' show SqliteException;

/// Why a receipt or its photo could not be stored.
enum ReceiptStorageFailure {
  /// The device has no free space left.
  storageFull,

  /// The scan file is missing or isn't an image the device can decode.
  unreadableImage,

  /// Anything else (I/O or permission error); see
  /// [ReceiptStorageException.cause].
  other,
}

/// Saving a receipt failed for a reason the UI can explain, e.g. "Not enough
/// storage". Thrown by [ReceiptImageStore.importScan] for every import
/// failure, and by the repository when the database is full.
final class ReceiptStorageException implements Exception {
  const ReceiptStorageException(this.reason, [this.cause]);

  /// Classifies [error] (a file, plugin or SQLite error): a
  /// [ReceiptStorageException] is returned as is, and anything unknown
  /// becomes [ReceiptStorageFailure.other].
  factory ReceiptStorageException.from(Object error) => switch (error) {
    ReceiptStorageException() => error,
    _ => ReceiptStorageException(reasonOf(error), error),
  };

  final ReceiptStorageFailure reason;

  /// The original error, for logs.
  final Object? cause;

  /// The [ReceiptStorageFailure] that [error] means.
  static ReceiptStorageFailure reasonOf(Object error) {
    switch (error) {
      case ReceiptStorageException(:final reason):
        return reason;
      case SqliteException(:final resultCode) when resultCode == _sqliteFull:
        return ReceiptStorageFailure.storageFull;
      case FileSystemException(:final osError?)
          when osError.errorCode == _enospc:
        return ReceiptStorageFailure.storageFull;
    }
    // Some errors only carry it as text: flutter_image_compress on Android,
    // and SQLite errors from drift_flutter's background isolate (a
    // `DriftRemoteException` whose text is the `SqliteException`'s).
    if (_noSpaceText.hasMatch(error.toString())) {
      return ReceiptStorageFailure.storageFull;
    }
    return ReceiptStorageFailure.other;
  }

  /// `SQLITE_FULL`: the database or disk is full.
  static const _sqliteFull = 13;

  /// `ENOSPC` on Linux/Android and Darwin/iOS.
  static const _enospc = 28;

  static final _noSpaceText = RegExp(
    r'ENOSPC|No space left|SQLITE_FULL|disk is full',
    caseSensitive: false,
  );

  @override
  String toString() =>
      'ReceiptStorageException(${reason.name}'
      '${cause == null ? '' : ': $cause'})';
}
