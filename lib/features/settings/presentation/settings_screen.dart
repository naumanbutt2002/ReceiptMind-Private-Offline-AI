import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/clock.dart';
import '../../../core/date/date_display.dart';
import '../../../core/date/local_date.dart';
import '../../../core/db/db_providers.dart';
import '../../../core/locale/locale_defaults.dart';
import '../../../core/money/money.dart';
import '../../../core/settings/app_settings.dart';
import '../../../core/settings/settings_providers.dart';
import '../../../core/widgets/currency_picker.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../export/export_service.dart';
import 'app_info_provider.dart';
import 'settings_routes.dart';

/// Appearance, receipt defaults, categories, CSV export, About & Privacy and
/// the version (tap it 7 times to turn on developer mode).
class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  /// Taps on the version tile that turn on developer mode.
  static const developerModeTaps = 7;

  /// A longer pause between two version taps starts the count again.
  static const developerModeTapWindow = Duration(seconds: 3);

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  int _versionTaps = 0;
  DateTime? _lastVersionTap;
  bool _exporting = false;

  AppLocalizations get _l10n => AppLocalizations.of(context);

  SettingsController get _controller =>
      ref.read(settingsControllerProvider.notifier);

  @override
  Widget build(BuildContext context) {
    final l10n = _l10n;
    final settings = ref.watch(settingsControllerProvider);
    final locale = ref.watch(deviceLocaleProvider);
    final categoryCount = ref.watch(categoryCountProvider).value;
    final version = ref.watch(appVersionProvider).value;
    final canOpenCategories = _hasRoute(context, SettingsRoutes.categories);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.navSettings)),
      body: ListView(
        children: [
          _SectionHeader(l10n.appearanceSection),
          ListTile(
            leading: const Icon(Icons.brightness_6_outlined),
            title: Text(l10n.appearanceTheme),
            subtitle: Text(_themeName(l10n, settings.themeMode)),
            onTap: () => _chooseTheme(settings.themeMode),
          ),
          const Divider(),
          _SectionHeader(l10n.settingsSectionReceipts),
          ListTile(
            leading: const Icon(Icons.payments_outlined),
            title: Text(l10n.settingsDefaultCurrency),
            subtitle: Text(_currencySubtitle(l10n, settings, locale)),
            onTap: () => _chooseCurrency(settings, locale),
          ),
          ListTile(
            leading: const Icon(Icons.calendar_today_outlined),
            title: Text(l10n.settingsDateFormat),
            subtitle: Text(
              l10n.dateOrderValue(
                settings.dateOrderFromLocale
                    ? l10n.settingsDateFormatAuto(
                        _dateOrderName(l10n, settings.dateOrder),
                      )
                    : _dateOrderName(l10n, settings.dateOrder),
                formatNumericDate(_today, settings.dateOrder),
              ),
            ),
            onTap: () => _chooseDateFormat(settings, locale),
          ),
          ListTile(
            leading: const Icon(Icons.category_outlined),
            title: Text(l10n.settingsCategories),
            subtitle: categoryCount == null
                ? null
                : Text(l10n.settingsCategoriesCount(categoryCount)),
            trailing: canOpenCategories
                ? const Icon(Icons.chevron_right)
                : null,
            onTap: canOpenCategories
                ? () => context.push(SettingsRoutes.categories)
                : null,
          ),
          const Divider(),
          _SectionHeader(l10n.settingsSectionData),
          ListTile(
            leading: const Icon(Icons.file_download_outlined),
            title: Text(l10n.exportCsv),
            subtitle: Text(l10n.exportCsvSubtitle),
            trailing: _exporting
                ? const SizedBox.square(
                    dimension: 24,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : null,
            enabled: !_exporting,
            onTap: _export,
          ),
          const Divider(),
          _SectionHeader(l10n.settingsSectionAbout),
          ListTile(
            leading: const Icon(Icons.privacy_tip_outlined),
            title: Text(l10n.settingsAbout),
            subtitle: Text(l10n.settingsAboutSubtitle),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.push(SettingsRoutes.about),
          ),
          ListTile(
            key: const ValueKey('settings-version'),
            leading: const Icon(Icons.info_outline),
            title: Text(l10n.versionTitle),
            subtitle: version == null
                ? null
                : Text(l10n.versionValue(version.version, version.buildNumber)),
            onTap: () => _onVersionTap(settings.developerMode),
          ),
          if (settings.developerMode)
            SwitchListTile(
              secondary: const Icon(Icons.developer_mode_outlined),
              title: Text(l10n.developerModeTitle),
              subtitle: Text(l10n.developerModeSubtitle),
              value: true,
              onChanged: (on) => _controller.setDeveloperMode(on),
            ),
        ],
      ),
    );
  }

  static LocalDate get _today => LocalDate.fromDateTime(DateTime.now());

  static bool _hasRoute(BuildContext context, String location) {
    final router = GoRouter.maybeOf(context);
    if (router == null) return false;
    return router.configuration.findMatch(Uri.parse(location)).isNotEmpty;
  }

  static String _currencySubtitle(
    AppLocalizations l10n,
    AppSettings settings,
    String locale,
  ) {
    final code = settings.defaultCurrency;
    final example = Money(123456, code).format(locale);
    return settings.currencyFromLocale
        ? l10n.settingsDefaultCurrencyAutoValue(code, example)
        : l10n.settingsDefaultCurrencyValue(code, example);
  }

  Future<void> _chooseTheme(ThemeMode current) async {
    final l10n = _l10n;
    final mode = await _choose<ThemeMode>(
      title: l10n.appearanceTheme,
      current: current,
      options: [
        for (final mode in ThemeMode.values) (mode, _themeName(l10n, mode)),
      ],
    );
    if (mode != null && mode != current) await _controller.setThemeMode(mode);
  }

  Future<void> _chooseCurrency(AppSettings settings, String locale) async {
    final choice = await showDefaultCurrencyPicker(
      context,
      selected: settings.defaultCurrency,
      locale: locale,
      deviceDefault: LocaleDefaults.currencyFor(locale),
      followsDevice: settings.currencyFromLocale,
    );
    if (choice == null) return;
    final code = choice.code;
    if (code == null) {
      await _controller.resetDefaultCurrency();
    } else {
      await _controller.setDefaultCurrency(code);
    }
  }

  Future<void> _chooseDateFormat(AppSettings settings, String locale) async {
    final l10n = _l10n;
    final today = _today;
    final autoOrder = LocaleDefaults.dateOrderFor(locale);
    String example(DateOrder order) => formatNumericDate(today, order);
    final choice = await _choose<_DateFormat>(
      title: l10n.settingsDateFormat,
      current: settings.dateOrderFromLocale
          ? _DateFormat.auto
          : _DateFormat.of(settings.dateOrder),
      options: [
        (
          _DateFormat.auto,
          l10n.dateOrderValue(
            l10n.settingsDateFormatAuto(_dateOrderName(l10n, autoOrder)),
            example(autoOrder),
          ),
        ),
        for (final order in DateOrder.values)
          (
            _DateFormat.of(order),
            l10n.dateOrderValue(_dateOrderName(l10n, order), example(order)),
          ),
      ],
    );
    if (choice == null) return;
    final order = choice.order;
    if (order == null) {
      await _controller.resetDateOrder();
    } else {
      await _controller.setDateOrder(order);
    }
  }

  /// A dialog with one radio button per option; picking one closes it.
  Future<T?> _choose<T extends Object>({
    required String title,
    required T current,
    required List<(T, String)> options,
  }) => showDialog<T>(
    context: context,
    builder: (context) => SimpleDialog(
      title: Text(title),
      children: [
        RadioGroup<T>(
          groupValue: current,
          onChanged: (value) => Navigator.of(context).pop(value),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final (value, label) in options)
                RadioListTile<T>(value: value, title: Text(label)),
            ],
          ),
        ),
      ],
    ),
  );

  Future<void> _export() async {
    final l10n = _l10n;
    final scope = await showDialog<_ExportScope>(
      context: context,
      builder: (context) => SimpleDialog(
        title: Text(l10n.exportChooseTitle),
        children: [
          ListTile(
            leading: const Icon(Icons.receipt_long_outlined),
            title: Text(l10n.exportAll),
            onTap: () => Navigator.of(context).pop(_ExportScope.all),
          ),
          ListTile(
            leading: const Icon(Icons.date_range_outlined),
            title: Text(l10n.exportDateRange),
            onTap: () => Navigator.of(context).pop(_ExportScope.dateRange),
          ),
        ],
      ),
    );
    if (scope == null || !mounted) return;

    LocalDate? from;
    LocalDate? to;
    if (scope == _ExportScope.dateRange) {
      final now = DateTime.now();
      final range = await showDateRangePicker(
        context: context,
        firstDate: DateTime(2000),
        lastDate: DateTime(now.year + 1, 12, 31),
        currentDate: now,
      );
      if (range == null || !mounted) return;
      from = LocalDate.fromDateTime(range.start);
      to = LocalDate.fromDateTime(range.end);
    }

    setState(() => _exporting = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      final result = await ref
          .read(exportServiceProvider)
          .exportCsv(from: from, to: to, shareSubject: l10n.exportShareSubject);
      if (result.isEmpty) {
        messenger.showSnackBar(SnackBar(content: Text(l10n.exportEmpty)));
      }
    } on Object catch (error, stack) {
      FlutterError.reportError(
        FlutterErrorDetails(exception: error, stack: stack),
      );
      messenger.showSnackBar(SnackBar(content: Text(l10n.exportFailed)));
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  Future<void> _onVersionTap(bool developerMode) async {
    final now = ref.read(clockProvider)();
    final last = _lastVersionTap;
    _lastVersionTap = now;
    if (last == null ||
        now.difference(last).abs() > SettingsScreen.developerModeTapWindow) {
      _versionTaps = 0;
    }
    _versionTaps++;
    if (_versionTaps < SettingsScreen.developerModeTaps) return;
    _versionTaps = 0;
    final l10n = _l10n;
    final messenger = ScaffoldMessenger.of(context);
    if (!developerMode) await _controller.setDeveloperMode(true);
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(
            developerMode ? l10n.developerModeAlreadyOn : l10n.developerModeOn,
          ),
        ),
      );
  }

  static String _themeName(AppLocalizations l10n, ThemeMode mode) =>
      switch (mode) {
        ThemeMode.system => l10n.appearanceSystem,
        ThemeMode.light => l10n.appearanceLight,
        ThemeMode.dark => l10n.appearanceDark,
      };

  static String _dateOrderName(AppLocalizations l10n, DateOrder order) =>
      switch (order) {
        DateOrder.dmy => l10n.dateOrderDmy,
        DateOrder.mdy => l10n.dateOrderMdy,
        DateOrder.ymd => l10n.dateOrderYmd,
      };
}

enum _ExportScope { all, dateRange }

/// The date format choices: Auto (follow the locale) or a fixed order.
enum _DateFormat {
  auto(null),
  dmy(DateOrder.dmy),
  mdy(DateOrder.mdy),
  ymd(DateOrder.ymd);

  const _DateFormat(this.order);

  final DateOrder? order;

  static _DateFormat of(DateOrder order) =>
      values.firstWhere((f) => f.order == order);
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader(this.title);

  final String title;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
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
