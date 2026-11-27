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

  /// The stored settings. Missing, unknown or wrongly typed values fall back
  /// to their defaults, so a corrupt preferences file can't stop the app
  /// from starting.
  AppSettings load() {
    final storedCurrency = _string(keyDefaultCurrency);
    final currency =
        storedCurrency != null && Currencies.isWellFormed(storedCurrency)
        ? storedCurrency
        : null;
    final dateOrder = _byNameOrNull(DateOrder.values, _string(keyDateOrder));
    final developerMode = _prefs.get(keyDeveloperMode);
    return AppSettings(
      themeMode:
          _byNameOrNull(ThemeMode.values, _string(keyThemeMode)) ??
          ThemeMode.system,
      defaultCurrency: currency ?? LocaleDefaults.currencyFor(locale),
      currencyFromLocale: currency == null,
      dateOrder: dateOrder ?? LocaleDefaults.dateOrderFor(locale),
      dateOrderFromLocale: dateOrder == null,
      developerMode: developerMode is bool && developerMode,
    );
  }

  /// [SharedPreferencesWithCache.getString] throws for a value of another
  /// type; this returns `null` instead.
  String? _string(String key) => switch (_prefs.get(key)) {
    final String value => value,
    _ => null,
  };

  Future<void> setThemeMode(ThemeMode mode) =>
      _prefs.setString(keyThemeMode, mode.name);

  Future<void> setDefaultCurrency(String code) {
    if (!Currencies.isWellFormed(code)) {
      throw ArgumentError.value(code, 'code', 'Not an ISO 4217 code');
    }
    return _prefs.setString(keyDefaultCurrency, code);
  }

  /// Forgets the user's currency, so the locale default applies again.
  Future<void> clearDefaultCurrency() => _prefs.remove(keyDefaultCurrency);

  Future<void> setDateOrder(DateOrder order) =>
      _prefs.setString(keyDateOrder, order.name);

  /// Back to "Auto": the date order follows the locale again.
  Future<void> clearDateOrder() => _prefs.remove(keyDateOrder);

  Future<void> setDeveloperMode(bool enabled) =>
      _prefs.setBool(keyDeveloperMode, enabled);

  static T? _byNameOrNull<T extends Enum>(List<T> values, String? name) {
    for (final value in values) {
      if (value.name == name) return value;
    }
    return null;
  }
}
