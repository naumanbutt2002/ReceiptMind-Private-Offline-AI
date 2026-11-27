import 'dart:developer' as developer;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:receipt_parser/receipt_parser.dart' hide PaymentMethod;

import '../../../core/locale/locale_defaults.dart';
import '../../../core/settings/settings_providers.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../scan/application/receipt_draft.dart';
import '../../scan/application/scan_state.dart';
import '../application/fixture_exporter.dart';
import '../developer_providers.dart';

/// Shows the anonymisation reminder with an editable file name. Returns the
/// cleaned name on Continue, or `null` on Cancel.
Future<String?> showFixtureReminderDialog(
  BuildContext context, {
  required String initialName,
}) => showDialog<String>(
  context: context,
  builder: (context) => _ReminderDialog(initialName: initialName),
);

class _ReminderDialog extends StatefulWidget {
  const _ReminderDialog({required this.initialName});

  final String initialName;

  @override
  State<_ReminderDialog> createState() => _ReminderDialogState();
}

class _ReminderDialogState extends State<_ReminderDialog> {
  late final _name = TextEditingController(text: widget.initialName);

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  void _continue() =>
      Navigator.of(context).pop(sanitizeFixtureName(_name.text));

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return AlertDialog(
      icon: const Icon(Icons.privacy_tip_outlined),
      title: Text(l10n.devAnonTitle),
      scrollable: true,
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(l10n.devAnonBody),
          const SizedBox(height: 16),
          TextField(
            controller: _name,
            decoration: InputDecoration(
              labelText: l10n.devAnonFileName,
              helperText: l10n.devAnonFileNameHelper,
              helperMaxLines: 2,
            ),
            autocorrect: false,
            enableSuggestions: false,
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => _continue(),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.devAnonCancel),
        ),
        FilledButton(onPressed: _continue, child: Text(l10n.devAnonContinue)),
      ],
    );
  }
}

/// "Export as fixture": shows the anonymisation reminder, then writes the
/// scan's OCR result with the user-[corrected] values and opens the share
/// sheet. [options] should be the ones the scan was parsed with.
Future<void> exportFixtureWithReminder(
  BuildContext context, {
  required ReviewData data,
  required ReceiptDraft corrected,
  required ParseOptions options,
}) async {
  final l10n = AppLocalizations.of(context);
  final messenger = ScaffoldMessenger.maybeOf(context);
  final document = data.document;
  if (document == null || document.lines.isEmpty) {
    messenger?.showSnackBar(SnackBar(content: Text(l10n.devExportNoOcr)));
    return;
  }
  final container = ProviderScope.containerOf(context, listen: false);
  String? country;
  try {
    country = LocaleDefaults.regionOf(container.read(deviceLocaleProvider))
        ?.toLowerCase();
  } on Object {
    country = null;
  }
  final name = await showFixtureReminderDialog(
    context,
    initialName: defaultFixtureName(
      merchant: corrected.merchant,
      date: corrected.date,
      countryCode: country,
    ),
  );
  if (name == null) return;
  try {
    await container
        .read(fixtureExporterProvider)
        .export(
          document: document,
          corrected: corrected,
          options: options,
          name: name,
          subject: l10n.devExportSubject(name),
        );
  } on Object catch (error, stackTrace) {
    developer.log(
      'Fixture export failed',
      name: 'developer',
      error: error,
      stackTrace: stackTrace,
    );
    messenger?.showSnackBar(SnackBar(content: Text(l10n.devExportFailed)));
  }
}
