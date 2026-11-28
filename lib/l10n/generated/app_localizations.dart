import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'generated/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[Locale('en')];

  /// App name shown in the app bar and task switcher.
  ///
  /// In en, this message translates to:
  /// **'ReceiptMind'**
  String get appTitle;

  /// Bottom navigation label for the receipt list.
  ///
  /// In en, this message translates to:
  /// **'Receipts'**
  String get navReceipts;

  /// Bottom navigation label for settings.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get navSettings;

  /// Title of the empty state on the receipt list.
  ///
  /// In en, this message translates to:
  /// **'No receipts yet'**
  String get receiptsEmptyTitle;

  /// Body of the empty state on the receipt list.
  ///
  /// In en, this message translates to:
  /// **'Scan a paper receipt or type one in. Everything you add stays on this phone.'**
  String get receiptsEmptyBody;

  /// Settings tile that opens the About & Privacy screen.
  ///
  /// In en, this message translates to:
  /// **'About & privacy'**
  String get settingsAbout;

  /// Subtitle of the about tile.
  ///
  /// In en, this message translates to:
  /// **'Private, offline AI receipt scanner'**
  String get settingsAboutSubtitle;

  /// Legal line in the about dialog.
  ///
  /// In en, this message translates to:
  /// **'Licensed under the Apache License 2.0. Your receipts never leave this device.'**
  String get aboutLegalese;

  /// Settings section header for receipt defaults.
  ///
  /// In en, this message translates to:
  /// **'Receipt defaults'**
  String get settingsSectionReceipts;

  /// Settings section header for app information.
  ///
  /// In en, this message translates to:
  /// **'About'**
  String get settingsSectionAbout;

  /// Settings tile: currency used for new receipts.
  ///
  /// In en, this message translates to:
  /// **'Default currency'**
  String get settingsDefaultCurrency;

  /// Subtitle showing the default currency code and a formatted example amount.
  ///
  /// In en, this message translates to:
  /// **'{code} · for example {example}'**
  String settingsDefaultCurrencyValue(String code, String example);

  /// Settings tile: how dates are read and shown.
  ///
  /// In en, this message translates to:
  /// **'Date format'**
  String get settingsDateFormat;

  /// Subtitle: date order name plus today's date as an example.
  ///
  /// In en, this message translates to:
  /// **'{order} · {example}'**
  String dateOrderValue(String order, String example);

  /// Date order option.
  ///
  /// In en, this message translates to:
  /// **'Day / month / year'**
  String get dateOrderDmy;

  /// Date order option.
  ///
  /// In en, this message translates to:
  /// **'Month / day / year'**
  String get dateOrderMdy;

  /// Date order option.
  ///
  /// In en, this message translates to:
  /// **'Year / month / day'**
  String get dateOrderYmd;

  /// Settings tile for receipt categories.
  ///
  /// In en, this message translates to:
  /// **'Categories'**
  String get settingsCategories;

  /// Number of receipt categories.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 category} other{{count} categories}}'**
  String settingsCategoriesCount(int count);

  /// App bar title of the scan progress screen.
  ///
  /// In en, this message translates to:
  /// **'Scan receipt'**
  String get scanTitle;

  /// Shown while the document scanner is starting.
  ///
  /// In en, this message translates to:
  /// **'Opening scanner…'**
  String get scanOpeningScanner;

  /// Shown while text recognition and parsing run on the scanned photo.
  ///
  /// In en, this message translates to:
  /// **'Reading receipt…'**
  String get scanReading;

  /// Privacy note under the reading progress indicator.
  ///
  /// In en, this message translates to:
  /// **'This happens on your phone. Nothing is uploaded.'**
  String get scanReadingHint;

  /// Title when the user denied camera access.
  ///
  /// In en, this message translates to:
  /// **'Camera access is off'**
  String get scanPermissionCameraTitle;

  /// Explains how to allow camera access after it was denied.
  ///
  /// In en, this message translates to:
  /// **'ReceiptMind needs the camera to scan receipts. Allow camera access for ReceiptMind in your phone\'s settings, then try again.'**
  String get scanPermissionCameraBody;

  /// Title when the user denied access to photos.
  ///
  /// In en, this message translates to:
  /// **'Photo access is off'**
  String get scanPermissionGalleryTitle;

  /// Explains how to allow photo access after it was denied.
  ///
  /// In en, this message translates to:
  /// **'ReceiptMind needs access to your photos to import a receipt. Allow photo access for ReceiptMind in your phone\'s settings, then try again.'**
  String get scanPermissionGalleryBody;

  /// Title when the device has no document scanner.
  ///
  /// In en, this message translates to:
  /// **'Scanner not available'**
  String get scanUnavailableTitle;

  /// Body when the device has no document scanner.
  ///
  /// In en, this message translates to:
  /// **'The document scanner isn\'t available on this phone right now. You can enter the receipt by hand instead.'**
  String get scanUnavailableBody;

  /// Title for any other scanner error.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t open the scanner'**
  String get scanErrorTitle;

  /// Body for any other scanner error.
  ///
  /// In en, this message translates to:
  /// **'Something went wrong. Try again, or enter the receipt by hand.'**
  String get scanErrorBody;

  /// Button that opens the scanner again after a failure.
  ///
  /// In en, this message translates to:
  /// **'Try again'**
  String get scanTryAgain;

  /// Button that opens an empty receipt form instead of scanning.
  ///
  /// In en, this message translates to:
  /// **'Enter manually'**
  String get scanEnterManually;

  /// Tooltip of the close button on the scan progress screen.
  ///
  /// In en, this message translates to:
  /// **'Cancel scan'**
  String get scanCancel;

  /// Call-to-action button on the empty receipt list; opens the camera scanner.
  ///
  /// In en, this message translates to:
  /// **'Scan your first receipt'**
  String get receiptsScanFirst;

  /// Secondary button on the empty receipt list; opens manual entry.
  ///
  /// In en, this message translates to:
  /// **'Enter one manually'**
  String get receiptsAddManually;

  /// Hint in the search bar on the receipt list.
  ///
  /// In en, this message translates to:
  /// **'Search merchant, notes or receipt text'**
  String get listSearchHint;

  /// Tooltip of the button that clears the search text.
  ///
  /// In en, this message translates to:
  /// **'Clear search'**
  String get listClearSearch;

  /// Category filter chip that shows receipts of every category.
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get listFilterAll;

  /// Small label above the current month's totals card.
  ///
  /// In en, this message translates to:
  /// **'This month'**
  String get listThisMonth;

  /// Shown in the month summary card when the current month has no receipts.
  ///
  /// In en, this message translates to:
  /// **'No receipts this month'**
  String get listNoReceiptsThisMonth;

  /// Title shown when a search or category filter has no results.
  ///
  /// In en, this message translates to:
  /// **'No matching receipts'**
  String get listNoMatchesTitle;

  /// Body shown when a search or category filter has no results.
  ///
  /// In en, this message translates to:
  /// **'Try a different search or category.'**
  String get listNoMatchesBody;

  /// Button that resets the search text and the category filter.
  ///
  /// In en, this message translates to:
  /// **'Clear search and filter'**
  String get listClearFilters;

  /// Shown when the receipt list fails to load.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t load your receipts.'**
  String get listLoadError;

  /// Label shown behind a receipt row while it is swiped away.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get listDelete;

  /// SnackBar text after a receipt was deleted.
  ///
  /// In en, this message translates to:
  /// **'Deleted {merchant}'**
  String listReceiptDeleted(String merchant);

  /// SnackBar action that restores a deleted receipt.
  ///
  /// In en, this message translates to:
  /// **'Undo'**
  String get listUndo;

  /// Category name for receipts without a category.
  ///
  /// In en, this message translates to:
  /// **'Uncategorised'**
  String get listUncategorised;

  /// Screen-reader label of one receipt row.
  ///
  /// In en, this message translates to:
  /// **'{merchant}, {date}, {amount}, {category}'**
  String listRowSemantics(
    String merchant,
    String date,
    String amount,
    String category,
  );

  /// Tooltip of the floating button on the receipt list.
  ///
  /// In en, this message translates to:
  /// **'Add receipt'**
  String get fabAddReceipt;

  /// Title of the bottom sheet opened by the floating button.
  ///
  /// In en, this message translates to:
  /// **'Add a receipt'**
  String get fabSheetTitle;

  /// Bottom sheet option: scan a receipt with the camera.
  ///
  /// In en, this message translates to:
  /// **'Scan'**
  String get fabScan;

  /// Subtitle of the Scan option.
  ///
  /// In en, this message translates to:
  /// **'Use the camera; edges are found automatically'**
  String get fabScanSubtitle;

  /// Bottom sheet option: pick a receipt photo from the gallery.
  ///
  /// In en, this message translates to:
  /// **'Import from photos'**
  String get fabImport;

  /// Subtitle of the Import from photos option.
  ///
  /// In en, this message translates to:
  /// **'Pick a photo of a receipt and crop it'**
  String get fabImportSubtitle;

  /// Bottom sheet option: type in a receipt without a photo.
  ///
  /// In en, this message translates to:
  /// **'Enter manually'**
  String get fabManual;

  /// Subtitle of the Enter manually option.
  ///
  /// In en, this message translates to:
  /// **'Type in the details without a photo'**
  String get fabManualSubtitle;

  /// App bar title of the receipt detail screen.
  ///
  /// In en, this message translates to:
  /// **'Receipt'**
  String get detailTitle;

  /// Action on the receipt detail screen.
  ///
  /// In en, this message translates to:
  /// **'Edit'**
  String get detailEdit;

  /// Action on the receipt detail screen.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get detailDelete;

  /// Action that shares the receipt photo through the system share sheet.
  ///
  /// In en, this message translates to:
  /// **'Share photo'**
  String get detailSharePhoto;

  /// SnackBar text when sharing the photo fails.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t share the photo.'**
  String get detailShareFailed;

  /// Title of the delete confirmation dialog.
  ///
  /// In en, this message translates to:
  /// **'Delete this receipt?'**
  String get detailDeleteTitle;

  /// Body of the delete confirmation dialog.
  ///
  /// In en, this message translates to:
  /// **'{merchant} is removed from your list. You can undo this right after.'**
  String detailDeleteBody(String merchant);

  /// Dialog button that cancels.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get detailCancel;

  /// Title shown when the receipt no longer exists.
  ///
  /// In en, this message translates to:
  /// **'Receipt not found'**
  String get detailNotFoundTitle;

  /// Body shown when the receipt no longer exists.
  ///
  /// In en, this message translates to:
  /// **'It may have been deleted.'**
  String get detailNotFoundBody;

  /// Button on the not-found state that returns to the list.
  ///
  /// In en, this message translates to:
  /// **'Back to receipts'**
  String get detailBackToList;

  /// Screen-reader label of the receipt photo on the detail screen and in the full-screen view.
  ///
  /// In en, this message translates to:
  /// **'Receipt photo'**
  String get detailPhoto;

  /// Shown when the receipt photo file is missing.
  ///
  /// In en, this message translates to:
  /// **'Photo not available'**
  String get detailPhotoMissing;

  /// Shown when the receipt has no photo (entered manually).
  ///
  /// In en, this message translates to:
  /// **'No photo'**
  String get detailNoPhoto;

  /// Tooltip of the close button on the full-screen photo.
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get detailCloseFullScreen;

  /// Field label.
  ///
  /// In en, this message translates to:
  /// **'Merchant'**
  String get detailMerchant;

  /// Field label.
  ///
  /// In en, this message translates to:
  /// **'Date'**
  String get detailDate;

  /// Field label.
  ///
  /// In en, this message translates to:
  /// **'Total'**
  String get detailTotal;

  /// Field label.
  ///
  /// In en, this message translates to:
  /// **'Subtotal'**
  String get detailSubtotal;

  /// Field label.
  ///
  /// In en, this message translates to:
  /// **'Tax'**
  String get detailTax;

  /// Field label.
  ///
  /// In en, this message translates to:
  /// **'Tip'**
  String get detailTip;

  /// Field label.
  ///
  /// In en, this message translates to:
  /// **'Currency'**
  String get detailCurrency;

  /// Field label.
  ///
  /// In en, this message translates to:
  /// **'Category'**
  String get detailCategory;

  /// Field label.
  ///
  /// In en, this message translates to:
  /// **'Payment method'**
  String get detailPaymentMethod;

  /// Field label.
  ///
  /// In en, this message translates to:
  /// **'Notes'**
  String get detailNotes;

  /// Payment method value.
  ///
  /// In en, this message translates to:
  /// **'Card'**
  String get detailPaymentCard;

  /// Payment method value.
  ///
  /// In en, this message translates to:
  /// **'Cash'**
  String get detailPaymentCash;

  /// Payment method value.
  ///
  /// In en, this message translates to:
  /// **'Other'**
  String get detailPaymentOther;

  /// How the fields were filled in: on-device rule parser.
  ///
  /// In en, this message translates to:
  /// **'Read from the photo by the rule parser'**
  String get detailMethodRules;

  /// How the fields were filled in: on-device AI on the recognised text.
  ///
  /// In en, this message translates to:
  /// **'Read from the photo by on-device AI'**
  String get detailMethodAiText;

  /// How the fields were filled in: on-device AI on the image.
  ///
  /// In en, this message translates to:
  /// **'Read from the photo by on-device AI (image)'**
  String get detailMethodAiVision;

  /// How the fields were filled in: typed by the user.
  ///
  /// In en, this message translates to:
  /// **'Entered manually'**
  String get detailMethodManual;

  /// Small note: extraction method plus overall confidence.
  ///
  /// In en, this message translates to:
  /// **'{method} · {percent}% confidence'**
  String detailConfidence(String method, int percent);

  /// Subtitle when the default currency follows the device region.
  ///
  /// In en, this message translates to:
  /// **'Device default · {code} · for example {example}'**
  String settingsDefaultCurrencyAutoValue(String code, String example);

  /// Date format option that follows the device locale; shows the order it resolves to.
  ///
  /// In en, this message translates to:
  /// **'Auto ({order})'**
  String settingsDateFormatAuto(String order);

  /// Settings section header for categories and export.
  ///
  /// In en, this message translates to:
  /// **'Data'**
  String get settingsSectionData;

  /// Settings section header for the theme.
  ///
  /// In en, this message translates to:
  /// **'Appearance'**
  String get appearanceSection;

  /// Settings tile and dialog title for light/dark theme.
  ///
  /// In en, this message translates to:
  /// **'Theme'**
  String get appearanceTheme;

  /// Theme option: follow the system light/dark setting.
  ///
  /// In en, this message translates to:
  /// **'System default'**
  String get appearanceSystem;

  /// Theme option.
  ///
  /// In en, this message translates to:
  /// **'Light'**
  String get appearanceLight;

  /// Theme option.
  ///
  /// In en, this message translates to:
  /// **'Dark'**
  String get appearanceDark;

  /// Settings tile that exports receipts as a CSV file.
  ///
  /// In en, this message translates to:
  /// **'Export to CSV'**
  String get exportCsv;

  /// Subtitle of the CSV export tile.
  ///
  /// In en, this message translates to:
  /// **'Share your receipts as a spreadsheet file'**
  String get exportCsvSubtitle;

  /// Title of the dialog that asks which receipts to export.
  ///
  /// In en, this message translates to:
  /// **'Export receipts'**
  String get exportChooseTitle;

  /// Export option: every receipt.
  ///
  /// In en, this message translates to:
  /// **'All receipts'**
  String get exportAll;

  /// Export option: pick a date range first.
  ///
  /// In en, this message translates to:
  /// **'Choose dates…'**
  String get exportDateRange;

  /// Snack bar when the export has no receipts.
  ///
  /// In en, this message translates to:
  /// **'No receipts to export'**
  String get exportEmpty;

  /// Snack bar when writing or sharing the CSV failed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t export receipts'**
  String get exportFailed;

  /// Subject used when the CSV is shared (e.g. by email).
  ///
  /// In en, this message translates to:
  /// **'ReceiptMind receipts'**
  String get exportShareSubject;

  /// Title of the About & Privacy screen.
  ///
  /// In en, this message translates to:
  /// **'About & privacy'**
  String get aboutTitle;

  /// Full product name under the app name on the About screen.
  ///
  /// In en, this message translates to:
  /// **'Private Offline AI Receipt Scanner'**
  String get aboutTagline;

  /// App version on the About screen.
  ///
  /// In en, this message translates to:
  /// **'Version {version}'**
  String aboutVersion(String version);

  /// Section header for the privacy statement.
  ///
  /// In en, this message translates to:
  /// **'Privacy'**
  String get aboutPrivacyTitle;

  /// One-line summary of the privacy statement.
  ///
  /// In en, this message translates to:
  /// **'Your receipts never leave this phone.'**
  String get aboutPrivacySummary;

  /// Privacy statement: local storage.
  ///
  /// In en, this message translates to:
  /// **'Receipt photos, recognised text and your spending data are stored only on this device.'**
  String get aboutPrivacyOnDevice;

  /// Privacy statement: no INTERNET permission.
  ///
  /// In en, this message translates to:
  /// **'The Android release build has no internet permission, so the app cannot send anything anywhere.'**
  String get aboutPrivacyNoInternet;

  /// Privacy statement: cloud backup off.
  ///
  /// In en, this message translates to:
  /// **'Android cloud backup is turned off, so receipts are not copied to Google Drive behind your back.'**
  String get aboutPrivacyNoBackup;

  /// Privacy statement: no telemetry.
  ///
  /// In en, this message translates to:
  /// **'No analytics and no crash reporting.'**
  String get aboutPrivacyNoTracking;

  /// Privacy statement: ML Kit runs on-device and its metrics cannot be sent.
  ///
  /// In en, this message translates to:
  /// **'Text recognition uses Google ML Kit on this device. ML Kit normally sends anonymous usage metrics (device model, app version, latency) to Google; without network permission it cannot. Receipt content is never part of those metrics.'**
  String get aboutPrivacyMlKit;

  /// Where the open-source code is published.
  ///
  /// In en, this message translates to:
  /// **'Source code: {url}'**
  String aboutSourceCode(String url);

  /// Button that opens the list of open-source licenses.
  ///
  /// In en, this message translates to:
  /// **'Open-source licenses'**
  String get aboutLicensesButton;

  /// Title of the currency picker sheet.
  ///
  /// In en, this message translates to:
  /// **'Choose currency'**
  String get currencyPickerTitle;

  /// Hint in the currency search field.
  ///
  /// In en, this message translates to:
  /// **'Search by code or symbol'**
  String get currencyPickerSearchHint;

  /// Tooltip of the button that clears the currency search.
  ///
  /// In en, this message translates to:
  /// **'Clear search'**
  String get currencyPickerClearSearch;

  /// Shown when the currency search matches nothing.
  ///
  /// In en, this message translates to:
  /// **'No matching currency'**
  String get currencyPickerNoResults;

  /// Currency picker entry that follows the device region.
  ///
  /// In en, this message translates to:
  /// **'Use device default'**
  String get currencyPickerDeviceDefault;

  /// Settings switch that turns developer mode off again.
  ///
  /// In en, this message translates to:
  /// **'Developer mode'**
  String get developerModeTitle;

  /// Subtitle of the developer mode switch.
  ///
  /// In en, this message translates to:
  /// **'Extra tools for checking how receipts are read'**
  String get developerModeSubtitle;

  /// Snack bar after tapping the version 7 times.
  ///
  /// In en, this message translates to:
  /// **'Developer mode is on'**
  String get developerModeOn;

  /// Snack bar when the version is tapped 7 times while developer mode is on.
  ///
  /// In en, this message translates to:
  /// **'Developer mode is already on'**
  String get developerModeAlreadyOn;

  /// Settings tile showing the app version.
  ///
  /// In en, this message translates to:
  /// **'Version'**
  String get versionTitle;

  /// App version and build number.
  ///
  /// In en, this message translates to:
  /// **'{version} ({build})'**
  String versionValue(String version, String build);

  /// App bar title of the review screen after a scan.
  ///
  /// In en, this message translates to:
  /// **'Review receipt'**
  String get reviewTitleNewScan;

  /// App bar title of the review screen for manual entry.
  ///
  /// In en, this message translates to:
  /// **'New receipt'**
  String get reviewTitleManual;

  /// App bar title of the review screen when editing a saved receipt.
  ///
  /// In en, this message translates to:
  /// **'Edit receipt'**
  String get reviewTitleEdit;

  /// Button that saves the receipt on the review screen.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get reviewSave;

  /// Tooltip of the close button in the review screen's app bar.
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get reviewClose;

  /// SnackBar shown after a receipt was saved.
  ///
  /// In en, this message translates to:
  /// **'Receipt saved'**
  String get reviewSaved;

  /// SnackBar shown when saving a receipt failed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t save the receipt. Please try again.'**
  String get reviewSaveFailed;

  /// Title of the confirmation dialog when leaving an unsaved new receipt.
  ///
  /// In en, this message translates to:
  /// **'Discard this receipt?'**
  String get reviewDiscardNewTitle;

  /// Title of the confirmation dialog when leaving an edited receipt without saving.
  ///
  /// In en, this message translates to:
  /// **'Discard changes?'**
  String get reviewDiscardEditTitle;

  /// Body of the confirmation dialog when leaving an unsaved new receipt.
  ///
  /// In en, this message translates to:
  /// **'The receipt won\'t be saved.'**
  String get reviewDiscardNewBody;

  /// Body of the confirmation dialog when leaving an edited receipt without saving.
  ///
  /// In en, this message translates to:
  /// **'Your changes won\'t be saved.'**
  String get reviewDiscardEditBody;

  /// Confirms discarding the receipt or the changes.
  ///
  /// In en, this message translates to:
  /// **'Discard'**
  String get reviewDiscard;

  /// Cancels the discard dialog and returns to the form.
  ///
  /// In en, this message translates to:
  /// **'Keep editing'**
  String get reviewKeepEditing;

  /// Banner on the review screen when OCR failed or found no text.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t read this receipt — fill it in manually'**
  String get reviewOcrFailed;

  /// Button that opens a sheet with the raw OCR text.
  ///
  /// In en, this message translates to:
  /// **'View recognised text'**
  String get reviewViewRecognisedText;

  /// Title of the sheet that shows the raw OCR text.
  ///
  /// In en, this message translates to:
  /// **'Recognised text'**
  String get reviewRecognisedTextTitle;

  /// Screen reader label of the receipt photo on the review screen.
  ///
  /// In en, this message translates to:
  /// **'Receipt photo'**
  String get reviewPhotoLabel;

  /// Screen reader hint: what tapping the receipt photo does.
  ///
  /// In en, this message translates to:
  /// **'Opens the photo full screen'**
  String get reviewPhotoHint;

  /// Tooltip of the button that opens the receipt photo full screen.
  ///
  /// In en, this message translates to:
  /// **'View photo full screen'**
  String get reviewPhotoFullScreen;

  /// Shown in place of a receipt photo that can't be loaded.
  ///
  /// In en, this message translates to:
  /// **'The photo can\'t be shown'**
  String get reviewPhotoUnavailable;

  /// Shown when the review screen opens without a scan (for example after the app was closed).
  ///
  /// In en, this message translates to:
  /// **'This scan is no longer available. Please scan the receipt again.'**
  String get reviewScanUnavailable;

  /// Shown when the receipt to edit can't be found.
  ///
  /// In en, this message translates to:
  /// **'This receipt no longer exists.'**
  String get reviewReceiptNotFound;

  /// Button that leaves the review screen when there is nothing to review.
  ///
  /// In en, this message translates to:
  /// **'Back to receipts'**
  String get reviewBackToReceipts;

  /// Expandable section with subtotal, tax and tip.
  ///
  /// In en, this message translates to:
  /// **'More details'**
  String get reviewMoreDetails;

  /// Screen reader label of the warning icon next to a field the parser wasn't sure about.
  ///
  /// In en, this message translates to:
  /// **'Needs checking'**
  String get reviewWarningLabel;

  /// Form field label: the shop or business name.
  ///
  /// In en, this message translates to:
  /// **'Merchant'**
  String get fieldMerchant;

  /// Form field label: the purchase date.
  ///
  /// In en, this message translates to:
  /// **'Date'**
  String get fieldDate;

  /// Tooltip of the button that opens the date picker.
  ///
  /// In en, this message translates to:
  /// **'Pick a date'**
  String get fieldPickDate;

  /// Form field label: the total amount paid.
  ///
  /// In en, this message translates to:
  /// **'Total'**
  String get fieldTotal;

  /// Form field label: the receipt's currency.
  ///
  /// In en, this message translates to:
  /// **'Currency'**
  String get fieldCurrency;

  /// Form field label: the amount before tax and tip.
  ///
  /// In en, this message translates to:
  /// **'Subtotal'**
  String get fieldSubtotal;

  /// Form field label: the tax amount.
  ///
  /// In en, this message translates to:
  /// **'Tax'**
  String get fieldTax;

  /// Form field label: the tip amount.
  ///
  /// In en, this message translates to:
  /// **'Tip'**
  String get fieldTip;

  /// Form section label: the receipt's category.
  ///
  /// In en, this message translates to:
  /// **'Category'**
  String get fieldCategory;

  /// Form section label: how the receipt was paid.
  ///
  /// In en, this message translates to:
  /// **'Payment method'**
  String get fieldPaymentMethod;

  /// Payment method option.
  ///
  /// In en, this message translates to:
  /// **'Card'**
  String get fieldPaymentCard;

  /// Payment method option.
  ///
  /// In en, this message translates to:
  /// **'Cash'**
  String get fieldPaymentCash;

  /// Payment method option.
  ///
  /// In en, this message translates to:
  /// **'Other'**
  String get fieldPaymentOther;

  /// Form field label: free-text notes.
  ///
  /// In en, this message translates to:
  /// **'Notes'**
  String get fieldNotes;

  /// Validation error: the merchant is empty.
  ///
  /// In en, this message translates to:
  /// **'Enter the merchant'**
  String get fieldMerchantRequired;

  /// Validation error: no date was chosen.
  ///
  /// In en, this message translates to:
  /// **'Pick the purchase date'**
  String get fieldDateRequired;

  /// Validation error: the total is empty.
  ///
  /// In en, this message translates to:
  /// **'Enter the total'**
  String get fieldTotalRequired;

  /// Validation error: the amount can't be read.
  ///
  /// In en, this message translates to:
  /// **'Enter an amount like {example}'**
  String fieldAmountInvalid(String example);

  /// Helper text on a field the parser wasn't sure about.
  ///
  /// In en, this message translates to:
  /// **'Check this value'**
  String get fieldWarningCheck;

  /// Helper text: the amounts don't add up.
  ///
  /// In en, this message translates to:
  /// **'Total doesn\'t match subtotal + tax + tip'**
  String get fieldWarningTotalMismatch;

  /// Helper text: the tax is not smaller than the total.
  ///
  /// In en, this message translates to:
  /// **'Tax should be less than the total'**
  String get fieldWarningTaxTooHigh;

  /// Helper text: the total is zero or negative.
  ///
  /// In en, this message translates to:
  /// **'Total should be more than zero'**
  String get fieldWarningNonPositiveTotal;

  /// Helper text: the parser found no total.
  ///
  /// In en, this message translates to:
  /// **'No total found on the receipt'**
  String get fieldWarningMissingTotal;

  /// Helper text: the parser found no date.
  ///
  /// In en, this message translates to:
  /// **'No date found on the receipt'**
  String get fieldWarningMissingDate;

  /// Helper text: the purchase date is after today.
  ///
  /// In en, this message translates to:
  /// **'This date is in the future'**
  String get fieldWarningFutureDate;

  /// Helper text: the purchase date is very old.
  ///
  /// In en, this message translates to:
  /// **'This date is more than two years ago'**
  String get fieldWarningOldDate;

  /// Helper text: the currency code isn't one the app knows.
  ///
  /// In en, this message translates to:
  /// **'Unknown currency, check it'**
  String get fieldWarningUnknownCurrency;

  /// Tooltip of the bug icon in the review screen's app bar (developer mode only).
  ///
  /// In en, this message translates to:
  /// **'Developer tools'**
  String get devToolsTooltip;

  /// Developer menu item that opens the OCR debug screen.
  ///
  /// In en, this message translates to:
  /// **'Inspect OCR'**
  String get devInspectOcr;

  /// Developer menu item that exports the scan as a parser test fixture.
  ///
  /// In en, this message translates to:
  /// **'Export as fixture'**
  String get devExportFixture;

  /// Title of the OCR debug screen.
  ///
  /// In en, this message translates to:
  /// **'OCR debug'**
  String get devOcrTitle;

  /// Shown on the OCR debug screen when there is no scan in review.
  ///
  /// In en, this message translates to:
  /// **'No scan to inspect'**
  String get devNoScan;

  /// Shown on the OCR debug screen when developer mode is off.
  ///
  /// In en, this message translates to:
  /// **'Turn on developer mode to use this screen.'**
  String get devModeOff;

  /// OCR debug tab with the photo and boxes.
  ///
  /// In en, this message translates to:
  /// **'Overlay'**
  String get devTabOverlay;

  /// OCR debug tab with fields, validator issues and the parser trace.
  ///
  /// In en, this message translates to:
  /// **'Parser'**
  String get devTabParser;

  /// OCR debug tab with the rows and raw OCR text.
  ///
  /// In en, this message translates to:
  /// **'Text'**
  String get devTabText;

  /// Toggle for OCR line boxes on the overlay.
  ///
  /// In en, this message translates to:
  /// **'Lines'**
  String get devLayerLines;

  /// Toggle for OCR word boxes on the overlay.
  ///
  /// In en, this message translates to:
  /// **'Words'**
  String get devLayerWords;

  /// Toggle for the parser's visual rows on the overlay.
  ///
  /// In en, this message translates to:
  /// **'Rows'**
  String get devLayerRows;

  /// Toggle that highlights the rows each field was read from.
  ///
  /// In en, this message translates to:
  /// **'Fields'**
  String get devLayerFields;

  /// Screen reader label of the photo on the OCR debug screen.
  ///
  /// In en, this message translates to:
  /// **'Receipt photo with OCR boxes'**
  String get devPhotoLabel;

  /// Shown instead of the photo when the image file can't be loaded.
  ///
  /// In en, this message translates to:
  /// **'Photo not available'**
  String get devPhotoMissing;

  /// OCR debug section header.
  ///
  /// In en, this message translates to:
  /// **'Summary'**
  String get devSectionSummary;

  /// OCR debug section header for the parsed fields.
  ///
  /// In en, this message translates to:
  /// **'Fields'**
  String get devSectionFields;

  /// OCR debug section header.
  ///
  /// In en, this message translates to:
  /// **'Validator issues'**
  String get devSectionIssues;

  /// OCR debug section header.
  ///
  /// In en, this message translates to:
  /// **'Parser trace'**
  String get devSectionTrace;

  /// OCR debug section header for the rebuilt rows.
  ///
  /// In en, this message translates to:
  /// **'Rows'**
  String get devSectionRows;

  /// OCR debug section header for the raw OCR text.
  ///
  /// In en, this message translates to:
  /// **'OCR text'**
  String get devSectionOcrText;

  /// Label in the OCR debug summary.
  ///
  /// In en, this message translates to:
  /// **'OCR engine'**
  String get devSummaryEngine;

  /// Label in the OCR debug summary.
  ///
  /// In en, this message translates to:
  /// **'Image size'**
  String get devSummaryImage;

  /// Label in the OCR debug summary: number of OCR lines.
  ///
  /// In en, this message translates to:
  /// **'OCR lines'**
  String get devSummaryLines;

  /// Label in the OCR debug summary: number of rebuilt rows.
  ///
  /// In en, this message translates to:
  /// **'Rows'**
  String get devSummaryRows;

  /// Label in the OCR debug summary.
  ///
  /// In en, this message translates to:
  /// **'Parser version'**
  String get devSummaryParser;

  /// Label in the OCR debug summary.
  ///
  /// In en, this message translates to:
  /// **'Overall confidence'**
  String get devSummaryConfidence;

  /// Value shown when something is not known.
  ///
  /// In en, this message translates to:
  /// **'unknown'**
  String get devUnknown;

  /// Shown for a field the parser didn't find.
  ///
  /// In en, this message translates to:
  /// **'not found'**
  String get devFieldNotFound;

  /// Parser confidence of a field, e.g. 'confidence 0.92'.
  ///
  /// In en, this message translates to:
  /// **'confidence {value}'**
  String devFieldConfidence(String value);

  /// Row a field was read from, e.g. 'row 23'.
  ///
  /// In en, this message translates to:
  /// **'row {index}'**
  String devFieldRow(int index);

  /// Shown when the validator found nothing.
  ///
  /// In en, this message translates to:
  /// **'No issues'**
  String get devNoIssues;

  /// Shown when the parser left no trace lines.
  ///
  /// In en, this message translates to:
  /// **'No trace'**
  String get devNoTrace;

  /// Shown when there is no parser output.
  ///
  /// In en, this message translates to:
  /// **'The parser did not run on this scan.'**
  String get devNoParse;

  /// Shown when the OCR result is empty.
  ///
  /// In en, this message translates to:
  /// **'OCR found no text.'**
  String get devNoText;

  /// Title of the reminder dialog shown before exporting a fixture.
  ///
  /// In en, this message translates to:
  /// **'Before you share'**
  String get devAnonTitle;

  /// Body of the anonymisation reminder dialog.
  ///
  /// In en, this message translates to:
  /// **'These files contain the full text of the receipt. Remove or replace anything personal before you share them: card numbers, names, loyalty or member IDs, and addresses.\n\nNothing is uploaded automatically. You choose where the files go.'**
  String get devAnonBody;

  /// Label of the fixture name field in the reminder dialog.
  ///
  /// In en, this message translates to:
  /// **'File name'**
  String get devAnonFileName;

  /// Helper text under the fixture name field.
  ///
  /// In en, this message translates to:
  /// **'For example au_supermarket_01'**
  String get devAnonFileNameHelper;

  /// Closes the reminder dialog without exporting.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get devAnonCancel;

  /// Confirms the reminder dialog and exports the fixture.
  ///
  /// In en, this message translates to:
  /// **'Continue'**
  String get devAnonContinue;

  /// Subject used when sharing fixture files.
  ///
  /// In en, this message translates to:
  /// **'ReceiptMind fixture {name}'**
  String devExportSubject(String name);

  /// Snack bar when the scan can't be exported.
  ///
  /// In en, this message translates to:
  /// **'This scan has no OCR result to export.'**
  String get devExportNoOcr;

  /// Snack bar when writing or sharing the fixture failed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t export the fixture.'**
  String get devExportFailed;

  /// App bar title of the categories screen.
  ///
  /// In en, this message translates to:
  /// **'Categories'**
  String get categoriesTitle;

  /// Button that opens the dialog to create a category.
  ///
  /// In en, this message translates to:
  /// **'Add category'**
  String get categoriesAdd;

  /// Empty state of the categories screen.
  ///
  /// In en, this message translates to:
  /// **'No categories yet. Add one to group your receipts.'**
  String get categoriesEmpty;

  /// Shown when the category list fails to load.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t load categories.'**
  String get categoriesLoadError;

  /// Subtitle of a category row: how many receipts use it.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =0{No receipts} =1{1 receipt} other{{count} receipts}}'**
  String categoriesReceiptCount(int count);

  /// Tooltip of the overflow menu button on a category row.
  ///
  /// In en, this message translates to:
  /// **'More options for {name}'**
  String categoriesMoreOptions(String name);

  /// Overflow menu item and action that edits a category.
  ///
  /// In en, this message translates to:
  /// **'Edit'**
  String get categoriesEdit;

  /// Overflow menu item and button that deletes a category.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get categoriesDelete;

  /// Title of the dialog that creates a category.
  ///
  /// In en, this message translates to:
  /// **'New category'**
  String get categoriesNewTitle;

  /// Title of the dialog that edits a category.
  ///
  /// In en, this message translates to:
  /// **'Edit category'**
  String get categoriesEditTitle;

  /// Label of the category name field.
  ///
  /// In en, this message translates to:
  /// **'Name'**
  String get categoriesNameLabel;

  /// Validation error when the category name is empty.
  ///
  /// In en, this message translates to:
  /// **'Enter a name'**
  String get categoriesNameRequired;

  /// Validation error when the category name is too long.
  ///
  /// In en, this message translates to:
  /// **'Use at most {max} characters'**
  String categoriesNameTooLong(int max);

  /// Validation error when another category has the same name.
  ///
  /// In en, this message translates to:
  /// **'A category with this name already exists'**
  String get categoriesNameDuplicate;

  /// Label above the icon picker in the category dialog.
  ///
  /// In en, this message translates to:
  /// **'Icon'**
  String get categoriesIconLabel;

  /// Label above the colour picker in the category dialog.
  ///
  /// In en, this message translates to:
  /// **'Colour'**
  String get categoriesColourLabel;

  /// Screen reader label for a colour swatch in the picker.
  ///
  /// In en, this message translates to:
  /// **'Colour {index} of {count}'**
  String categoriesColourOption(int index, int count);

  /// Button that closes a category dialog without changes.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get categoriesCancel;

  /// Button that saves the category.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get categoriesSave;

  /// Shown when saving a category fails for an unexpected reason.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t save the category. Please try again.'**
  String get categoriesSaveError;

  /// Title of the confirmation dialog before deleting a category.
  ///
  /// In en, this message translates to:
  /// **'Delete “{name}”?'**
  String categoriesDeleteTitle(String name);

  /// Body of the delete confirmation: how many receipts lose their category.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =0{No receipts use this category.} =1{1 receipt will become uncategorised.} other{{count} receipts will become uncategorised.}}'**
  String categoriesDeleteBody(int count);

  /// Snack bar shown after a category is deleted.
  ///
  /// In en, this message translates to:
  /// **'Deleted “{name}”'**
  String categoriesDeleted(String name);

  /// Screen reader name of the 'groceries' category icon in the icon picker.
  ///
  /// In en, this message translates to:
  /// **'Groceries'**
  String get categoriesIconGroceries;

  /// Screen reader name of the 'dining' category icon in the icon picker.
  ///
  /// In en, this message translates to:
  /// **'Dining'**
  String get categoriesIconDining;

  /// Screen reader name of the 'transport' category icon in the icon picker.
  ///
  /// In en, this message translates to:
  /// **'Transport'**
  String get categoriesIconTransport;

  /// Screen reader name of the 'shopping' category icon in the icon picker.
  ///
  /// In en, this message translates to:
  /// **'Shopping'**
  String get categoriesIconShopping;

  /// Screen reader name of the 'bills' category icon in the icon picker.
  ///
  /// In en, this message translates to:
  /// **'Bills'**
  String get categoriesIconBills;

  /// Screen reader name of the 'health' category icon in the icon picker.
  ///
  /// In en, this message translates to:
  /// **'Health'**
  String get categoriesIconHealth;

  /// Screen reader name of the 'other' category icon in the icon picker.
  ///
  /// In en, this message translates to:
  /// **'Other'**
  String get categoriesIconOther;

  /// Screen reader name of the 'coffee' category icon in the icon picker.
  ///
  /// In en, this message translates to:
  /// **'Coffee'**
  String get categoriesIconCoffee;

  /// Screen reader name of the 'drinks' category icon in the icon picker.
  ///
  /// In en, this message translates to:
  /// **'Drinks'**
  String get categoriesIconDrinks;

  /// Screen reader name of the 'fuel' category icon in the icon picker.
  ///
  /// In en, this message translates to:
  /// **'Fuel'**
  String get categoriesIconFuel;

  /// Screen reader name of the 'parking' category icon in the icon picker.
  ///
  /// In en, this message translates to:
  /// **'Parking'**
  String get categoriesIconParking;

  /// Screen reader name of the 'travel' category icon in the icon picker.
  ///
  /// In en, this message translates to:
  /// **'Travel'**
  String get categoriesIconTravel;

  /// Screen reader name of the 'home' category icon in the icon picker.
  ///
  /// In en, this message translates to:
  /// **'Home'**
  String get categoriesIconHome;

  /// Screen reader name of the 'utilities' category icon in the icon picker.
  ///
  /// In en, this message translates to:
  /// **'Utilities'**
  String get categoriesIconUtilities;

  /// Screen reader name of the 'phone' category icon in the icon picker.
  ///
  /// In en, this message translates to:
  /// **'Phone'**
  String get categoriesIconPhone;

  /// Screen reader name of the 'electronics' category icon in the icon picker.
  ///
  /// In en, this message translates to:
  /// **'Electronics'**
  String get categoriesIconElectronics;

  /// Screen reader name of the 'subscriptions' category icon in the icon picker.
  ///
  /// In en, this message translates to:
  /// **'Subscriptions'**
  String get categoriesIconSubscriptions;

  /// Screen reader name of the 'entertainment' category icon in the icon picker.
  ///
  /// In en, this message translates to:
  /// **'Entertainment'**
  String get categoriesIconEntertainment;

  /// Screen reader name of the 'games' category icon in the icon picker.
  ///
  /// In en, this message translates to:
  /// **'Games'**
  String get categoriesIconGames;

  /// Screen reader name of the 'education' category icon in the icon picker.
  ///
  /// In en, this message translates to:
  /// **'Education'**
  String get categoriesIconEducation;

  /// Screen reader name of the 'books' category icon in the icon picker.
  ///
  /// In en, this message translates to:
  /// **'Books'**
  String get categoriesIconBooks;

  /// Screen reader name of the 'fitness' category icon in the icon picker.
  ///
  /// In en, this message translates to:
  /// **'Fitness'**
  String get categoriesIconFitness;

  /// Screen reader name of the 'pharmacy' category icon in the icon picker.
  ///
  /// In en, this message translates to:
  /// **'Pharmacy'**
  String get categoriesIconPharmacy;

  /// Screen reader name of the 'beauty' category icon in the icon picker.
  ///
  /// In en, this message translates to:
  /// **'Beauty'**
  String get categoriesIconBeauty;

  /// Screen reader name of the 'clothing' category icon in the icon picker.
  ///
  /// In en, this message translates to:
  /// **'Clothing'**
  String get categoriesIconClothing;

  /// Screen reader name of the 'kids' category icon in the icon picker.
  ///
  /// In en, this message translates to:
  /// **'Kids'**
  String get categoriesIconKids;

  /// Screen reader name of the 'pets' category icon in the icon picker.
  ///
  /// In en, this message translates to:
  /// **'Pets'**
  String get categoriesIconPets;

  /// Screen reader name of the 'gifts' category icon in the icon picker.
  ///
  /// In en, this message translates to:
  /// **'Gifts'**
  String get categoriesIconGifts;

  /// Screen reader name of the 'work' category icon in the icon picker.
  ///
  /// In en, this message translates to:
  /// **'Work'**
  String get categoriesIconWork;

  /// Screen reader name of the 'repairs' category icon in the icon picker.
  ///
  /// In en, this message translates to:
  /// **'Repairs'**
  String get categoriesIconRepairs;

  /// Screen reader name of the 'insurance' category icon in the icon picker.
  ///
  /// In en, this message translates to:
  /// **'Insurance'**
  String get categoriesIconInsurance;

  /// SnackBar shown when saving a receipt failed because the phone's storage is full.
  ///
  /// In en, this message translates to:
  /// **'Not enough storage space to save the receipt. Free up some space and try again.'**
  String get reviewSaveFailedStorage;

  /// Title of the dialog shown when the scanned photo was deleted (e.g. by the system) before the receipt could be saved.
  ///
  /// In en, this message translates to:
  /// **'Photo no longer available'**
  String get reviewPhotoMissingTitle;

  /// Body of the dialog shown when the scanned photo is gone before saving.
  ///
  /// In en, this message translates to:
  /// **'The scanned photo was removed from the phone\'s temporary storage before it could be saved. You can save the receipt without the photo, or discard it and scan again.'**
  String get reviewPhotoMissingBody;

  /// Button in the missing-photo dialog that saves the receipt without its photo.
  ///
  /// In en, this message translates to:
  /// **'Save without photo'**
  String get reviewSaveWithoutPhoto;

  /// SnackBar when deleting a receipt from the list or the detail screen fails; the receipt is still there.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t delete the receipt. Please try again.'**
  String get listDeleteFailed;

  /// SnackBar when Undo after deleting a receipt fails.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t restore the receipt.'**
  String get listRestoreFailed;

  /// SnackBar when deleting a category fails.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t delete the category. Please try again.'**
  String get categoriesDeleteError;

  /// Screen-reader hint for tapping the receipt photo on the detail screen; TalkBack reads it as 'Double-tap to view full screen'.
  ///
  /// In en, this message translates to:
  /// **'view full screen'**
  String get detailPhotoOpenHint;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
