import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../application/receipt_list_providers.dart';
import '../../data/receipts_providers.dart';

/// Hero tag shared by a receipt's list thumbnail and its detail photo.
String receiptHeroTag(String receiptId) => 'receipt-photo-$receiptId';

/// A square thumbnail of a receipt photo. Shows a placeholder icon while the
/// file loads, when the receipt has no photo, or when the file is missing.
///
/// The decoded image is only as large as it is drawn (`cacheWidth`), and the
/// resolved path is cached in [resolvedImagePathProvider], so long lists
/// scroll without re-reading paths or decoding full-size images.
class ReceiptThumbnail extends ConsumerWidget {
  const ReceiptThumbnail({super.key, required this.imagePath, this.size = 56});

  /// The receipt's stored (relative) image path, or `null` for no photo.
  final String? imagePath;
  final double size;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final path = imagePath;
    if (path == null) {
      return _Placeholder(size: size, icon: Icons.receipt_long_outlined);
    }
    final thumb = ref.watch(receiptImageStoreProvider).thumbnailFor(path);
    final absolute = ref.watch(resolvedImagePathProvider(thumb)).value;
    final placeholder = _Placeholder(size: size, icon: Icons.image_outlined);
    if (absolute == null) return placeholder;
    final pixels = (size * MediaQuery.devicePixelRatioOf(context)).round();
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: Image.file(
        File(absolute),
        width: size,
        height: size,
        fit: BoxFit.cover,
        cacheWidth: pixels,
        gaplessPlayback: true,
        excludeFromSemantics: true,
        frameBuilder: (context, child, frame, wasSynchronouslyLoaded) =>
            frame == null && !wasSynchronouslyLoaded ? placeholder : child,
        errorBuilder: (context, error, stackTrace) =>
            _Placeholder(size: size, icon: Icons.broken_image_outlined),
      ),
    );
  }
}

class _Placeholder extends StatelessWidget {
  const _Placeholder({required this.size, required this.icon});

  final double size;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
      ),
      alignment: Alignment.center,
      child: Icon(icon, size: size * 0.5, color: scheme.onSurfaceVariant),
    );
  }
}
