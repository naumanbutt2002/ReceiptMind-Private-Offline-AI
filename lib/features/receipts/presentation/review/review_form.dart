import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:receipt_parser/receipt_parser.dart' show ReceiptField;

import '../../../../core/clock.dart';
import '../../../../core/date/date_display.dart';
import '../../../../core/date/local_date.dart';
import '../../../../core/db/app_database.dart';
import '../../../../core/money/money.dart';
import '../../../../core/settings/settings_providers.dart';
import '../../../../core/widgets/category_icons.dart';
import '../../../../core/widgets/currency_picker.dart';
import '../../../../l10n/generated/app_localizations.dart';
import '../../../developer/presentation/developer_menu_button.dart';
import '../../../scan/application/receipt_draft.dart';
import '../../../scan/application/scan_controller.dart';
import '../../../scan/application/scan_state.dart';
import '../../data/receipts_providers.dart';
import 'recognised_text_sheet.dart';
import 'review_keys.dart';
import 'review_messages.dart';
import 'review_photo.dart';
import 'review_providers.dart';
import 'review_screen.dart';

/// Below this width the photo sits above the form; from it on, beside it.
const reviewWideLayoutBreakpoint = 600.0;

/// The review form for one [ReviewInput]: fields, ⚠️ flags, the photo, save
/// and discard.
class ReviewForm extends ConsumerStatefulWidget {
  const ReviewForm({
    required this.mode,
    required this.input,
    required this.title,
    super.key,
  });

  final ReviewMode mode;
  final ReviewInput input;
  final String title;

  @override
  ConsumerState<ReviewForm> createState() => _ReviewFormState();
}

