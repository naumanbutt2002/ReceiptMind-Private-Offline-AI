import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

import '../../../core/date/local_date.dart';
import '../../../core/db/app_database.dart';
import '../../../core/db/daos/receipts_dao.dart';
import '../../scan/application/receipt_draft.dart';
import 'receipt_image_store.dart';
import 'receipt_storage_exception.dart';

/// Saves and loads receipts: the database row plus the stored photo.
///
/// Deleting a receipt removes only the row. Its image files stay until
/// [ReceiptImageStore.deleteOrphans] runs at the next start, so "Undo"
/// ([restore]) needs no file work.
class ReceiptRepository {
  ReceiptRepository(
    this._dao,
    this._images, {
    this._clock = DateTime.now,
    this._newId = _uuidV7,
  });

  final ReceiptsDao _dao;
  final ReceiptImageStore _images;
  final DateTime Function() _clock;
  final String Function() _newId;

  static String _uuidV7() => const Uuid().v7();

  /// Longest merchant name the database accepts (UTF-16 code units).
  static const merchantMaxLength = 200;

  /// Saves a new receipt and returns its id.
  ///
  /// If the draft has a [ReceiptDraft.sourceImagePath], the scan is imported
  /// first; if the row can't be inserted, the imported files are deleted and
  /// the error is rethrown. A failed import, or a full disk, throws
  /// [ReceiptStorageException]. Throws [ArgumentError] for an incomplete
  /// draft or one that already has an id.
  Future<String> createFromDraft(ReceiptDraft draft) async {
    _checkComplete(draft);
    if (!draft.isNew) {
      throw ArgumentError.value(draft.id, 'draft.id', 'Use update()');
    }
    final id = _newId();
    final source = draft.sourceImagePath;
    final stored = source == null
        ? null
        : await _images.importScan(source, id: id);
    final now = _clock();
    try {
      await _dao.transaction(
        () => _dao.insertReceipt(
          ReceiptsCompanion.insert(
            id: id,
            merchant: _merchant(draft.merchant),
            purchaseDate: draft.date!,
            totalMinor: draft.totalMinor!,
            subtotalMinor: Value(draft.subtotalMinor),
            taxMinor: Value(draft.taxMinor),
            tipMinor: Value(draft.tipMinor),
            currency: draft.currency,
            paymentMethod: Value(draft.paymentMethod),
            categoryId: Value(draft.categoryId),
            notes: Value(_notes(draft.notes)),
            imagePath: Value(stored?.image ?? draft.imagePath),
            rawOcrText: Value(draft.rawOcrText),
            extractionMethod: draft.extractionMethod,
            confidence: Value(draft.confidence),
            createdAt: now,
            updatedAt: now,
          ),
        ),
      );
    } catch (error, stackTrace) {
      if (stored != null) await _deleteQuietly(stored.image);
      _rethrow(error, stackTrace);
    }
    return id;
  }

  /// Saves an edited receipt ([ReceiptDraft.id] is required). Keeps
  /// `createdAt`.
  ///
  /// The photo changes only when the draft has a new
  /// [ReceiptDraft.sourceImagePath]: it is imported under a fresh file name,
  /// and the previous files are deleted once the row is updated (or the new
  /// files, if the update fails). [ReceiptDraft.imagePath] is ignored.
  /// Throws [StateError] if the receipt no longer exists, and
  /// [ReceiptStorageException] if the import fails or the disk is full.
  Future<void> update(ReceiptDraft draft) async {
    _checkComplete(draft);
    final id = draft.id;
    if (id == null) {
      throw ArgumentError.value(null, 'draft.id', 'Use createFromDraft()');
    }
    final source = draft.sourceImagePath;
    final stored = source == null
        ? null
        : await _images.importScan(source, id: _newId());
    final String? previousImage;
    try {
      previousImage = await _dao.transaction(() async {
        final existing = await _dao.getReceipt(id);
        if (existing == null) throw StateError('Receipt $id does not exist');
        final updated = await _dao.updateReceipt(
          existing.copyWith(
            merchant: _merchant(draft.merchant),
            purchaseDate: draft.date!,
            totalMinor: draft.totalMinor!,
            subtotalMinor: Value(draft.subtotalMinor),
            taxMinor: Value(draft.taxMinor),
            tipMinor: Value(draft.tipMinor),
            currency: draft.currency,
            paymentMethod: Value(draft.paymentMethod),
            categoryId: Value(draft.categoryId),
            notes: Value(_notes(draft.notes)),
            imagePath: Value(stored?.image ?? existing.imagePath),
            rawOcrText: Value(draft.rawOcrText),
            extractionMethod: draft.extractionMethod,
            confidence: Value(draft.confidence),
            updatedAt: _clock(),
          ),
        );
        if (!updated) throw StateError('Receipt $id does not exist');
        return existing.imagePath;
      });
    } catch (error, stackTrace) {
      if (stored != null) await _deleteQuietly(stored.image);
      _rethrow(error, stackTrace);
    }
    if (stored != null && previousImage != null) {
      await _deleteQuietly(previousImage);
    }
  }

