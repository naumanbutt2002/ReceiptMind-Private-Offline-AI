import 'dart:io';

import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../l10n/generated/app_localizations.dart';
import 'review_keys.dart';

/// The receipt photo beside (or above) the review form: pinch to zoom, tap
/// (or the corner button) to open it full screen.
class ReviewPhoto extends StatelessWidget {
  const ReviewPhoto({required this.path, super.key});

  /// Absolute path of the JPEG.
  final String path;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    void open() => openReceiptPhotoViewer(context, path);

    return ClipRRect(
      key: ReviewKeys.photo,
      borderRadius: BorderRadius.circular(12),
      child: ColoredBox(
        color: scheme.surfaceContainerHighest,
        child: Stack(
          fit: StackFit.expand,
          children: [
            Semantics(
              label: l10n.reviewPhotoLabel,
              hint: l10n.reviewPhotoHint,
              image: true,
              excludeSemantics: true,
              onTap: open,
              child: GestureDetector(
                onTap: open,
                child: ReceiptImageView(
                  image: FileImage(File(path)),
                  maxScale: 5,
                  minWidthFactor: previewMinWidthFactor,
                ),
              ),
            ),
            PositionedDirectional(
              end: 4,
              bottom: 4,
              child: IconButton.filledTonal(
                key: ReviewKeys.photoFullScreenButton,
                tooltip: l10n.reviewPhotoFullScreen,
                icon: const Icon(Icons.open_in_full),
                onPressed: open,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Shows the photo at [path] full screen on the root navigator (above the
/// bottom navigation), with zoom and pan.
Future<void> openReceiptPhotoViewer(BuildContext context, String path) =>
    Navigator.of(context, rootNavigator: true).push(
      MaterialPageRoute<void>(
        fullscreenDialog: true,
        builder: (context) => ReceiptPhotoViewer(path: path),
      ),
    );

/// A full-screen, zoomable receipt photo.
class ReceiptPhotoViewer extends StatelessWidget {
  const ReceiptPhotoViewer({required this.path, super.key});

  final String path;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      key: ReviewKeys.photoViewer,
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: Text(l10n.reviewPhotoLabel),
        leading: const CloseButton(),
      ),
      body: SafeArea(
        child: Semantics(
          label: l10n.reviewPhotoLabel,
          image: true,
          excludeSemantics: true,
          child: ReceiptImageView(
            image: FileImage(File(path)),
            maxScale: 8,
            minWidthFactor: viewerMinWidthFactor,
          ),
        ),
      ),
    );
  }
}

/// In the review form a photo is drawn at least half as wide as its box.
const previewMinWidthFactor = 0.5;

/// Full screen, a photo is drawn at least 60 % as wide as the screen.
const viewerMinWidthFactor = 0.6;

/// The size to draw an image of [image] pixels in a [box]: scaled to fit
/// (`BoxFit.contain`), but never narrower than [minWidthFactor] × the box
/// width. A long receipt (say 1000 × 6000 px) would otherwise shrink to an
/// unreadable strip; it is drawn wider and taller than the box instead, and
/// the user pans down to read it.
@visibleForTesting
Size receiptImageExtent(
  Size box,
  Size image, {
  required double minWidthFactor,
}) {
  if (image.isEmpty || box.isEmpty || !box.isFinite) return box;
  final scale = math.min(box.width / image.width, box.height / image.height);
  final contained = image * scale;
  final minWidth = box.width * minWidthFactor.clamp(0, 1);
  if (contained.width >= minWidth) return contained;
  return Size(minWidth, minWidth * image.height / image.width);
}

/// A zoomable receipt image. A long receipt starts at the top, drawn at least
/// [minWidthFactor] of the box wide (see [receiptImageExtent]), and pans
/// vertically; other images fit the box.
class ReceiptImageView extends StatefulWidget {
  const ReceiptImageView({
    required this.image,
    required this.maxScale,
    required this.minWidthFactor,
    super.key,
  });

  final ImageProvider image;
  final double maxScale;
  final double minWidthFactor;

  @override
  State<ReceiptImageView> createState() => _ReceiptImageViewState();
}

class _ReceiptImageViewState extends State<ReceiptImageView> {
  ImageStream? _stream;
  late final _listener = ImageStreamListener(_onImage, onError: _onError);

  /// The image's pixel size once it is decoded. The [Image] below shares the
  /// same cache entry, so this costs no extra decode.
  Size? _imageSize;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _resolve();
  }

  @override
  void didUpdateWidget(ReceiptImageView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.image != widget.image) {
      _imageSize = null;
      _resolve();
    }
  }

  @override
  void dispose() {
    _stream?.removeListener(_listener);
    super.dispose();
  }

  void _resolve() {
    final stream = widget.image.resolve(createLocalImageConfiguration(context));
    if (stream.key == _stream?.key) return;
    _stream?.removeListener(_listener);
    _stream = stream..addListener(_listener);
  }

  void _onImage(ImageInfo info, bool synchronousCall) {
    final size = Size(
      info.image.width.toDouble(),
      info.image.height.toDouble(),
    );
    info.dispose();
    if (!mounted || size == _imageSize) return;
    setState(() => _imageSize = size);
  }

  void _onError(Object error, StackTrace? stackTrace) {
    // The Image below shows the error.
  }

  @override
  Widget build(BuildContext context) {
    final image = _ReceiptImage(image: widget.image);
    return LayoutBuilder(
      builder: (context, constraints) {
        final box = constraints.biggest;
        final imageSize = _imageSize;
        if (imageSize != null && box.isFinite) {
          final extent = receiptImageExtent(
            box,
            imageSize,
            minWidthFactor: widget.minWidthFactor,
          );
          if (extent.height > box.height + 0.5) {
            // Long receipt: as wide as the box, top first.
            return InteractiveViewer(
              constrained: false,
              maxScale: widget.maxScale,
              child: SizedBox(
                width: box.width,
                height: extent.height,
                child: image,
              ),
            );
          }
        }
        return InteractiveViewer(
          maxScale: widget.maxScale,
          child: SizedBox.expand(child: image),
        );
      },
    );
  }
}

class _ReceiptImage extends StatelessWidget {
  const _ReceiptImage({required this.image});

  final ImageProvider image;

  @override
  Widget build(BuildContext context) => Image(
    image: image,
    fit: BoxFit.contain,
    gaplessPlayback: true,
    excludeFromSemantics: true,
    errorBuilder: (context, error, stackTrace) {
      final scheme = Theme.of(context).colorScheme;
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.broken_image_outlined, color: scheme.onSurfaceVariant),
              const SizedBox(height: 8),
              // A short photo box at 200 % text has no room for every line:
              // clip the message instead of overflowing.
              Flexible(
                child: Text(
                  AppLocalizations.of(context).reviewPhotoUnavailable,
                  textAlign: TextAlign.center,
                  overflow: TextOverflow.ellipsis,
                  maxLines: 4,
                  style: TextStyle(color: scheme.onSurfaceVariant),
                ),
              ),
            ],
          ),
        ),
      );
    },
  );
}