class _ReviewFormState extends ConsumerState<ReviewForm> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _merchant;
  late final TextEditingController _dateText;
  late final TextEditingController _total;
  late final TextEditingController _subtotal;
  late final TextEditingController _tax;
  late final TextEditingController _tip;
  late final TextEditingController _notes;

  final _merchantFocus = FocusNode(debugLabel: 'merchant');
  final _dateFocus = FocusNode(debugLabel: 'date');
  final _totalFocus = FocusNode(debugLabel: 'total');
  final _subtotalFocus = FocusNode(debugLabel: 'subtotal');
  final _taxFocus = FocusNode(debugLabel: 'tax');
  final _tipFocus = FocusNode(debugLabel: 'tip');

  /// The validated fields from top to bottom, with their focus nodes: a
  /// failed save scrolls to and focuses the first invalid one.
  late final List<(Key, FocusNode)> _validatedFields = [
    (ReviewKeys.merchantField, _merchantFocus),
    (ReviewKeys.dateField, _dateFocus),
    (ReviewKeys.totalField, _totalFocus),
    (ReviewKeys.subtotalField, _subtotalFocus),
    (ReviewKeys.taxField, _taxFocus),
    (ReviewKeys.tipField, _tipFocus),
  ];

  late LocalDate? _date;
  late String _currency;
  late int? _categoryId;
  late PaymentMethod? _payment;

  /// Fields still showing ⚠️; a field leaves the set once the user edits it.
  late final Set<ReceiptField> _flags;
  late bool _moreExpanded;

  bool _dirty = false;
  bool _saving = false;

  /// Set once the screen is about to leave, so [PopScope] lets it go.
  bool _leaving = false;
  AutovalidateMode _autovalidate = AutovalidateMode.disabled;

  ReceiptDraft get _initial => widget.input.draft;
  String get _locale => ref.read(deviceLocaleProvider);
  DateOrder get _dateOrder => ref.read(settingsControllerProvider).dateOrder;

  @override
  void initState() {
    super.initState();
    final draft = _initial;
    String amount(int? minor) =>
        minor == null ? '' : amountFieldText(minor, draft.currency, _locale);

    _date = draft.date;
    _currency = draft.currency;
    _categoryId = draft.categoryId;
    _payment = draft.paymentMethod;
    _merchant = TextEditingController(text: draft.merchant);
    _dateText = TextEditingController(text: _formatDate(draft.date));
    _total = TextEditingController(text: amount(draft.totalMinor));
    _subtotal = TextEditingController(text: amount(draft.subtotalMinor));
    _tax = TextEditingController(text: amount(draft.taxMinor));
    _tip = TextEditingController(text: amount(draft.tipMinor));
    _notes = TextEditingController(text: draft.notes);
    _flags = {
      for (final MapEntry(:key, :value) in widget.input.warnings.entries)
        if (value.isNotEmpty) key,
    };
    _moreExpanded =
        draft.subtotalMinor != null ||
        draft.taxMinor != null ||
        draft.tipMinor != null ||
        _flags.contains(ReceiptField.subtotal) ||
        _flags.contains(ReceiptField.tax) ||
        _flags.contains(ReceiptField.tip);
  }

  @override
  void dispose() {
    for (final controller in [
      _merchant,
      _dateText,
      _total,
      _subtotal,
      _tax,
      _tip,
      _notes,
    ]) {
      controller.dispose();
    }
    for (final (_, focusNode) in _validatedFields) {
      focusNode.dispose();
    }
    super.dispose();
  }

  String _formatDate(LocalDate? date) =>
      date == null ? '' : formatNumericDate(date, _dateOrder);

  /// Marks the form as changed and clears [field]'s ⚠️.
  void _edited([ReceiptField? field]) {
    if (_dirty && (field == null || !_flags.contains(field))) return;
    setState(() {
      _dirty = true;
      if (field != null) _flags.remove(field);
    });
  }

  // --- Actions -------------------------------------------------------------

  Future<void> _pickDate() async {
    final today = LocalDate.fromDateTime(ref.read(clockProvider)());
    final first = DateTime(1970);
    final last = DateTime(today.year + 5, 12, 31);
    var initial = (_date ?? today).toDateTimeUtc();
    initial = DateTime(initial.year, initial.month, initial.day);
    if (initial.isBefore(first)) initial = first;
    if (initial.isAfter(last)) initial = last;

    final format = datePickerFormat(
      _dateOrder,
      Localizations.localeOf(context),
    );
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: first,
      lastDate: last,
      currentDate: DateTime(today.year, today.month, today.day),
      locale: format.locale,
      fieldHintText: format.hint,
    );
    if (picked == null || !mounted) return;
    final date = LocalDate.fromDateTime(picked);
    setState(() {
      _date = date;
      _dateText.text = _formatDate(date);
    });
    _edited(ReceiptField.date);
  }

  Future<void> _pickCurrency() async {
    final code = await showCurrencyPicker(
      context,
      selected: _currency,
      locale: _locale,
    );
    if (code == null || !mounted) return;
    if (code != _currency) {
      final from = _currency;
      setState(() {
        // Keep the amounts' values: 12.500 KWD becomes 12.50 AUD, not 12,500.
        for (final controller in [_total, _subtotal, _tax, _tip]) {
          final converted = convertAmountFieldText(
            controller.text,
            from: from,
            to: code,
            locale: _locale,
          );
          if (converted != null) controller.text = converted;
        }
        _currency = code;
      });
    }
    _edited(ReceiptField.currency);
  }

  void _showRecognisedText(String text) =>
      showRecognisedTextSheet(context, text);

  bool get _moreFieldInvalid => [
    _subtotal,
    _tax,
    _tip,
  ].any((c) => !parseAmountField(c.text, _currency, _locale).isValid);

  Future<void> _save() async {
    if (_saving) return;
    FocusScope.of(context).unfocus();
    if (_moreFieldInvalid && !_moreExpanded) {
      // Show the invalid field before validating, so its error is visible.
      setState(() => _moreExpanded = true);
      await WidgetsBinding.instance.endOfFrame;
      if (!mounted) return;
    }
    setState(() => _autovalidate = AutovalidateMode.onUserInteraction);
    final invalid = _formKey.currentState?.validateGranularly() ?? const {};
    if (invalid.isNotEmpty) {
      _revealFirstInvalid(invalid);
      return;
    }
    await _submit(_buildDraft());
  }

  /// Scrolls to the top-most invalid field and focuses it, so its error is
  /// in view (and read out by a screen reader).
  void _revealFirstInvalid(Set<FormFieldState<Object?>> invalid) {
    FormFieldState<Object?>? first;
    FocusNode? focusNode;
    for (final (key, node) in _validatedFields) {
      first = invalid.where((field) => field.widget.key == key).firstOrNull;
      if (first != null) {
        focusNode = node;
        break;
      }
    }
    first ??= invalid.first;
    if (!first.mounted) return;
    // Jump rather than animate: an animation would be cut short by the text
    // field scrolling only its caret into view when it gains focus, leaving
    // the label and the error message off screen.
    Scrollable.ensureVisible(first.context, alignment: 0.2);
    focusNode?.requestFocus();
  }

  Future<void> _submit(ReceiptDraft draft) async {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _saving = true);
    try {
      switch (widget.mode) {
        case ReviewMode.newScan:
          await ref.read(scanControllerProvider.notifier).save(draft);
        case ReviewMode.manual:
          await ref.read(receiptRepositoryProvider).createFromDraft(draft);
        case ReviewMode.edit:
          await ref.read(receiptRepositoryProvider).update(draft);
      }
    } on Object catch (error) {
      debugPrint('ReviewForm: saving failed: $error');
      if (!mounted) return;
      setState(() => _saving = false);
      await _saveFailed(error, draft, messenger, l10n);
      return;
    }
    if (!mounted) return;
    messenger.showSnackBar(SnackBar(content: Text(l10n.reviewSaved)));
    _leave(toList: widget.mode != ReviewMode.edit);
  }

  /// Explains a failed save, and recovers where it can.
  Future<void> _saveFailed(
    Object error,
    ReceiptDraft draft,
    ScaffoldMessengerState messenger,
    AppLocalizations l10n,
  ) async {
    // The receipt was deleted while it was being edited (the repository
    // throws StateError for that): there is nothing left to update.
    if (widget.mode == ReviewMode.edit && error is StateError) {
      messenger.showSnackBar(
        SnackBar(content: Text(l10n.reviewReceiptNotFound)),
      );
      _leave(toList: true);
      return;
    }
    // The scanner's temporary photo is gone (cleared by the system or
    // another app): saving again can't work, but the typed values can be
    // kept without the photo.
    final source = draft.sourceImagePath;
    if (source != null && !File(source).existsSync()) {
      if (await _confirmSaveWithoutPhoto() && mounted) {
        await _submit(_withoutPhoto(draft));
      }
      return;
    }
    messenger.showSnackBar(
      SnackBar(
        content: Text(
          isStorageFullError(error)
              ? l10n.reviewSaveFailedStorage
              : l10n.reviewSaveFailed,
        ),
      ),
    );
  }

  Future<bool> _confirmSaveWithoutPhoto() async {
    final l10n = AppLocalizations.of(context);
    final save = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        key: ReviewKeys.photoMissingDialog,
        title: Text(l10n.reviewPhotoMissingTitle),
        content: Text(l10n.reviewPhotoMissingBody),
        scrollable: true,
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(l10n.reviewKeepEditing),
          ),
          TextButton(
            key: ReviewKeys.saveWithoutPhoto,
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(l10n.reviewSaveWithoutPhoto),
          ),
        ],
      ),
    );
    return save ?? false;
  }

  static ReceiptDraft _withoutPhoto(ReceiptDraft draft) => ReceiptDraft(
    id: draft.id,
    merchant: draft.merchant,
    date: draft.date,
    totalMinor: draft.totalMinor,
    subtotalMinor: draft.subtotalMinor,
    taxMinor: draft.taxMinor,
    tipMinor: draft.tipMinor,
    currency: draft.currency,
    paymentMethod: draft.paymentMethod,
    categoryId: draft.categoryId,
    notes: draft.notes,
    imagePath: draft.imagePath,
    rawOcrText: draft.rawOcrText,
    extractionMethod: draft.extractionMethod,
    confidence: draft.confidence,
  );

  ReceiptDraft _buildDraft() {
    int? amount(TextEditingController c) =>
        parseAmountField(c.text, _currency, _locale).minor;
    final base = _initial;
    return ReceiptDraft(
      id: base.id,
      merchant: _merchant.text.trim(),
      date: _date,
      totalMinor: amount(_total),
      subtotalMinor: amount(_subtotal),
      taxMinor: amount(_tax),
      tipMinor: amount(_tip),
      currency: _currency,
      paymentMethod: _payment,
      categoryId: _categoryId,
      notes: _notes.text.trim(),
      sourceImagePath: base.sourceImagePath,
      imagePath: base.imagePath,
      rawOcrText: base.rawOcrText,
      extractionMethod: base.extractionMethod,
      confidence: base.confidence,
    );
  }

  /// Close button and system Back: confirm when there are unsaved changes.
  Future<void> _close() async {
    if (_saving || _leaving) return;
    if (_dirty && !await _confirmDiscard()) return;
    if (!mounted) return;
    if (widget.mode == ReviewMode.newScan) {
      ref.read(scanControllerProvider.notifier).reset();
    }
    _leave(toList: false);
  }

  Future<bool> _confirmDiscard() async {
    final l10n = AppLocalizations.of(context);
    final isEdit = widget.mode == ReviewMode.edit;
    final discard = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        key: ReviewKeys.discardDialog,
        title: Text(
          isEdit ? l10n.reviewDiscardEditTitle : l10n.reviewDiscardNewTitle,
        ),
        content: Text(
          isEdit ? l10n.reviewDiscardEditBody : l10n.reviewDiscardNewBody,
        ),
        actions: [
          TextButton(
            key: ReviewKeys.discardCancel,
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(l10n.reviewKeepEditing),
          ),
          TextButton(
            key: ReviewKeys.discardConfirm,
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(l10n.reviewDiscard),
          ),
        ],
      ),
    );
    return discard ?? false;
  }

  /// Leaves the screen: to the receipt list ([toList]), or back to where the
  /// user came from when there is somewhere to go back to.
  void _leave({required bool toList}) {
    setState(() => _leaving = true);
    // Wait a frame so PopScope sees `canPop: true` before popping.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (!toList && context.canPop()) {
        context.pop();
      } else {
        context.go(reviewReceiptsLocation);
      }
    });
  }

  // --- Layout --------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final photo = widget.input.photoPath;
    return PopScope(
      canPop:
          _leaving ||
          (!_dirty && !_saving && widget.mode != ReviewMode.newScan),
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _close();
      },
      child: Scaffold(
        appBar: AppBar(
          leading: IconButton(
            key: ReviewKeys.closeButton,
            tooltip: l10n.reviewClose,
            icon: const Icon(Icons.close),
            onPressed: _close,
          ),
          title: Text(widget.title),
          actions: [
            // Developer tools (hidden unless developer mode is on): inspect
            // the OCR and export this scan as a parser fixture.
            if (widget.mode == ReviewMode.newScan)
              if (ref.watch(scanControllerProvider) case ScanReview(
                :final data,
              ))
                DeveloperMenuButton(data: data, corrected: _buildDraft),
            Padding(
              padding: const EdgeInsetsDirectional.only(end: 8),
              child: TextButton(
                key: ReviewKeys.saveButton,
                onPressed: _saving ? null : _save,
                child: _saving
                    ? const SizedBox.square(
                        dimension: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text(l10n.reviewSave),
              ),
            ),
          ],
        ),
        body: SafeArea(
          child: Form(
            key: _formKey,
            autovalidateMode: _autovalidate,
            child: LayoutBuilder(
              builder: (context, constraints) {
                final fields = _buildFields(context);
                if (photo == null) return fields;
                if (constraints.maxWidth >= reviewWideLayoutBreakpoint) {
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsetsDirectional.fromSTEB(
                            16,
                            8,
                            0,
                            16,
                          ),
                          child: ReviewPhoto(path: photo),
                        ),
                      ),
                      Expanded(child: fields),
                    ],
                  );
                }
                // Keep the photo in view while scrolling the form; it shrinks
                // when the keyboard takes space and hides when there's none.
                final photoHeight = math.min(
                  constraints.maxHeight * 0.3,
                  320.0,
                );
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (photoHeight >= 96)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                        child: SizedBox(
                          height: photoHeight,
                          child: ReviewPhoto(path: photo),
                        ),
                      ),
                    Expanded(child: fields),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFields(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final input = widget.input;
    final recognisedText = input.recognisedText;
    const gap = SizedBox(height: 16);

    // Not a lazy ListView: every field must stay built so Form.validate()
    // checks the ones scrolled out of view too.
    return SingleChildScrollView(
      key: ReviewKeys.form,
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (input.ocrFailed) ...[_OcrFailedBanner(), gap],
          if (recognisedText != null)
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: TextButton.icon(
                key: ReviewKeys.recognisedTextButton,
                onPressed: () => _showRecognisedText(recognisedText),
                icon: const Icon(Icons.text_snippet_outlined),
                label: Text(l10n.reviewViewRecognisedText),
              ),
            ),
          TextFormField(
            key: ReviewKeys.merchantField,
            controller: _merchant,
            focusNode: _merchantFocus,
            decoration: _decoration(l10n.fieldMerchant, ReceiptField.merchant),
            textCapitalization: TextCapitalization.words,
            textInputAction: TextInputAction.next,
            maxLength: 200,
            buildCounter: _noCounter,
            onChanged: (_) => _edited(ReceiptField.merchant),
            validator: (value) => (value ?? '').trim().isEmpty
                ? l10n.fieldMerchantRequired
                : null,
          ),
          gap,
          TextFormField(
            key: ReviewKeys.dateField,
            controller: _dateText,
            focusNode: _dateFocus,
            readOnly: true,
            onTap: _pickDate,
            decoration: _decoration(
              l10n.fieldDate,
              ReceiptField.date,
              trailing: IconButton(
                key: ReviewKeys.datePickerButton,
                tooltip: l10n.fieldPickDate,
                icon: const Icon(Icons.calendar_today_outlined),
                onPressed: _pickDate,
              ),
            ),
            validator: (_) => _date == null ? l10n.fieldDateRequired : null,
          ),
          gap,
          _amountField(
            key: ReviewKeys.totalField,
            controller: _total,
            focusNode: _totalFocus,
            label: l10n.fieldTotal,
            field: ReceiptField.total,
            required: true,
          ),
          gap,
          _CurrencyField(
            decoration: _decoration(
              l10n.fieldCurrency,
              ReceiptField.currency,
              trailing: const Icon(Icons.arrow_drop_down),
            ),
            code: _currency,
            onTap: _pickCurrency,
          ),
          const SizedBox(height: 8),
          _MoreToggle(
            expanded: _moreExpanded,
            onPressed: () => setState(() => _moreExpanded = !_moreExpanded),
          ),
          if (_moreExpanded) ...[
            const SizedBox(height: 8),
            _amountField(
              key: ReviewKeys.subtotalField,
              controller: _subtotal,
              focusNode: _subtotalFocus,
              label: l10n.fieldSubtotal,
              field: ReceiptField.subtotal,
            ),
            gap,
            _amountField(
              key: ReviewKeys.taxField,
              controller: _tax,
              focusNode: _taxFocus,
              label: l10n.fieldTax,
              field: ReceiptField.tax,
            ),
            gap,
            _amountField(
              key: ReviewKeys.tipField,
              controller: _tip,
              focusNode: _tipFocus,
              label: l10n.fieldTip,
              field: ReceiptField.tip,
            ),
          ],
          gap,
          _SectionLabel(l10n.fieldCategory),
          const SizedBox(height: 8),
          _CategoryChips(
            selected: _categoryId,
            onChanged: (id) {
              setState(() => _categoryId = id);
              _edited();
            },
          ),
          gap,
          _SectionLabel(l10n.fieldPaymentMethod),
          const SizedBox(height: 8),
          _PaymentMethodField(
            selected: _payment,
            onChanged: (method) {
              setState(() => _payment = method);
              _edited(ReceiptField.paymentMethod);
            },
          ),
          if (_flags.contains(ReceiptField.paymentMethod))
            _WarningLine(
              key: ReviewKeys.warning(ReceiptField.paymentMethod),
              text: _warningText(ReceiptField.paymentMethod)!,
            ),
          gap,
          TextFormField(
            key: ReviewKeys.notesField,
            controller: _notes,
            decoration: InputDecoration(
              labelText: l10n.fieldNotes,
              alignLabelWithHint: true,
            ),
            minLines: 3,
            maxLines: null,
            keyboardType: TextInputType.multiline,
            textCapitalization: TextCapitalization.sentences,
            onChanged: (_) => _edited(),
            style: theme.textTheme.bodyLarge,
          ),
        ],
      ),
    );
  }

  Widget _amountField({
    required Key key,
    required TextEditingController controller,
    required FocusNode focusNode,
    required String label,
    required ReceiptField field,
    bool required = false,
  }) {
    final l10n = AppLocalizations.of(context);
    return TextFormField(
      key: key,
      controller: controller,
      focusNode: focusNode,
      decoration: _decoration(label, field, suffixText: _currency),
      keyboardType: const TextInputType.numberWithOptions(
        decimal: true,
        signed: true,
      ),
      textInputAction: TextInputAction.next,
      onChanged: (_) => _edited(field),
      validator: (value) {
        final parsed = parseAmountField(value ?? '', _currency, _locale);
        if (parsed.isEmpty) return required ? l10n.fieldTotalRequired : null;
        if (!parsed.isValid) {
          return l10n.fieldAmountInvalid(amountExample(_currency, _locale));
        }
        return null;
      },
    );
  }

  String? _warningText(ReceiptField field) => _flags.contains(field)
      ? reviewWarningText(
          AppLocalizations.of(context),
          widget.input.warnings[field] ?? const [],
        )
      : null;

  InputDecoration _decoration(
    String label,
    ReceiptField field, {
    Widget? trailing,
    String? suffixText,
  }) {
    final warning = _warningText(field);
    final icon = warning == null
        ? null
        : _WarningIcon(key: ReviewKeys.warning(field));
    return InputDecoration(
      labelText: label,
      helperText: warning,
      helperMaxLines: 3,
      errorMaxLines: 3,
      suffixText: suffixText,
      suffixIcon: switch ((icon, trailing)) {
        (null, null) => null,
        (final Widget i, null) => i,
        (null, final Widget t) => t,
        (final Widget i, final Widget t) => Row(
          mainAxisSize: MainAxisSize.min,
          children: [i, t],
        ),
      },
    );
  }
}

