import 'dart:developer' as developer;

import 'package:cunning_document_scanner/cunning_document_scanner.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'document_scanner.dart';

/// Signature of [CunningDocumentScanner.getPictures], as far as the app uses
/// it. Lets tests replace the static plugin call.
typedef GetPicturesFn = Future<List<String>?> Function({
  required int noOfPages,
  required ScannerSource scannerSource,
  required IosScannerOptions iosScannerOptions,
});

/// Signature of [CunningDocumentScanner.cleanCache].
typedef CleanCacheFn = Future<void> Function();

/// [DocumentScanner] backed by `cunning_document_scanner`: the ML Kit
/// document scanner on Android (with a built-in cropper as the fallback) and
/// VisionKit on iOS.
final class CunningDocumentScannerImpl implements DocumentScanner {
  CunningDocumentScannerImpl({
    GetPicturesFn? getPictures,
    CleanCacheFn? cleanCache,
    this._platform,
  }) : _getPictures = getPictures ?? _pluginGetPictures,
       _cleanCache = cleanCache ?? CunningDocumentScanner.cleanCache;

  final GetPicturesFn _getPictures;
  final CleanCacheFn _cleanCache;

  /// Overrides [defaultTargetPlatform] in tests.
  final TargetPlatform? _platform;

  @override
  Future<String?> scan(ScanSource source) async {
    final List<String>? paths;
    try {
      paths = await _getPictures(
        noOfPages: 1,
        scannerSource: _scannerSource(source),
        // iOS writes PNG by default; JPEG keeps the temp file small and is
        // what the image store expects.
        iosScannerOptions: IosScannerOptions(
          imageFormat: IosImageFormat.jpg,
          jpgCompressionQuality: 0.9,
        ),
      );
    } on CunningDocumentScannerException catch (e) {
      throw scanFailureFromCode(e.code, e.message);
    } on PlatformException catch (e) {
      throw scanFailureFromCode(e.code, e.message);
    } on MissingPluginException catch (e) {
      throw ScanFailure(ScanFailureReason.unavailable, e.message);
    }
    if (paths == null || paths.isEmpty) return null;
    return paths.first;
  }

  @override
  Future<void> cleanCache() async {
    try {
      await _cleanCache();
    } on Object catch (e, stackTrace) {
      // Runs at startup: a failure here must never take the app down.
      developer.log(
        'Could not clean the scanner cache',
        name: 'scan',
        error: e,
        stackTrace: stackTrace,
      );
    }
  }

  /// On Android the camera UI gets a gallery shortcut too; on iOS
  /// `cameraAndGallery` would show an extra menu first, so the camera opens
  /// directly.
  ScannerSource _scannerSource(ScanSource source) => switch (source) {
    ScanSource.gallery => ScannerSource.gallery,
    ScanSource.camera =>
      (_platform ?? defaultTargetPlatform) == TargetPlatform.android
          ? ScannerSource.cameraAndGallery
          : ScannerSource.camera,
  };

  /// Maps a plugin error code to a [ScanFailure]. Codes seen in
  /// `cunning_document_scanner` 3.0.3: `permission_denied`, `UNAVAILABLE`
  /// (iOS without VisionKit), `ALREADY_ACTIVE`, `NO_ACTIVITY`,
  /// `NO_VIEW_CONTROLLER`, `NO_CONTEXT` and `ERROR`.
  @visibleForTesting
  static ScanFailure scanFailureFromCode(String? code, String? message) {
    final reason = switch (code?.toLowerCase()) {
      'permission_denied' => ScanFailureReason.permissionDenied,
      'unavailable' => ScanFailureReason.unavailable,
      _ => ScanFailureReason.other,
    };
    final details = [?code, ?message].join(': ');
    return ScanFailure(reason, details.isEmpty ? null : details);
  }

  static Future<List<String>?> _pluginGetPictures({
    required int noOfPages,
    required ScannerSource scannerSource,
    required IosScannerOptions iosScannerOptions,
  }) => CunningDocumentScanner.getPictures(
    noOfPages: noOfPages,
    scannerSource: scannerSource,
    iosScannerOptions: iosScannerOptions,
  );
}
