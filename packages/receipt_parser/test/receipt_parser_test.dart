import 'package:receipt_parser/receipt_parser.dart';
import 'package:test/test.dart';

void main() {
  test('exposes a semantic version', () {
    expect(receiptParserVersion, matches(RegExp(r'^\d+\.\d+\.\d+$')));
  });
}
