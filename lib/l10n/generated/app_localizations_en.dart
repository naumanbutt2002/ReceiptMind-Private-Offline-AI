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
      'Scan a paper receipt or type one in. Everything you add stays on this phone.';

  @override
  String get settingsAbout => 'About & privacy';

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

  @override
  String get scanTitle => 'Scan receipt';

  @override
  String get scanOpeningScanner => 'Opening scanner…';

  @override
  String get scanReading => 'Reading receipt…';

  @override
  String get scanReadingHint =>
      'This happens on your phone. Nothing is uploaded.';

  @override
  String get scanPermissionCameraTitle => 'Camera access is off';

  @override
  String get scanPermissionCameraBody =>
      'ReceiptMind needs the camera to scan receipts. Allow camera access for ReceiptMind in your phone\'s settings, then try again.';

  @override
  String get scanPermissionGalleryTitle => 'Photo access is off';

  @override
  String get scanPermissionGalleryBody =>
      'ReceiptMind needs access to your photos to import a receipt. Allow photo access for ReceiptMind in your phone\'s settings, then try again.';

  @override
  String get scanUnavailableTitle => 'Scanner not available';

  @override
  String get scanUnavailableBody =>
      'The document scanner isn\'t available on this phone right now. You can enter the receipt by hand instead.';

  @override
  String get scanErrorTitle => 'Couldn\'t open the scanner';

  @override
  String get scanErrorBody =>
      'Something went wrong. Try again, or enter the receipt by hand.';

  @override
  String get scanTryAgain => 'Try again';

  @override
  String get scanEnterManually => 'Enter manually';

  @override
  String get scanCancel => 'Cancel scan';

  @override
  String get receiptsScanFirst => 'Scan your first receipt';

  @override
  String get receiptsAddManually => 'Enter one manually';

  @override
  String get listSearchHint => 'Search merchant, notes or receipt text';

  @override
  String get listClearSearch => 'Clear search';

  @override
  String get listFilterAll => 'All';

  @override
  String get listThisMonth => 'This month';

  @override
  String get listNoReceiptsThisMonth => 'No receipts this month';

  @override
  String get listNoMatchesTitle => 'No matching receipts';

  @override
  String get listNoMatchesBody => 'Try a different search or category.';

  @override
  String get listClearFilters => 'Clear search and filter';

  @override
  String get listLoadError => 'Couldn\'t load your receipts.';

  @override
  String get listDelete => 'Delete';

  @override
  String listReceiptDeleted(String merchant) {
    return 'Deleted $merchant';
  }

  @override
  String get listUndo => 'Undo';

  @override
  String get listUncategorised => 'Uncategorised';

  @override
  String listRowSemantics(
    String merchant,
    String date,
    String amount,
    String category,
  ) {
    return '$merchant, $date, $amount, $category';
  }

  @override
  String get fabAddReceipt => 'Add receipt';

  @override
  String get fabSheetTitle => 'Add a receipt';

  @override
  String get fabScan => 'Scan';

  @override
  String get fabScanSubtitle => 'Use the camera; edges are found automatically';

  @override
  String get fabImport => 'Import from photos';

  @override
  String get fabImportSubtitle => 'Pick a photo of a receipt and crop it';

  @override
  String get fabManual => 'Enter manually';

  @override
  String get fabManualSubtitle => 'Type in the details without a photo';

  @override
  String get detailTitle => 'Receipt';

  @override
  String get detailEdit => 'Edit';

  @override
  String get detailDelete => 'Delete';

  @override
  String get detailSharePhoto => 'Share photo';

  @override
  String get detailShareFailed => 'Couldn\'t share the photo.';

  @override
  String get detailDeleteTitle => 'Delete this receipt?';

  @override
  String detailDeleteBody(String merchant) {
    return '$merchant is removed from your list. You can undo this right after.';
  }

  @override
  String get detailCancel => 'Cancel';

  @override
  String get detailNotFoundTitle => 'Receipt not found';

  @override
  String get detailNotFoundBody => 'It may have been deleted.';

  @override
  String get detailBackToList => 'Back to receipts';

  @override
  String get detailPhoto => 'Receipt photo. Double-tap to view full screen.';

  @override
  String get detailPhotoMissing => 'Photo not available';

  @override
  String get detailNoPhoto => 'No photo';

  @override
  String get detailCloseFullScreen => 'Close';

  @override
  String get detailMerchant => 'Merchant';

  @override
  String get detailDate => 'Date';

  @override
  String get detailTotal => 'Total';

  @override
  String get detailSubtotal => 'Subtotal';

  @override
  String get detailTax => 'Tax';

  @override
  String get detailTip => 'Tip';

  @override
  String get detailCurrency => 'Currency';

  @override
  String get detailCategory => 'Category';

  @override
  String get detailPaymentMethod => 'Payment method';

  @override
  String get detailNotes => 'Notes';

  @override
  String get detailPaymentCard => 'Card';

  @override
  String get detailPaymentCash => 'Cash';

  @override
  String get detailPaymentOther => 'Other';

  @override
  String get detailMethodRules => 'Read from the photo by the rule parser';

  @override
  String get detailMethodAiText => 'Read from the photo by on-device AI';

  @override
  String get detailMethodAiVision =>
      'Read from the photo by on-device AI (image)';

  @override
  String get detailMethodManual => 'Entered manually';

  @override
  String detailConfidence(String method, int percent) {
    return '$method · $percent% confidence';
  }

  @override
  String settingsDefaultCurrencyAutoValue(String code, String example) {
    return 'Device default · $code · for example $example';
  }

  @override
  String settingsDateFormatAuto(String order) {
    return 'Auto ($order)';
  }

  @override
  String get settingsSectionData => 'Data';

  @override
  String get appearanceSection => 'Appearance';

  @override
  String get appearanceTheme => 'Theme';

  @override
  String get appearanceSystem => 'System default';

  @override
  String get appearanceLight => 'Light';

  @override
  String get appearanceDark => 'Dark';

  @override
  String get exportCsv => 'Export to CSV';

  @override
  String get exportCsvSubtitle => 'Share your receipts as a spreadsheet file';

  @override
  String get exportChooseTitle => 'Export receipts';

  @override
  String get exportAll => 'All receipts';

  @override
  String get exportDateRange => 'Choose dates…';

  @override
  String get exportEmpty => 'No receipts to export';

  @override
  String get exportFailed => 'Couldn\'t export receipts';

  @override
  String get exportShareSubject => 'ReceiptMind receipts';

  @override
  String get aboutTitle => 'About & privacy';

  @override
  String get aboutTagline => 'Private Offline AI Receipt Scanner';

  @override
  String aboutVersion(String version) {
    return 'Version $version';
  }

  @override
  String get aboutPrivacyTitle => 'Privacy';

  @override
  String get aboutPrivacySummary => 'Your receipts never leave this phone.';

  @override
  String get aboutPrivacyOnDevice =>
      'Receipt photos, recognised text and your spending data are stored only on this device.';

  @override
  String get aboutPrivacyNoInternet =>
      'The Android release build has no internet permission, so the app cannot send anything anywhere.';

  @override
  String get aboutPrivacyNoBackup =>
      'Android cloud backup is turned off, so receipts are not copied to Google Drive behind your back.';

  @override
  String get aboutPrivacyNoTracking => 'No analytics and no crash reporting.';

  @override
  String get aboutPrivacyMlKit =>
      'Text recognition uses Google ML Kit on this device. ML Kit normally sends anonymous usage metrics (device model, app version, latency) to Google; without network permission it cannot. Receipt content is never part of those metrics.';

  @override
  String aboutSourceCode(String url) {
    return 'Source code: $url';
  }

  @override
  String get aboutLicensesButton => 'Open-source licenses';

  @override
  String get currencyPickerTitle => 'Choose currency';

  @override
  String get currencyPickerSearchHint => 'Search by code or symbol';

  @override
  String get currencyPickerClearSearch => 'Clear search';

  @override
  String get currencyPickerNoResults => 'No matching currency';

  @override
  String get currencyPickerDeviceDefault => 'Use device default';

  @override
  String get developerModeTitle => 'Developer mode';

  @override
  String get developerModeSubtitle =>
      'Extra tools for checking how receipts are read';

  @override
  String get developerModeOn => 'Developer mode is on';

  @override
  String get developerModeAlreadyOn => 'Developer mode is already on';

  @override
  String get versionTitle => 'Version';

  @override
  String versionValue(String version, String build) {
    return '$version ($build)';
  }

  @override
  String get reviewTitleNewScan => 'Review receipt';

  @override
  String get reviewTitleManual => 'New receipt';

  @override
  String get reviewTitleEdit => 'Edit receipt';

  @override
  String get reviewSave => 'Save';

  @override
  String get reviewClose => 'Close';

  @override
  String get reviewSaved => 'Receipt saved';

  @override
  String get reviewSaveFailed =>
      'Couldn\'t save the receipt. Please try again.';

  @override
  String get reviewDiscardNewTitle => 'Discard this receipt?';

  @override
  String get reviewDiscardEditTitle => 'Discard changes?';

  @override
  String get reviewDiscardNewBody => 'The receipt won\'t be saved.';

  @override
  String get reviewDiscardEditBody => 'Your changes won\'t be saved.';

  @override
  String get reviewDiscard => 'Discard';

  @override
  String get reviewKeepEditing => 'Keep editing';

  @override
  String get reviewOcrFailed =>
      'Couldn\'t read this receipt — fill it in manually';

  @override
  String get reviewViewRecognisedText => 'View recognised text';

  @override
  String get reviewRecognisedTextTitle => 'Recognised text';

  @override
  String get reviewPhotoLabel => 'Receipt photo';

  @override
  String get reviewPhotoHint => 'Opens the photo full screen';

  @override
  String get reviewPhotoFullScreen => 'View photo full screen';

  @override
  String get reviewPhotoUnavailable => 'The photo can\'t be shown';

  @override
  String get reviewScanUnavailable =>
      'This scan is no longer available. Please scan the receipt again.';

  @override
  String get reviewReceiptNotFound => 'This receipt no longer exists.';

  @override
  String get reviewBackToReceipts => 'Back to receipts';

  @override
  String get reviewMoreDetails => 'More details';

  @override
  String get reviewWarningLabel => 'Needs checking';

  @override
  String get fieldMerchant => 'Merchant';

  @override
  String get fieldDate => 'Date';

  @override
  String get fieldPickDate => 'Pick a date';

  @override
  String get fieldTotal => 'Total';

  @override
  String get fieldCurrency => 'Currency';

  @override
  String get fieldSubtotal => 'Subtotal';

  @override
  String get fieldTax => 'Tax';

  @override
  String get fieldTip => 'Tip';

  @override
  String get fieldCategory => 'Category';

  @override
  String get fieldPaymentMethod => 'Payment method';

  @override
  String get fieldPaymentCard => 'Card';

  @override
  String get fieldPaymentCash => 'Cash';

  @override
  String get fieldPaymentOther => 'Other';

  @override
  String get fieldNotes => 'Notes';

  @override
  String get fieldMerchantRequired => 'Enter the merchant';

  @override
  String get fieldDateRequired => 'Pick the purchase date';

  @override
  String get fieldTotalRequired => 'Enter the total';

  @override
  String fieldAmountInvalid(String example) {
    return 'Enter an amount like $example';
  }

  @override
  String get fieldWarningCheck => 'Check this value';

  @override
  String get fieldWarningTotalMismatch =>
      'Total doesn\'t match subtotal + tax + tip';

  @override
  String get fieldWarningTaxTooHigh => 'Tax should be less than the total';

  @override
  String get fieldWarningNonPositiveTotal => 'Total should be more than zero';

  @override
  String get fieldWarningMissingTotal => 'No total found on the receipt';

  @override
  String get fieldWarningMissingDate => 'No date found on the receipt';

  @override
  String get fieldWarningFutureDate => 'This date is in the future';

  @override
  String get fieldWarningOldDate => 'This date is more than two years ago';

  @override
  String get fieldWarningUnknownCurrency => 'Unknown currency, check it';

  @override
  String get devToolsTooltip => 'Developer tools';

  @override
  String get devInspectOcr => 'Inspect OCR';

  @override
  String get devExportFixture => 'Export as fixture';

  @override
  String get devOcrTitle => 'OCR debug';

  @override
  String get devNoScan => 'No scan to inspect';

  @override
  String get devModeOff => 'Turn on developer mode to use this screen.';

  @override
  String get devTabOverlay => 'Overlay';

  @override
  String get devTabParser => 'Parser';

  @override
  String get devTabText => 'Text';

  @override
  String get devLayerLines => 'Lines';

  @override
  String get devLayerWords => 'Words';

  @override
  String get devLayerRows => 'Rows';

  @override
  String get devLayerFields => 'Fields';

  @override
  String get devPhotoLabel => 'Receipt photo with OCR boxes';

  @override
  String get devPhotoMissing => 'Photo not available';

  @override
  String get devSectionSummary => 'Summary';

  @override
  String get devSectionFields => 'Fields';

  @override
  String get devSectionIssues => 'Validator issues';

  @override
  String get devSectionTrace => 'Parser trace';

  @override
  String get devSectionRows => 'Rows';

  @override
  String get devSectionOcrText => 'OCR text';

  @override
  String get devSummaryEngine => 'OCR engine';

  @override
  String get devSummaryImage => 'Image size';

  @override
  String get devSummaryLines => 'OCR lines';

  @override
  String get devSummaryRows => 'Rows';

  @override
  String get devSummaryParser => 'Parser version';

  @override
  String get devSummaryConfidence => 'Overall confidence';

  @override
  String get devUnknown => 'unknown';

  @override
  String get devFieldNotFound => 'not found';

  @override
  String devFieldConfidence(String value) {
    return 'confidence $value';
  }

  @override
  String devFieldRow(int index) {
    return 'row $index';
  }

  @override
  String get devNoIssues => 'No issues';

  @override
  String get devNoTrace => 'No trace';

  @override
  String get devNoParse => 'The parser did not run on this scan.';

  @override
  String get devNoText => 'OCR found no text.';

  @override
  String get devAnonTitle => 'Before you share';

  @override
  String get devAnonBody =>
      'These files contain the full text of the receipt. Remove or replace anything personal before you share them: card numbers, names, loyalty or member IDs, and addresses.\n\nNothing is uploaded automatically. You choose where the files go.';

  @override
  String get devAnonFileName => 'File name';

  @override
  String get devAnonFileNameHelper => 'For example au_supermarket_01';

  @override
  String get devAnonCancel => 'Cancel';

  @override
  String get devAnonContinue => 'Continue';

  @override
  String devExportSubject(String name) {
    return 'ReceiptMind fixture $name';
  }

  @override
  String get devExportNoOcr => 'This scan has no OCR result to export.';

  @override
  String get devExportFailed => 'Couldn\'t export the fixture.';

  @override
  String get categoriesTitle => 'Categories';

  @override
  String get categoriesAdd => 'Add category';

  @override
  String get categoriesEmpty =>
      'No categories yet. Add one to group your receipts.';

  @override
  String get categoriesLoadError => 'Couldn\'t load categories.';

  @override
  String categoriesReceiptCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count receipts',
      one: '1 receipt',
      zero: 'No receipts',
    );
    return '$_temp0';
  }

  @override
  String categoriesMoreOptions(String name) {
    return 'More options for $name';
  }

  @override
  String get categoriesEdit => 'Edit';

  @override
  String get categoriesDelete => 'Delete';

  @override
  String get categoriesNewTitle => 'New category';

  @override
  String get categoriesEditTitle => 'Edit category';

  @override
  String get categoriesNameLabel => 'Name';

  @override
  String get categoriesNameRequired => 'Enter a name';

  @override
  String categoriesNameTooLong(int max) {
    return 'Use at most $max characters';
  }

  @override
  String get categoriesNameDuplicate =>
      'A category with this name already exists';

  @override
  String get categoriesIconLabel => 'Icon';

  @override
  String get categoriesColourLabel => 'Colour';

  @override
  String categoriesColourOption(int index, int count) {
    return 'Colour $index of $count';
  }

  @override
  String get categoriesCancel => 'Cancel';

  @override
  String get categoriesSave => 'Save';

  @override
  String get categoriesSaveError =>
      'Couldn\'t save the category. Please try again.';

  @override
  String categoriesDeleteTitle(String name) {
    return 'Delete “$name”?';
  }

  @override
  String categoriesDeleteBody(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count receipts will become uncategorised.',
      one: '1 receipt will become uncategorised.',
      zero: 'No receipts use this category.',
    );
    return '$_temp0';
  }

  @override
  String categoriesDeleted(String name) {
    return 'Deleted “$name”';
  }

  @override
  String get categoriesIconGroceries => 'Groceries';

  @override
  String get categoriesIconDining => 'Dining';

  @override
  String get categoriesIconTransport => 'Transport';

  @override
  String get categoriesIconShopping => 'Shopping';

  @override
  String get categoriesIconBills => 'Bills';

  @override
  String get categoriesIconHealth => 'Health';

  @override
  String get categoriesIconOther => 'Other';

  @override
  String get categoriesIconCoffee => 'Coffee';

  @override
  String get categoriesIconDrinks => 'Drinks';

  @override
  String get categoriesIconFuel => 'Fuel';

  @override
  String get categoriesIconParking => 'Parking';

  @override
  String get categoriesIconTravel => 'Travel';

  @override
  String get categoriesIconHome => 'Home';

  @override
  String get categoriesIconUtilities => 'Utilities';

  @override
  String get categoriesIconPhone => 'Phone';

  @override
  String get categoriesIconElectronics => 'Electronics';

  @override
  String get categoriesIconSubscriptions => 'Subscriptions';

  @override
  String get categoriesIconEntertainment => 'Entertainment';

  @override
  String get categoriesIconGames => 'Games';

  @override
  String get categoriesIconEducation => 'Education';

  @override
  String get categoriesIconBooks => 'Books';

  @override
  String get categoriesIconFitness => 'Fitness';

  @override
  String get categoriesIconPharmacy => 'Pharmacy';

  @override
  String get categoriesIconBeauty => 'Beauty';

  @override
  String get categoriesIconClothing => 'Clothing';

  @override
  String get categoriesIconKids => 'Kids';

  @override
  String get categoriesIconPets => 'Pets';

  @override
  String get categoriesIconGifts => 'Gifts';

  @override
  String get categoriesIconWork => 'Work';

  @override
  String get categoriesIconRepairs => 'Repairs';

  @override
  String get categoriesIconInsurance => 'Insurance';

  @override
  String get reviewSaveFailedStorage =>
      'Not enough storage space to save the receipt. Free up some space and try again.';

  @override
  String get reviewPhotoMissingTitle => 'Photo no longer available';

  @override
  String get reviewPhotoMissingBody =>
      'The scanned photo was removed from the phone\'s temporary storage before it could be saved. You can save the receipt without the photo, or discard it and scan again.';

  @override
  String get reviewSaveWithoutPhoto => 'Save without photo';

  @override
  String get listDeleteFailed =>
      'Couldn\'t delete the receipt. Please try again.';

  @override
  String get listRestoreFailed => 'Couldn\'t restore the receipt.';

  @override
  String get categoriesDeleteError =>
      'Couldn\'t delete the category. Please try again.';
}
