import 'package:cunning_document_scanner/cunning_document_scanner.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:receipt_mind/features/scan/capture/cunning_document_scanner_impl.dart';
import 'package:receipt_mind/features/scan/capture/document_scanner.dart';

/// Records the plugin call and answers with [result] or throws [error].
final class _FakePlugin {
  _FakePlugin({this.result, this.error});

  final List<String>? result;
  final Object? error;

  int calls = 0;
  int? noOfPages;
  ScannerSource? scannerSource;
  IosScannerOptions? iosScannerOptions;

  Future<List<String>?> getPictures({
    required int noOfPages,
    required ScannerSource scannerSource,
    required IosScannerOptions iosScannerOptions,
  }) async {
    calls++;
    this.noOfPages = noOfPages;
    this.scannerSource = scannerSource;
    this.iosScannerOptions = iosScannerOptions;
    if (error case final error?) throw error;
    return result;
  }
}

CunningDocumentScannerImpl _scanner(
  _FakePlugin plugin, {
  TargetPlatform platform = TargetPlatform.android,
}) => CunningDocumentScannerImpl(
  getPictures: plugin.getPictures,
  cleanCache: () async {},
  platform: platform,
);

TypeMatcher<ScanFailure> _failure(ScanFailureReason reason) =>
    isA<ScanFailure>().having((f) => f.reason, 'reason', reason);

void main() {
  group('scan', () {
    test('returns the first path', () async {
      final plugin = _FakePlugin(result: ['/cache/a.jpg', '/cache/b.jpg']);

      expect(await _scanner(plugin).scan(ScanSource.camera), '/cache/a.jpg');
      expect(plugin.noOfPages, 1);
      expect(plugin.iosScannerOptions!.imageFormat, IosImageFormat.jpg);
      expect(plugin.iosScannerOptions!.jpgCompressionQuality, 0.9);
    });

    test('returns null when the user cancels', () async {
      expect(await _scanner(_FakePlugin()).scan(ScanSource.camera), isNull);
    });

    test('returns null for an empty list', () async {
      final plugin = _FakePlugin(result: const []);
      expect(await _scanner(plugin).scan(ScanSource.gallery), isNull);
    });

    test('camera on Android allows gallery import from the scanner', () async {
      final plugin = _FakePlugin(result: ['/a.jpg']);
      await _scanner(plugin).scan(ScanSource.camera);
      expect(plugin.scannerSource, ScannerSource.cameraAndGallery);
    });

    test('camera on iOS opens the camera directly', () async {
      final plugin = _FakePlugin(result: ['/a.jpg']);
      await _scanner(
        plugin,
        platform: TargetPlatform.iOS,
      ).scan(ScanSource.camera);
      expect(plugin.scannerSource, ScannerSource.camera);
    });

    test('gallery opens the gallery picker', () async {
      for (final platform in [TargetPlatform.android, TargetPlatform.iOS]) {
        final plugin = _FakePlugin(result: ['/a.jpg']);
        await _scanner(plugin, platform: platform).scan(ScanSource.gallery);
        expect(plugin.scannerSource, ScannerSource.gallery);
      }
    });
  });

  group('failure mapping', () {
    Future<void> expectFailure(Object error, ScanFailureReason reason) =>
        expectLater(
          _scanner(_FakePlugin(error: error)).scan(ScanSource.camera),
          throwsA(_failure(reason)),
        );

    test('permission_denied → permissionDenied', () async {
      await expectFailure(
        const CunningDocumentScannerException.permissionDenied(),
        ScanFailureReason.permissionDenied,
      );
      await expectFailure(
        const CunningDocumentScannerException(
          'Camera',
          code: 'PERMISSION_DENIED',
        ),
        ScanFailureReason.permissionDenied,
      );
    });

    test('UNAVAILABLE → unavailable', () async {
      await expectFailure(
        const CunningDocumentScannerException(
          'Document camera is not available on this device',
          code: 'UNAVAILABLE',
        ),
        ScanFailureReason.unavailable,
      );
    });

    test('a missing plugin → unavailable', () async {
      await expectFailure(
        MissingPluginException('No implementation found'),
        ScanFailureReason.unavailable,
      );
    });

    test('other codes → other, with code and message kept', () async {
      for (final code in [
        'ERROR',
        'ALREADY_ACTIVE',
        'NO_ACTIVITY',
        'NO_VIEW_CONTROLLER',
        null,
      ]) {
        await expectLater(
          _scanner(
            _FakePlugin(
              error: CunningDocumentScannerException('boom', code: code),
            ),
          ).scan(ScanSource.camera),
          throwsA(
            _failure(ScanFailureReason.other).having(
              (f) => f.message,
              'message',
              code == null ? 'boom' : '$code: boom',
            ),
          ),
        );
      }
    });

    test('a raw PlatformException is mapped too', () async {
      await expectFailure(
        PlatformException(code: 'permission_denied'),
        ScanFailureReason.permissionDenied,
      );
      await expectFailure(
        PlatformException(code: 'ERROR', message: 'x'),
        ScanFailureReason.other,
      );
    });
  });

  group('cleanCache', () {
    test('calls the plugin', () async {
      var calls = 0;
      final scanner = CunningDocumentScannerImpl(
        getPictures: _FakePlugin().getPictures,
        cleanCache: () async => calls++,
      );
      await scanner.cleanCache();
      expect(calls, 1);
    });

    test('swallows failures', () async {
      for (final error in <Object>[
        const CunningDocumentScannerException('io', code: 'CLEAN_CACHE_ERROR'),
        PlatformException(code: 'NO_CONTEXT'),
        MissingPluginException(),
        StateError('anything'),
      ]) {
        final scanner = CunningDocumentScannerImpl(
          getPictures: _FakePlugin().getPictures,
          cleanCache: () async => throw error,
        );
        await expectLater(scanner.cleanCache(), completes);
      }
    });
  });
}
