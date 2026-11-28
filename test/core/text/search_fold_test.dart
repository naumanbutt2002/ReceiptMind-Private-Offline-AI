import 'package:flutter_test/flutter_test.dart';
import 'package:receipt_mind/core/text/search_fold.dart';

void main() {
  group('foldForSearch', () {
    test('lower-cases ASCII and leaves it otherwise unchanged', () {
      expect(
        foldForSearch('Bunnings WAREHOUSE 100%'),
        'bunnings warehouse 100%',
      );
      expect(foldForSearch(r'a_b\c'), r'a_b\c');
      expect(foldForSearch(''), '');
    });

    test('removes accents in either case', () {
      expect(foldForSearch('CAFÉ'), 'cafe');
      expect(foldForSearch('café'), 'cafe');
      expect(foldForSearch('Müller'), 'muller');
      expect(foldForSearch('ÀÁÂÃÄÅ àáâãäå'), 'aaaaaa aaaaaa');
      expect(foldForSearch('Ça Ñandú'), 'ca nandu');
      expect(foldForSearch('Łódź'), 'lodz');
      expect(foldForSearch('Øresund Ålesund'), 'oresund alesund');
      expect(
        foldForSearch('Dvořák Škoda Țară Şişli'),
        'dvorak skoda tara sisli',
      );
      expect(foldForSearch('İstanbul ılık'), 'istanbul ilik');
      expect(foldForSearch('Đà Nẵng Phở'), 'da nang pho');
      expect(foldForSearch('Ðe Þorn'), 'de thorn');
    });

    test('spells out ligatures and sharp s', () {
      expect(foldForSearch('straße'), 'strasse');
      expect(foldForSearch('STRASSE'), 'strasse');
      expect(foldForSearch('GROẞE'), 'grosse');
      expect(foldForSearch('Æble Œuvre'), 'aeble oeuvre');
      expect(foldForSearch('ﬁsh ﬂour'), 'fish flour');
    });

    test('drops combining marks of decomposed text', () {
      expect(foldForSearch('Café'), 'cafe');
      expect(foldForSearch('Müller'), 'muller');
      expect(foldForSearch('Café'), foldForSearch('Café'));
    });

    test('lower-cases other scripts and keeps astral characters', () {
      expect(foldForSearch('ΚΑΦΈΣ'), 'καφεσ');
      expect(foldForSearch('Ёлка'), 'елка');
      expect(foldForSearch('東京 Café'), '東京 cafe');
      expect(foldForSearch('Pizza 🍕 ÉTÉ'), 'pizza 🍕 ete');
    });

    test('never introduces LIKE wildcards or the escape char', () {
      final sample = String.fromCharCodes([
        for (var c = 0x80; c < 0x2000; c++) c,
        for (var c = 0x1E00; c < 0x1F00; c++) c,
        for (var c = 0xFB00; c < 0xFB07; c++) c,
      ]);
      final folded = foldForSearch(sample);
      expect(folded, isNot(contains('%')));
      expect(folded, isNot(contains('_')));
      expect(folded, isNot(contains(r'\')));
    });

    test('every BMP character folds like its lower-case form', () {
      final mismatches = <String>[];
      for (var c = 0; c < 0x10000; c++) {
        if (c >= 0xD800 && c <= 0xDFFF) continue; // lone surrogates
        final char = String.fromCharCode(c);
        if (foldForSearch(char) != foldForSearch(char.toLowerCase())) {
          mismatches.add('U+${c.toRadixString(16)}');
        }
      }
      expect(mismatches, isEmpty);
    });

    test('astral upper-case letters are lower-cased', () {
      expect(foldForSearch('\u{10400}'), '\u{10428}'); // Deseret
    });

    test('is idempotent', () {
      for (final s in ['CAFÉ Straße', 'Æble ﬁsh', 'İı', 'Ёлка ΆΣ']) {
        expect(foldForSearch(foldForSearch(s)), foldForSearch(s));
      }
    });
  });
}
