import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:receipt_mind/core/date/local_date.dart';
import 'package:receipt_mind/core/locale/locale_defaults.dart';

void main() {
  setUpAll(initializeDateFormatting);

  final cases = <String, (String, DateOrder)>{
    'en_US': ('USD', DateOrder.mdy),
    'en_AU': ('AUD', DateOrder.dmy),
    'en_GB': ('GBP', DateOrder.dmy),
    'de_DE': ('EUR', DateOrder.dmy),
    'fr_FR': ('EUR', DateOrder.dmy),
    'ja_JP': ('JPY', DateOrder.ymd),
    'en_PK': ('PKR', DateOrder.dmy),
    'ur_PK': ('PKR', DateOrder.dmy),
    'en_IN': ('INR', DateOrder.dmy),
    'en_CA': ('CAD', DateOrder.ymd),
  };

  cases.forEach((locale, expected) {
    test('$locale → ${expected.$1}, ${expected.$2.name}', () {
      expect(LocaleDefaults.currencyFor(locale), expected.$1);
      expect(LocaleDefaults.dateOrderFor(locale), expected.$2);
    });
  });

  test('accepts platform spellings', () {
    expect(LocaleDefaults.currencyFor('en-AU'), 'AUD');
    expect(LocaleDefaults.currencyFor('en_AU.UTF-8'), 'AUD');
  });

  test('falls back for unknown locales', () {
    expect(LocaleDefaults.currencyFor('xx_YY'), 'USD');
    expect(LocaleDefaults.dateOrderFor('xx_YY'), DateOrder.dmy);
    expect(LocaleDefaults.currencyFor(''), 'USD');
  });

  test('region decides when intl lacks the locale', () {
    expect(LocaleDefaults.dateOrderFor('de_XX'), DateOrder.dmy);
    expect(LocaleDefaults.dateOrderFor('xx_US'), DateOrder.mdy);
    expect(LocaleDefaults.dateOrderFor('xx_JP'), DateOrder.ymd);
    expect(LocaleDefaults.dateOrderFor('es_US'), DateOrder.dmy); // CLDR data
    expect(LocaleDefaults.currencyFor('es_US'), 'USD');
    expect(LocaleDefaults.currencyFor('zh_Hant_TW'), 'TWD');
  });

  test('language-only locales use intl', () {
    expect(LocaleDefaults.currencyFor('de'), 'EUR');
    expect(LocaleDefaults.currencyFor('ja'), 'JPY');
  });

  test('regionOf parses platform spellings', () {
    expect(LocaleDefaults.regionOf('en_AU'), 'AU');
    expect(LocaleDefaults.regionOf('en-AU'), 'AU');
    expect(LocaleDefaults.regionOf('zh_Hans_CN'), 'CN');
    expect(LocaleDefaults.regionOf('en'), isNull);
  });

  test('numberLocaleFor falls back to something intl can format', () {
    expect(LocaleDefaults.numberLocaleFor('en_PK'), isNotEmpty);
    expect(LocaleDefaults.numberLocaleFor('xx_YY'), 'en');
    expect(
      LocaleDefaults.numberLocaleFor('de_DE'),
      'de',
    ); // intl keys by language
  });
}
