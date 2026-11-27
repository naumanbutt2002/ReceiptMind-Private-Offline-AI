/// Where the scanner takes the receipt from.
enum ScanSource { camera, gallery }

/// Why a scan could not start or finish. A cancelled scan is not a failure:
/// [DocumentScanner.scan] returns `null` for it.
enum ScanFailureReason {
  /// The user denied camera (or photo) access.
  permissionDenied,

  /// No scanner on this device (e.g. the ML Kit module is missing).
  unavailable,

  /// Anything else; [ScanFailure.message] has the details for logs.
  other,
}

final class ScanFailure implements Exception {
  const ScanFailure(this.reason, [this.message]);

  final ScanFailureReason reason;
  final String? message;

  @override
  String toString() =>
      'ScanFailure(${reason.name}${message == null ? '' : ': $message'})';
}

/// Takes one receipt photo with edge detection and cropping. Implemented with
/// `cunning_document_scanner`; tests use a fake.
abstract interface class DocumentScanner {
  /// Absolute path of the scanned JPEG (a temporary file owned by the
  /// scanner), or `null` when the user cancelled. Throws [ScanFailure].
  Future<String?> scan(ScanSource source);

  /// Deletes the scanner's temporary files.
  Future<void> cleanCache();
}
