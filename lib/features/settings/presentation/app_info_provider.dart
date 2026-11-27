import 'package:package_info_plus/package_info_plus.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'app_info_provider.g.dart';

/// App version and build number from the platform. Tests override this.
@Riverpod(keepAlive: true)
Future<AppVersion> appVersion(Ref ref) async {
  final info = await PackageInfo.fromPlatform();
  return AppVersion(info.version, info.buildNumber);
}

/// `0.1.0` and `1`, from `version: 0.1.0+1` in pubspec.yaml.
final class AppVersion {
  const AppVersion(this.version, this.buildNumber);

  final String version;
  final String buildNumber;

  @override
  bool operator ==(Object other) =>
      other is AppVersion &&
      other.version == version &&
      other.buildNumber == buildNumber;

  @override
  int get hashCode => Object.hash(version, buildNumber);
}
