import 'package:flutter/material.dart';
import 'package:receipt_parser/receipt_parser.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../locale/locale_defaults.dart';
import 'app_settings.dart';

/// Reads and writes [AppSettings] in SharedPreferences. Only values the user
/// changed are stored; everything else follows the device locale.
class SettingsRepository {
  SettingsRepository(this._prefs, {required this.locale});

  static const keyThemeMode = 'settings.themeMode';
  static const keyDefaultCurrency = 'settings.defaultCurrency';
  static const keyDateOrder = 'settings.dateOrder';
  static const keyDeveloperMode = 'settings.developerMode';
  static const allKeys = {
    keyThemeMode,
    keyDefaultCurrency,
    keyDateOrder,
    keyDeveloperMode,
  };

  final SharedPreferencesWithCache _prefs;

  /// Device locale, e.g. `en_AU`.
  final String locale;

  AppSettings load() {
    final storedCurrency = _prefs.getString(keyDefaultCurrency);
    return AppSettings(
      themeMode: _byName(
        ThemeMode.values,
        _prefs.getString(keyThemeMode),
        ThemeMode.system,
      ),
      defaultCurrency:
          storedCurrency != null && Currencies.isWellFormed(storedCurrency)
          ? storedCurrency
          : LocaleDefaults.currencyFor(locale),
      dateOrder: _byName(
        DateOrder.values,
        _prefs.getString(keyDateOrder),
        LocaleDefaults.dateOrderFor(locale),
      ),
      developerMode: _prefs.getBool(keyDeveloperMode) ?? false,
    );
  }

  Future<void> setThemeMode(ThemeMode mode) =>
      _prefs.setString(keyThemeMode, mode.name);

  Future<void> setDefaultCurrency(String code) {
    if (!Currencies.isWellFormed(code)) {
      throw ArgumentError.value(code, 'code', 'Not an ISO 4217 code');
    }
    return _prefs.setString(keyDefaultCurrency, code);
  }

  Future<void> setDateOrder(DateOrder order) =>
      _prefs.setString(keyDateOrder, order.name);

  Future<void> setDeveloperMode(bool enabled) =>
      _prefs.setBool(keyDeveloperMode, enabled);

  static T _byName<T extends Enum>(List<T> values, String? name, T fallback) {
    for (final value in values) {
      if (value.name == name) return value;
    }
    return fallback;
  }
}
