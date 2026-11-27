import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../l10n/generated/app_localizations.dart';
import '../application/scan_controller.dart';
import '../application/scan_state.dart';
import '../capture/document_scanner.dart';
import '../scan_routes.dart';

/// Opens the document scanner, shows "Reading receipt…" while OCR and the
/// parser run, then replaces itself with the review screen. A cancelled
/// scan goes back to where the user came from.
class ScanProgressScreen extends ConsumerStatefulWidget {
  const ScanProgressScreen({required this.source, super.key});

  final ScanSource source;

  @override
  ConsumerState<ScanProgressScreen> createState() => _ScanProgressScreenState();
}

class _ScanProgressScreenState extends ConsumerState<ScanProgressScreen> {
  /// Set once this screen navigates away, so it never navigates twice.
  bool _leaving = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _start();
    });
  }

  ScanController get _controller => ref.read(scanControllerProvider.notifier);

  void _start() => _controller.start(widget.source);

  /// "Try again": ignored while a scan is already running, so a double tap
  /// doesn't open a second scanner (which fails with `ALREADY_ACTIVE` and
  /// would drop the first scan's result).
  void _retry() {
    if (ref.read(scanControllerProvider)
        case ScanCapturing() || ScanReading()) {
      return;
    }
    _start();
  }

  /// Leaves the screen and drops the scan (a running OCR result is ignored).
  void _close() {
    _controller.reset();
    _leave();
  }

  void _leave() {
    if (_leaving) return;
    _leaving = true;
    if (context.canPop()) {
      context.pop();
    } else {
      context.go(ScanRoutes.receipts);
    }
  }

  void _replaceWith(String location) {
    if (_leaving) return;
    _leaving = true;
    if (context.canPop()) {
      context.pushReplacement(location);
    } else {
      context.go(location);
    }
  }

  void _enterManually() {
    _controller.reset();
    _replaceWith(ScanRoutes.manualEntry);
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(scanControllerProvider, (previous, next) {
      if (!mounted) return;
      switch (next) {
        case ScanReview():
          _replaceWith(ScanRoutes.review);
        // Cancelled in the scanner. A reset from this screen (close, Back)
        // navigates by itself.
        case ScanIdle() when previous is ScanCapturing:
          _leave();
        case _:
      }
    });
    final state = ref.watch(scanControllerProvider);
    final l10n = AppLocalizations.of(context);

    return PopScope(
      onPopInvokedWithResult: (didPop, _) {
        if (didPop && ref.read(scanControllerProvider) is! ScanReview) {
          _controller.reset();
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(l10n.scanTitle),
          leading: IconButton(
            icon: const Icon(Icons.close),
            tooltip: l10n.scanCancel,
            onPressed: _close,
          ),
        ),
        body: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) => SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minHeight: (constraints.maxHeight - 48).clamp(
                    0,
                    double.infinity,
                  ),
                ),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 480),
                    child: switch (state) {
                      ScanFailed(:final failure) => _FailureView(
                        reason: failure.reason,
                        source: widget.source,
                        onTryAgain: _retry,
                        onEnterManually: _enterManually,
                      ),
                      ScanReading() || ScanReview() => _ProgressView(
                        message: l10n.scanReading,
                        hint: l10n.scanReadingHint,
                      ),
                      ScanIdle() || ScanCapturing() => _ProgressView(
                        message: l10n.scanOpeningScanner,
                      ),
                    },
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ProgressView extends StatelessWidget {
  const _ProgressView({required this.message, this.hint});

  final String message;
  final String? hint;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Semantics(
      liveRegion: true,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const ExcludeSemantics(child: CircularProgressIndicator()),
          const SizedBox(height: 24),
          Text(
            message,
            style: theme.textTheme.titleMedium,
            textAlign: TextAlign.center,
          ),
          if (hint case final hint?) ...[
            const SizedBox(height: 8),
            Text(
              hint,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ],
      ),
    );
  }
}

class _FailureView extends StatelessWidget {
  const _FailureView({
    required this.reason,
    required this.source,
    required this.onTryAgain,
    required this.onEnterManually,
  });

  final ScanFailureReason reason;
  final ScanSource source;
  final VoidCallback onTryAgain;
  final VoidCallback onEnterManually;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final (icon, title, body) = switch (reason) {
      ScanFailureReason.permissionDenied => switch (source) {
        ScanSource.camera => (
          Icons.no_photography_outlined,
          l10n.scanPermissionCameraTitle,
          l10n.scanPermissionCameraBody,
        ),
        ScanSource.gallery => (
          Icons.hide_image_outlined,
          l10n.scanPermissionGalleryTitle,
          l10n.scanPermissionGalleryBody,
        ),
      },
      ScanFailureReason.unavailable => (
        Icons.document_scanner_outlined,
        l10n.scanUnavailableTitle,
        l10n.scanUnavailableBody,
      ),
      ScanFailureReason.other => (
        Icons.error_outline,
        l10n.scanErrorTitle,
        l10n.scanErrorBody,
      ),
    };
    final tryAgain = Text(l10n.scanTryAgain);
    final enterManually = Text(l10n.scanEnterManually);
    // Without a scanner, typing the receipt in is the way forward.
    final manualFirst = reason == ScanFailureReason.unavailable;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Icon(icon, size: 48, color: theme.colorScheme.primary),
        const SizedBox(height: 16),
        Semantics(
          header: true,
          child: Text(
            title,
            style: theme.textTheme.headlineSmall,
            textAlign: TextAlign.center,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          body,
          style: theme.textTheme.bodyLarge,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 24),
        if (manualFirst) ...[
          FilledButton(onPressed: onEnterManually, child: enterManually),
          const SizedBox(height: 8),
          OutlinedButton(onPressed: onTryAgain, child: tryAgain),
        ] else ...[
          FilledButton(onPressed: onTryAgain, child: tryAgain),
          const SizedBox(height: 8),
          OutlinedButton(onPressed: onEnterManually, child: enterManually),
        ],
      ],
    );
  }
}
