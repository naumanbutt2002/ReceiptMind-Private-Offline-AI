import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/settings/settings_providers.dart';
import '../../l10n/generated/app_localizations.dart';
import '../scan/application/scan_controller.dart';
import '../scan/application/scan_state.dart';
import 'presentation/ocr_debug_screen.dart';

/// Locations of the developer tools.
abstract final class DeveloperRoutes {
  /// OCR debug screen for the scan in review.
  static const ocr = '/dev/ocr';
}

/// Top-level developer routes, outside the bottom navigation shell.
final List<RouteBase> developerRoutes = [
  GoRoute(
    path: DeveloperRoutes.ocr,
    builder: (context, state) => const OcrDebugRouteScreen(),
  ),
];

/// [OcrDebugScreen] for the scan in `scanControllerProvider`. Shows a
/// message when developer mode is off or no scan is in review.
class OcrDebugRouteScreen extends ConsumerWidget {
  const OcrDebugRouteScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final developerMode = ref.watch(
      settingsControllerProvider.select((s) => s.developerMode),
    );
    final scan = ref.watch(scanControllerProvider);
    if (developerMode && scan is ScanReview) {
      return OcrDebugScreen(
        data: scan.data,
        imagePath: scan.data.draft.sourceImagePath,
      );
    }
    return Scaffold(
      appBar: AppBar(title: Text(l10n.devOcrTitle)),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            developerMode ? l10n.devNoScan : l10n.devModeOff,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyLarge,
          ),
        ),
      ),
    );
  }
}
