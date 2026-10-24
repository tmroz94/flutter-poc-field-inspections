import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

part 'app_database.g.dart';

/// Wizard drafts, one row per wizard (`new` or an inspection id), stored as
/// JSON so the draft shape can change without migrations during the PoC.
class Drafts extends Table {
  TextColumn get key => text()();
  TextColumn get json => text()();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column<Object>> get primaryKey => {key};
}

/// Writes waiting for the server (offline submit), sent in order by SyncService.
class Outbox extends Table {
  IntColumn get id => integer().autoIncrement()();

  /// `create` or `update`.
  TextColumn get kind => text()();

  /// Inspection id for updates; null for creates.
  TextColumn get inspectionId => text().nullable()();
  TextColumn get site => text()();
  TextColumn get body => text()();
  DateTimeColumn get createdAt => dateTime()();
  IntColumn get attempts => integer().withDefault(const Constant(0))();

  /// Set when the server rejected the write (not for network errors).
  TextColumn get lastError => text().nullable()();
}

/// SQLite on iOS and Android; SQLite compiled to WebAssembly on the web
/// (`web/sqlite3.wasm` + `web/drift_worker.js`, from the drift 2.35.3 release).
@DriftDatabase(tables: [Drafts, Outbox])
class AppDatabase extends _$AppDatabase {
  AppDatabase([QueryExecutor? executor]) : super(executor ?? _open());

  @override
  int get schemaVersion => 1;

  static QueryExecutor _open() => driftDatabase(
    name: 'field_inspections',
    web: DriftWebOptions(sqlite3Wasm: Uri.parse('sqlite3.wasm'), driftWorker: Uri.parse('drift_worker.js')),
  );
}