Widget? _noCounter(
  BuildContext context, {
  required int currentLength,
  required bool isFocused,
  required int? maxLength,
}) => null;

/// The ⚠️ colour: readable on light and dark surfaces (≥ 3:1 for icons).
Color _warningColor(BuildContext context) =>
    Theme.of(context).brightness == Brightness.dark
    ? const Color(0xFFFFD54F)
    : const Color(0xFFB45309);

class _WarningIcon extends StatelessWidget {
  const _WarningIcon({super.key});

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsetsDirectional.only(end: 8),
    child: Icon(
      Icons.warning_amber_rounded,
      color: _warningColor(context),
      semanticLabel: AppLocalizations.of(context).reviewWarningLabel,
    ),
  );
}

/// A ⚠️ helper line under a field that has no input decoration.
class _WarningLine extends StatelessWidget {
  const _WarningLine({required this.text, super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.warning_amber_rounded,
            size: 18,
            color: _warningColor(context),
            semanticLabel: AppLocalizations.of(context).reviewWarningLabel,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _OcrFailedBanner extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Semantics(
      liveRegion: true,
      child: Card(
        key: ReviewKeys.ocrFailedBanner,
        color: scheme.errorContainer,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Icon(Icons.info_outline, color: scheme.onErrorContainer),
              const SizedBox(width: 16),
              Expanded(
                child: Text(
                  AppLocalizations.of(context).reviewOcrFailed,
                  style: TextStyle(color: scheme.onErrorContainer),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Semantics(
      header: true,
      child: Text(
        text,
        style: theme.textTheme.titleSmall?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }
}

class _CurrencyField extends StatelessWidget {
  const _CurrencyField({
    required this.decoration,
    required this.code,
    required this.onTap,
  });

  final InputDecoration decoration;
  final String code;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final symbol = Currencies.of(code).symbol;
    return Semantics(
      button: true,
      child: InkWell(
        key: ReviewKeys.currencyField,
        onTap: onTap,
        borderRadius: BorderRadius.circular(4),
        child: InputDecorator(
          decoration: decoration,
          child: Text(symbol == code ? code : '$code · $symbol'),
        ),
      ),
    );
  }
}

class _MoreToggle extends StatelessWidget {
  const _MoreToggle({required this.expanded, required this.onPressed});

  final bool expanded;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => Semantics(
    expanded: expanded,
    child: ListTile(
      key: ReviewKeys.moreToggle,
      contentPadding: EdgeInsets.zero,
      title: Text(AppLocalizations.of(context).reviewMoreDetails),
      trailing: Icon(expanded ? Icons.expand_less : Icons.expand_more),
      onTap: onPressed,
    ),
  );
}

class _CategoryChips extends ConsumerWidget {
  const _CategoryChips({required this.selected, required this.onChanged});

  final int? selected;
  final ValueChanged<int?> onChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final categories = ref.watch(reviewCategoriesProvider).value ?? const [];
    return Wrap(
      spacing: 8,
      runSpacing: 4,
      children: [
        for (final category in categories)
          ChoiceChip(
            key: ReviewKeys.category(category.id),
            avatar: Icon(
              categoryIcon(category.iconKey),
              color: Color(category.color),
            ),
            label: Text(category.name),
            selected: category.id == selected,
            onSelected: (isSelected) =>
                onChanged(isSelected ? category.id : null),
          ),
      ],
    );
  }
}

class _PaymentMethodField extends StatelessWidget {
  const _PaymentMethodField({required this.selected, required this.onChanged});

  final PaymentMethod? selected;
  final ValueChanged<PaymentMethod?> onChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final method = selected;
    return SizedBox(
      width: double.infinity,
      child: SegmentedButton<PaymentMethod>(
        key: ReviewKeys.paymentMethod,
        emptySelectionAllowed: true,
        showSelectedIcon: false,
        selected: {?method},
        onSelectionChanged: (selection) =>
            onChanged(selection.isEmpty ? null : selection.first),
        segments: [
          ButtonSegment(
            value: PaymentMethod.card,
            icon: const Icon(Icons.credit_card),
            label: Text(l10n.fieldPaymentCard),
          ),
          ButtonSegment(
            value: PaymentMethod.cash,
            icon: const Icon(Icons.payments_outlined),
            label: Text(l10n.fieldPaymentCash),
          ),
          ButtonSegment(
            value: PaymentMethod.other,
            icon: const Icon(Icons.more_horiz),
            label: Text(l10n.fieldPaymentOther),
          ),
        ],
      ),
    );
  }
}
