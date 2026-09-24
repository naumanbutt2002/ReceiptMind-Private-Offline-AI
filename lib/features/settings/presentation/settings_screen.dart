import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../../../core/date/date_display.dart';
import '../../../core/date/local_date.dart';
import '../../../core/db/db_providers.dart';
import '../../../core/money/money.dart';
import '../../../core/settings/settings_providers.dart';
import '../../../l10n/generated/app_localizations.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final settings = ref.watch(settingsControllerProvider);
    final locale = ref.watch(deviceLocaleProvider);
    final categoryCount = ref.watch(categoryCountProvider).value;
    final today = LocalDate.fromDateTime(DateTime.now());

    return Scaffold(
      appBar: AppBar(title: Text(l10n.navSettings)),
      body: ListView(
        children: [
          _SectionHeader(l10n.settingsSectionReceipts),
          ListTile(
            leading: const Icon(Icons.payments_outlined),
            title: Text(l10n.settingsDefaultCurrency),
            subtitle: Text(
              l10n.settingsDefaultCurrencyValue(
                settings.defaultCurrency,
                Money(123456, settings.defaultCurrency).format(locale),
              ),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.calendar_today_outlined),
            title: Text(l10n.settingsDateFormat),
            subtitle: Text(
              l10n.dateOrderValue(
                _dateOrderName(l10n, settings.dateOrder),
                formatNumericDate(today, settings.dateOrder),
              ),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.category_outlined),
            title: Text(l10n.settingsCategories),
            subtitle: categoryCount == null
                ? null
                : Text(l10n.settingsCategoriesCount(categoryCount)),
          ),
          const Divider(),
          _SectionHeader(l10n.settingsSectionAbout),
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

  static String _dateOrderName(AppLocalizations l10n, DateOrder order) =>
      switch (order) {
        DateOrder.dmy => l10n.dateOrderDmy,
        DateOrder.mdy => l10n.dateOrderMdy,
        DateOrder.ymd => l10n.dateOrderYmd,
      };
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader(this.title);

  final String title;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
      child: Text(
        title,
        style: theme.textTheme.labelLarge?.copyWith(
          color: theme.colorScheme.primary,
        ),
      ),
    );
  }
}
