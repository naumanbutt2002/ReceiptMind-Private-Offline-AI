import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;

import 'image_compressor.dart';
import 'receipt_image_store.dart';
import 'receipt_storage_exception.dart';

export 'image_compressor.dart';
export 'receipt_storage_exception.dart';

/// The scaling arguments for [ImageCompressor.compressJpeg].
typedef CompressBounds = ({int minWidth, int minHeight});

/// [ReceiptImageStore] on the file system, under [baseDirectory]
/// (the app support directory):
///
/// ```
/// receipts/<id>.jpg         JPEG q80, long edge ≤ 2400 px, no EXIF
/// receipts/thumbs/<id>.jpg  JPEG q70, 360 px wide
/// ```
///
/// Very long receipts (narrower than 1:4) keep a readable width instead, see
/// [imageBounds].
///
/// Files are written under a temporary name (`<id>.tmp.jpg`) and renamed when
/// complete, so a stored image is never half-written. The temporary name ends
/// in `.jpg` because `flutter_image_compress` rejects any other extension for
/// JPEG output; ids can't contain a dot, so it never clashes with an image.
class FileReceiptImageStore implements ReceiptImageStore {
  FileReceiptImageStore({
    required this._baseDirectory,
    required this._compressor,
    this._clock = DateTime.now,
  });

  final Future<Directory> Function() _baseDirectory;
  final ImageCompressor _compressor;
  final DateTime Function() _clock;

  /// Image names (`<id>.jpg`) imported by this instance. [deleteOrphans] keeps
  /// them: a scan may be imported but its row not inserted yet. Orphans among
  /// them are removed at the next start.
  final Set<String> _importedNames = {};

  static const directoryName = 'receipts';
  static const thumbnailDirectoryName = 'thumbs';
  static const imageQuality = 80;
  static const maxLongEdge = 2400;

  /// Width a very long receipt keeps (if the scan is that wide), so its text
  /// stays readable: at a 2400 px long edge a 1:20 receipt would be 120 px
  /// wide.
  static const minShortEdge = 600;

  /// Long edge limit for those very long receipts, below the 8192 px texture
  /// limit of most GPUs.
  static const maxTallLongEdge = 8000;
  static const thumbnailQuality = 70;
  static const thumbnailWidth = 360;

  /// Temporary files younger than this may belong to a running import.
  static const tempFileGracePeriod = Duration(minutes: 10);

  static const _jpg = '.jpg';
  static const _tmp = '.tmp.jpg';

  /// Bounds that scale [source] down so its long edge is at most
  /// [maxLongEdge], or keep its size if it is already small enough.
  ///
  /// A receipt narrower than 1:4 would end up less than [minShortEdge] wide
  /// that way, so it keeps that width (or its own, if narrower) and may be up
  /// to [maxTallLongEdge] long; beyond that it is scaled down further.
  ///
  /// Both bounds are equal, so the result doesn't depend on which side is the
  /// width (the plugin swaps them for EXIF-rotated images) and is the same on
  /// Android (`scale = max(1, min(w / minW, h / minH))`) and iOS
  /// (`scale = min(1, minW / shortSide)` when `minW == minH`). The result
  /// `m ≤ short` is the new short edge: the scale is `short / m`, so the long
  /// edge becomes `⌊long · m / short⌋`, which is at most 2400 for
  /// `m = ⌊short · 2400 / long⌋` (and at most 8000 for the cap below).
  static CompressBounds imageBounds(ImageSize source) {
    final short = math.min(source.width, source.height);
    final long = math.max(source.width, source.height);
    if (long <= maxLongEdge) return (minWidth: short, minHeight: short);
    final fit = short * maxLongEdge ~/ long;
    final readable = math.min(short, minShortEdge);
    final cap = short * maxTallLongEdge ~/ long;
    final m = math.max(1, math.min(math.max(fit, readable), cap));
    return (minWidth: m, minHeight: m);
  }

  /// Bounds that scale [source] down to [thumbnailWidth] px wide, or keep its
  /// size if it is narrower. Equal bounds for the same reasons as
  /// [imageBounds]: the scale becomes `short / m = width / 360`.
  static CompressBounds thumbnailBounds(ImageSize source) {
    final short = math.min(source.width, source.height);
    final m = source.width <= thumbnailWidth
        ? short
        : math.max(1, (short * thumbnailWidth / source.width).round());
    return (minWidth: m, minHeight: m);
  }

