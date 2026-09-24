import 'package:receipt_parser/receipt_parser.dart';
import 'package:receipt_parser/src/extract/currency_extractor.dart';
import 'package:receipt_parser/src/extract/date_extractor.dart';
import 'package:receipt_parser/src/extract/merchant_extractor.dart';
import 'package:receipt_parser/src/extract/payment_extractor.dart';
import 'package:receipt_parser/src/extract/tax_extractor.dart';
import 'package:receipt_parser/src/extract/total_extractor.dart';
import 'package:receipt_parser/src/lexicon/vocabulary.dart';
import 'package:receipt_parser/src/text/text_normalizer.dart';
import 'package:test/test.dart';

import '../helpers.dart';

void main() {
  group('KeywordMatcher', () {
    final m = KeywordMatcher(['total', 'grand total', 'ec-karte']);
    bool has(String s) => m.hasMatch(foldForKeywords(s));

    test('matches whole words and phrases', () {
      expect(has('TOTAL 12.50'), isTrue);
      expect(has('Grand  Total'), isTrue);
      expect(has('EC-Karte 23,45'), isTrue);
      expect(has('T0TAL 9.99'), isTrue);
    });
    test('does not match inside words', () {
      expect(has('SUBTOTAL 10.00'), isFalse);
      expect(has('Totally awesome'), isFalse);
    });
    test('prefers the longest keyword', () {
      expect(m.firstMatch('grand total 9'), 'grand total');
    });
  });

  group('CurrencyExtractor', () {
    const e = CurrencyExtractor();
    String code(String text, {String def = 'AUD'}) =>
        e.extract(text.split('\n'), options(currency: def)).value;

    test('an ISO code next to an amount wins', () {
      expect(code('Summe EUR 23,45'), 'EUR');
      expect(code(r'TOTAL 45.60 NZD'), 'NZD');
    });
    test('unambiguous symbols', () {
      expect(code('Total £12.00'), 'GBP');
      expect(code('Summe 12,00 €'), 'EUR');
      expect(code(r'Total A$ 12.00', def: 'USD'), 'AUD');
    });
    test(r'a bare $ is the default dollar currency', () {
      expect(code(r'Total $12.00', def: 'CAD'), 'CAD');
      final usd = e.extract([r'Total $12.00'], options(currency: 'EUR'));
      expect(usd.value, 'USD');
      expect(usd.confidence, lessThan(0.6));
    });
    test('falls back to the default with low confidence', () {
      final f = e.extract(['TOTAL 12.00'], options(currency: 'GBP'));
      expect(f.value, 'GBP');
      expect(f.confidence, 0.7);
    });
    test('ignores codes that are also words', () {
      expect(code('TRY OUR NEW MENU\nTotal 9.00'), 'AUD');
    });
  });

  group('DateExtractor', () {
    LocalDate? date(String text, {DateOrder order = DateOrder.dmy}) =>
        const DateExtractor()
            .extract(contextFor(text, opts: options(dateOrder: order)))
            ?.value;

    final cases = <String, String>{
      'Date: 12/09/2026 14:32': '2026-09-12',
      'Datum 12.09.26': '2026-09-12',
      '2026-09-12 10:01': '2026-09-12',
      'Sat 12 Sep 2026': '2026-09-12',
      '12-SEP-26 17:36': '2026-09-12',
      'Sep 12, 2026 7:41 PM': '2026-09-12',
      '03. März 2026': '2026-03-03',
      '25/08/2026': '2026-08-25',
    };
    cases.forEach((text, iso) {
      test('"$text"', () => expect(date(text)?.toIso(), iso));
    });

    test('ambiguous dates follow the date order', () {
      expect(date('03/04/2026')?.toIso(), '2026-04-03');
      expect(date('03/04/2026', order: DateOrder.mdy)?.toIso(), '2026-03-04');
      expect(date('08/25/2026', order: DateOrder.dmy)?.toIso(), '2026-08-25');
    });
    test('rejects future and very old dates', () {
      expect(date('12/10/2026'), isNull);
      expect(date('12/10/2001'), isNull);
    });
    test('prefers the labelled date over a returns deadline', () {
      expect(
        date('Returns until 01/09/2026\nDate 20/08/2026')?.toIso(),
        '2026-08-20',
      );
    });
    test('does not read amounts or phone numbers as dates', () {
      expect(date('Total 12.50\nTel 02 9876 5432'), isNull);
    });
  });

  group('TaxExtractor', () {
    TaxResult taxes(String text, {String currency = 'AUD'}) =>
        const TaxExtractor().extract(
          contextFor(text, opts: options(currency: currency)),
        );

    test('a GST-included statement is tax, and marks the tax included', () {
      final t = taxes('TOTAL 45.60\nTotal includes GST 4.15');
      expect(t.tax?.value, 415);
      expect(t.taxIncluded, isTrue);
    });
    test('a total including tax is not a tax line', () {
      expect(taxes('TOTAL INC GST 45.60').tax, isNull);
    });
    test('separate tax lines add up; a total tax line wins', () {
      expect(taxes('STATE TAX 2.50\nCOUNTY TAX 1.05').tax?.value, 355);
      expect(
        taxes('STATE TAX 2.50\nCOUNTY TAX 1.05\nTOTAL TAX 3.55').tax?.value,
        355,
      );
      expect(taxes('SALES TAX 8.875% 3.55').tax?.value, 355);
    });
    test('a German MwSt table with net, tax and gross', () {
      final t = taxes(
        'MwSt  Netto  MwSt  Brutto\n'
        'A 19%  8,40  1,60  10,00\n'
        'B 7%  9,35  0,65  10,00\n',
        currency: 'EUR',
      );
      expect(t.tax?.value, 225);
      expect(t.taxIncluded, isTrue);
    });
    test('a UK VAT table with only net and VAT columns', () {
      final t = taxes(
        'VAT RATE  NET  VAT\nA 20.00%  7.24  1.45\nZ 0.00%  10.12  0.00',
        currency: 'GBP',
      );
      expect(t.tax?.value, 145);
    });
    test('a table total row is used instead of summing', () {
      final t = taxes(
        'MwSt  Netto  Brutto\n'
        'A 19%  8,40  1,60  10,00\n'
        'B 7%  9,35  0,65  10,00\n'
        'Summe  17,75  2,25  20,00',
        currency: 'EUR',
      );
      expect(t.tax?.value, 225);
    });
    test('subtotal, also when the amount is on the next row', () {
      expect(taxes('SUBTOTAL 41.45').subtotal?.value, 4145);
      expect(taxes('SUBTOTAL\n41.45').subtotal?.value, 4145);
    });
    test('an item named like a tip is not a tip', () {
      expect(taxes('PG TIPS 80 BAGS 3.00\nMilk 1.65\nTOTAL 4.65').tip, isNull);
      expect(
        taxes('Tip Top Bread 4.00\nSUBTOTAL 4.00\nTIP 1.00').tip?.value,
        100,
      );
    });
    test('tip, ignoring printed suggestions', () {
      expect(taxes('Suggested tip 18% 7.20\nTIP 5.00').tip?.value, 500);
      expect(taxes('Suggested tip 18% 7.20').tip, isNull);
    });
  });

  group('TotalExtractor', () {
    int? total(String text) {
      final context = contextFor(text);
      final taxes = const TaxExtractor().extract(context);
      return const TotalExtractor().extract(context, taxes)?.value;
    }

    test('the TOTAL row', () {
      expect(total('Milk 3.10\nBread 4.00\nTOTAL 7.10\nCASH 10.00'), 710);
    });
    test('skips subtotal, change, savings, rounding and tax rows', () {
      expect(
        total(
          'SUBTOTAL 51.66\nROUNDING -0.01\nTOTAL 51.65\n'
          'CASH 60.00\nCHANGE 8.35\nTOTAL SAVINGS 3.40\nGST 4.70',
        ),
        5165,
      );
    });
    test('a TOTAL label with the amount on the next row', () {
      expect(total('Item 5.00\nTOTAL\n5.00'), 500);
    });
    test('weak labels count when there is no TOTAL', () {
      expect(total('Item 5.00\nBALANCE DUE 5.00'), 500);
      expect(total('Item 44.16\nBALANCE 44.16\nCASH 50.00'), 4416);
    });
    test('the final total after a tip', () {
      expect(
        total(
          'SUBTOTAL 107.00\nTAX 9.50\nTOTAL 116.50\nTIP 23.00\nTOTAL 139.50',
        ),
        13950,
      );
    });
    test('an item named TOTAL above the subtotal loses to the real total', () {
      expect(
        total('TOTAL CEREAL 5.49\nMilk 2.00\nSUBTOTAL 7.49\nTOTAL 7.49'),
        749,
      );
    });
    test('falls back to the largest amount', () {
      expect(total('Coffee 4.50\nCake 6.00\nVISA 10.50'), 1050);
    });
    test('TOTAL INC GST is a total', () {
      expect(total('Item 45.60\nTOTAL INC GST 45.60'), 4560);
    });
    test('nothing to find', () {
      expect(total('Thank you'), isNull);
    });
  });

  group('MerchantExtractor', () {
    String? merchant(String text) =>
        const MerchantExtractor().extract(contextFor(text))?.value;

    test('skips invoice headers, addresses and phone numbers', () {
      expect(
        merchant(
          'TAX INVOICE\nWOOLWORTHS METRO\n123 George St\n'
          'Sydney NSW 2000\nPh (02) 9876 5432\nMilk 3.10',
        ),
        'Woolworths Metro',
      );
    });
    test('takes the name after "welcome to"', () {
      expect(merchant('WELCOME TO\nCHEVRON'), 'Chevron');
      expect(merchant('Welcome to Target'), 'Target');
    });
    test('keeps acronyms and mixed case', () {
      expect(merchant('CVS PHARMACY'), 'CVS Pharmacy');
      expect(merchant('dm-drogerie markt'), 'dm-drogerie markt');
    });
    test('strips store numbers', () {
      expect(merchant('KMART #1052'), 'Kmart');
      expect(merchant('ALDI Filiale 123'), 'Aldi');
    });
    test('joins a two-line name only when confirmed below', () {
      expect(
        merchant('TESCO\nExpress\nTesco Express Camden Road\nTel 0345'),
        'Tesco Express',
      );
      expect(merchant('SHELL\nColes Express\n12 Main Rd'), 'Shell');
    });
    test('German address lines', () {
      expect(
        merchant('Hauptstr. 12\n10115 Berlin\nBäckerei Kamps'),
        'Bäckerei Kamps',
      );
    });
  });

  group('PaymentExtractor', () {
    PaymentMethod? payment(String text, {int? total}) =>
        const PaymentExtractor().extract(contextFor(text), total)?.value;

    test('card', () {
      expect(payment('VISA  45.60\n**** **** **** 4821'), PaymentMethod.card);
      expect(payment('EFTPOS APPROVED'), PaymentMethod.card);
      expect(payment('EC-Karte 23,45'), PaymentMethod.card);
    });
    test('cash', () {
      expect(
        payment('CASH 60.00\nCHANGE 8.35', total: 5165),
        PaymentMethod.cash,
      );
      expect(payment('Gegeben BAR 50,00\nRückgeld 30,78'), PaymentMethod.cash);
    });
    test('ignores loyalty cards and cash out', () {
      expect(payment('Rewards card **** 1234\nCASH 20.00'), PaymentMethod.cash);
      expect(payment('CASH OUT 0.00'), isNull);
    });
    test('unknown', () => expect(payment('Thank you'), isNull));
  });
}
