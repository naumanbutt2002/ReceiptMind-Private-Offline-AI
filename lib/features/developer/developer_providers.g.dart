// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'developer_providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Writes and shares parser fixtures. Tests override it with a fake sharer
/// and a temporary directory.

@ProviderFor(fixtureExporter)
final fixtureExporterProvider = FixtureExporterProvider._();

/// Writes and shares parser fixtures. Tests override it with a fake sharer
/// and a temporary directory.

final class FixtureExporterProvider
    extends
        $FunctionalProvider<FixtureExporter, FixtureExporter, FixtureExporter>
    with $Provider<FixtureExporter> {
  /// Writes and shares parser fixtures. Tests override it with a fake sharer
  /// and a temporary directory.
  FixtureExporterProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'fixtureExporterProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$fixtureExporterHash();

  @$internal
  @override
  $ProviderElement<FixtureExporter> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  FixtureExporter create(Ref ref) {
    return fixtureExporter(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(FixtureExporter value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<FixtureExporter>(value),
    );
  }
}

String _$fixtureExporterHash() => r'3f6bd55dcc34dfc149dca655fc1558830b42a8d0';
