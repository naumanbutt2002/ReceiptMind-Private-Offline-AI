import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/date/date_display.dart';
import '../../../../core/db/app_database.dart';
import '../../../../core/money/money.dart';
import '../../../../core/settings/settings_providers.dart';
import '../../../../core/widgets/amount_text.dart';
import '../../../../core/widgets/category_icons.dart';
import '../../../../l10n/generated/app_localizations.dart';
import '../../application/receipt_list_providers.dart';
import '../../application/receipt_photo_sharer.dart';
import '../../data/receipts_providers.dart';
import '../list/receipt_deleted_snack_bar.dart';
import '../list/receipt_thumbnail.dart';
import '../receipt_routes_detail.dart';

/// One receipt: its photo and every field, with Edit, Delete and Share photo.
class ReceiptDetailScreen extends ConsumerWidget {
  const ReceiptDetailScreen({super.key, required this.id});

  final String id;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final receipt = ref.watch(receiptDetailProvider(id));
    final row = receipt.value;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.detailTitle),
        actions: row == null
            ? null
            : [
                IconButton(
                  key: const Key('detail-edit'),
                  tooltip: l10n.detailEdit,
                  icon: const Icon(Icons.edit_outlined),
                  onPressed: () =>
                      context.push(ReceiptPaths.edit(row.id)).ignore(),
                ),
                if (row.imagePath case final imagePath?)
                  _SharePhotoButton(imagePath: imagePath),
                IconButton(
                  key: const Key('detail-delete'),
                  tooltip: l10n.detailDelete,
                  icon: const Icon(Icons.delete_outline),
                  onPressed: () => _confirmDelete(context, ref, row),
                ),
              ],
      ),
      body: switch (receipt) {
        AsyncData(value: final row?) => _ReceiptDetailBody(receipt: row),
        AsyncData() || AsyncError() => const _NotFound(),
        _ => const Center(child: CircularProgressIndicator()),
      },
    );
  }

  Future<void> _confirmDelete(
    BuildContext context,
    WidgetRef ref,
    ReceiptRow row,
  ) async {
    final l10n = AppLocalizations.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l10n.detailDeleteTitle),
        content: Text(l10n.detailDeleteBody(row.merchant)),
        actions: [
          TextButton(
            key: const Key('detail-delete-cancel'),
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(l10n.detailCancel),
          ),
          FilledButton(
            key: const Key('detail-delete-confirm'),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(l10n.detailDelete),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    final repository = ref.read(receiptRepositoryProvider);
    // Leave first, so this screen never flashes "Receipt not found".
    if (context.canPop()) {
      context.pop();
    } else {
      context.go(ReceiptPaths.list);
    }
    final ReceiptRow? deleted;
    try {
      deleted = await repository.delete(row.id);
    } on Object catch (error) {
      debugPrint('ReceiptDetailScreen: delete failed: $error');
      showReceiptDeleteFailedSnackBar(messenger: messenger, l10n: l10n);
      return;
    }
    if (deleted == null) return;
    showReceiptDeletedSnackBar(
      messenger: messenger,
      l10n: l10n,
      repository: repository,
      deleted: deleted,
    );
  }
}

/// "Share photo". Ignores taps while the share sheet is opening, so a
/// double tap can't open two sheets (the second would fail).
class _SharePhotoButton extends ConsumerStatefulWidget {
  const _SharePhotoButton({required this.imagePath});

  final String imagePath;

  @override
  ConsumerState<_SharePhotoButton> createState() => _SharePhotoButtonState();
}

class _SharePhotoButtonState extends ConsumerState<_SharePhotoButton> {
  bool _sharing = false;

  Future<void> _share() async {
    if (_sharing) return;
    _sharing = true;
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final box = context.findRenderObject() as RenderBox?;
    final origin = box == null || !box.hasSize
        ? null
        : box.localToGlobal(Offset.zero) & box.size;
    try {
      final path = await ref.read(
        resolvedImagePathProvider(widget.imagePath).future,
      );
      await ref
          .read(receiptPhotoSharerProvider)
          .sharePhoto(path, origin: origin);
    } catch (e) {
      debugPrint('ReceiptDetailScreen: sharing failed: $e');
      messenger.showSnackBar(SnackBar(content: Text(l10n.detailShareFailed)));
    } finally {
      _sharing = false;
    }
  }

