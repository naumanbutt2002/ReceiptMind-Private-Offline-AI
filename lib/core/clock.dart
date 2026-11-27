import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'clock.g.dart';

/// The current time. Tests override it to fix "today" (for example the
/// parser's future-date check).
@Riverpod(keepAlive: true)
DateTime Function() clock(Ref ref) => DateTime.now;
