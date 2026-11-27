// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'startup.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Runs [StartupHousekeeping] once per app start (the app reads it after the
/// first frame).

@ProviderFor(startupHousekeeping)
final startupHousekeepingProvider = StartupHousekeepingProvider._();

/// Runs [StartupHousekeeping] once per app start (the app reads it after the
/// first frame).

final class StartupHousekeepingProvider
    extends $FunctionalProvider<AsyncValue<void>, void, FutureOr<void>>
    with $FutureModifier<void>, $FutureProvider<void> {
  /// Runs [StartupHousekeeping] once per app start (the app reads it after the
  /// first frame).
  StartupHousekeepingProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'startupHousekeepingProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$startupHousekeepingHash();

  @$internal
  @override
  $FutureProviderElement<void> $createElement($ProviderPointer pointer) =>
      $FutureProviderElement(pointer);

  @override
  FutureOr<void> create(Ref ref) {
    return startupHousekeeping(ref);
  }
}

String _$startupHousekeepingHash() =>
    r'1f5e9f10d303aa63b4dc36a87807347fe4371feb';
