import 'dart:async';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/services.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:receipt_mind/features/receipts/data/file_receipt_image_store.dart';

/// Output size of flutter_image_compress on Android:
/// `scale = max(1, min(w / minW, h / minH))`, then `(w / scale).toInt()`.
ImageSize androidScale(ImageSize source, CompressBounds bounds) {
  final scale = math.max(
    1.0,
    math.min(source.width / bounds.minWidth, source.height / bounds.minHeight),
  );
  return (
    width: (source.width / scale).toInt(),
    height: (source.height / scale).toInt(),
  );
}

/// Output size on iOS (`UIImage+scale.m`).
ImageSize iosScale(ImageSize source, CompressBounds bounds) {
  final imgRatio = source.width / source.height;
  final maxRatio = bounds.minWidth / bounds.minHeight;
  var ratio = imgRatio < maxRatio
      ? bounds.minWidth / source.width
      : bounds.minHeight / source.height;
  ratio = math.min(1, ratio);
  return (
    width: (ratio * source.width).floor(),
    height: (ratio * source.height).floor(),
  );
}

/// The real plugin's target-name check (flutter_image_compress 2.5): JPEG
/// output must go to a `.jpg`/`.jpeg` path, or it throws before encoding.
final pluginValidator = FlutterImageCompressValidator(
  const MethodChannel('flutter_image_compress'),
);

/// Copies bytes instead of encoding, and tracks image sizes per path using
/// the Android scaling rule.
class FakeCompressor implements ImageCompressor {
  final sizes = <String, ImageSize>{};
  final calls = <({String target, CompressBounds bounds, int quality})>[];
  bool failThumbnail = false;
  bool failImage = false;
  Object imageError = const FileSystemException('image');

  /// When set, the main image waits for it before it is written.
  Completer<void>? holdImage;

  @override
  Future<ImageSize> readSize(String path) async =>
      sizes[path] ?? (throw StateError('No size for $path'));

  @override
  Future<void> compressJpeg({
    required String sourcePath,
    required String targetPath,
    required int minWidth,
    required int minHeight,
    required int quality,
  }) async {
    pluginValidator.checkFileNameAndFormat(targetPath, CompressFormat.jpeg);
    final bounds = (minWidth: minWidth, minHeight: minHeight);
    calls.add((target: targetPath, bounds: bounds, quality: quality));
    final isThumbnail = targetPath.contains('/thumbs/');
    if (failImage && !isThumbnail) throw imageError;
    if (!isThumbnail) await holdImage?.future;
    // Write the target first, like the plugin does, then fail.
    await File(targetPath).writeAsBytes(await File(sourcePath).readAsBytes());
    if (failThumbnail && isThumbnail) {
      throw const FileSystemException('thumbnail');
    }
    final size = androidScale(sizes[sourcePath]!, bounds);
    sizes[targetPath] = size;
    // The store renames `<id>.tmp.jpg` to `<id>.jpg`.
    if (targetPath.endsWith('.tmp.jpg')) {
      sizes[targetPath.replaceFirst(RegExp(r'\.tmp\.jpg$'), '.jpg')] = size;
    }
  }
}

