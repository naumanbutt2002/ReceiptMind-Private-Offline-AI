import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:receipt_mind/features/receipts/data/receipt_storage_exception.dart';

void main() {
  ReceiptStorageFailure reasonOf(Object error) =>
      ReceiptStorageException.reasonOf(error);

  test('a full disk is recognised from SQLite, dart:io and plugin text', () {
    expect(
      reasonOf(
        SqliteException(
          extendedResultCode: 13,
          message: 'database or disk is full',
        ),
      ),
      ReceiptStorageFailure.storageFull,
    );
    expect(
      reasonOf(
        const FileSystemException(
          'Cannot rename',
          '/x',
          OSError('No space left on device', 28),
        ),
      ),
      ReceiptStorageFailure.storageFull,
    );
    expect(
      reasonOf(Exception('open failed: ENOSPC (No space left on device)')),
      ReceiptStorageFailure.storageFull,
    );
    // How a SQLite error from drift's background isolate reads.
    expect(
      reasonOf(
        Exception(
          SqliteException(
            extendedResultCode: 13,
            message: 'database or disk is full',
          ).toString(),
        ),
      ),
      ReceiptStorageFailure.storageFull,
    );
  });

  test('other errors are not mistaken for a full disk', () {
    expect(
      reasonOf(
        SqliteException(
          extendedResultCode: 787, // SQLITE_CONSTRAINT_FOREIGNKEY
          message: 'FOREIGN KEY constraint failed',
        ),
      ),
      ReceiptStorageFailure.other,
    );
    expect(
      reasonOf(
        const FileSystemException(
          'Cannot open',
          '/x',
          OSError('Permission denied', 13),
        ),
      ),
      ReceiptStorageFailure.other,
    );
    expect(reasonOf(StateError('nope')), ReceiptStorageFailure.other);
  });

  test('from() keeps an existing exception and wraps anything else', () {
    const typed = ReceiptStorageException(
      ReceiptStorageFailure.unreadableImage,
    );
    expect(ReceiptStorageException.from(typed), same(typed));

    final error = StateError('x');
    final wrapped = ReceiptStorageException.from(error);
    expect(wrapped.reason, ReceiptStorageFailure.other);
    expect(wrapped.cause, same(error));
    expect(wrapped.toString(), contains('other'));
  });
}
