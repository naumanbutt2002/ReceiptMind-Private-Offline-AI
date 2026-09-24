import 'package:receipt_parser/receipt_parser.dart';
import 'package:test/test.dart';

import '../helpers.dart';

void main() {
  const sample = '''
TAX INVOICE
WOOLWORTHS METRO
123 George St Sydney NSW 2000
ABN 88 000 014 675
Milk 2L          3.10
Bread            4.00
2 x 1.50         3.00
SUBTOTAL        10.10
TOTAL           10.10
Total includes GST 0.27
VISA            10.10
**** **** **** 4821 APPROVED
12/09/2026 14:32
''';

  group('RuleReceiptParser', () {
    final receipt = parseText(sample);

    test('reads every field', () {
      expect(receipt.merchant?.value, 'Woolworths Metro');
      expect(receipt.date?.value, LocalDate(2026, 9, 12));
      expect(receipt.total?.value, 1010);
      expect(receipt.subtotal?.value, 1010);
      expect(receipt.tax?.value, 27);
      expect(receipt.taxIncluded, isTrue);
      expect(receipt.tip, isNull);
      expect(receipt.currency.value, 'AUD');
      expect(receipt.paymentMethod?.value, PaymentMethod.card);
    });

    test('explains itself', () {
      expect(receipt.rows, hasLength(13));
      expect(receipt.total?.rowIndex, 8);
      expect(receipt.total?.reason, contains('keyword:total'));
      expect(receipt.trace, contains(startsWith('total: 1010')));
      expect(receipt.overallConfidence, greaterThan(0.7));
      expect(receipt.total.toString(), contains('1010'));
    });

    test('an empty document', () {
      final empty = parseText('');
      expect(empty.total, isNull);
      expect(empty.merchant, isNull);
      expect(empty.currency.value, 'AUD');
      expect(empty.overallConfidence, 0);
    });

    test('custom lexicons', () {
      final english = const RuleReceiptParser().parse(
        OcrDocument.fromPlainText('Laden\nSumme 5,00\nBar 10,00'),
        ParseOptions(
          defaultCurrency: 'EUR',
          dateOrder: DateOrder.dmy,
          today: today,
          lexicons: const [Lexicon.en],
        ),
      );
      // Without German words, "Summe" is unknown: largest amount, low confidence.
      expect(english.total?.value, 1000);
      expect(english.total!.confidence, lessThan(0.6));
    });
  });

  group('ReceiptValidator', () {
    const validator = ReceiptValidator();
    List<IssueCode> codes(ParsedReceipt r) => [
      for (final i in validator.validate(r, options())) i.code,
    ];
    ParsedField<T> sure<T extends Object>(T value) =>
        ParsedField(value, confidence: 0.9, reason: 'test');
    ParsedReceipt receipt({
      int? total = 1100,
      int? subtotal,
      int? tax,
      int? tip,
      LocalDate? date,
      String currency = 'AUD',
      bool taxIncluded = false,
    }) => ParsedReceipt(
      currency: sure(currency),
      rows: const [],
      merchant: sure('Shop'),
      date: sure(date ?? LocalDate(2026, 9, 1)),
      total: total == null ? null : sure(total),
      subtotal: subtotal == null ? null : sure(subtotal),
      tax: tax == null ? null : sure(tax),
      tip: tip == null ? null : sure(tip),
      taxIncluded: taxIncluded,
    );

    test('a consistent receipt has no issues', () {
      expect(codes(receipt(subtotal: 1000, tax: 100)), isEmpty);
      expect(codes(receipt(subtotal: 1100, tax: 100)), isEmpty); // inclusive
      expect(codes(receipt(subtotal: 999, tax: 100)), isEmpty); // rounding
    });
    test('total problems', () {
      expect(codes(receipt(total: null)), [IssueCode.missingTotal]);
      expect(codes(receipt(total: 0)), [IssueCode.nonPositiveTotal]);
      expect(codes(receipt(subtotal: 900, tax: 100)), [
        IssueCode.totalMismatch,
      ]);
      expect(
        codes(receipt(subtotal: 900, tax: 100, taxIncluded: true)),
        isEmpty,
      );
      expect(codes(receipt(tax: 1100)), [IssueCode.taxNotLessThanTotal]);
    });
    test('date problems', () {
      expect(codes(receipt(date: LocalDate(2026, 9, 25))), [
        IssueCode.futureDate,
      ]);
      expect(codes(receipt(date: LocalDate(2024, 9, 23))), [IssueCode.oldDate]);
      expect(
        codes(
          ParsedReceipt(
            currency: sure('AUD'),
            rows: const [],
            total: sure(100),
          ),
        ),
        [IssueCode.missingDate],
      );
    });
    test('unknown currency and low confidence', () {
      expect(codes(receipt(currency: 'XYZ')), [IssueCode.unknownCurrency]);
      final unsure = ParsedReceipt(
        currency: sure('AUD'),
        rows: const [],
        date: sure(LocalDate(2026, 9, 1)),
        total: const ParsedField(100, confidence: 0.3, reason: 'largest'),
      );
      final issues = validator.validate(unsure, options());
      expect(
        issues,
        contains(
          const ValidationIssue(
            ReceiptField.total,
            IssueCode.lowConfidence,
            IssueSeverity.info,
          ),
        ),
      );
    });
  });
}