void main() {
  late Directory base;
  late FakeCompressor compressor;
  late FileReceiptImageStore store;
  late String source;

  FileReceiptImageStore newStore() => FileReceiptImageStore(
    baseDirectory: () async => base,
    compressor: compressor,
  );

  setUp(() async {
    base = await Directory.systemTemp.createTemp('image_store_test');
    compressor = FakeCompressor();
    store = newStore();
    source = p.join(base.path, 'scan.jpg');
    await File(source).writeAsBytes([0xFF, 0xD8, 1, 2, 3, 0xFF, 0xD9]);
  });
  tearDown(() => base.delete(recursive: true));

  File file(String relative) => File(p.join(base.path, relative));

  Future<void> writeStored(String name, {Duration age = Duration.zero}) async {
    for (final relative in ['receipts/$name', 'receipts/thumbs/$name']) {
      final f = file(relative);
      await f.parent.create(recursive: true);
      await f.writeAsString('x');
      if (age > Duration.zero) {
        await f.setLastModified(DateTime.now().subtract(age));
      }
    }
  }

  group('scaling bounds', () {
    void expectWithin(ImageSize source, {required ImageSize image}) {
      final bounds = FileReceiptImageStore.imageBounds(source);
      expect(androidScale(source, bounds), image, reason: 'Android');
      expect(iosScale(source, bounds), image, reason: 'iOS');
    }

    test('a tall receipt ends 2400 px on the long edge', () {
      expectWithin(
        (width: 1000, height: 6000),
        image: (width: 400, height: 2400),
      );
    });

    test('a 3000×4000 photo ends 1800×2400', () {
      expectWithin(
        (width: 3000, height: 4000),
        image: (width: 1800, height: 2400),
      );
    });

    test('a wide image is limited on its width', () {
      expectWithin(
        (width: 4000, height: 3000),
        image: (width: 2400, height: 1800),
      );
    });

    test('a small image is never upscaled', () {
      expectWithin(
        (width: 800, height: 1200),
        image: (width: 800, height: 1200),
      );
      expectWithin(
        (width: 2400, height: 1000),
        image: (width: 2400, height: 1000),
      );
    });

    test('the long edge never exceeds 2400 for awkward sizes', () {
      for (final (w, h) in [
        (2401, 2401),
        (3001, 4007),
        (1237, 9999),
        (100, 30000),
        (4032, 3024),
        (2448, 3264),
      ]) {
        final source = (width: w, height: h);
        final bounds = FileReceiptImageStore.imageBounds(source);
        for (final out in [
          androidScale(source, bounds),
          iosScale(source, bounds),
        ]) {
          expect(math.max(out.width, out.height), lessThanOrEqualTo(2400));
          expect(math.max(out.width, out.height), greaterThan(2390));
          expect(math.min(out.width, out.height), greaterThan(0));
        }
      }
    });

    test('bounds are equal, so EXIF rotation does not change the result', () {
      final bounds = FileReceiptImageStore.imageBounds((
        width: 3000,
        height: 4000,
      ));
      expect(bounds.minWidth, bounds.minHeight);
    });

    test('thumbnails are 360 px wide and never upscaled', () {
      for (final (source, expected) in [
        ((width: 400, height: 2400), (width: 360, height: 2160)),
        ((width: 1800, height: 2400), (width: 360, height: 480)),
        ((width: 2400, height: 1800), (width: 360, height: 270)),
        ((width: 300, height: 500), (width: 300, height: 500)),
        ((width: 360, height: 100), (width: 360, height: 100)),
      ]) {
        final bounds = FileReceiptImageStore.thumbnailBounds(source);
        expect(androidScale(source, bounds), expected, reason: '$source');
        expect(iosScale(source, bounds), expected, reason: '$source');
      }
    });
  });

  group('importScan', () {
    test('writes the image and thumbnail with the right settings', () async {
      compressor.sizes[source] = (width: 1000, height: 6000);

      final stored = await store.importScan(source, id: 'abc');

      expect(stored, (
        image: 'receipts/abc.jpg',
        thumbnail: 'receipts/thumbs/abc.jpg',
      ));
      expect(file('receipts/abc.jpg').existsSync(), isTrue);
      expect(file('receipts/thumbs/abc.jpg').existsSync(), isTrue);
      expect(File(source).existsSync(), isTrue, reason: 'source kept');
      expect(compressor.calls, hasLength(2));
      expect(compressor.calls[0].quality, 80);
      expect(compressor.calls[0].target, endsWith('receipts/abc.tmp.jpg'));
      expect(compressor.calls[1].quality, 70);
      expect(
        compressor.calls[1].target,
        endsWith('receipts/thumbs/abc.tmp.jpg'),
      );
      expect(compressor.sizes[file('receipts/abc.jpg').path], (
        width: 400,
        height: 2400,
      ));
      expect(compressor.sizes[file('receipts/thumbs/abc.jpg').path], (
        width: 360,
        height: 2160,
      ));
      // No temp files left behind.
      final names = base
          .listSync(recursive: true)
          .map((e) => p.basename(e.path));
      expect(names.where((n) => n.contains('.tmp')), isEmpty);
    });

    test('a failed thumbnail removes the image and rethrows', () async {
      compressor
        ..sizes[source] = (width: 3000, height: 4000)
        ..failThumbnail = true;

      await expectLater(
        store.importScan(source, id: 'abc'),
        throwsA(
          isA<ReceiptStorageException>()
              .having((e) => e.reason, 'reason', ReceiptStorageFailure.other)
              .having((e) => e.cause, 'cause', isA<FileSystemException>()),
        ),
      );
      final files = base.listSync(recursive: true).whereType<File>();
      expect(files.map((f) => p.basename(f.path)), ['scan.jpg']);
    });

    test('a failed image leaves nothing behind', () async {
      compressor
        ..sizes[source] = (width: 3000, height: 4000)
        ..failImage = true;

      await expectLater(
        store.importScan(source, id: 'abc'),
        throwsA(
          isA<ReceiptStorageException>()
              .having((e) => e.reason, 'reason', ReceiptStorageFailure.other)
              .having((e) => e.cause, 'cause', isA<FileSystemException>()),
        ),
      );
      final files = base.listSync(recursive: true).whereType<File>();
      expect(files.map((f) => p.basename(f.path)), ['scan.jpg']);
    });

    test('the plugin accepts every target name (regression: .jpg.tmp)', () {
      // flutter_image_compress throws for a JPEG target that doesn't end in
      // `.jpg`, which made every real import fail.
      expect(
        () => pluginValidator.checkFileNameAndFormat(
          '/x/receipts/abc.jpg.tmp',
          CompressFormat.jpeg,
        ),
        throwsA(anything),
      );
    });

    test('a full disk is reported as storageFull', () async {
      compressor
        ..sizes[source] = (width: 3000, height: 4000)
        ..failImage = true
        ..imageError = const FileSystemException(
          'Cannot write',
          '/x',
          OSError('No space left on device', 28),
        );

      await expectLater(
        store.importScan(source, id: 'abc'),
        throwsA(
          isA<ReceiptStorageException>().having(
            (e) => e.reason,
            'reason',
            ReceiptStorageFailure.storageFull,
          ),
        ),
      );
      final files = base.listSync(recursive: true).whereType<File>();
      expect(files.map((f) => p.basename(f.path)), ['scan.jpg']);
    });

    test('a missing scan file is reported as unreadableImage', () async {
      await expectLater(
        store.importScan(p.join(base.path, 'gone.jpg'), id: 'abc'),
        throwsA(
          isA<ReceiptStorageException>().having(
            (e) => e.reason,
            'reason',
            ReceiptStorageFailure.unreadableImage,
          ),
        ),
      );
      expect(compressor.calls, isEmpty);
      expect(await store.deleteOrphans({}), 0);
    });

    test('rejects ids that are not plain file names', () async {
      for (final id in ['', '../x', 'a/b', 'a.b']) {
        await expectLater(
          store.importScan(source, id: id),
          throwsArgumentError,
          reason: id,
        );
      }
    });
  });

  test('resolve and thumbnailFor', () async {
    expect(store.thumbnailFor('receipts/abc.jpg'), 'receipts/thumbs/abc.jpg');
    expect(
      await store.resolve('receipts/abc.jpg'),
      p.join(base.path, 'receipts', 'abc.jpg'),
    );
    await expectLater(store.resolve('../etc/passwd'), throwsArgumentError);
    await expectLater(store.resolve('/etc/passwd'), throwsArgumentError);
  });

  test(
    'delete removes image and thumbnail and ignores missing files',
    () async {
      await writeStored('a.jpg');
      await store.delete('receipts/a.jpg');
      expect(file('receipts/a.jpg').existsSync(), isFalse);
      expect(file('receipts/thumbs/a.jpg').existsSync(), isFalse);

      await store.delete('receipts/a.jpg'); // no error
      await file('receipts/b.jpg').writeAsString('x'); // no thumbnail
      await store.delete('receipts/b.jpg');
      expect(file('receipts/b.jpg').existsSync(), isFalse);
    },
  );

  group('deleteOrphans', () {
    test('returns 0 when nothing was stored yet', () async {
      expect(await store.deleteOrphans({}), 0);
    });

    test(
      'removes unreferenced images, their thumbnails and stray thumbnails',
      () async {
        await writeStored('keep.jpg');
        await writeStored('gone.jpg');
        await file('receipts/thumbs/stray.jpg').writeAsString('x');
        await file('receipts/notes.txt').writeAsString('x'); // not ours

        final removed = await store.deleteOrphans({'receipts/keep.jpg'});

        expect(removed, 1);
        expect(file('receipts/keep.jpg').existsSync(), isTrue);
        expect(file('receipts/thumbs/keep.jpg').existsSync(), isTrue);
        expect(file('receipts/gone.jpg').existsSync(), isFalse);
        expect(file('receipts/thumbs/gone.jpg').existsSync(), isFalse);
        expect(file('receipts/thumbs/stray.jpg').existsSync(), isFalse);
        expect(file('receipts/notes.txt').existsSync(), isTrue);
      },
    );

    test('keeps young temp files and removes stale ones', () async {
      await writeStored('young.tmp.jpg');
      await writeStored('old.tmp.jpg', age: const Duration(minutes: 11));

      // Temp files end in .jpg too, but are never counted as orphan images.
      expect(await store.deleteOrphans({}), 0);

      expect(file('receipts/young.tmp.jpg').existsSync(), isTrue);
      expect(file('receipts/thumbs/young.tmp.jpg').existsSync(), isTrue);
      expect(file('receipts/old.tmp.jpg').existsSync(), isFalse);
      expect(file('receipts/thumbs/old.tmp.jpg').existsSync(), isFalse);
    });

    test('never touches an import that is still running', () async {
      compressor
        ..sizes[source] = (width: 1000, height: 1000)
        ..holdImage = Completer<void>();
      final import = store.importScan(source, id: 'busy');
      // Let the import create its folders and reach the held compress.
      await pumpEventQueue();
      // Even an old-looking temp file of a running import is kept.
      await file('receipts/busy.tmp.jpg').writeAsString('partial');
      await file('receipts/busy.tmp.jpg')
          .setLastModified(DateTime.now().subtract(const Duration(hours: 1)));

      expect(await store.deleteOrphans({}), 0);
      expect(file('receipts/busy.tmp.jpg').existsSync(), isTrue);

      compressor.holdImage!.complete();
      final stored = await import;
      expect(await store.deleteOrphans({}), 0);
      expect(file(stored.image).existsSync(), isTrue);
      expect(file(stored.thumbnail).existsSync(), isTrue);
    });

    test(
      'keeps images imported by this instance until the next start',
      () async {
        compressor.sizes[source] = (width: 1000, height: 1000);
        await store.importScan(source, id: 'fresh');

        // The row may not be inserted yet: the same store keeps the files.
        expect(await store.deleteOrphans({}), 0);
        expect(file('receipts/fresh.jpg').existsSync(), isTrue);

        // A new store (the next app start) removes them.
        expect(await newStore().deleteOrphans({}), 1);
        expect(file('receipts/fresh.jpg').existsSync(), isFalse);
        expect(file('receipts/thumbs/fresh.jpg').existsSync(), isFalse);
      },
    );
  });
  group('FlutterImageCompressor', () {
    late List<Map<String, Object>> calls;
    late String target;

    FlutterImageCompressor compressorWith(
      Future<List<int>?> Function() output, {
      Object? error,
    }) => FlutterImageCompressor(
      compressAndGetFile:
          (
            path,
            targetPath, {
            required minWidth,
            required minHeight,
            required quality,
            required format,
            required keepExif,
            required autoCorrectionAngle,
          }) async {
            // The real plugin validates the name before anything else.
            pluginValidator.checkFileNameAndFormat(targetPath, format);
            calls.add({
              'path': path,
              'target': targetPath,
              'minWidth': minWidth,
              'minHeight': minHeight,
              'quality': quality,
              'format': format,
              'keepExif': keepExif,
              'autoCorrectionAngle': autoCorrectionAngle,
            });
            if (error != null) throw error;
            final bytes = await output();
            if (bytes == null) return null;
            await File(targetPath).writeAsBytes(bytes);
            return XFile(targetPath);
          },
    );

    Future<void> compress(FlutterImageCompressor c) => c.compressJpeg(
      sourcePath: source,
      targetPath: target,
      minWidth: 400,
      minHeight: 400,
      quality: 80,
    );

    setUp(() {
      calls = [];
      target = p.join(base.path, 'out.tmp.jpg');
    });

    test('strips EXIF and turns the pixels upright first', () async {
      // keepExif: false drops the orientation tag, so autoCorrectionAngle
      // must rotate the pixels or a camera photo would be stored sideways.
      await compress(compressorWith(() async => [1, 2, 3]));

      expect(calls.single, {
        'path': source,
        'target': target,
        'minWidth': 400,
        'minHeight': 400,
        'quality': 80,
        'format': CompressFormat.jpeg,
        'keepExif': false,
        'autoCorrectionAngle': true,
      });
    });

    test('an empty output file is an error', () async {
      // Android reports success with an empty file when every OOM retry
      // failed.
      await expectLater(
        compress(compressorWith(() async => [])),
        throwsA(isA<ReceiptStorageException>()),
      );
      await expectLater(
        compress(compressorWith(() async => null)),
        throwsA(isA<ReceiptStorageException>()),
      );
    });

    test('maps plugin errors to storage failures', () async {
      for (final (error, reason) in [
        (
          CompressError('not an image', code: 'decode_failed'),
          ReceiptStorageFailure.unreadableImage,
        ),
        (
          CompressError('Image file does not exist in /x.'),
          ReceiptStorageFailure.unreadableImage,
        ),
        (
          CompressError(
            '/x/out.tmp.jpg: open failed: ENOSPC (No space left on device)',
            code: 'unknown',
          ),
          ReceiptStorageFailure.storageFull,
        ),
        (CompressError('boom', code: 'unknown'), ReceiptStorageFailure.other),
      ]) {
        await expectLater(
          compress(compressorWith(() async => [1], error: error)),
          throwsA(
            isA<ReceiptStorageException>()
                .having((e) => e.reason, 'reason', reason)
                .having((e) => e.cause, 'cause', error),
          ),
          reason: '$error',
        );
      }
    });
  });
}
