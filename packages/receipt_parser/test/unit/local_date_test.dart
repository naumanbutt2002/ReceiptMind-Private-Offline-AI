import 'package:receipt_parser/receipt_parser.dart';
import 'package:test/test.dart';

void main() {
  test('rejects dates that do not exist', () {
    expect(() => LocalDate(2026, 2, 30), throwsArgumentError);
    expect(() => LocalDate(2026, 13, 1), throwsArgumentError);
    expect(LocalDate(2028, 2, 29).day, 29); // leap year
  });

  test('ISO round trip', () {
    final date = LocalDate(2026, 9, 4);
    expect(date.toIso(), '2026-09-04');
    expect(LocalDate.parseIso('2026-09-04'), date);
  });

  test('parseIso rejects bad input', () {
    expect(() => LocalDate.parseIso('2026-9-4'), throwsFormatException);
    expect(() => LocalDate.parseIso('2026-02-30'), throwsFormatException);
    expect(LocalDate.tryParseIso('nope'), isNull);
  });

  test('month boundaries', () {
    expect(LocalDate(2026, 9, 24).firstOfMonth, LocalDate(2026, 9, 1));
    expect(LocalDate(2026, 9, 24).firstOfNextMonth, LocalDate(2026, 10, 1));
    expect(LocalDate(2026, 12, 31).firstOfNextMonth, LocalDate(2027, 1, 1));
  });

  test('addDays crosses months and years', () {
    expect(LocalDate(2026, 12, 31).addDays(1), LocalDate(2027, 1, 1));
    expect(LocalDate(2026, 3, 1).addDays(-1), LocalDate(2026, 2, 28));
  });

  test('ordering and equality', () {
    final a = LocalDate(2026, 1, 31);
    final b = LocalDate(2026, 2, 1);
    expect(a.isBefore(b), isTrue);
    expect(b.isAfter(a), isTrue);
    expect([b, a]..sort(), [a, b]);
    expect(LocalDate(2026, 1, 31), a);
    expect({a, LocalDate(2026, 1, 31)}, hasLength(1));
  });

  test('fromDateTime uses the local calendar date', () {
    expect(
      LocalDate.fromDateTime(DateTime(2026, 9, 24, 23, 59)),
      LocalDate(2026, 9, 24),
    );
  });
}