  @override
  Future<StoredImage> importScan(
    String sourcePath, {
    required String id,
  }) async {
    if (!_isSafeId(id)) {
      throw ArgumentError.value(id, 'id', 'Not a safe file name');
    }
    final base = await _baseDirectory();
    final name = '$id$_jpg';
    final image = '$directoryName/$name';
    final thumbnail = thumbnailFor(image);
    final imageFile = File(_absolute(base, image));
    final thumbnailFile = File(_absolute(base, thumbnail));
    final tempImage = '$directoryName/$id$_tmp';
    final imageTemp = File(_absolute(base, tempImage));
    final thumbnailTemp = File(_absolute(base, thumbnailFor(tempImage)));

    _importedNames.add(name);
    try {
      if (!await File(sourcePath).exists()) {
        throw ReceiptStorageException(
          ReceiptStorageFailure.unreadableImage,
          PathNotFoundException(sourcePath, const OSError()),
        );
      }
      await thumbnailFile.parent.create(recursive: true);
      final size = await _compressor.readSize(sourcePath);
      final bounds = imageBounds(size);
      await _compressor.compressJpeg(
        sourcePath: sourcePath,
        targetPath: imageTemp.path,
        minWidth: bounds.minWidth,
        minHeight: bounds.minHeight,
        quality: imageQuality,
      );
      await imageTemp.rename(imageFile.path);

      // The thumbnail comes from the stored image: a much smaller decode.
      final storedSize = await _compressor.readSize(imageFile.path);
      final thumbBounds = thumbnailBounds(storedSize);
      await _compressor.compressJpeg(
        sourcePath: imageFile.path,
        targetPath: thumbnailTemp.path,
        minWidth: thumbBounds.minWidth,
        minHeight: thumbBounds.minHeight,
        quality: thumbnailQuality,
      );
      await thumbnailTemp.rename(thumbnailFile.path);
    } catch (error, stackTrace) {
      for (final file in [imageTemp, imageFile, thumbnailTemp, thumbnailFile]) {
        try {
          await _deleteIfExists(file);
        } on FileSystemException catch (e) {
          // Keep the original error; orphan cleanup retries at next start.
          debugPrint('ReceiptImageStore: could not delete ${file.path}: $e');
        }
      }
      _importedNames.remove(name);
      Error.throwWithStackTrace(
        ReceiptStorageException.from(error),
        stackTrace,
      );
    }
    return (image: image, thumbnail: thumbnail);
  }

  @override
  Future<String> resolve(String relativePath) async =>
      _absolute(await _baseDirectory(), relativePath);

  @override
  String thumbnailFor(String relativeImagePath) => p.posix.join(
    p.posix.dirname(relativeImagePath),
    thumbnailDirectoryName,
    p.posix.basename(relativeImagePath),
  );

  @override
  Future<void> delete(String relativeImagePath) async {
    final base = await _baseDirectory();
    await _deleteIfExists(File(_absolute(base, relativeImagePath)));
    await _deleteIfExists(
      File(_absolute(base, thumbnailFor(relativeImagePath))),
    );
  }

  @override
  Future<int> deleteOrphans(Set<String> referencedImagePaths) async {
    final base = await _baseDirectory();
    final images = Directory(_absolute(base, directoryName));
    if (!await images.exists()) return 0;
    final thumbnails = Directory(p.join(images.path, thumbnailDirectoryName));

    bool referenced(String name) =>
        _importedNames.contains(name) ||
        referencedImagePaths.contains('$directoryName/$name');

    // Temp names end in `.jpg` too, so they are checked first.
    var removed = 0;
    await for (final file in images.list().where((e) => e is File)) {
      final name = p.basename(file.path);
      if (name.endsWith(_tmp)) {
        await _deleteStaleTemp(File(file.path));
      } else if (name.endsWith(_jpg) && !referenced(name)) {
        await _deleteIfExists(File(file.path));
        await _deleteIfExists(File(p.join(thumbnails.path, name)));
        removed++;
      }
    }
    if (await thumbnails.exists()) {
      await for (final file in thumbnails.list().where((e) => e is File)) {
        final name = p.basename(file.path);
        if (name.endsWith(_tmp)) {
          await _deleteStaleTemp(File(file.path));
        } else if (name.endsWith(_jpg) && !referenced(name)) {
          await _deleteIfExists(File(file.path));
        }
      }
    }
    return removed;
  }

  Future<void> _deleteStaleTemp(File file) async {
    final name = p.basename(file.path);
    final id = name.substring(0, name.length - _tmp.length);
    if (_importedNames.contains('$id$_jpg')) return;
    try {
      final modified = await file.lastModified();
      if (_clock().difference(modified) >= tempFileGracePeriod) {
        await _deleteIfExists(file);
      }
    } on FileSystemException catch (e) {
      debugPrint('ReceiptImageStore: skipped ${file.path}: $e');
    }
  }

  /// Joins a stored relative path onto [base]. Rejects absolute paths and
  /// `..` so a bad DB value can't reach files outside the base directory.
  static String _absolute(Directory base, String relativePath) {
    final parts = p.posix.split(relativePath);
    if (p.posix.isAbsolute(relativePath) ||
        parts.contains('..') ||
        relativePath.contains(r'\')) {
      throw ArgumentError.value(relativePath, 'relativePath', 'Not relative');
    }
    return p.joinAll([base.path, ...parts]);
  }

  static bool _isSafeId(String id) => RegExp(r'^[A-Za-z0-9_-]+$').hasMatch(id);

  static Future<void> _deleteIfExists(File file) async {
    try {
      await file.delete();
    } on PathNotFoundException {
      // Already gone.
    }
  }
}
