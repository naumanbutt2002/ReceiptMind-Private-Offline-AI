// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'ReceiptMind';

  @override
  String get navReceipts => 'Receipts';

  @override
  String get navSettings => 'Settings';

  @override
  String get receiptsEmptyTitle => 'No receipts yet';

  @override
  String get receiptsEmptyBody =>
      'Scanning is coming soon. Everything you add stays on this phone.';

  @override
  String get settingsAbout => 'About ReceiptMind';

  @override
  String get settingsAboutSubtitle => 'Private, offline AI receipt scanner';

  @override
  String get aboutLegalese =>
      'Licensed under the Apache License 2.0. Your receipts never leave this device.';

  @override
  String get settingsSectionReceipts => 'Receipt defaults';

  @override
  String get settingsSectionAbout => 'About';

  @override
  String get settingsDefaultCurrency => 'Default currency';

  @override
  String settingsDefaultCurrencyValue(String code, String example) {
    return '$code · for example $example';
  }

  @override
  String get settingsDateFormat => 'Date format';

  @override
  String dateOrderValue(String order, String example) {
    return '$order · $example';
  }

  @override
  String get dateOrderDmy => 'Day / month / year';

  @override
  String get dateOrderMdy => 'Month / day / year';

  @override
  String get dateOrderYmd => 'Year / month / day';

  @override
  String get settingsCategories => 'Categories';

  @override
  String settingsCategoriesCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count categories',
      one: '1 category',
    );
    return '$_temp0';
  }
}
