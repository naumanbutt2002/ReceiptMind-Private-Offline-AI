import 'dart:typed_data';

/// Folds [text] for search matching: lower case, accents and other diacritics
/// removed, and common ligatures spelled out, so "CAFÉ", "Café" and "cafe"
/// (or "STRASSE" and "straße") all compare equal.
///
/// Covers Latin script (Latin-1, Latin Extended-A/B, Latin Extended
/// Additional, including Vietnamese), Greek tonos/dialytika and Cyrillic ё.
/// Combining marks (text in decomposed form) are dropped. Other characters
/// are only lower-cased. The result never contains `%`, `_` or `\` unless the
/// input did, so it can be escaped for `LIKE` after folding.
///
/// Pure and deterministic: the same function runs inside SQLite (as
/// `rm_fold`) and on the search query in Dart.
String foldForSearch(String text) {
  final length = text.length;
  // Fast path: plain ASCII only needs lower-casing.
  var i = 0;
  while (i < length && text.codeUnitAt(i) < 0x80) {
    i++;
  }
  if (i == length) return text.toLowerCase();
  return _fold(text, lowerRest: true);
}

/// One pass over the UTF-16 code units. Units below [_tableSize] go through
/// the precomputed table; a few higher ones are handled explicitly, and the
/// rest (CJK, symbols, astral characters) are copied; if any of them has a
/// lower-case form and [lowerRest] is set, the result is lower-cased once.
String _fold(String text, {required bool lowerRest}) {
  final table = _table;
  final length = text.length;
  final out = Uint16List(length * 3); // a unit expands to at most 3 ("ffi")
  var n = 0;
  var hasOther = false;
  for (var i = 0; i < length; i++) {
    final unit = text.codeUnitAt(i);
    if (unit < 0x80) {
      out[n++] = (unit >= 0x41 && unit <= 0x5A) ? unit + 0x20 : unit;
    } else if (unit < _tableSize) {
      final folded = table[unit];
      if (folded == _multi) {
        for (final u in _multiUnits[unit]!.codeUnits) {
          out[n++] = u;
        }
      } else if (folded != _drop) {
        out[n++] = folded;
      }
    } else if (_isCombiningMark(unit)) {
      continue;
    } else if (_multiUnits[unit] case final spelled?) {
      for (final u in spelled.codeUnits) {
        out[n++] = u;
      }
    } else {
      out[n++] = unit;
      hasOther = hasOther || _mayChangeCase(unit);
    }
  }
  final result = String.fromCharCodes(out, 0, n);
  if (!hasOther || !lowerRest) return result;
  final lower = result.toLowerCase();
  // Lower-casing a few symbols yields accented letters (Å sign -> å), so fold
  // once more; the output is lower case already, so no further round.
  return lower == result ? result : _fold(lower, lowerRest: false);
}

bool _isCombiningMark(int unit) =>
    (unit >= 0x0300 && unit <= 0x036F) || // Combining Diacritical Marks
    (unit >= 0x1AB0 && unit <= 0x1AFF) || // ... Extended
    (unit >= 0x1DC0 && unit <= 0x1DFF) || // ... Supplement
    (unit >= 0x20D0 && unit <= 0x20FF) || // ... for Symbols
    (unit >= 0xFE20 && unit <= 0xFE2F); // Combining Half Marks

/// Whether a unit at or above [_tableSize] can be an upper-case letter (or
/// the lead surrogate of one), so the result needs `toLowerCase`. Symbols
/// such as € and CJK text skip that extra pass.
bool _mayChangeCase(int unit) =>
    (unit >= 0x2100 && unit <= 0x2CFF) || // letterlike, Glagolitic, Coptic...
    (unit >= 0xA640 && unit <= 0xA7FF) || // Cyrillic Ext-B, Latin Ext-D
    (unit >= 0xAB70 && unit <= 0xABBF) || // Cherokee
    (unit >= 0xFF21 && unit <= 0xFF3A) || // fullwidth A-Z
    unit == 0xD801 || // Deseret, Osage
    unit == 0xD803 || // Old Hungarian
    unit == 0xD806 || // Warang Citi
    unit == 0xD81B || // Medefaidrin
    unit == 0xD83A; // Adlam

