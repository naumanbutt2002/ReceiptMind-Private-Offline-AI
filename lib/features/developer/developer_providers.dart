import 'package:path_provider/path_provider.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'application/fixture_exporter.dart';

part 'developer_providers.g.dart';

/// Writes and shares parser fixtures. Tests override it with a fake sharer
/// and a temporary directory.
@Riverpod(keepAlive: true)
FixtureExporter fixtureExporter(Ref ref) => const FixtureExporter(
  tempDirectory: getTemporaryDirectory,
  sharer: SharePlusFixtureSharer(),
);
