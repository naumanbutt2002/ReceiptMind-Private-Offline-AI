import 'package:flutter/material.dart';

import '../../../../l10n/generated/app_localizations.dart';
import 'review_keys.dart';

/// Shows the raw OCR [text] in a bottom sheet. The text is selectable, so it
/// can be copied into a field.
Future<void> showRecognisedTextSheet(BuildContext context, String text) =>
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (context) {
        final l10n = AppLocalizations.of(context);
        final theme = Theme.of(context);
        return DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.6,
          minChildSize: 0.3,
          maxChildSize: 0.95,
          builder: (context, controller) => ListView(
            key: ReviewKeys.recognisedTextSheet,
            controller: controller,
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
            children: [
              Semantics(
                header: true,
                child: Text(
                  l10n.reviewRecognisedTextTitle,
                  style: theme.textTheme.titleLarge,
                ),
              ),
              const SizedBox(height: 16),
              SelectableText(
                text,
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontFamily: 'monospace',
                  fontFamilyFallback: const ['Courier', 'RobotoMono'],
                ),
              ),
            ],
          ),
        );
      },
    );
