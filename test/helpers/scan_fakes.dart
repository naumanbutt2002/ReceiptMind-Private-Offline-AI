import 'dart:async';

import 'package:receipt_mind/features/receipts/data/receipt_repository.dart';
import 'package:receipt_mind/features/scan/application/receipt_draft.dart';
import 'package:receipt_mind/features/scan/capture/document_scanner.dart';
import 'package:receipt_mind/features/scan/ocr/ocr_engine.dart';

/// A GST-inclusive Australian receipt as plain OCR text. Parsed with
/// `defaultCurrency: 'AUD'`, `dateOrder: dmy` and a "today" after
/// 2026-09-12 it gives: merchant "Freshway Market", date 2026-09-12, total
/// 10870, subtotal 10870, tax 988, card payment.
const auReceiptText = r'''FRESHWAY MARKET
123 George St, Sydney NSW 2000
Ph (02) 9555 0123
ABN 12 345 678 901
TAX INVOICE
12/09/2026 14:32 Reg 3 Trn 4821
Bananas 1kg 3.90
Full Cream Milk 2L 3.60
Sourdough Loaf 6.50
Coffee Beans 1kg 24.00
Olive Oil 750ml 11.00
Chicken Thigh Fillet 1kg 12.90
Cheddar Block 500g 8.00
Greek Yoghurt 1kg 6.80
Free Range Eggs 12pk 7.20
Basmati Rice 2kg 6.40
Penne Pasta 500g 2.20
Tomato Passata 700g 3.00
Baby Spinach 120g 3.50
Dishwashing Liquid 4.50
Paper Towel 2pk 5.20
SUBTOTAL 108.70
Total includes GST 9.88
TOTAL $108.70
VISA CREDIT 108.70
CARD NO: **** **** **** 4821
APPROVED AUTH: 482915
Thank you for shopping with us''';

/// [DocumentScanner] that answers with [path] (`null` = cancelled) or
/// throws [failure]. Set [gate] to hold the answer until it completes.
final class FakeDocumentScanner implements DocumentScanner {
  FakeDocumentScanner({this.path = '/tmp/scan.jpg', this.failure});

  String? path;
  Object? failure;
  Completer<void>? gate;

  final List<ScanSource> calls = [];
  int cleanCacheCalls = 0;

  /// Thrown by [cleanCache] when set.
  Object? cleanCacheError;

  @override
  Future<String?> scan(ScanSource source) async {
    calls.add(source);
    if (gate case final gate?) await gate.future;
    if (failure case final failure?) throw failure;
    return path;
  }

  @override
  Future<void> cleanCache() async {
    cleanCacheCalls++;
    if (cleanCacheError case final error?) throw error;
  }
}

/// [OcrEngine] that returns [document] or throws [error]. Set [gate] to
/// hold the answer until it completes.
final class FakeOcrEngine implements OcrEngine {
  FakeOcrEngine({OcrDocument? document, this.error})
    : document = document ?? OcrDocument.fromPlainText(auReceiptText);

  OcrDocument document;
  Object? error;
  Completer<void>? gate;

  final List<String> calls = [];
  bool disposed = false;

  @override
  String get id => 'fake';

  @override
  Future<OcrDocument> recognize(String imagePath) async {
    calls.add(imagePath);
    if (gate case final gate?) await gate.future;
    if (error case final error?) throw error;
    return document;
  }

  @override
  Future<void> dispose() async => disposed = true;
}

/// [ReceiptRepository] that records drafts instead of writing a database.
/// Only [createFromDraft] and [update] are implemented.
final class FakeReceiptRepository implements ReceiptRepository {
  final List<ReceiptDraft> created = [];
  final List<ReceiptDraft> updated = [];

  /// Thrown by [createFromDraft] and [update] when set.
  Object? error;

  @override
  Future<String> createFromDraft(ReceiptDraft draft) async {
    if (error case final error?) throw error;
    created.add(draft);
    return 'receipt-${created.length}';
  }

  @override
  Future<void> update(ReceiptDraft draft) async {
    if (error case final error?) throw error;
    updated.add(draft);
  }

  @override
  Object? noSuchMethod(Invocation invocation) => throw UnimplementedError(
    'FakeReceiptRepository.${invocation.memberName}',
  );
}