  @override
  Widget build(BuildContext context) => IconButton(
    key: const Key('detail-share'),
    tooltip: AppLocalizations.of(context).detailSharePhoto,
    icon: const Icon(Icons.share_outlined),
    onPressed: _share,
  );
}

class _ReceiptDetailBody extends ConsumerWidget {
  const _ReceiptDetailBody({required this.receipt});

  final ReceiptRow receipt;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final dateOrder = ref.watch(
      settingsControllerProvider.select((s) => s.dateOrder),
    );
    final categoryId = receipt.categoryId;
    final category = categoryId == null
        ? null
        : ref.watch(categoriesByIdProvider)[categoryId];
    final notes = receipt.notes;
    final payment = receipt.paymentMethod;
    Money money(int minor) => Money(minor, receipt.currency);

    return ListView(
      key: const Key('detail-body'),
      padding: const EdgeInsets.only(bottom: 24),
      children: [
        _Photo(receipt: receipt),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                receipt.merchant,
                key: const Key('detail-merchant'),
                style: theme.textTheme.headlineSmall,
              ),
              const SizedBox(height: 4),
              AmountText(
                money(receipt.totalMinor),
                key: const Key('detail-total'),
                style: theme.textTheme.displaySmall,
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        _Field(
          label: l10n.detailDate,
          value: Text(formatNumericDate(receipt.purchaseDate, dateOrder)),
          icon: Icons.calendar_today_outlined,
        ),
        if (receipt.subtotalMinor case final subtotal?)
          _Field(
            label: l10n.detailSubtotal,
            value: AmountText(money(subtotal)),
            icon: Icons.receipt_outlined,
          ),
        if (receipt.taxMinor case final tax?)
          _Field(
            label: l10n.detailTax,
            value: AmountText(money(tax)),
            icon: Icons.account_balance_outlined,
          ),
        if (receipt.tipMinor case final tip?)
          _Field(
            label: l10n.detailTip,
            value: AmountText(money(tip)),
            icon: Icons.volunteer_activism_outlined,
          ),
        _Field(
          label: l10n.detailCurrency,
          value: Text(_currencyText(receipt.currency)),
          icon: Icons.payments_outlined,
        ),
        _Field(
          label: l10n.detailCategory,
          value: Text(category?.name ?? l10n.listUncategorised),
          leading: CategoryAvatar(
            iconKey: category?.iconKey,
            color: category?.color,
            size: 24,
          ),
        ),
        if (payment != null)
          _Field(
            label: l10n.detailPaymentMethod,
            value: Text(switch (payment) {
              PaymentMethod.card => l10n.detailPaymentCard,
              PaymentMethod.cash => l10n.detailPaymentCash,
              PaymentMethod.other => l10n.detailPaymentOther,
            }),
            icon: switch (payment) {
              PaymentMethod.card => Icons.credit_card,
              PaymentMethod.cash => Icons.money,
              PaymentMethod.other => Icons.account_balance_wallet_outlined,
            },
          ),
        if (notes != null && notes.isNotEmpty)
          _Field(
            label: l10n.detailNotes,
            value: Text(notes),
            icon: Icons.notes,
          ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
          child: Text(
            _extractionNote(l10n, receipt),
            key: const Key('detail-extraction'),
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      ],
    );
  }

  static String _currencyText(String code) {
    final info = Currencies.of(code);
    return info.symbol == code ? code : '$code (${info.symbol})';
  }

  static String _extractionNote(AppLocalizations l10n, ReceiptRow receipt) {
    final method = switch (receipt.extractionMethod) {
      ExtractionMethod.rules => l10n.detailMethodRules,
      ExtractionMethod.aiText => l10n.detailMethodAiText,
      ExtractionMethod.aiVision => l10n.detailMethodAiVision,
      ExtractionMethod.manual => l10n.detailMethodManual,
    };
    final confidence = receipt.confidence;
    if (confidence == null ||
        receipt.extractionMethod == ExtractionMethod.manual) {
      return method;
    }
    return l10n.detailConfidence(method, (confidence * 100).round());
  }
}

class _Field extends StatelessWidget {
  const _Field({
    required this.label,
    required this.value,
    this.icon,
    this.leading,
  });

