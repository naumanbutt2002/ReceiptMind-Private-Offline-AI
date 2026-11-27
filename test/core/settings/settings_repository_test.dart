import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:receipt_mind/core/date/local_date.dart';
import 'package:receipt_mind/core/settings/settings_providers.dart';
import 'package:receipt_mind/core/settings/settings_repository.dart';

import '../../helpers/test_app.dart';

void main() {
  setUpAll(initializeDateFormatting);

  test('defaults come from the locale', () async {
    final repo = SettingsRepository(await inMemoryPrefs(), locale: 'en_AU');
    final settings = repo.load();
    expect(settings.themeMode, ThemeMode.system);
    expect(settings.defaultCurrency, 'AUD');
    expect(settings.dateOrder, DateOrder.dmy);
    expect(settings.developerMode, isFalse);
    expect(settings.currencyFromLocale, isTrue);
    expect(settings.dateOrderFromLocale, isTrue);
  });

  test('stored values win over locale defaults', () async {
    final prefs = await inMemoryPrefs({
      SettingsRepository.keyThemeMode: 'dark',
      SettingsRepository.keyDefaultCurrency: 'EUR',
      SettingsRepository.keyDateOrder: 'ymd',
      SettingsRepository.keyDeveloperMode: true,
    });
    final settings = SettingsRepository(prefs, locale: 'en_US').load();
    expect(settings.themeMode, ThemeMode.dark);
    expect(settings.defaultCurrency, 'EUR');
    expect(settings.dateOrder, DateOrder.ymd);
    expect(settings.developerMode, isTrue);
    expect(settings.currencyFromLocale, isFalse);
    expect(settings.dateOrderFromLocale, isFalse);
  });

  test('corrupt stored values fall back to defaults', () async {
    final prefs = await inMemoryPrefs({
      SettingsRepository.keyThemeMode: 'purple',
      SettingsRepository.keyDefaultCurrency: 'euro',
      SettingsRepository.keyDateOrder: 'backwards',
    });
    final settings = SettingsRepository(prefs, locale: 'en_US').load();
    expect(settings.themeMode, ThemeMode.system);
    expect(settings.defaultCurrency, 'USD');
    expect(settings.dateOrder, DateOrder.mdy);
    expect(settings.currencyFromLocale, isTrue);
    expect(settings.dateOrderFromLocale, isTrue);
  });

  test('values of the wrong type fall back to defaults', () async {
    // getString/getBool throw a TypeError for these; loading must not.
    final prefs = await inMemoryPrefs({
      SettingsRepository.keyThemeMode: 2,
      SettingsRepository.keyDefaultCurrency: true,
      SettingsRepository.keyDateOrder: 1.5,
      SettingsRepository.keyDeveloperMode: 'yes',
    });
    final settings = SettingsRepository(prefs, locale: 'en_AU').load();
    expect(settings.themeMode, ThemeMode.system);
    expect(settings.defaultCurrency, 'AUD');
    expect(settings.currencyFromLocale, isTrue);
    expect(settings.dateOrder, DateOrder.dmy);
    expect(settings.dateOrderFromLocale, isTrue);
    expect(settings.developerMode, isFalse);
  });

  test('rejects malformed currency codes', () async {
    final repo = SettingsRepository(await inMemoryPrefs(), locale: 'en_US');
    expect(() => repo.setDefaultCurrency('dollars'), throwsArgumentError);
  });

  test('controller changes persist across a restart', () async {
    final prefs = await inMemoryPrefs();
    ProviderContainer boot() => ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        deviceLocaleProvider.overrideWithValue('en_AU'),
      ],
    );

    final first = boot();
    final controller = first.read(settingsControllerProvider.notifier);
    await controller.setThemeMode(ThemeMode.dark);
    await controller.setDefaultCurrency('NZD');
    await controller.setDateOrder(DateOrder.ymd);
    await controller.setDeveloperMode(true);
    first.dispose();

    final second = boot();
    addTearDown(second.dispose);
    final settings = second.read(settingsControllerProvider);
    expect(settings.themeMode, ThemeMode.dark);
    expect(settings.defaultCurrency, 'NZD');
    expect(settings.dateOrder, DateOrder.ymd);
    expect(settings.developerMode, isTrue);
  });

  test('reset returns currency and date order to the locale', () async {
    final prefs = await inMemoryPrefs({
      SettingsRepository.keyDefaultCurrency: 'EUR',
      SettingsRepository.keyDateOrder: 'ymd',
    });
    final container = ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        deviceLocaleProvider.overrideWithValue('en_US'),
      ],
    );
    addTearDown(container.dispose);
    final controller = container.read(settingsControllerProvider.notifier);

    await controller.resetDefaultCurrency();
    await controller.resetDateOrder();

    final settings = container.read(settingsControllerProvider);
    expect(settings.defaultCurrency, 'USD');
    expect(settings.currencyFromLocale, isTrue);
    expect(settings.dateOrder, DateOrder.mdy);
    expect(settings.dateOrderFromLocale, isTrue);
    expect(prefs.getString(SettingsRepository.keyDefaultCurrency), isNull);
    expect(prefs.getString(SettingsRepository.keyDateOrder), isNull);

    // Choosing a value again stores it and stops following the locale.
    await controller.setDateOrder(DateOrder.dmy);
    expect(
      container.read(settingsControllerProvider).dateOrderFromLocale,
      isFalse,
    );
    expect(
      SettingsRepository(prefs, locale: 'en_US').load().dateOrder,
      DateOrder.dmy,
    );
  });
}
