import 'package:go_router/go_router.dart';

import 'about_screen.dart';

/// Locations of the screens under `/settings`.
abstract final class SettingsRoutes {
  static const about = '/settings/about';

  /// Owned by the categories feature (M5).
  static const categories = '/settings/categories';
}

/// Child routes of `/settings`; add them to the `/settings` `GoRoute`'s
/// `routes:` list.
final List<RouteBase> settingsChildRoutes = [
  GoRoute(path: 'about', builder: (context, state) => const AboutScreen()),
];
