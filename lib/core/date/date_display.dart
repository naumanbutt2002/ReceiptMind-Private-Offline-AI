import 'dart:ui' show Locale;

import 'local_date.dart';

/// Short numeric date in the user's chosen order: 24/09/2026, 09/24/2026 or
/// 2026-09-24.
String formatNumericDate(LocalDate date, DateOrder order) {
  final d = date.day.toString().padLeft(2, '0');
  final m = date.month.toString().padLeft(2, '0');
  final y = date.year.toString().padLeft(4, '0');
  return switch (order) {
    DateOrder.dmy => '$d/$m/$y',
    DateOrder.mdy => '$m/$d/$y',
    DateOrder.ymd => '$y-$m-$d',
  };
}

/// How the Material date pickers should read and show typed dates so they
/// follow the user's date order instead of the app language's default.
///
/// The app only ships English strings, so Flutter resolves an en-AU or en-GB
/// device to plain `en`, whose date fields expect `mm/dd/yyyy`: "01/11/2026"
/// typed in Australia became 11 January. For English, [locale] picks an
/// English variant with the same numeric order (dd/MM/y, M/d/y or y-MM-dd)
/// and [hint] spells that order out (en_CA's own hint says mm/dd/yyyy even
/// though it reads y-MM-dd). Other languages keep their own formats: both
/// fields are `null`.
({Locale? locale, String? hint}) datePickerFormat(
  DateOrder order,
  Locale appLocale,
) {
  if (appLocale.languageCode != 'en') return (locale: null, hint: null);
  return switch (order) {
    DateOrder.dmy => (locale: const Locale('en', 'GB'), hint: 'dd/mm/yyyy'),
    DateOrder.mdy => (locale: const Locale('en', 'US'), hint: 'mm/dd/yyyy'),
    DateOrder.ymd => (locale: const Locale('en', 'CA'), hint: 'yyyy-mm-dd'),
  };
}
