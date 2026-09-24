import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:receipt_mind/core/money/money.dart';
import 'package:receipt_mind/core/money/money_input.dart';

void main() {
  setUpAll(initializeDateFormatting);

  group('Money', () {
    test('adds and subtracts in the same currency', () {
      expect(
        const Money(1050, 'AUD') + const Money(250, 'AUD'),
        const Money(1300, 'AUD'),
      );
      expect(
        const Money(100, 'AUD') - const Money(250, 'AUD'),
        const Money(-150, 'AUD'),
      );
    });

    test('refuses to mix currencies', () {
      expect(
        () => const Money(1, 'AUD') + const Money(1, 'USD'),
        throwsArgumentError,
      );
    });

    test('decimal strings are exact', () {
      expect(const Money(1250, 'USD').toDecimalString(), '12.50');
      expect(const Money(5, 'USD').toDecimalString(), '0.05');
      expect(const Money(-5, 'USD').toDecimalString(), '-0.05');
      expect(const Money(1500, 'JPY').toDecimalString(), '1500');
      expect(const Money(12345, 'KWD').toDecimalString(), '12.345');
      expect(const Money(0, 'EUR').toDecimalString(), '0.00');
    });

    test('formats for the locale', () {
      expect(const Money(4560, 'AUD').format('en_AU'), r'$45.60');
      expect(const Money(4560, 'AUD').format('en_US'), r'A$45.60');
      expect(const Money(123456, 'USD').format('en_US'), r'$1,234.56');
      expect(const Money(1250, 'EUR').format('de_DE'), '12,50 €');
      expect(const Money(1500, 'JPY').format('ja_JP'), '¥1,500');
      expect(const Money(12345, 'KWD').format('en_US'), 'KD12.345');
      expect(const Money(4560, 'AUD').format('en_PK'), r'A$45.60');
      expect(const Money(4560, 'CAD').format('en_US'), r'CA$45.60');
    });

    test('unknown locales still format', () {
      expect(const Money(100, 'USD').format('xx_YY'), r'$1.00');
      expect(const Money(150000, 'PKR').format('en_PK'), contains('1,500.00'));
    });
  });

  group('MoneyInput', () {
    test('parses with the currency digits', () {
      expect(
        MoneyInput.parse('12.50', currency: 'AUD', locale: 'en_AU'),
        const Money(1250, 'AUD'),
      );
      expect(
        MoneyInput.parse('12,50', currency: 'EUR', locale: 'de_DE'),
        const Money(1250, 'EUR'),
      );
      expect(
        MoneyInput.parse('1500', currency: 'JPY', locale: 'ja_JP'),
        const Money(1500, 'JPY'),
      );
    });

    test('uses the locale separator for three-decimal currencies', () {
      expect(
        MoneyInput.parse('1,234', currency: 'KWD', locale: 'en_US'),
        const Money(1234000, 'KWD'),
      );
      expect(
        MoneyInput.parse('1.234', currency: 'KWD', locale: 'en_US'),
        const Money(1234, 'KWD'),
      );
    });

    test('returns null for nonsense', () {
      expect(MoneyInput.parse('abc', currency: 'USD', locale: 'en_US'), isNull);
    });
  });
}
