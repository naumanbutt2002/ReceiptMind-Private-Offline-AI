import 'package:flutter/material.dart';

import '../../l10n/generated/app_localizations.dart';
import '../money/money.dart';

/// Shows a searchable list of currencies and returns the chosen ISO 4217
/// code, or `null` if the user closed the sheet.
///
/// [selected] is ticked in the list; [locale] (e.g. `en_AU`) formats the
/// example amounts.
Future<String?> showCurrencyPicker(
  BuildContext context, {
  required String selected,
  required String locale,
}) async {
  final choice = await _show(context, selected: selected, locale: locale);
  return choice?.code;
}

/// What the user picked in [showDefaultCurrencyPicker].
final class CurrencyChoice {
  const CurrencyChoice(this.code);

  /// "Use device default".
  const CurrencyChoice.deviceDefault() : code = null;

  /// The chosen code, or `null` for the device default.
  final String? code;

  bool get isDeviceDefault => code == null;
}

/// Like [showCurrencyPicker], with a "Use device default" entry at the top
/// that shows [deviceDefault]. Used by Settings.
Future<CurrencyChoice?> showDefaultCurrencyPicker(
  BuildContext context, {
  required String selected,
  required String locale,
  required String deviceDefault,
  required bool followsDevice,
}) => _show(
  context,
  selected: selected,
  locale: locale,
  deviceDefault: deviceDefault,
  followsDevice: followsDevice,
);

Future<CurrencyChoice?> _show(
  BuildContext context, {
  required String selected,
  required String locale,
  String? deviceDefault,
  bool followsDevice = false,
}) => showModalBottomSheet<CurrencyChoice>(
  context: context,
  isScrollControlled: true,
  useSafeArea: true,
  showDragHandle: true,
  // 90 % high, so the barrier above it still closes the sheet.
  builder: (context) => FractionallySizedBox(
    heightFactor: 0.9,
    child: CurrencyPickerSheet(
      selected: selected,
      locale: locale,
      deviceDefault: deviceDefault,
      followsDevice: followsDevice,
    ),
  ),
);

/// The body of the currency picker sheet. Pops a [CurrencyChoice].
class CurrencyPickerSheet extends StatefulWidget {
  const CurrencyPickerSheet({
    super.key,
    required this.selected,
    required this.locale,
    this.deviceDefault,
    this.followsDevice = false,
  });

  final String selected;
  final String locale;

  /// When set, a "Use device default" entry with this code comes first.
  final String? deviceDefault;

  /// Whether the "Use device default" entry is the current choice.
  final bool followsDevice;

  @override
  State<CurrencyPickerSheet> createState() => _CurrencyPickerSheetState();
}

class _CurrencyPickerSheetState extends State<CurrencyPickerSheet> {
  final _search = TextEditingController();
  late final List<Currency> _all = [
    // A well-formed code we have no data for still shows up, so it stays
    // selectable.
    if (!Currencies.all.any((c) => c.code == widget.selected))
      Currencies.of(widget.selected),
    ...Currencies.all,
  ];

  @override
  void initState() {
    super.initState();
    _search.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  /// Matches the code or the symbol, ignoring case: `kw` → KWD, `€` → EUR,
  /// `rs` → LKR and PKR.
  List<Currency> get _filtered {
    final query = _search.text.trim().toLowerCase();
    if (query.isEmpty) return _all;
    return [
      for (final c in _all)
        if (c.code.toLowerCase().contains(query) ||
            c.symbol.toLowerCase().contains(query))
          c,
    ];
  }

  String _example(String code) => Money(123456, code).format(widget.locale);

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final filtered = _filtered;
    final deviceDefault = widget.deviceDefault;
    final showDeviceDefault = deviceDefault != null && _search.text.isEmpty;
    final checkColor = theme.colorScheme.primary;

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
          child: Align(
            alignment: AlignmentDirectional.centerStart,
            child: Text(
              l10n.currencyPickerTitle,
              style: theme.textTheme.titleLarge,
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: TextField(
            controller: _search,
            textCapitalization: TextCapitalization.characters,
            decoration: InputDecoration(
              prefixIcon: const Icon(Icons.search),
              hintText: l10n.currencyPickerSearchHint,
              border: const OutlineInputBorder(),
              suffixIcon: _search.text.isEmpty
                  ? null
                  : IconButton(
                      tooltip: l10n.currencyPickerClearSearch,
                      icon: const Icon(Icons.clear),
                      onPressed: _search.clear,
                    ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Expanded(
          child: filtered.isEmpty && !showDeviceDefault
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(
                      l10n.currencyPickerNoResults,
                      textAlign: TextAlign.center,
                    ),
                  ),
                )
              : ListView(
                  children: [
                    if (showDeviceDefault) ...[
                      ListTile(
                        leading: const Icon(Icons.smartphone_outlined),
                        title: Text(l10n.currencyPickerDeviceDefault),
                        subtitle: Text(
                          l10n.settingsDefaultCurrencyValue(
                            deviceDefault,
                            _example(deviceDefault),
                          ),
                        ),
                        trailing: widget.followsDevice
                            ? Icon(Icons.check, color: checkColor)
                            : null,
                        selected: widget.followsDevice,
                        onTap: () =>
                            Navigator.of(context)
                                .pop(const CurrencyChoice.deviceDefault()),
                      ),
                      const Divider(),
                    ],
                    for (final c in filtered)
                      _CurrencyTile(
                        currency: c,
                        example: _example(c.code),
                        selected:
                            !widget.followsDevice && c.code == widget.selected,
                        checkColor: checkColor,
                      ),
                  ],
                ),
        ),
      ],
    );
  }
}

class _CurrencyTile extends StatelessWidget {
  const _CurrencyTile({
    required this.currency,
    required this.example,
    required this.selected,
    required this.checkColor,
  });

  final Currency currency;
  final String example;
  final bool selected;
  final Color checkColor;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      key: ValueKey('currency-${currency.code}'),
      title: Text(currency.code),
      subtitle: Text(example),
      trailing: selected ? Icon(Icons.check, color: checkColor) : null,
      selected: selected,
      onTap: () => Navigator.of(context).pop(CurrencyChoice(currency.code)),
    );
  }
}
