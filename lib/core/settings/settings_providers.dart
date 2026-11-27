import 'package:flutter/material.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../date/local_date.dart';
import 'app_settings.dart';
import 'settings_repository.dart';

part 'settings_providers.g.dart';

/// Created in `main()` before the app starts, then injected via override.
@Riverpod(keepAlive: true)
SharedPreferencesWithCache sharedPreferences(Ref ref) =>
    throw UnimplementedError('Override sharedPreferencesProvider in main()');

/// Device locale such as `en_AU`, injected in `main()`.
@Riverpod(keepAlive: true)
String deviceLocale(Ref ref) =>
    throw UnimplementedError('Override deviceLocaleProvider in main()');

@Riverpod(keepAlive: true)
SettingsRepository settingsRepository(Ref ref) => SettingsRepository(
  ref.watch(sharedPreferencesProvider),
  locale: ref.watch(deviceLocaleProvider),
);

@Riverpod(keepAlive: true)
class SettingsController extends _$SettingsController {
  @override
  AppSettings build() => ref.watch(settingsRepositoryProvider).load();

  SettingsRepository get _repo => ref.read(settingsRepositoryProvider);

  Future<void> setThemeMode(ThemeMode mode) async {
    await _repo.setThemeMode(mode);
    state = state.copyWith(themeMode: mode);
  }

  Future<void> setDefaultCurrency(String code) async {
    await _repo.setDefaultCurrency(code);
    state = state.copyWith(defaultCurrency: code, currencyFromLocale: false);
  }

  /// "Use device default": the currency follows the device region again.
  Future<void> resetDefaultCurrency() async {
    await _repo.clearDefaultCurrency();
    state = state.copyWith(
      defaultCurrency: _repo.load().defaultCurrency,
      currencyFromLocale: true,
    );
  }

  Future<void> setDateOrder(DateOrder order) async {
    await _repo.setDateOrder(order);
    state = state.copyWith(dateOrder: order, dateOrderFromLocale: false);
  }

  /// "Auto": the date order follows the device locale again.
  Future<void> resetDateOrder() async {
    await _repo.clearDateOrder();
    state = state.copyWith(
      dateOrder: _repo.load().dateOrder,
      dateOrderFromLocale: true,
    );
  }

  Future<void> setDeveloperMode(bool enabled) async {
    await _repo.setDeveloperMode(enabled);
    state = state.copyWith(developerMode: enabled);
  }
}
