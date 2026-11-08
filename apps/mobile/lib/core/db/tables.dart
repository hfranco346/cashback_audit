import 'package:drift/drift.dart';

/// Cache tables store the API JSON payload as-is. The cache is a read model
/// for offline viewing and fast start-up; the backend stays the source of truth.

class CachedCards extends Table {
  TextColumn get id => text()();
  IntColumn get position => integer()();
  TextColumn get json => text()();

  @override
  Set<Column> get primaryKey => {id};
}

class CachedCategories extends Table {
  TextColumn get id => text()();
  IntColumn get position => integer()();
  TextColumn get json => text()();

  @override
  Set<Column> get primaryKey => {id};
}

class CachedMerchants extends Table {
  TextColumn get id => text()();
  IntColumn get position => integer()();
  TextColumn get json => text()();

  @override
  Set<Column> get primaryKey => {id};
}

/// Verification summaries (history list).
class CachedVerifications extends Table {
  TextColumn get id => text()();
  TextColumn get cardId => text()();
  DateTimeColumn get createdAt => dateTime()();
  TextColumn get json => text()();

  @override
  Set<Column> get primaryKey => {id};
}

/// Full verification objects (breakdown and transactions).
class CachedVerificationDetails extends Table {
  TextColumn get id => text()();
  TextColumn get json => text()();

  @override
  Set<Column> get primaryKey => {id};
}
