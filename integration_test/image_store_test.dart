// M3 on-device test: the real FileReceiptImageStore (flutter_image_compress +
// ui.ImageDescriptor) shrinks large scans, strips EXIF (including GPS) and
// writes a 360 px thumbnail. M8: a camera photo whose EXIF says "rotate 90°"
// is stored upright, because stripping EXIF also drops that tag.
//
//   flutter test integration_test/image_store_test.dart -d emulator-5554
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:receipt_mind/features/receipts/data/file_receipt_image_store.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  late Directory base;

  setUp(() async {
    base = await (await getTemporaryDirectory()).createTemp('m3_store');
  });
  tearDown(() => base.delete(recursive: true));

  for (final (name, width, height) in [
    ('photo', 3000, 4000),
    ('tall receipt', 1000, 6000),
  ]) {
    testWidgets('stores a $width×$height $name small and without EXIF', (
      tester,
    ) async {
      final jpeg = await _receiptLikeJpeg(width, height);
      final withExif = _insertGpsExif(jpeg);
      expect(_hasExif(withExif), isTrue, reason: 'test setup');
      final source = File(p.join(base.path, 'scan.jpg'));
      await source.writeAsBytes(withExif);

      final store = FileReceiptImageStore(
        baseDirectory: () async => base,
        compressor: const FlutterImageCompressor(),
      );
      final watch = Stopwatch()..start();
      final stored = await store.importScan(source.path, id: 'm3test');
      watch.stop();

      final image = await File(await store.resolve(stored.image)).readAsBytes();
      final thumb = await File(await store.resolve(stored.thumbnail))
          .readAsBytes();
      final imageSize = _jpegSize(image);
      final thumbSize = _jpegSize(thumb);
      debugPrint(
        'M3 store $name: source ${withExif.length ~/ 1024} KB '
        '${width}x$height → image ${image.length ~/ 1024} KB '
        '${imageSize.width}x${imageSize.height}, thumbnail '
        '${thumb.length ~/ 1024} KB ${thumbSize.width}x${thumbSize.height}, '
        '${watch.elapsedMilliseconds} ms',
      );

      expect(image.length, lessThanOrEqualTo(600 * 1024));
      expect(
        math.max(imageSize.width, imageSize.height),
        lessThanOrEqualTo(2400),
      );
      expect(
        math.max(imageSize.width, imageSize.height),
        greaterThan(2390),
        reason: 'scaled to the limit, not further',
      );
      expect(thumbSize.width, 360);
      expect(_hasExif(image), isFalse, reason: 'image EXIF stripped');
      expect(_hasExif(thumb), isFalse, reason: 'thumbnail EXIF stripped');
      expect(await source.exists(), isTrue, reason: 'source left alone');
    });
  }

  testWidgets(
    'a sideways camera photo (EXIF orientation 6) is stored upright',
    (tester) async {
      // Raw pixels are landscape 1200×800 with a dark square in the raw
      // top-left corner. Orientation 6 means "rotate 90° clockwise to view",
      // so the upright photo is portrait 800×1200 with the square top-right.
      const width = 1200, height = 800, square = 200;
      final raw = Uint8List((width + 1) * height);
      for (var y = 0; y < height; y++) {
        for (var x = 0; x < width; x++) {
          raw[y * (width + 1) + 1 + x] = x < square && y < square ? 20 : 230;
        }
      }
      final jpeg = await FlutterImageCompress.compressWithList(
        _png(width, height, raw),
        minWidth: width,
        minHeight: height,
        quality: 92,
        format: CompressFormat.jpeg,
      );
      final rotated = _insertOrientationExif(jpeg, 6);
      expect(_hasExif(rotated), isTrue, reason: 'test setup');
      final source = File(p.join(base.path, 'camera.jpg'));
      await source.writeAsBytes(rotated);

      final store = FileReceiptImageStore(
        baseDirectory: () async => base,
        compressor: const FlutterImageCompressor(),
      );
      final stored = await store.importScan(source.path, id: 'upright');

      final image = await File(await store.resolve(stored.image)).readAsBytes();
      final thumb = await File(await store.resolve(stored.thumbnail))
          .readAsBytes();
      expect(_hasExif(image), isFalse, reason: 'EXIF stripped');
      expect(_jpegSize(image), (width: 800, height: 1200), reason: 'portrait');
      expect(_jpegSize(thumb), (width: 360, height: 540));

      // The pixels were turned, not just the size: the square is top-right.
      final pixels = await _decodeGrey(image);
      expect(pixels.at(800 - 50, 50), lessThan(100), reason: 'top-right dark');
      expect(pixels.at(50, 50), greaterThan(180), reason: 'top-left light');
      expect(pixels.at(800 - 50, 1200 - 50), greaterThan(180));
    },
  );
}