  final String label;
  final Widget value;
  final IconData? icon;
  final Widget? leading;

  @override
  Widget build(BuildContext context) {
    return MergeSemantics(
      child: ListTile(
        leading: leading ?? (icon == null ? null : Icon(icon)),
        title: Text(label),
        subtitle: DefaultTextStyle.merge(
          style: Theme.of(context).textTheme.bodyLarge,
          child: value,
        ),
      ),
    );
  }
}

/// The receipt photo (tap for full screen), or a small "No photo" note.
class _Photo extends ConsumerWidget {
  const _Photo({required this.receipt});

  final ReceiptRow receipt;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    final imagePath = receipt.imagePath;
    if (imagePath == null) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
        child: Row(
          key: const Key('detail-no-photo'),
          children: [
            Icon(Icons.hide_image_outlined, color: scheme.onSurfaceVariant),
            const SizedBox(width: 8),
            Text(l10n.detailNoPhoto),
          ],
        ),
      );
    }
    final absolute = ref.watch(resolvedImagePathProvider(imagePath)).value;
    final size = MediaQuery.sizeOf(context);
    final height = (size.height * 0.4).clamp(160.0, 420.0);
    final missing = _MissingPhoto(height: height);
    return Semantics(
      label: l10n.detailPhoto,
      button: true,
      image: true,
      excludeSemantics: true,
      onTap: absolute == null ? null : () => _openFullScreen(context, absolute),
      child: GestureDetector(
        key: const Key('detail-photo'),
        onTap: absolute == null
            ? null
            : () => _openFullScreen(context, absolute),
        child: Hero(
          tag: receiptHeroTag(receipt.id),
          child: Container(
            height: height,
            color: scheme.surfaceContainerHighest,
            child: absolute == null
                ? null
                : Image.file(
                    File(absolute),
                    fit: BoxFit.contain,
                    cacheHeight:
                        (height * MediaQuery.devicePixelRatioOf(context))
                            .round(),
                    gaplessPlayback: true,
                    errorBuilder: (context, error, stackTrace) => missing,
                  ),
          ),
        ),
      ),
    );
  }

  void _openFullScreen(BuildContext context, String absolutePath) {
    Navigator.of(context, rootNavigator: true).push(
      MaterialPageRoute<void>(
        fullscreenDialog: true,
        builder: (_) => _FullScreenPhoto(path: absolutePath),
      ),
    );
  }
}

class _MissingPhoto extends StatelessWidget {
  const _MissingPhoto({required this.height});

  final double height;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return SizedBox(
      key: const Key('detail-photo-missing'),
      height: height,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.broken_image_outlined,
            size: 48,
            color: scheme.onSurfaceVariant,
          ),
          const SizedBox(height: 8),
          Text(AppLocalizations.of(context).detailPhotoMissing),
        ],
      ),
    );
  }
}

/// The photo on black; pinch to zoom, drag to pan.
class _FullScreenPhoto extends StatelessWidget {
  const _FullScreenPhoto({required this.path});

  final String path;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      key: const Key('detail-fullscreen'),
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        leading: IconButton(
          tooltip: l10n.detailCloseFullScreen,
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: InteractiveViewer(
        maxScale: 6,
        child: Center(
          child: Semantics(
            label: l10n.detailPhoto,
            image: true,
            child: Image.file(
              File(path),
              fit: BoxFit.contain,
              errorBuilder: (context, error, stackTrace) => Icon(
                Icons.broken_image_outlined,
                size: 64,
                color: Colors.white70,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _NotFound extends StatelessWidget {
  const _NotFound();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    return Center(
      key: const Key('detail-not-found'),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.search_off, size: 72, color: theme.colorScheme.primary),
            const SizedBox(height: 16),
            Text(
              l10n.detailNotFoundTitle,
              textAlign: TextAlign.center,
              style: theme.textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Text(l10n.detailNotFoundBody, textAlign: TextAlign.center),
            const SizedBox(height: 24),
            OutlinedButton(
              onPressed: () => context.canPop()
                  ? context.pop()
                  : context.go(ReceiptPaths.list),
              child: Text(l10n.detailBackToList),
            ),
          ],
        ),
      ),
    );
  }
}
