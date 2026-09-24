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
