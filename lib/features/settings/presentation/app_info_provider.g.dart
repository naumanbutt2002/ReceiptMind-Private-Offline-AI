// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'app_info_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// App version and build number from the platform. Tests override this.

@ProviderFor(appVersion)
final appVersionProvider = AppVersionProvider._();

/// App version and build number from the platform. Tests override this.

final class AppVersionProvider
    extends
        $FunctionalProvider<
          AsyncValue<AppVersion>,
          AppVersion,
          FutureOr<AppVersion>
        >
    with $FutureModifier<AppVersion>, $FutureProvider<AppVersion> {
  /// App version and build number from the platform. Tests override this.
  AppVersionProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'appVersionProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$appVersionHash();

  @$internal
  @override
  $FutureProviderElement<AppVersion> $createElement($ProviderPointer pointer) =>
      $FutureProviderElement(pointer);

  @override
  FutureOr<AppVersion> create(Ref ref) {
    return appVersion(ref);
  }
}

String _$appVersionHash() => r'8415d89581065e64449b296f0eb493f525282ec2';
