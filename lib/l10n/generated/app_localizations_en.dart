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
}
