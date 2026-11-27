import 'dart:io';

import 'package:flutter/material.dart';
import 'package:receipt_parser/fixtures.dart' show formatMinorUnits;
import 'package:receipt_parser/receipt_parser.dart';

import '../../../l10n/generated/app_localizations.dart';
import '../../scan/application/scan_state.dart';
import '../application/row_layout.dart';
import 'ocr_overlay_painter.dart';

/// Developer screen for one scan: the photo with the OCR boxes and the
/// parser's rows on top, every parsed field with its confidence, reason and
/// row, the validator issues and the parser trace.
///
/// Without boxes (a plain-text OCR result) only the text tabs are shown.
class OcrDebugScreen extends StatefulWidget {
  const OcrDebugScreen({required this.data, this.imagePath, super.key});

  final ReviewData data;

  /// Absolute path of the scanned photo; without it the boxes are drawn on a
  /// blank page.
  final String? imagePath;

  @override
  State<OcrDebugScreen> createState() => _OcrDebugScreenState();
}

class _OcrDebugScreenState extends State<OcrDebugScreen> {
  late List<RowLayout> _rows;
  Size? _decodedSize;
  ImageStream? _stream;
  ImageStreamListener? _listener;

  @override
  void initState() {
    super.initState();
    _update();
  }

  @override
  void didUpdateWidget(OcrDebugScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.data != widget.data ||
        oldWidget.imagePath != widget.imagePath) {
      _update();
    }
  }

  @override
  void dispose() {
    _stopListening();
    super.dispose();
  }

  OcrDocument? get _document => widget.data.document;

  bool get _hasLayout => _document?.hasLayout ?? false;

  void _update() {
    final document = _document;
    _rows = document == null ? const [] : buildRowLayout(document);
    _stopListening();
    _decodedSize = null;
    final path = widget.imagePath;
    // ML Kit boxes are in the pixels of the decoded image; read its size when
    // the OCR result doesn't carry it.
    if (_hasLayout &&
        path != null &&
        (document!.imageWidth == null || document.imageHeight == null)) {
      final stream = FileImage(File(path)).resolve(ImageConfiguration.empty);
      final listener = ImageStreamListener((info, _) {
        if (!mounted) return;
        setState(() {
          _decodedSize = Size(
            info.image.width.toDouble(),
            info.image.height.toDouble(),
          );
        });
        info.dispose();
      }, onError: (_, _) {});
      stream.addListener(listener);
      _stream = stream;
      _listener = listener;
    }
  }

  void _stopListening() {
    final listener = _listener;
    if (listener != null) _stream?.removeListener(listener);
    _stream = null;
    _listener = null;
  }

  Size _imageSize(OcrDocument document) {
    final w = document.imageWidth;
    final h = document.imageHeight;
    if (w != null && h != null && w > 0 && h > 0) {
      return Size(w.toDouble(), h.toDouble());
    }
    return _decodedSize ?? boxExtent(document);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final document = _document;
    final tabs = [
      if (_hasLayout) Tab(text: l10n.devTabOverlay),
      Tab(text: l10n.devTabParser),
      Tab(text: l10n.devTabText),
    ];
    return DefaultTabController(
      length: tabs.length,
      child: Scaffold(
        appBar: AppBar(
          title: Text(l10n.devOcrTitle),
          bottom: TabBar(tabs: tabs),
        ),
        body: TabBarView(
          // The overlay pans and zooms; swiping between tabs would fight it.
          physics: const NeverScrollableScrollPhysics(),
          children: [
            if (_hasLayout)
              _OverlayTab(
                document: document!,
                rows: _rows,
                imageSize: _imageSize(document),
                imagePath: widget.imagePath,
                parsed: widget.data.parsed,
              ),
            _ParserTab(data: widget.data, rowCount: _rowCount),
            _TextTab(data: widget.data, rows: _rows),
          ],
        ),
      ),
    );
  }

  int get _rowCount => widget.data.parsed?.rows.length ?? _rows.length;
}

/// Field → row index for every parsed field that names a row.
Map<ReceiptField, int> fieldRowsOf(ParsedReceipt? parsed) {
  if (parsed == null) return const {};
  return {
    for (final MapEntry(:key, :value) in _fieldsOf(parsed).entries)
      if (value?.rowIndex != null) key: value!.rowIndex!,
  };
}

