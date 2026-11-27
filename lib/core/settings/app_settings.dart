import 'package:flutter/material.dart';

import '../date/local_date.dart';

/// User preferences. Values the user never changed come from the locale.
@immutable
class AppSettings {
  const AppSettings({
    required this.themeMode,
    required this.defaultCurrency,
    required this.dateOrder,
    required this.developerMode,
    this.currencyFromLocale = false,
    this.dateOrderFromLocale = false,
  });

  final ThemeMode themeMode;

  /// ISO 4217 code used for new receipts and as the parser's currency hint.
  /// Always set: the user's choice, or the locale default.
  final String defaultCurrency;

  /// How ambiguous dates like 03/04/2026 are read and shown. Always set: the
  /// user's choice, or the locale default.
  final DateOrder dateOrder;

  /// Unlocks the OCR debug screen (M7).
  final bool developerMode;

  /// True when the user never picked a currency (or reset it), so
  /// [defaultCurrency] follows the device region.
  final bool currencyFromLocale;

  /// True when the date format is "Auto", so [dateOrder] follows the device
  /// locale.
  final bool dateOrderFromLocale;

  AppSettings copyWith({
    ThemeMode? themeMode,
    String? defaultCurrency,
    DateOrder? dateOrder,
    bool? developerMode,
    bool? currencyFromLocale,
    bool? dateOrderFromLocale,
  }) => AppSettings(
    themeMode: themeMode ?? this.themeMode,
    defaultCurrency: defaultCurrency ?? this.defaultCurrency,
    dateOrder: dateOrder ?? this.dateOrder,
    developerMode: developerMode ?? this.developerMode,
    currencyFromLocale: currencyFromLocale ?? this.currencyFromLocale,
    dateOrderFromLocale: dateOrderFromLocale ?? this.dateOrderFromLocale,
  );

  @override
  bool operator ==(Object other) =>
      other is AppSettings &&
      other.themeMode == themeMode &&
      other.defaultCurrency == defaultCurrency &&
      other.dateOrder == dateOrder &&
      other.developerMode == developerMode &&
      other.currencyFromLocale == currencyFromLocale &&
      other.dateOrderFromLocale == dateOrderFromLocale;

  @override
  int get hashCode => Object.hash(
    themeMode,
    defaultCurrency,
    dateOrder,
    developerMode,
    currencyFromLocale,
    dateOrderFromLocale,
  );
}