/// Decodes [jpeg] and returns a reader for the grey level at (x, y).
Future<({int Function(int x, int y) at})> _decodeGrey(Uint8List jpeg) async {
  final codec = await ui.instantiateImageCodec(jpeg);
  final frame = await codec.getNextFrame();
  final image = frame.image;
  final data = (await image.toByteData())!;
  final width = image.width;
  image.dispose();
  codec.dispose();
  return (at: (int x, int y) => data.getUint8((y * width + x) * 4));
}

/// Inserts an APP1 `Exif` segment whose IFD0 has only an Orientation tag.
Uint8List _insertOrientationExif(Uint8List jpeg, int orientation) {
  expect(jpeg[0] == 0xFF && jpeg[1] == 0xD8, isTrue, reason: 'JPEG SOI');
  final tiff = <int>[
    ...'MM'.codeUnits, 0, 42, ..._be32(8), // big-endian header, IFD0 at 8
    0, 1, // one entry
    0x01, 0x12, 0, 3, ..._be32(1), 0, orientation, 0, 0, // Orientation SHORT
    ..._be32(0), // no next IFD
  ];
  final payload = [...'Exif'.codeUnits, 0, 0, ...tiff];
  final length = payload.length + 2;
  return Uint8List.fromList([
    0xFF, 0xD8, //
    0xFF, 0xE1, length >> 8, length & 0xFF, ...payload,
    ...jpeg.sublist(2),
  ]);
}

/// An off-white "paper" with a soft gradient, slight noise and dark text-like
/// bars, so the JPEG has realistic content instead of compressing to nothing.
///
/// The pixels are written as a greyscale PNG in plain Dart (no GPU texture, so
/// no texture-size limit) and turned into a JPEG by the real plugin.
Future<Uint8List> _receiptLikeJpeg(int width, int height) async {
  final random = math.Random(42);
  final lineHeight = math.max(24, height ~/ 120);
  // One filter byte (0 = none) per row, then the grey values.
  final raw = Uint8List((width + 1) * height);
  for (var y = 0; y < height; y++) {
    final row = y ~/ lineHeight;
    final inText = y % lineHeight < lineHeight * 0.55;
    final shade = 235 - (y * 20 ~/ height);
    final offset = y * (width + 1) + 1;
    var barEnd = -1;
    for (var x = 0; x < width; x++) {
      if (inText && x > barEnd + 8 && random.nextInt(40) == 0) {
        barEnd = x + 6 + random.nextInt(width ~/ 30 + 1);
      }
      var v = shade + random.nextInt(7) - 3 - (x * 10 ~/ width);
      if (inText && x <= barEnd && row.isOdd == (x * 3 < width * 2)) {
        v = 30 + random.nextInt(20);
      }
      raw[offset + x] = v;
    }
  }
  final png = _png(width, height, raw);

  // minWidth/minHeight equal to the size: no scaling, just re-encode.
  return FlutterImageCompress.compressWithList(
    png,
    minWidth: width,
    minHeight: height,
    quality: 92,
    format: CompressFormat.jpeg,
  );
}

/// An 8-bit greyscale PNG from filtered scanlines.
Uint8List _png(int width, int height, Uint8List scanlines) {
  final out = BytesBuilder(copy: false)
    ..add([0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A]);
  void chunk(String type, List<int> data) {
    final typed = [...type.codeUnits, ...data];
    out
      ..add(_be32(data.length))
      ..add(typed)
      ..add(_be32(_crc32(typed)));
  }

  chunk('IHDR', [..._be32(width), ..._be32(height), 8, 0, 0, 0, 0]);
  chunk('IDAT', ZLibEncoder(level: 6).convert(scanlines));
  chunk('IEND', const []);
  return out.toBytes();
}

final _crcTable = List<int>.generate(256, (n) {
  var c = n;
  for (var k = 0; k < 8; k++) {
    c = c & 1 != 0 ? 0xEDB88320 ^ (c >> 1) : c >> 1;
  }
  return c;
});

int _crc32(List<int> bytes) {
  var c = 0xFFFFFFFF;
  for (final b in bytes) {
    c = _crcTable[(c ^ b) & 0xFF] ^ (c >> 8);
  }
  return c ^ 0xFFFFFFFF;
}

