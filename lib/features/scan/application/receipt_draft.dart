import 'package:flutter/foundation.dart';

import '../../../core/date/local_date.dart';
import '../../../core/db/app_database.dart';

/// The values the review screen edits and [ReceiptRepository] saves: a new
/// scan, a manual entry, or an edit of an existing receipt. Amounts are
/// integer minor units of [currency].
@immutable
class ReceiptDraft {
  const ReceiptDraft({
    required this.currency,
    required this.extractionMethod,
    this.id,
    this.merchant = '',
    this.date,
    this.totalMinor,
    this.subtotalMinor,
    this.taxMinor,
    this.tipMinor,
    this.paymentMethod,
    this.categoryId,
    this.notes = '',
    this.sourceImagePath,
    this.imagePath,
    this.rawOcrText,
    this.confidence,
  });

  /// Set when editing an existing receipt; `null` for a new one.
  final String? id;
  final String merchant;
  final LocalDate? date;
  final int? totalMinor;
  final int? subtotalMinor;
  final int? taxMinor;
  final int? tipMinor;

  /// ISO 4217 code.
  final String currency;
  final PaymentMethod? paymentMethod;
  final int? categoryId;
  final String notes;

  /// Absolute path of a new scan (the scanner's temporary JPEG). Saving
  /// imports it into app storage.
  final String? sourceImagePath;

  /// Stored image of an existing receipt, relative to the app support
  /// directory (`receipts/<id>.jpg`).
  final String? imagePath;
  final String? rawOcrText;
  final ExtractionMethod extractionMethod;

  /// Overall parser confidence, 0..1.
  final double? confidence;

  bool get isNew => id == null;

  /// Merchant, date and a total are required before saving.
  bool get isComplete =>
      merchant.trim().isNotEmpty && date != null && totalMinor != null;

  ReceiptDraft copyWith({
    String? merchant,
    LocalDate? date,
    int? totalMinor,
    int? subtotalMinor,
    int? taxMinor,
    int? tipMinor,
    String? currency,
    PaymentMethod? paymentMethod,
    int? categoryId,
    String? notes,
    bool clearSubtotal = false,
    bool clearTax = false,
    bool clearTip = false,
    bool clearPaymentMethod = false,
    bool clearCategory = false,
  }) => ReceiptDraft(
    id: id,
    merchant: merchant ?? this.merchant,
    date: date ?? this.date,
    totalMinor: totalMinor ?? this.totalMinor,
    subtotalMinor: clearSubtotal ? null : subtotalMinor ?? this.subtotalMinor,
    taxMinor: clearTax ? null : taxMinor ?? this.taxMinor,
    tipMinor: clearTip ? null : tipMinor ?? this.tipMinor,
    currency: currency ?? this.currency,
    paymentMethod: clearPaymentMethod
        ? null
        : paymentMethod ?? this.paymentMethod,
    categoryId: clearCategory ? null : categoryId ?? this.categoryId,
    notes: notes ?? this.notes,
    sourceImagePath: sourceImagePath,
    imagePath: imagePath,
    rawOcrText: rawOcrText,
    extractionMethod: extractionMethod,
    confidence: confidence,
  );

  @override
  bool operator ==(Object other) =>
      other is ReceiptDraft &&
      other.id == id &&
      other.merchant == merchant &&
      other.date == date &&
      other.totalMinor == totalMinor &&
      other.subtotalMinor == subtotalMinor &&
      other.taxMinor == taxMinor &&
      other.tipMinor == tipMinor &&
      other.currency == currency &&
      other.paymentMethod == paymentMethod &&
      other.categoryId == categoryId &&
      other.notes == notes &&
      other.sourceImagePath == sourceImagePath &&
      other.imagePath == imagePath &&
      other.rawOcrText == rawOcrText &&
      other.extractionMethod == extractionMethod &&
      other.confidence == confidence;

  @override
  int get hashCode => Object.hash(
    id,
    merchant,
    date,
    totalMinor,
    subtotalMinor,
    taxMinor,
    tipMinor,
    currency,
    paymentMethod,
    categoryId,
    notes,
    sourceImagePath,
    imagePath,
    rawOcrText,
    extractionMethod,
    confidence,
  );
}
