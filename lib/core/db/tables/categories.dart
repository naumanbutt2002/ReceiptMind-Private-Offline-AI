import 'package:drift/drift.dart';

/// Safety cap on a category name's length in UTF-16 code units, the unit
/// drift's length check counts (`String.length`, checked in Dart only; the
/// SQL schema has no length CHECK). The visible limit, 40 characters
/// (grapheme clusters), is enforced by the category editor. 40 of the longest
/// standard emoji sequences (about 20 code units each) still fit.
///
/// Keep in sync with the `withLength` below (drift_dev needs a literal).
const categoryNameMaxCodeUnits = 1000;

@DataClassName('CategoryRow')
class Categories extends Table {
  IntColumn get id => integer().autoIncrement()();

  /// See [categoryNameMaxCodeUnits] for why the cap is in code units.
  TextColumn get name => text().withLength(min: 1, max: 1000).unique()();

  /// Key into the app's curated icon map (keeps icon tree-shaking working).
  TextColumn get iconKey => text()();

  /// ARGB colour value.
  IntColumn get color => integer()();
  IntColumn get sortOrder => integer().withDefault(const Constant(0))();
}
