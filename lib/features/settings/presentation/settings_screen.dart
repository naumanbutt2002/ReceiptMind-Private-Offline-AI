import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../../../l10n/generated/app_localizations.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.navSettings)),
      body: ListView(
        children: [
          ListTile(
            leading: const Icon(Icons.info_outline),
            title: Text(l10n.settingsAbout),
            subtitle: Text(l10n.settingsAboutSubtitle),
            onTap: () async {
              final info = await PackageInfo.fromPlatform();
              if (!context.mounted) return;
              showAboutDialog(
                context: context,
                applicationName: l10n.appTitle,
                applicationVersion: info.version,
                applicationLegalese: l10n.aboutLegalese,
              );
            },
          ),
        ],
      ),
    );
  }
}
