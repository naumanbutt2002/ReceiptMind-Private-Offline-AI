import 'package:flutter/foundation.dart';
import 'package:receipt_parser/receipt_parser.dart';

import '../capture/document_scanner.dart';
import 'receipt_draft.dart';

/// Where the scan flow is: `idle → capturing → reading → review | failed`.
/// A cancelled scan goes back to [ScanIdle].
@immutable
sealed class ScanState {
  const ScanState();
}

final class ScanIdle extends ScanState {
  const ScanIdle();
}

/// The document scanner is open.
final class ScanCapturing extends ScanState {
  const ScanCapturing(this.source);

  final ScanSource source;
}

/// OCR and parsing are running on the scanned image.
final class ScanReading extends ScanState {
  const ScanReading(this.imagePath);

  final String imagePath;
}

/// Ready for the review screen.
final class ScanReview extends ScanState {
  const ScanReview(this.data);

  final ReviewData data;
}

/// The scanner could not run (permission denied, unavailable, …).
final class ScanFailed extends ScanState {
  const ScanFailed(this.failure);

  final ScanFailure failure;
}

/// Everything the review screen needs about a new scan.
@immutable
class ReviewData {
  const ReviewData({
    required this.draft,
    this.warnings = const {},
    this.ocrFailed = false,
    this.document,
    this.parsed,
    this.issues = const [],
  });

  /// Pre-filled values; `sourceImagePath` points at the scanned JPEG.
  final ReceiptDraft draft;

  /// Fields to flag with ⚠️ and why (low confidence or a validator issue).
  final Map<ReceiptField, List<IssueCode>> warnings;

  /// OCR failed or found no text: the form is empty and shows a banner, the
  /// photo is still kept.
  final bool ocrFailed;

  /// The OCR result and parser output, for "View recognised text" and the
  /// developer screen (M7).
  final OcrDocument? document;
  final ParsedReceipt? parsed;
  final List<ValidationIssue> issues;

  bool isFlagged(ReceiptField field) => warnings[field]?.isNotEmpty ?? false;
}
