import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../money/money.dart';
import '../settings/settings_providers.dart';

/// An amount formatted for the device locale (`$45.60`, `12,50 €`), with
/// tabular figures so amounts line up in lists.
class AmountText extends ConsumerWidget {
  const AmountText(
    this.money, {
    super.key,
    this.style,
    this.textAlign,
    this.maxLines = 1,
  });

  final Money money;
  final TextStyle? style;
  final TextAlign? textAlign;
  final int? maxLines;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final locale = ref.watch(deviceLocaleProvider);
    return Text(
      money.format(locale),
      style: (style ?? const TextStyle()).copyWith(
        fontFeatures: const [FontFeature.tabularFigures()],
      ),
      textAlign: textAlign,
      maxLines: maxLines,
      overflow: maxLines == null ? null : TextOverflow.ellipsis,
    );
  }
}