Map<ReceiptField, ParsedField<Object>?> _fieldsOf(ParsedReceipt parsed) => {
  ReceiptField.merchant: parsed.merchant,
  ReceiptField.date: parsed.date,
  ReceiptField.total: parsed.total,
  ReceiptField.subtotal: parsed.subtotal,
  ReceiptField.tax: parsed.tax,
  ReceiptField.tip: parsed.tip,
  ReceiptField.currency: parsed.currency,
  ReceiptField.paymentMethod: parsed.paymentMethod,
};

class _OverlayTab extends StatefulWidget {
  const _OverlayTab({
    required this.document,
    required this.rows,
    required this.imageSize,
    required this.imagePath,
    required this.parsed,
  });

  final OcrDocument document;
  final List<RowLayout> rows;
  final Size imageSize;
  final String? imagePath;
  final ParsedReceipt? parsed;

  @override
  State<_OverlayTab> createState() => _OverlayTabState();
}

class _OverlayTabState extends State<_OverlayTab>
    with AutomaticKeepAliveClientMixin {
  final _layers = {OverlayLayer.rows, OverlayLayer.fields};

  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final l10n = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    final fieldRows = fieldRowsOf(widget.parsed);
    final labels = {
      OverlayLayer.lines: l10n.devLayerLines,
      OverlayLayer.words: l10n.devLayerWords,
      OverlayLayer.rows: l10n.devLayerRows,
      OverlayLayer.fields: l10n.devLayerFields,
    };
    final path = widget.imagePath;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
          child: Wrap(
            spacing: 8,
            runSpacing: 4,
            children: [
              for (final layer in OverlayLayer.values)
                FilterChip(
                  label: Text(labels[layer]!),
                  selected: _layers.contains(layer),
                  onSelected: (on) => setState(() {
                    on ? _layers.add(layer) : _layers.remove(layer);
                  }),
                ),
            ],
          ),
        ),
        if (_layers.contains(OverlayLayer.fields) && fieldRows.isNotEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 4, 12, 0),
            child: Wrap(
              spacing: 12,
              runSpacing: 4,
              children: [
                for (final MapEntry(key: field, value: row)
                    in fieldRows.entries)
                  _Legend(
                    color: fieldColor(field),
                    text: '${field.name} · ${l10n.devFieldRow(row)}',
                  ),
              ],
            ),
          ),
        const SizedBox(height: 8),
        Expanded(
          child: ClipRect(
            child: Semantics(
              label: l10n.devPhotoLabel,
              image: true,
              child: InteractiveViewer(
                maxScale: 10,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    if (path != null)
                      Image.file(
                        File(path),
                        fit: BoxFit.contain,
                        excludeFromSemantics: true,
                        errorBuilder: (context, _, _) =>
                            Center(child: Text(l10n.devPhotoMissing)),
                      )
                    else
                      ColoredBox(color: scheme.surfaceContainerHighest),
                    CustomPaint(
                      painter: OcrOverlayPainter(
                        document: widget.document,
                        rows: widget.rows,
                        imageSize: widget.imageSize,
                        layers: {..._layers},
                        fieldRows: fieldRows,
                        textDirection: Directionality.of(context),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _Legend extends StatelessWidget {
  const _Legend({required this.color, required this.text});

  final Color color;
  final String text;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Container(width: 12, height: 12, color: color),
      const SizedBox(width: 4),
      Text(text, style: Theme.of(context).textTheme.labelSmall),
    ],
  );
}

class _ParserTab extends StatelessWidget {
  const _ParserTab({required this.data, required this.rowCount});

  final ReviewData data;
  final int rowCount;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final document = data.document;
    final parsed = data.parsed;
    final mono = _monoStyle(context);
    String imageSize() {
      final w = document?.imageWidth;
      final h = document?.imageHeight;
      return w == null || h == null ? l10n.devUnknown : '$w × $h';
    }

    return ListView(
      padding: const EdgeInsets.only(bottom: 24),
      children: [
        _Header(l10n.devSectionSummary),
        _KeyValue(l10n.devSummaryEngine, document?.engineId ?? l10n.devUnknown),
        _KeyValue(l10n.devSummaryImage, imageSize()),
        _KeyValue(l10n.devSummaryLines, '${document?.lines.length ?? 0}'),
        _KeyValue(l10n.devSummaryRows, '$rowCount'),
        _KeyValue(l10n.devSummaryParser, receiptParserVersion),
        if (parsed != null)
          _KeyValue(
            l10n.devSummaryConfidence,
            parsed.overallConfidence.toStringAsFixed(2),
          ),
        _Header(l10n.devSectionFields),
        if (parsed == null)
          _Note(l10n.devNoParse)
        else
          for (final MapEntry(key: field, value: value) in _fieldsOf(
            parsed,
          ).entries)
            _FieldTile(
              field: field,
              value: value,
              currency: parsed.currency.value,
            ),
        _Header(l10n.devSectionIssues),
        if (data.issues.isEmpty)
          _Note(l10n.devNoIssues)
        else
          for (final issue in data.issues)
            ListTile(
              dense: true,
              leading: Icon(switch (issue.severity) {
                IssueSeverity.error => Icons.error_outline,
                IssueSeverity.warning => Icons.warning_amber_outlined,
                IssueSeverity.info => Icons.info_outline,
              }),
              title: Text('${issue.field.name}: ${issue.code.name}'),
              subtitle: Text(issue.severity.name),
            ),
        _Header(l10n.devSectionTrace),
        if (parsed == null || parsed.trace.isEmpty)
          _Note(l10n.devNoTrace)
        else
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: SelectableText(parsed.trace.join('\n'), style: mono),
          ),
      ],
    );
  }
}

class _FieldTile extends StatelessWidget {
  const _FieldTile({
    required this.field,
    required this.value,
    required this.currency,
  });

  final ReceiptField field;
  final ParsedField<Object>? value;
  final String currency;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final v = value;
    final details = v == null
        ? null
        : [
            l10n.devFieldConfidence(v.confidence.toStringAsFixed(2)),
            v.reason,
            if (v.rowIndex != null) l10n.devFieldRow(v.rowIndex!),
          ].join(' · ');
    return ListTile(
      dense: true,
      leading: Icon(Icons.circle, size: 14, color: fieldColor(field)),
      minLeadingWidth: 16,
      title: Text.rich(
        TextSpan(
          children: [
            TextSpan(
              text: '${field.name}  ',
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            TextSpan(
              text: v == null
                  ? l10n.devFieldNotFound
                  : formatFieldValue(v.value, currency),
            ),
          ],
        ),
      ),
      subtitle: details == null ? null : Text(details),
    );
  }
}

/// A parsed value as fixture text: amounts as decimals in [currency]'s minor
/// digits, dates as ISO, enums by name.
String formatFieldValue(Object value, String currency) => switch (value) {
  final int minor => formatMinorUnits(
    minor,
    Currencies.isWellFormed(currency) ? Currencies.of(currency).minorDigits : 2,
  ),
  final LocalDate date => date.toIso(),
  final Enum e => e.name,
  _ => value.toString(),
};

class _TextTab extends StatelessWidget {
  const _TextTab({required this.data, required this.rows});

  final ReviewData data;
  final List<RowLayout> rows;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final mono = _monoStyle(context);
    final document = data.document;
    final rowLines = data.parsed != null
        ? [for (final r in data.parsed!.rows) '${r.index}: ${r.text}']
        : [for (final r in rows) '${r.index}: ${r.text}'];
    final hasText = document != null && document.text.trim().isNotEmpty;
    return ListView(
      padding: const EdgeInsets.only(bottom: 24),
      children: [
        _Header(l10n.devSectionRows),
        if (rowLines.isEmpty)
          _Note(l10n.devNoText)
        else
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: SelectableText(rowLines.join('\n'), style: mono),
          ),
        _Header(l10n.devSectionOcrText),
        if (!hasText)
          _Note(l10n.devNoText)
        else
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: SelectableText(document.text, style: mono),
          ),
      ],
    );
  }
}

TextStyle? _monoStyle(BuildContext context) => Theme.of(context)
    .textTheme
    .bodySmall
    ?.copyWith(fontFamily: 'monospace', fontFamilyFallback: const ['Menlo']);

class _Header extends StatelessWidget {
  const _Header(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
    child: Text(
      text,
      style: Theme.of(context).textTheme.titleSmall
          ?.copyWith(color: Theme.of(context).colorScheme.primary),
    ),
  );
}

class _KeyValue extends StatelessWidget {
  const _KeyValue(this.label, this.value);

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
    child: Wrap(
      spacing: 8,
      children: [
        Text(label, style: Theme.of(context).textTheme.bodySmall),
        SelectableText(value),
      ],
    ),
  );
}

class _Note extends StatelessWidget {
  const _Note(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 16),
    child: Text(text, style: Theme.of(context).textTheme.bodyMedium),
  );
}
