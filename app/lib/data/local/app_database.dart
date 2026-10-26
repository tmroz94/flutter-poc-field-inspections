import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

import '../../core/platform/capabilities.dart';

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

/// Photo and file bytes for drafts (camera, gallery, file picker, drop, paste).
class Blobs extends Table {
  TextColumn get id => text()();
  BlobColumn get data => blob()();
  TextColumn get mime => text()();
  DateTimeColumn get createdAt => dateTime()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

/// SQLite on iOS and Android; SQLite compiled to WebAssembly on the web
/// (`web/sqlite3.wasm` + `web/drift_worker.js`, from the drift 2.35.3 release).
@DriftDatabase(tables: [Drafts, Outbox, Blobs])
class AppDatabase extends _$AppDatabase {
  AppDatabase([QueryExecutor? executor]) : super(executor ?? _open());

  @override
  int get schemaVersion => 2;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onUpgrade: (m, from, to) async {
      if (from < 2) await m.createTable(blobs);
    },
  );

  /// Web only: the storage drift picked for this browser (shown in Diagnostics).
  /// OPFS when the page is cross-origin isolated, otherwise IndexedDB.
  static String? webStorage;

  static QueryExecutor _open() => driftDatabase(
    name: 'field_inspections',
    // Desktop: the app's support folder, not drift's default of Documents,
    // which there is the user's own folder (and may not exist on Linux).
    // Phones keep the default (inside the app's sandbox).
    native: Capabilities.current().isDesktop ? const DriftNativeOptions(databaseDirectory: getApplicationSupportDirectory) : null,
    web: DriftWebOptions(
      sqlite3Wasm: Uri.parse('sqlite3.wasm'),
      driftWorker: Uri.parse('drift_worker.js'),
      onResult: (r) {
        webStorage = switch (r.chosenImplementation.name) {
          final n when n.startsWith('opfs') => 'OPFS',
          final n when n.contains('IndexedDb') => 'IndexedDB',
          _ => 'in memory, not persisted',
        };
        if (r.missingFeatures.isNotEmpty) debugPrint('drift: ${r.chosenImplementation.name}, missing ${r.missingFeatures}');
      },
    ),
  );
}