List<int> _be32(int v) => [
  v >> 24 & 0xFF,
  v >> 16 & 0xFF,
  v >> 8 & 0xFF,
  v & 0xFF,
];

/// Inserts an APP1 `Exif` segment with a GPS IFD (lat/long) after SOI.
Uint8List _insertGpsExif(Uint8List jpeg) {
  expect(jpeg[0] == 0xFF && jpeg[1] == 0xD8, isTrue, reason: 'JPEG SOI');
  final tiff = BytesBuilder();
  void u16(int v) => tiff.add([v >> 8 & 0xFF, v & 0xFF]);
  void u32(int v) => tiff.add(_be32(v));
  void entry(int tag, int type, int count, List<int> value) {
    u16(tag);
    u16(type);
    u32(count);
    tiff.add([...value, ...List.filled(4 - value.length, 0)]);
  }

  const byte = 1, ascii = 2, long = 4, rational = 5;

  // Header (big-endian), IFD0 at 8.
  tiff.add('MM'.codeUnits);
  u16(42);
  u32(8);
  // IFD0: one entry, the GPS IFD pointer. 8 + 2 + 12 + 4 = 26.
  const gpsIfd = 26;
  u16(1);
  entry(0x8825, long, 1, _be32(gpsIfd));
  u32(0);
  // GPS IFD: 5 entries. 26 + 2 + 60 + 4 = 92, then two 3-rational values.
  const latitude = 92, longitude = 116;
  u16(5);
  entry(0x0000, byte, 4, [2, 3, 0, 0]); // GPSVersionID
  entry(0x0001, ascii, 2, 'S\x00'.codeUnits); // GPSLatitudeRef
  entry(0x0002, rational, 3, _be32(latitude)); // GPSLatitude
  entry(0x0003, ascii, 2, 'E\x00'.codeUnits); // GPSLongitudeRef
  entry(0x0004, rational, 3, _be32(longitude)); // GPSLongitude
  u32(0);
  for (final (d, m, s) in [(33, 52, 4), (151, 12, 26)]) {
    for (final v in [d, m, s]) {
      u32(v);
      u32(1);
    }
  }
  final tiffBytes = tiff.toBytes();
  expect(tiffBytes.length, 140);

  final payload = [...'Exif'.codeUnits, 0, 0, ...tiffBytes];
  final length = payload.length + 2;
  return Uint8List.fromList([
    0xFF, 0xD8, //
    0xFF, 0xE1, length >> 8, length & 0xFF, ...payload,
    ...jpeg.sublist(2),
  ]);
}

/// Walks the JPEG markers up to the start of scan and calls [visit] with
/// each segment's marker and payload.
void _segments(
  Uint8List jpeg,
  void Function(int marker, Uint8List data) visit,
) {
  var i = 2;
  while (i + 4 <= jpeg.length) {
    if (jpeg[i] != 0xFF) throw FormatException('Bad JPEG marker at $i');
    final marker = jpeg[i + 1];
    if (marker == 0xFF) {
      i++; // fill byte
      continue;
    }
    if (marker == 0xD8 ||
        marker == 0x01 ||
        (marker >= 0xD0 && marker <= 0xD7)) {
      i += 2;
      continue;
    }
    final length = jpeg[i + 2] << 8 | jpeg[i + 3];
    visit(marker, Uint8List.sublistView(jpeg, i + 4, i + 2 + length));
    if (marker == 0xDA) return; // start of scan
    i += 2 + length;
  }
}

bool _hasExif(Uint8List jpeg) {
  var found = false;
  _segments(jpeg, (marker, data) {
    if (marker == 0xE1 &&
        data.length >= 6 &&
        String.fromCharCodes(data.sublist(0, 4)) == 'Exif' &&
        data[4] == 0 &&
        data[5] == 0) {
      found = true;
    }
  });
  return found;
}

/// Width and height from the SOFn header.
({int width, int height}) _jpegSize(Uint8List jpeg) {
  ({int width, int height})? size;
  _segments(jpeg, (marker, data) {
    final isSof =
        marker >= 0xC0 &&
        marker <= 0xCF &&
        marker != 0xC4 &&
        marker != 0xC8 &&
        marker != 0xCC;
    if (isSof && size == null) {
      size = (height: data[1] << 8 | data[2], width: data[3] << 8 | data[4]);
    }
  });
  return size ?? (throw const FormatException('No SOF segment'));
}
