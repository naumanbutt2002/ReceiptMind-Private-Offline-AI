import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../l10n/generated/app_localizations.dart';
import 'app_info_provider.dart';

/// App name, version, the privacy statement (same facts as the README's
/// Privacy section) and the open-source licenses.
class AboutScreen extends ConsumerWidget {
  const AboutScreen({super.key});

  static const sourceCodeUrl =
      'github.com/naumanbutt2002/ReceiptMind-Private-Offline-AI';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final version = ref.watch(appVersionProvider).value;
    final versionText = version == null
        ? null
        : l10n.versionValue(version.version, version.buildNumber);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.aboutTitle)),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: 16),
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                ExcludeSemantics(
                  child: CircleAvatar(
                    radius: 28,
                    backgroundColor: theme.colorScheme.primaryContainer,
                    foregroundColor: theme.colorScheme.onPrimaryContainer,
                    child: const Icon(Icons.receipt_long, size: 32),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(l10n.appTitle, style: theme.textTheme.headlineSmall),
                      Text(
                        l10n.aboutTagline,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                      if (versionText != null)
                        Text(
                          l10n.aboutVersion(versionText),
                          style: theme.textTheme.bodyMedium,
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          _Header(l10n.aboutPrivacyTitle),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Text(
              l10n.aboutPrivacySummary,
              style: theme.textTheme.titleMedium,
            ),
          ),
          _Fact(Icons.phone_android_outlined, l10n.aboutPrivacyOnDevice),
          _Fact(Icons.wifi_off_outlined, l10n.aboutPrivacyNoInternet),
          _Fact(Icons.cloud_off_outlined, l10n.aboutPrivacyNoBackup),
          _Fact(Icons.visibility_off_outlined, l10n.aboutPrivacyNoTracking),
          _Fact(Icons.document_scanner_outlined, l10n.aboutPrivacyMlKit),
          const Divider(height: 32),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(l10n.aboutLegalese, style: theme.textTheme.bodyMedium),
                const SizedBox(height: 8),
                SelectableText(
                  l10n.aboutSourceCode(sourceCodeUrl),
                  style: theme.textTheme.bodyMedium,
                ),
                const SizedBox(height: 16),
                OutlinedButton.icon(
                  icon: const Icon(Icons.description_outlined),
                  label: Text(l10n.aboutLicensesButton),
                  onPressed: () => showLicensePage(
                    context: context,
                    applicationName: l10n.appTitle,
                    applicationVersion: versionText,
                    applicationLegalese: l10n.aboutLegalese,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header(this.title);

  final String title;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      child: Semantics(
        header: true,
        child: Text(
          title,
          style: theme.textTheme.labelLarge?.copyWith(
            color: theme.colorScheme.primary,
          ),
        ),
      ),
    );
  }
}

class _Fact extends StatelessWidget {
  const _Fact(this.icon, this.text);

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon),
      title: Text(text),
      titleTextStyle: Theme.of(context).textTheme.bodyMedium,
    );
  }
}
