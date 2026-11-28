// ML Kit output for photos of six synthetic receipts (docs: the QA photo set),
// exported on the Android emulator with "Export as fixture". The photos are
// turned 1–2°, so these dumps cover what the text fixtures can't: tilted
// boxes, prices that sit above or below their label, and line boxes made
// taller by the slant and by descenders.
import 'dart:convert';
import 'dart:io';

import 'package:receipt_parser/receipt_parser.dart';
import 'package:test/test.dart';

typedef _Expected = ({
  String currency,
  DateOrder order,
  String merchant,
  LocalDate date,
  int total,
  int? subtotal,
  int? tax,
  int? tip,
  PaymentMethod payment,
});

final _photos = <String, _Expected>{
  'au_supermarket_01': (
    currency: 'AUD',
    order: DateOrder.dmy,
    merchant: 'Woolworths Metro',
    date: LocalDate(2026, 9, 12),
    total: 5983,
    subtotal: null,
    tax: 302,
    tip: null,
    payment: PaymentMethod.card,
  ),
  'us_restaurant_01': (
    currency: 'USD',
    order: DateOrder.mdy,
    merchant: "Luigi's Trattoria",
    date: LocalDate(2026, 7, 18),
    total: 13950,
    subtotal: 10700,
    tax: 950,
    tip: 2300,
    payment: PaymentMethod.card,
  ),
  'uk_retail_01': (
    currency: 'GBP',
    order: DateOrder.dmy,
    merchant: 'WHSmith',
    date: LocalDate(2026, 8, 19),
    total: 4416,
    subtotal: null,
    tax: 533,
    tip: null,
    payment: PaymentMethod.cash,
  ),
  'de_restaurant_01': (
    currency: 'EUR',
    order: DateOrder.dmy,
    merchant: 'Gasthaus Zum Löwen',
    date: LocalDate(2026, 3, 21),
    total: 5040,
    subtotal: null,
    tax: 457,
    tip: null,
    payment: PaymentMethod.card,
  ),
  'au_pharmacy_01': (
    currency: 'AUD',
    order: DateOrder.dmy,
    merchant: 'Bayside Discount Chemist',
    date: LocalDate(2026, 5, 5),
    total: 5165,
    subtotal: 5166,
    tax: 209,
    tip: null,
    payment: PaymentMethod.cash,
  ),
  'us_retail_01': (
    currency: 'USD',
    order: DateOrder.mdy,
    merchant: 'Target',
    date: LocalDate(2026, 9, 5),
    total: 5736,
    subtotal: 5328,
    tax: 408,
    tip: null,
    payment: PaymentMethod.card,
  ),
};

void main() {
  for (final MapEntry(key: name, value: want) in _photos.entries) {
    test('photo OCR $name', () {
      final json = File('test/data/photo_ocr/$name.ocr.json')
          .readAsStringSync();
      final document = OcrDocument.fromJson(
        jsonDecode(json) as Map<String, Object?>,
      );
      final r = const RuleReceiptParser().parse(
        document,
        ParseOptions(
          defaultCurrency: want.currency,
          dateOrder: want.order,
          today: LocalDate(2026, 11, 28),
        ),
      );
      expect(r.merchant?.value.toLowerCase(), want.merchant.toLowerCase());
      expect(r.date?.value, want.date);
      expect(r.total?.value, want.total);
      expect(r.currency.value, want.currency);
      if (want.subtotal != null) expect(r.subtotal?.value, want.subtotal);
      expect(r.tax?.value, want.tax);
      expect(r.tip?.value, want.tip);
      expect(r.paymentMethod?.value, want.payment);
    });
  }
}