  /// Deletes the row and returns it for [restore], or `null` if it didn't
  /// exist. The image files are left for orphan cleanup.
  Future<ReceiptRow?> delete(String id) => _dao.deleteReceipt(id);

  /// Re-inserts a row returned by [delete] ("Undo"). If its category was
  /// deleted in the meantime, the receipt comes back uncategorised.
  Future<void> restore(ReceiptRow row) => _dao.restoreReceipt(row);

  /// Receipts newest first, filtered by a search [query] (merchant, notes,
  /// recognised text) and a [categoryId].
  Stream<List<ReceiptRow>> watchReceipts({String? query, int? categoryId}) =>
      _dao.watchReceipts(query: query, categoryId: categoryId);

  /// Totals per currency (minor units) for the month containing [month].
  Stream<Map<String, int>> watchMonthTotals(LocalDate month) =>
      _dao.watchMonthTotals(month);

  Future<ReceiptRow?> getReceipt(String id) => _dao.getReceipt(id);

  /// One receipt; emits `null` once it is deleted.
  Stream<ReceiptRow?> watchReceipt(String id) => _dao.watchReceipt(id);

  /// Receipts purchased between [from] and [to] (inclusive), oldest first.
  Future<List<ReceiptRow>> receiptsBetween({LocalDate? from, LocalDate? to}) =>
      _dao.receiptsBetween(from: from, to: to);

  /// A draft for editing [row] (edit mode of the review screen).
  ReceiptDraft draftFromRow(ReceiptRow row) => ReceiptDraft(
    id: row.id,
    merchant: row.merchant,
    date: row.purchaseDate,
    totalMinor: row.totalMinor,
    subtotalMinor: row.subtotalMinor,
    taxMinor: row.taxMinor,
    tipMinor: row.tipMinor,
    currency: row.currency,
    paymentMethod: row.paymentMethod,
    categoryId: row.categoryId,
    notes: row.notes ?? '',
    imagePath: row.imagePath,
    rawOcrText: row.rawOcrText,
    extractionMethod: row.extractionMethod,
    confidence: row.confidence,
  );

  static void _checkComplete(ReceiptDraft draft) {
    if (!draft.isComplete) {
      throw ArgumentError.value(
        draft,
        'draft',
        'Merchant, date and total are required',
      );
    }
  }

  /// Trimmed, and cut to [merchantMaxLength] so a long OCR line or pasted
  /// text can't fail the insert (the form counts characters, the database
  /// UTF-16 code units). A cut never splits a surrogate pair.
  static String _merchant(String merchant) {
    final trimmed = merchant.trim();
    if (trimmed.length <= merchantMaxLength) return trimmed;
    var end = merchantMaxLength;
    final last = trimmed.codeUnitAt(end - 1);
    if (last >= 0xD800 && last <= 0xDBFF) end--; // high surrogate
    return trimmed.substring(0, end).trimRight();
  }

  /// Rethrows [error], as a [ReceiptStorageException] when the disk is full
  /// so the UI can say so.
  static Never _rethrow(Object error, StackTrace stackTrace) {
    if (error is! ReceiptStorageException &&
        ReceiptStorageException.reasonOf(error) ==
            ReceiptStorageFailure.storageFull) {
      Error.throwWithStackTrace(
        ReceiptStorageException(ReceiptStorageFailure.storageFull, error),
        stackTrace,
      );
    }
    Error.throwWithStackTrace(error, stackTrace);
  }

  static String? _notes(String notes) {
    final trimmed = notes.trim();
    return trimmed.isEmpty ? null : trimmed;
  }

  Future<void> _deleteQuietly(String relativeImagePath) async {
    try {
      await _images.delete(relativeImagePath);
    } catch (e) {
      // Orphan cleanup removes it at the next start.
      debugPrint('ReceiptRepository: could not delete $relativeImagePath: $e');
    }
  }
}
