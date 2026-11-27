import 'dart:ui';

import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:share_plus/share_plus.dart';

part 'receipt_photo_sharer.g.dart';

/// Hands a receipt photo to the system share sheet. Only ever called when the
/// user taps "Share photo"; nothing is sent anywhere by the app itself.
abstract interface class ReceiptPhotoSharer {
  /// Shares the JPEG at [absolutePath]. [origin] anchors the share popover on
  /// iPad.
  Future<void> sharePhoto(String absolutePath, {Rect? origin});
}

/// [ReceiptPhotoSharer] backed by `share_plus`.
final class SharePlusReceiptPhotoSharer implements ReceiptPhotoSharer {
  const SharePlusReceiptPhotoSharer();

  @override
  Future<void> sharePhoto(String absolutePath, {Rect? origin}) async {
    await SharePlus.instance.share(
      ShareParams(
        files: [XFile(absolutePath, mimeType: 'image/jpeg')],
        sharePositionOrigin: origin,
      ),
    );
  }
}

@Riverpod(keepAlive: true)
ReceiptPhotoSharer receiptPhotoSharer(Ref ref) =>
    const SharePlusReceiptPhotoSharer();
