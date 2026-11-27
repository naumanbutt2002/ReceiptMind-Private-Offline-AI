import 'package:intl/intl.dart';

import '../../../../core/date/local_date.dart';

/// "September 2026" in the app's language ([localeName] from
/// `AppLocalizations.localeName`).
String formatMonthYear(LocalDate month, String localeName) {
  final locale = DateFormat.localeExists(localeName) ? localeName : 'en_US';
  return DateFormat.yMMMM(locale).format(month.toDateTimeUtc());
}
