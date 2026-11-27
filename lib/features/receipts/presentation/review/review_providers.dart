import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/db/app_database.dart';
import '../../../../core/db/db_providers.dart';

/// Categories for the review form's chips, in display order.
///
/// Written without codegen: riverpod_generator can't resolve Drift's
/// generated row types (`CategoryRow`) while build_runner regenerates them.
final reviewCategoriesProvider = StreamProvider.autoDispose<List<CategoryRow>>(
  (ref) => ref.watch(categoriesDaoProvider).watchAll(),
);
