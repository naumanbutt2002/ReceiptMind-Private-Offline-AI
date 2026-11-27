import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';

import '../../../../core/db/app_database.dart';
import '../../../../l10n/generated/app_localizations.dart';
import '../../data/receipt_repository.dart';

/// How long the "Deleted … · Undo" SnackBar stays up.
const undoSnackBarDuration = Duration(seconds: 6);

/// Shows "Deleted `merchant`" with an **Undo** action that re-inserts
/// [deleted] through [repository]. Pass the messenger captured before any
/// navigation, so this also works after the calling screen was popped.
void showReceiptDeletedSnackBar({
  required ScaffoldMessengerState messenger,
  required AppLocalizations l10n,
  required ReceiptRepository repository,
  required ReceiptRow deleted,
  VoidCallback? onUndo,
}) {
  messenger
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        key: const Key('receipt-deleted-snackbar'),
        content: Text(l10n.listReceiptDeleted(deleted.merchant)),
        duration: undoSnackBarDuration,
        // An undo offer should go away by itself; with an action the default
        // is to stay until dismissed.
        persist: false,
        action: SnackBarAction(
          label: l10n.listUndo,
          onPressed: () {
            onUndo?.call();
            restoreDeletedReceipt(repository, deleted).catchError((
              Object error,
            ) {
              debugPrint('Undo delete failed: $error');
              messenger.showSnackBar(
                SnackBar(content: Text(l10n.listRestoreFailed)),
              );
            });
          },
        ),
      ),
    );
}

/// Shows that deleting a receipt failed (it is still in the list).
void showReceiptDeleteFailedSnackBar({
  required ScaffoldMessengerState messenger,
  required AppLocalizations l10n,
}) {
  messenger
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(l10n.listDeleteFailed)));
}

/// Re-inserts a deleted receipt. If its category was deleted in the meantime
/// (the foreign key no longer matches), the receipt comes back uncategorised
/// instead of being lost.
// TODO(lead): move this fallback into ReceiptsDao.restoreReceipt.
Future<void> restoreDeletedReceipt(
  ReceiptRepository repository,
  ReceiptRow deleted,
) async {
  try {
    await repository.restore(deleted);
  } on Object {
    if (deleted.categoryId == null) rethrow;
    await repository.restore(deleted.copyWith(categoryId: const Value(null)));
  }
}
