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
  });

  final ThemeMode themeMode;

  /// ISO 4217 code used for new receipts and as the parser's currency hint.
  final String defaultCurrency;

  /// How ambiguous dates like 03/04/2026 are read and shown.
  final DateOrder dateOrder;

  /// Unlocks the OCR debug screen (M7).
  final bool developerMode;

  AppSettings copyWith({
    ThemeMode? themeMode,
    String? defaultCurrency,
    DateOrder? dateOrder,
    bool? developerMode,
  }) => AppSettings(
    themeMode: themeMode ?? this.themeMode,
    defaultCurrency: defaultCurrency ?? this.defaultCurrency,
    dateOrder: dateOrder ?? this.dateOrder,
    developerMode: developerMode ?? this.developerMode,
  );

  @override
  bool operator ==(Object other) =>
      other is AppSettings &&
      other.themeMode == themeMode &&
      other.defaultCurrency == defaultCurrency &&
      other.dateOrder == dateOrder &&
      other.developerMode == developerMode;

  @override
  int get hashCode =>
      Object.hash(themeMode, defaultCurrency, dateOrder, developerMode);
}
