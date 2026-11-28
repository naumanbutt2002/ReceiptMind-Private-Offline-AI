// sqlite3 is not a direct dependency: it comes with drift / drift_flutter,
// whose `setup` callbacks hand us its database type.
import 'package:sqlite3/common.dart';

import '../text/search_fold.dart';

/// Name of the SQL function that applies [foldForSearch] to a text value.
/// `rm_fold(NULL)` is `NULL`; non-text values are folded as text.
const searchFoldFunction = 'rm_fold';

/// Registers the app's SQL functions on a freshly opened connection. Pass it
/// as the `setup` callback of every connection (device and tests), because
/// queries such as receipt search depend on it.
///
/// A top-level function so it can be sent to drift's background isolate.
void registerSearchFunctions(CommonDatabase db) {
  db.createFunction(
    functionName: searchFoldFunction,
    argumentCount: const AllowedArgumentCount(1),
    deterministic: true,
    function: _fold,
  );
}

Object? _fold(SqliteArguments args) {
  final value = args[0];
  return switch (value) {
    null => null,
    String() => foldForSearch(value),
    _ => foldForSearch(value.toString()),
  };
}
