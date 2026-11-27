import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:receipt_parser/receipt_parser.dart'
    show IssueCode, ReceiptField;

import '../../../../core/clock.dart';
import '../../../../core/date/local_date.dart';
import '../../../../core/db/app_database.dart';
import '../../../../core/settings/settings_providers.dart';
import '../../../../l10n/generated/app_localizations.dart';
import '../../../scan/application/receipt_draft.dart';
import '../../../scan/application/scan_controller.dart';
import '../../../scan/application/scan_state.dart';
import '../../data/receipts_providers.dart';
import 'review_form.dart';
import 'review_keys.dart';

/// What the review screen is for (PLAN §9).
enum ReviewMode {
  /// A scan just read: the draft comes from `scanControllerProvider`.
  newScan,

  /// An empty receipt without a photo.
  manual,

  /// An existing receipt, loaded by id.
  edit,
}

/// Everything [ReviewForm] starts from, whatever the mode.
@immutable
class ReviewInput {
  const ReviewInput({
    required this.draft,
    this.warnings = const {},
    this.ocrFailed = false,
    this.recognisedText,
    this.photoPath,
  });

  final ReceiptDraft draft;

  /// Fields to flag with ⚠️ and why.
  final Map<ReceiptField, List<IssueCode>> warnings;

  /// Show the "Couldn't read this receipt" banner.
  final bool ocrFailed;

  /// Raw OCR text for "View recognised text"; `null` hides the button.
  final String? recognisedText;

  /// Absolute path of the photo to show; `null` hides the image area.
  final String? photoPath;
}

/// Review and edit a receipt's fields before saving: after a scan, for a
/// manual entry, or to edit a saved receipt.
class ReviewScreen extends ConsumerStatefulWidget {
  const ReviewScreen({required this.mode, this.receiptId, super.key})
    : assert(
        mode != ReviewMode.edit || receiptId != null,
        'Edit mode needs a receiptId',
      );

  final ReviewMode mode;

  /// The receipt to edit ([ReviewMode.edit] only).
  final String? receiptId;

  @override
  ConsumerState<ReviewScreen> createState() => _ReviewScreenState();
}

class _ReviewScreenState extends ConsumerState<ReviewScreen> {
  ReviewInput? _input;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    switch (widget.mode) {
      case ReviewMode.newScan:
        _ready(_newScanInput());
      case ReviewMode.manual:
        _ready(_manualInput());
      case ReviewMode.edit:
        _loadForEdit().then((input) {
          if (mounted) setState(() => _ready(input));
        });
    }
  }

  void _ready(ReviewInput? input) {
    _input = input;
    _loading = false;
    if (input == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _leaveUnavailable());
    }
  }

  /// The snapshot of the scan. Read once: saving or discarding resets the
  /// controller, and the form must not change under the user meanwhile.
  ReviewInput? _newScanInput() {
    final state = ref.read(scanControllerProvider);
    if (state is! ScanReview) return null;
    final data = state.data;
    return ReviewInput(
      draft: data.draft,
      warnings: data.warnings,
      ocrFailed: data.ocrFailed,
      recognisedText: _nonBlank(data.draft.rawOcrText ?? data.document?.text),
      photoPath: data.draft.sourceImagePath,
    );
  }

  ReviewInput _manualInput() {
    final settings = ref.read(settingsControllerProvider);
    final today = LocalDate.fromDateTime(ref.read(clockProvider)());
    return ReviewInput(
      draft: ReceiptDraft(
        currency: settings.defaultCurrency,
        extractionMethod: ExtractionMethod.manual,
        date: today,
      ),
    );
  }

  Future<ReviewInput?> _loadForEdit() async {
    final repository = ref.read(receiptRepositoryProvider);
    final imageStore = ref.read(receiptImageStoreProvider);
    try {
      final row = await repository.getReceipt(widget.receiptId!);
      if (row == null) return null;
      final draft = repository.draftFromRow(row);
      final relative = draft.imagePath;
      String? photo;
      if (relative != null) {
        try {
          photo = await imageStore.resolve(relative);
        } on Object catch (error) {
          debugPrint('ReviewScreen: could not resolve $relative: $error');
        }
      }
      return ReviewInput(
        draft: draft,
        recognisedText: _nonBlank(draft.rawOcrText),
        photoPath: photo,
      );
    } on Object catch (error) {
      debugPrint('ReviewScreen: could not load ${widget.receiptId}: $error');
      return null;
    }
  }

  /// Nothing to review (the scan was lost, e.g. after the app was killed, or
  /// the receipt was deleted): say so briefly and leave.
  void _leaveUnavailable() {
    if (!mounted) return;
    final l10n = AppLocalizations.of(context);
    ScaffoldMessenger.maybeOf(context)?.showSnackBar(
      SnackBar(
        content: Text(
          widget.mode == ReviewMode.edit
              ? l10n.reviewReceiptNotFound
              : l10n.reviewScanUnavailable,
        ),
      ),
    );
    if (widget.mode == ReviewMode.edit && context.canPop()) {
      context.pop();
    } else {
      context.go(reviewReceiptsLocation);
    }
  }

  @override
  Widget build(BuildContext context) {
    final input = _input;
    if (input != null) {
      return ReviewForm(
        mode: widget.mode,
        input: input,
        title: _title(AppLocalizations.of(context)),
      );
    }
    return _Placeholder(
      title: _title(AppLocalizations.of(context)),
      loading: _loading,
      isEdit: widget.mode == ReviewMode.edit,
    );
  }

  String _title(AppLocalizations l10n) => switch (widget.mode) {
    ReviewMode.newScan => l10n.reviewTitleNewScan,
    ReviewMode.manual => l10n.reviewTitleManual,
    ReviewMode.edit => l10n.reviewTitleEdit,
  };
}

/// Where the screen goes after saving a new receipt, or when there is nothing
/// to review.
const reviewReceiptsLocation = '/receipts';

String? _nonBlank(String? text) =>
    text == null || text.trim().isEmpty ? null : text;

/// Shown while an edited receipt loads, or briefly when there is nothing to
/// review.
class _Placeholder extends StatelessWidget {
  const _Placeholder({
    required this.title,
    required this.loading,
    required this.isEdit,
  });

  final String title;
  final bool loading;
  final bool isEdit;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: loading
          ? const Center(
              child: CircularProgressIndicator(key: ReviewKeys.loading),
            )
          : SingleChildScrollView(
              key: ReviewKeys.unavailable,
              padding: const EdgeInsets.all(32),
              child: Column(
                children: [
                  Text(
                    isEdit
                        ? l10n.reviewReceiptNotFound
                        : l10n.reviewScanUnavailable,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  FilledButton(
                    onPressed: () => context.go(reviewReceiptsLocation),
                    child: Text(l10n.reviewBackToReceipts),
                  ),
                ],
              ),
            ),
    );
  }
}