/// Table covers Latin, Greek, Cyrillic and Latin Extended Additional.
const _tableSize = 0x2000;
const _drop = 0;
const _multi = 0xFFFF;

/// Folded form of every unit below [_tableSize]: one unit, [_drop] for
/// combining marks, or [_multi] when it spells out to several letters (see
/// [_multiUnits]). Built once, on first use (also in drift's isolate).
final Uint16List _table = () {
  final table = Uint16List(_tableSize);
  for (var unit = 0; unit < _tableSize; unit++) {
    if (_isCombiningMark(unit)) {
      table[unit] = _drop;
      continue;
    }
    final folded = StringBuffer();
    for (final u in String.fromCharCode(unit).toLowerCase().codeUnits) {
      if (_isCombiningMark(u)) continue;
      folded.write(_foldTable[u] ?? String.fromCharCode(u));
    }
    final s = folded.toString();
    if (s.length == 1) {
      table[unit] = s.codeUnitAt(0);
    } else if (s.isEmpty) {
      table[unit] = _drop;
    } else {
      table[unit] = _multi;
      _multiUnits[unit] = s;
    }
  }
  return table;
}();

/// Units that spell out to several letters (ß -> ss, Æ -> ae, ﬁ -> fi).
final Map<int, String> _multiUnits = {
  for (final MapEntry(:key, :value) in _foldTable.entries)
    if (key >= _tableSize) key: value,
};

/// Lower-case precomposed letters grouped by what they fold to. Input is
/// lower-cased before lookup, so only lower-case forms are listed.
const _foldGroups = <String, String>{
  'a': 'àáâãäåāăąǎǟǡǻȁȃȧᶏḁạảấầẩẫậắằẳẵặⱥɐ',
  'b': 'ḃḅḇƀɓ',
  'c': 'çćĉċčḉƈȼ',
  'd': 'ďđðḋḍḏḑḓɗɖ',
  'e': 'èéêëēĕėęěȅȇȩḕḗḙḛḝẹẻẽếềểễệɇ',
  'f': 'ḟƒ',
  'g': 'ĝğġģǧǵḡɠǥ',
  'h': 'ĥħȟḣḥḧḩḫẖ',
  'i': 'ìíîïĩīĭįıǐȉȋḭḯỉịɨ',
  'j': 'ĵǰɉ',
  'k': 'ķĸǩḱḳḵƙ',
  'l': 'ĺļľŀłḷḹḻḽƚ',
  'm': 'ḿṁṃ',
  'n': 'ñńņňŉǹṅṇṉṋɲ',
  'o': 'òóôõöøōŏőơǒǫǭǿȍȏȫȭȯȱṍṏṑṓọỏốồổỗộớờởỡợɵ',
  'p': 'ṕṗƥ',
  'q': 'ɋ',
  'r': 'ŕŗřȑȓṙṛṝṟɍ',
  's': 'śŝşšșſṡṣṥṧṩ',
  't': 'ţťŧțṫṭṯṱẗƭ',
  'u': 'ùúûüũūŭůűųưǔǖǘǚǜȕȗṳṵṷṹṻụủứừửữựʉ',
  'v': 'ṽṿ',
  'w': 'ŵẁẃẅẇẉẘ',
  'x': 'ẋẍ',
  'y': 'ýÿŷȳẏẙỳỵỷỹɏ',
  'z': 'źżžẑẓẕƶȥ',
  'ss': 'ß',
  'ae': 'æǣǽ',
  'oe': 'œ',
  'ij': 'ĳ',
  'th': 'þ',
  'ff': 'ﬀ',
  'fi': 'ﬁ',
  'fl': 'ﬂ',
  'ffi': 'ﬃ',
  'ffl': 'ﬄ',
  'st': 'ﬅﬆ',
  // Greek accents and final sigma, Cyrillic ё.
  'α': 'ά',
  'ε': 'έ',
  'η': 'ή',
  'ι': 'ίϊΐ',
  'ο': 'ό',
  'υ': 'ύϋΰ',
  'ω': 'ώ',
  'σ': 'ς',
  'е': 'ё',
};

final Map<int, String> _foldTable = {
  for (final MapEntry(key: folded, value: chars) in _foldGroups.entries)
    for (final unit in chars.codeUnits) unit: folded,
};
