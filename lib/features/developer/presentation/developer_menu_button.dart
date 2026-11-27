import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:receipt_parser/receipt_parser.dart' hide PaymentMethod;

import '../../../core/clock.dart';
import '../../../core/settings/settings_providers.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../scan/application/receipt_draft.dart';
import '../../scan/application/scan_state.dart';
import '../developer_routes.dart';
import 'fixture_export_flow.dart';

enum _DevAction { inspect, export }

/// App-bar button with the developer tools for a scan in review: "Inspect
/// OCR" opens [DeveloperRoutes.ocr], "Export as fixture" runs
/// [exportFixtureWithReminder]. Renders nothing unless developer mode is on.
class DeveloperMenuButton extends ConsumerWidget {
  const DeveloperMenuButton({
    required this.data,
    required this.corrected,
    this.options,
    super.key,
  });

  /// The scan in review.
  final ReviewData data;

  /// Returns the draft with the user's corrections at the moment of export.
  final ValueGetter<ReceiptDraft> corrected;

  /// The options the scan was parsed with. Defaults to the current settings
  /// and today's date, which is what the scan controller uses.
  final ParseOptions? options;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final developerMode = ref.watch(
      settingsControllerProvider.select((s) => s.developerMode),
    );
    if (!developerMode) return const SizedBox.shrink();
    final l10n = AppLocalizations.of(context);
    final hasOcr = data.document?.lines.isNotEmpty ?? false;
    return PopupMenuButton<_DevAction>(
      icon: const Icon(Icons.bug_report_outlined),
      tooltip: l10n.devToolsTooltip,
      onSelected: (action) {
        switch (action) {
          case _DevAction.inspect:
            context.push(DeveloperRoutes.ocr);
          case _DevAction.export:
            final settings = ref.read(settingsControllerProvider);
            exportFixtureWithReminder(
              context,
              data: data,
              corrected: corrected(),
              options:
                  options ??
                  ParseOptions(
                    defaultCurrency: settings.defaultCurrency,
                    dateOrder: settings.dateOrder,
                    today: LocalDate.fromDateTime(ref.read(clockProvider)()),
                  ),
            );
        }
      },
      itemBuilder: (context) => [
        PopupMenuItem(
          value: _DevAction.inspect,
          enabled: data.document != null,
          child: ListTile(
            leading: const Icon(Icons.document_scanner_outlined),
            title: Text(l10n.devInspectOcr),
            contentPadding: EdgeInsets.zero,
          ),
        ),
        PopupMenuItem(
          value: _DevAction.export,
          enabled: hasOcr,
          child: ListTile(
            leading: const Icon(Icons.ios_share),
            title: Text(l10n.devExportFixture),
            contentPadding: EdgeInsets.zero,
          ),
        ),
      ],
    );
  }
}
