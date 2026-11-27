import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter_image_compress/flutter_image_compress.dart';

import 'receipt_storage_exception.dart';

/// Pixel size of an encoded image.
typedef ImageSize = ({int width, int height});

/// Reads image sizes and re-encodes images as JPEG. A seam over the
/// `flutter_image_compress` plugin and `dart:ui` so [FileReceiptImageStore]
/// can be tested with a fake.
abstract interface class ImageCompressor {
  /// Width and height of the image at [path], read from its header (no full
  /// decode). The size is after the EXIF orientation is applied.
  Future<ImageSize> readSize(String path);

  /// Re-encodes [sourcePath] as a JPEG at [targetPath] without EXIF, with the
  /// pixels rotated upright. [targetPath] must end in `.jpg`.
  ///
  /// The output is scaled down (never up) by `max(1, min(width / minWidth,
  /// height / minHeight))`, keeping the aspect ratio: the image ends up no
  /// smaller than [minWidth] × [minHeight] on either side. This is how the
  /// plugin scales on Android; on iOS it gives the same result when
  /// `minWidth == minHeight`.
  Future<void> compressJpeg({
    required String sourcePath,
    required String targetPath,
    required int minWidth,
    required int minHeight,
    required int quality,
  });
}

/// Signature of [FlutterImageCompress.compressAndGetFile], as far as
/// [FlutterImageCompressor] uses it. Lets tests replace the static call.
typedef CompressAndGetFileFn = Future<XFile?> Function(
  String path,
  String targetPath, {
  required int minWidth,
  required int minHeight,
  required int quality,
  required CompressFormat format,
  required bool keepExif,
  required bool autoCorrectionAngle,
});

/// The real [ImageCompressor]: `ui.ImageDescriptor` for sizes and
/// `FlutterImageCompress.compressAndGetFile` for encoding.
final class FlutterImageCompressor implements ImageCompressor {
  const FlutterImageCompressor({CompressAndGetFileFn? compressAndGetFile})
    : _compressAndGetFile = compressAndGetFile ?? _pluginCompressAndGetFile;

  final CompressAndGetFileFn _compressAndGetFile;

  @override
  Future<ImageSize> readSize(String path) async {
    final buffer = await ui.ImmutableBuffer.fromFilePath(path);
    try {
      final descriptor = await ui.ImageDescriptor.encoded(buffer);
      try {
        return (width: descriptor.width, height: descriptor.height);
      } finally {
        descriptor.dispose();
      }
    } finally {
      buffer.dispose();
    }
  }

  /// Throws [ReceiptStorageException] when the plugin fails or writes
  /// nothing.
  @override
  Future<void> compressJpeg({
    required String sourcePath,
    required String targetPath,
    required int minWidth,
    required int minHeight,
    required int quality,
  }) async {
    final XFile? result;
    try {
      result = await _compressAndGetFile(
        sourcePath,
        targetPath,
        minWidth: minWidth,
        minHeight: minHeight,
        quality: quality,
        format: CompressFormat.jpeg,
        // EXIF (GPS, camera, time) is dropped, so the pixels must be turned
        // upright first or a camera photo would end up sideways.
        keepExif: false,
        autoCorrectionAngle: true,
      );
    } on CompressError catch (e) {
      throw ReceiptStorageException(_reasonOf(e), e);
    }
    // On Android the plugin reports success with an empty file when the
    // image can't be encoded (e.g. it ran out of memory on every retry).
    final written = File(targetPath);
    if (result == null ||
        !await written.exists() ||
        await written.length() == 0) {
      throw ReceiptStorageException(
        ReceiptStorageFailure.other,
        FileSystemException('The compressed image is empty', targetPath),
      );
    }
  }

  static ReceiptStorageFailure _reasonOf(CompressError error) {
    if (error.code == 'decode_failed' ||
        error.message.contains('does not exist')) {
      return ReceiptStorageFailure.unreadableImage;
    }
    return ReceiptStorageException.reasonOf(error);
  }

  static Future<XFile?> _pluginCompressAndGetFile(
    String path,
    String targetPath, {
    required int minWidth,
    required int minHeight,
    required int quality,
    required CompressFormat format,
    required bool keepExif,
    required bool autoCorrectionAngle,
  }) => FlutterImageCompress.compressAndGetFile(
    path,
    targetPath,
    minWidth: minWidth,
    minHeight: minHeight,
    quality: quality,
    format: format,
    keepExif: keepExif,
    autoCorrectionAngle: autoCorrectionAngle,
  );
}
