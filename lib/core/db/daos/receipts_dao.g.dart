// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'receipts_dao.dart';

// ignore_for_file: type=lint
mixin _$ReceiptsDaoMixin on DatabaseAccessor<AppDatabase> {
  $CategoriesTable get categories => attachedDatabase.categories;
  $ReceiptsTable get receipts => attachedDatabase.receipts;
  ReceiptsDaoManager get managers => ReceiptsDaoManager(this);
}

class ReceiptsDaoManager {
  final _$ReceiptsDaoMixin _db;
  ReceiptsDaoManager(this._db);
  $$CategoriesTableTableManager get categories =>
      $$CategoriesTableTableManager(_db.attachedDatabase, _db.categories);
  $$ReceiptsTableTableManager get receipts =>
      $$ReceiptsTableTableManager(_db.attachedDatabase, _db.receipts);
}
