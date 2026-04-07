import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

import 'daos/document_dao.dart';
import 'daos/field_dao.dart';
import 'daos/fts_dao.dart';
import 'daos/sync_queue_dao.dart';

part 'database.g.dart';

// ── TABLE: documents ──────────────────────────────────────────────────────────
/// Primary metadata table. Mirrors Supabase schema (same columns + user_id).
class Documents extends Table {
  TextColumn get id          => text()();                         // UUID
  TextColumn get filename    => text()();                         // e.g. "aadhaar.jpg"
  TextColumn get localPath   => text()();                         // /docs/{uuid}.jpg
  TextColumn get thumbPath   => text().nullable()();              // /docs/{uuid}_thumb.jpg
  TextColumn get category    => text()();                         // "Identity", "Education" …
  TextColumn get subcategory => text().nullable()();
  TextColumn get documentDate=> text().nullable()();              // ISO8601
  TextColumn get expiryDate  => text().nullable()();              // ISO8601
  RealColumn get confidence  => real().withDefault(const Constant(0.0))();
  TextColumn get fileHash    => text().nullable()();              // SHA-256
  BoolColumn get isTampered  => boolean().withDefault(const Constant(false))();
  TextColumn get rawText     => text().nullable()();              // Raw OCR dump
  BoolColumn get isSynced    => boolean().withDefault(const Constant(false))();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {id};
}

// ── TABLE: document_fields ────────────────────────────────────────────────────
/// Each field extracted by Gemini (e.g. "Name", "DOB", "Aadhaar No.")
class DocumentFields extends Table {
  IntColumn get id          => integer().autoIncrement()();
  TextColumn get documentId => text().references(Documents, #id)();
  TextColumn get label      => text()();     // "Aadhaar Number"
  TextColumn get value      => text()();     // "1234 5678 9012"
  RealColumn get confidence => real().withDefault(const Constant(0.0))();
  BoolColumn get isCopyable => boolean().withDefault(const Constant(true))();
}

// ── TABLE: sync_queue ─────────────────────────────────────────────────────────
/// Change log for background sync to Supabase PostgreSQL
class SyncQueue extends Table {
  IntColumn get id         => integer().autoIncrement()();
  TextColumn get targetTable => text()();      // "documents" | "document_fields"
  TextColumn get recordId  => text()();      // UUID
  TextColumn get operation => text()();      // "INSERT" | "UPDATE" | "DELETE"
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  BoolColumn get isPending => boolean().withDefault(const Constant(true))();
}

// ── TABLE: chat_history ───────────────────────────────────────────────────────
/// Local-only chat messages — never synced to cloud
class ChatHistory extends Table {
  IntColumn get id       => integer().autoIncrement()();
  TextColumn get role    => text()();    // "user" | "assistant"
  TextColumn get message => text()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
}

// ── DATABASE ──────────────────────────────────────────────────────────────────
@DriftDatabase(
  tables: [Documents, DocumentFields, SyncQueue, ChatHistory],
  daos: [DocumentDao, FieldDao, FtsDao, SyncQueueDao],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());

  @override
  int get schemaVersion => 1;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (m) async {
      await m.createAll();

      // ── Create FTS5 virtual table for offline full-text search ────────────
      await customStatement('''
        CREATE VIRTUAL TABLE IF NOT EXISTS documents_fts
        USING fts5(
          doc_id,
          all_text,
          content='documents',
          content_rowid='rowid'
        );
      ''');

      // ── Triggers to keep FTS in sync with documents table ────────────────
      await customStatement('''
        CREATE TRIGGER IF NOT EXISTS documents_fts_insert
        AFTER INSERT ON documents BEGIN
          INSERT INTO documents_fts(rowid, doc_id, all_text)
          VALUES (new.rowid, new.id, COALESCE(new.raw_text, ''));
        END;
      ''');
      await customStatement('''
        CREATE TRIGGER IF NOT EXISTS documents_fts_update
        AFTER UPDATE ON documents BEGIN
          UPDATE documents_fts SET all_text = COALESCE(new.raw_text, '')
          WHERE doc_id = new.id;
        END;
      ''');
      await customStatement('''
        CREATE TRIGGER IF NOT EXISTS documents_fts_delete
        AFTER DELETE ON documents BEGIN
          DELETE FROM documents_fts WHERE doc_id = old.id;
        END;
      ''');
    },
  );

  static QueryExecutor _openConnection() {
    return driftDatabase(name: 'digisafe_vault');
  }
}
