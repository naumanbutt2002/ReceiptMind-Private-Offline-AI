import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../l10n/generated/app_localizations.dart';
import '../receipt_routes_detail.dart';

/// The FAB's bottom sheet: Scan, Import from photos, Enter manually.
Future<void> showAddReceiptSheet(BuildContext context) {
  final router = GoRouter.of(context);
  return showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    useSafeArea: true,
    isScrollControlled: true,
    builder: (sheetContext) {
      final l10n = AppLocalizations.of(sheetContext);
      void open(String location) {
        Navigator.of(sheetContext).pop();
        router.push(location).ignore();
      }

      return SingleChildScrollView(
        padding: const EdgeInsets.only(bottom: 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 8),
              child: Text(
                l10n.fabSheetTitle,
                style: Theme.of(sheetContext).textTheme.titleMedium,
              ),
            ),
            ListTile(
              key: const Key('fab-scan'),
              leading: const Icon(Icons.document_scanner_outlined),
              title: Text(l10n.fabScan),
              subtitle: Text(l10n.fabScanSubtitle),
              onTap: () => open(ReceiptPaths.scanCamera),
            ),
            ListTile(
              key: const Key('fab-import'),
              leading: const Icon(Icons.photo_library_outlined),
              title: Text(l10n.fabImport),
              subtitle: Text(l10n.fabImportSubtitle),
              onTap: () => open(ReceiptPaths.scanGallery),
            ),
            ListTile(
              key: const Key('fab-manual'),
              leading: const Icon(Icons.edit_note_outlined),
              title: Text(l10n.fabManual),
              subtitle: Text(l10n.fabManualSubtitle),
              onTap: () => open(ReceiptPaths.newManual),
            ),
          ],
        ),
      );
    },
  );
}
