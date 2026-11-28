import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:receipt_mind/core/date/date_display.dart';
import 'package:receipt_mind/core/date/local_date.dart';

void main() {
  final date = LocalDate(2026, 9, 4);

  test('numeric date follows the chosen order', () {
    expect(formatNumericDate(date, DateOrder.dmy), '04/09/2026');
    expect(formatNumericDate(date, DateOrder.mdy), '09/04/2026');
    expect(formatNumericDate(date, DateOrder.ymd), '2026-09-04');
  });

  test('date pickers use an English variant with the same order', () {
    const au = Locale('en', 'AU');
    expect(datePickerFormat(DateOrder.dmy, au), (
      locale: const Locale('en', 'GB'),
      hint: 'dd/mm/yyyy',
    ));
    expect(datePickerFormat(DateOrder.mdy, au), (
      locale: const Locale('en', 'US'),
      hint: 'mm/dd/yyyy',
    ));
    expect(datePickerFormat(DateOrder.ymd, const Locale('en')), (
      locale: const Locale('en', 'CA'),
      hint: 'yyyy-mm-dd',
    ));
    // Other languages keep their own date formats.
    expect(datePickerFormat(DateOrder.dmy, const Locale('de', 'DE')), (
      locale: null,
      hint: null,
    ));
  });

  test('converter stores ISO text', () {
    const converter = LocalDateConverter();
    expect(converter.toSql(date), '2026-09-04');
    expect(converter.fromSql('2026-09-04'), date);
  });
}
