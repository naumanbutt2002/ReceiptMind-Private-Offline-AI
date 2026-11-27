import 'package:go_router/go_router.dart';

import 'presentation/categories_screen.dart';

/// Full location of the categories screen.
const categoriesLocation = '/settings/categories';

/// Routes of the categories feature, to nest under the `/settings` route:
///
/// ```dart
/// GoRoute(path: Routes.settings, builder: ..., routes: categoriesRoutes)
/// ```
final List<RouteBase> categoriesRoutes = [
  GoRoute(
    path: 'categories',
    builder: (context, state) => const CategoriesScreen(),
  ),
];
