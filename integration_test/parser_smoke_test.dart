// M2 smoke test: the rule parser runs inside the app on a device or emulator
// and reads three sample OCR dumps correctly.
//
//   flutter test integration_test/parser_smoke_test.dart -d emulator-5554
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:receipt_parser/receipt_parser.dart';

import 'parser_samples.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  for (final sample in parserSamples) {
    testWidgets('parses ${sample.id} on the device', (tester) async {
      final document = sample.layout
          ? OcrDocument.fromJson(
              jsonDecode(sample.input) as Map<String, Object?>,
            )
          : OcrDocument.fromPlainText(sample.input);
      final options = ParseOptions(
        defaultCurrency: sample.options['defaultCurrency']!,
        dateOrder: DateOrder.values.byName(sample.options['dateOrder']!),
        today: LocalDate.parseIso(sample.options['today']!),
      );

      final watch = Stopwatch()..start();
      final receipt = const RuleReceiptParser().parse(document, options);
      watch.stop();
      debugPrint(
        'M2 smoke ${sample.id}: ${watch.elapsedMicroseconds} µs, '
        'total ${receipt.total}, date ${receipt.date}, '
        'merchant ${receipt.merchant}',
      );

      final digits = Currencies.of(receipt.currency.value).minorDigits;
      final expected = sample.expected;
      expect(
        receipt.merchant?.value.toLowerCase(),
        expected['merchant']!.toLowerCase(),
      );
      expect(receipt.date?.value.toIso(), expected['date']);
      expect(
        receipt.total?.value,
        parseMinorUnits(expected['total']!, minorDigits: digits),
      );
      expect(receipt.currency.value, expected['currency']);
      expect(receipt.paymentMethod?.value.name, expected['paymentMethod']);
      expect(
        const ReceiptValidator()
            .validate(receipt, options)
            .where((i) => i.severity == IssueSeverity.error),
        isEmpty,
      );
      // Parsing is synchronous on the UI isolate for now: keep it fast.
      expect(watch.elapsedMilliseconds, lessThan(100));
    });
  }
}
