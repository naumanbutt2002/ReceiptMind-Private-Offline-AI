import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/clock.dart';
import '../../core/date/local_date.dart';
import '../../core/db/app_database.dart';
import '../../core/db/db_providers.dart';
import '../receipts/data/receipts_providers.dart';
import 'csv_exporter.dart';

part 'export_service.g.dart';

/// Loads the receipts to export; both bounds are inclusive and optional.
typedef ReceiptLoader = Future<List<ReceiptRow>> Function({
  LocalDate? from,
  LocalDate? to,
});

/// Hands a file to the platform share sheet. Tests use a fake.
abstract interface class FileSharer {
  Future<void> shareFile(
    String path, {
    required String mimeType,
    String? subject,
  });
}

/// [FileSharer] backed by `share_plus`.
final class SharePlusFileSharer implements FileSharer {
  const SharePlusFileSharer();

  @override
  Future<void> shareFile(
    String path, {
    required String mimeType,
    String? subject,
  }) async {
    await SharePlus.instance.share(
      ShareParams(
        files: [XFile(path, mimeType: mimeType)],
        subject: subject,
      ),
    );
  }
}

/// What an export did.
final class ExportResult {
  const ExportResult({required this.receiptCount, this.file});

  /// Nothing matched, so no file was written or shared.
  const ExportResult.empty() : receiptCount = 0, file = null;

  final int receiptCount;

  /// The CSV file that was shared, or `null` when there was nothing to export.
  final File? file;

  bool get isEmpty => receiptCount == 0;
}

/// Writes receipts to `receiptmind-export-<yyyymmdd>.csv` (with `-2`, `-3`,
/// … for later exports the same day) in the temp directory and opens the
/// share sheet. Nothing is uploaded: the user picks
/// where the file goes.
class ExportService {
  ExportService({
    required this._loadReceipts,
    required this._loadCategoryNames,
    required this._tempDirectory,
    required this._sharer,
    DateTime Function()? clock,
  }) : _clock = clock ?? DateTime.now;

  static const mimeType = 'text/csv';

  final ReceiptLoader _loadReceipts;
  final Future<Map<int, String>> Function() _loadCategoryNames;
  final Future<Directory> Function() _tempDirectory;
  final FileSharer _sharer;
  final DateTime Function() _clock;

  /// Exports receipts dated [from]..[to] (inclusive; `null` = open-ended).
  /// Returns [ExportResult.empty] without writing a file when none match.
  Future<ExportResult> exportCsv({
    LocalDate? from,
    LocalDate? to,
    String? shareSubject,
  }) async {
    final receipts = await _loadReceipts(from: from, to: to);
    if (receipts.isEmpty) return const ExportResult.empty();

    final bytes = CsvExporter.toBytes(
      receipts,
      categoryNames: await _loadCategoryNames(),
    );
    final file = await _newFile(await _tempDirectory(), fileNameFor(_clock()));
    await file.writeAsBytes(bytes, flush: true);
    await _sharer.shareFile(
      file.path,
      mimeType: mimeType,
      subject: shareSubject,
    );
    return ExportResult(receiptCount: receipts.length, file: file);
  }

  /// A file in [dir] named [name], or `name-2.csv`, `name-3.csv`, … when an
  /// earlier export today still exists (a share target may still be reading
  /// it, so it is never overwritten).
  static Future<File> _newFile(Directory dir, String name) async {
    final base = p.basenameWithoutExtension(name);
    final extension = p.extension(name);
    var file = File(p.join(dir.path, name));
    for (var n = 2; await file.exists(); n++) {
      file = File(p.join(dir.path, '$base-$n$extension'));
    }
    return file;
  }

  /// `receiptmind-export-20261116.csv` for the given day.
  static String fileNameFor(DateTime now) {
    final y = now.year.toString().padLeft(4, '0');
    final m = now.month.toString().padLeft(2, '0');
    final d = now.day.toString().padLeft(2, '0');
    return 'receiptmind-export-$y$m$d.csv';
  }
}

@Riverpod(keepAlive: true)
FileSharer fileSharer(Ref ref) => const SharePlusFileSharer();

@riverpod
ExportService exportService(Ref ref) {
  final categories = ref.watch(categoriesDaoProvider);
  return ExportService(
    loadReceipts: ref.watch(receiptRepositoryProvider).receiptsBetween,
    loadCategoryNames: () async => {
      for (final c in await categories.watchAll().first) c.id: c.name,
    },
    tempDirectory: getTemporaryDirectory,
    sharer: ref.watch(fileSharerProvider),
    clock: ref.watch(clockProvider),
  );
}
