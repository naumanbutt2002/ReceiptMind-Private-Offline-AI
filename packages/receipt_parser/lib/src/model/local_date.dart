/// A calendar date without time or time zone, e.g. the purchase date printed
/// on a receipt. Stored as ISO text (`YYYY-MM-DD`) so it never shifts when the
/// user travels across time zones.
final class LocalDate implements Comparable<LocalDate> {
  /// Creates a date; throws [ArgumentError] when it does not exist
  /// (e.g. 2026-02-30).
  factory LocalDate(int year, int month, int day) {
    final probe = DateTime.utc(year, month, day);
    if (probe.year != year || probe.month != month || probe.day != day) {
      throw ArgumentError('Invalid date: $year-$month-$day');
    }
    return LocalDate._(year, month, day);
  }

  const LocalDate._(this.year, this.month, this.day);

  /// The calendar date of [dateTime] in its own time zone.
  factory LocalDate.fromDateTime(DateTime dateTime) =>
      LocalDate._(dateTime.year, dateTime.month, dateTime.day);

  /// Parses `YYYY-MM-DD`; throws [FormatException] otherwise.
  factory LocalDate.parseIso(String text) {
    final match = _isoPattern.firstMatch(text);
    if (match == null) throw FormatException('Not an ISO date', text);
    try {
      return LocalDate(
        int.parse(match[1]!),
        int.parse(match[2]!),
        int.parse(match[3]!),
      );
    } on ArgumentError {
      throw FormatException('Not a valid date', text);
    }
  }

  /// Like [LocalDate.parseIso] but returns `null` for invalid input.
  static LocalDate? tryParseIso(String text) {
    try {
      return LocalDate.parseIso(text);
    } on FormatException {
      return null;
    }
  }

  static final _isoPattern = RegExp(r'^(\d{4})-(\d{2})-(\d{2})$');

  final int year;
  final int month;
  final int day;

  /// First day of this date's month.
  LocalDate get firstOfMonth => LocalDate._(year, month, 1);

  /// First day of the following month.
  LocalDate get firstOfNextMonth => month == 12
      ? LocalDate._(year + 1, 1, 1)
      : LocalDate._(year, month + 1, 1);

  LocalDate addDays(int days) =>
      LocalDate.fromDateTime(DateTime.utc(year, month, day + days));

  /// Midnight UTC on this date, for date pickers and arithmetic.
  DateTime toDateTimeUtc() => DateTime.utc(year, month, day);

  String toIso() =>
      '${year.toString().padLeft(4, '0')}-'
      '${month.toString().padLeft(2, '0')}-'
      '${day.toString().padLeft(2, '0')}';

  bool isBefore(LocalDate other) => compareTo(other) < 0;
  bool isAfter(LocalDate other) => compareTo(other) > 0;

  @override
  int compareTo(LocalDate other) {
    if (year != other.year) return year.compareTo(other.year);
    if (month != other.month) return month.compareTo(other.month);
    return day.compareTo(other.day);
  }

  @override
  bool operator ==(Object other) =>
      other is LocalDate &&
      other.year == year &&
      other.month == month &&
      other.day == day;

  @override
  int get hashCode => Object.hash(year, month, day);

  @override
  String toString() => toIso();
}
