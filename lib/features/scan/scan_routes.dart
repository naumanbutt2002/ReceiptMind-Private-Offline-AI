import 'package:go_router/go_router.dart';

import 'capture/document_scanner.dart';
import 'presentation/scan_progress_screen.dart';

/// Locations used by the scan flow.
abstract final class ScanRoutes {
  /// `/scan?source=camera|gallery`; see [scanFrom].
  static const scan = '/scan';

  /// The review screen for the scan in `scanControllerProvider` (defined by
  /// the receipts feature).
  static const review = '/scan/review';

  /// Empty receipt form, offered when the scanner can't run.
  static const manualEntry = '/receipts/new';

  /// Where a cancelled scan returns when there is nothing to pop.
  static const receipts = '/receipts';

  /// Location that opens the scanner for [source].
  static String scanFrom(ScanSource source) => '$scan?source=${source.name}';
}

/// Top-level routes of the scan flow, outside the bottom navigation shell.
final List<RouteBase> scanRoutes = [
  GoRoute(
    path: ScanRoutes.scan,
    builder: (context, state) => ScanProgressScreen(
      source: switch (state.uri.queryParameters['source']) {
        'gallery' => ScanSource.gallery,
        _ => ScanSource.camera,
      },
    ),
  ),
];
