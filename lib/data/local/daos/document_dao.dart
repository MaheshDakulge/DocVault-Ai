import 'package:drift/drift.dart';
import '../database.dart';

part 'document_dao.g.dart';

/// All CRUD operations for the documents table
/// Read operations always serve from SQLite — 100% offline.
@DriftAccessor(tables: [Documents])
class DocumentDao extends DatabaseAccessor<AppDatabase> with _$DocumentDaoMixin {
  DocumentDao(super.db);

  // ── READ ──────────────────────────────────────────────────────────────────
  /// All documents ordered by creation date (newest first)
  Future<List<Document>> getAllDocuments() =>
      (select(documents)..orderBy([(d) => OrderingTerm.desc(d.createdAt)])).get();

  /// Stream for real-time UI updates
  Stream<List<Document>> watchAllDocuments() =>
      (select(documents)..orderBy([(d) => OrderingTerm.desc(d.createdAt)])).watch();

  /// Documents grouped by category
  Future<List<Document>> getByCategory(String category) =>
      (select(documents)..where((d) => d.category.equals(category))).get();

  /// Single document by UUID
  Future<Document?> getById(String id) =>
      (select(documents)..where((d) => d.id.equals(id))).getSingleOrNull();

  /// Documents whose expiry is within [days] days from today
  Future<List<Document>> getExpiringWithin(int days) async {
    final cutoff = DateTime.now().add(Duration(days: days)).toIso8601String();
    return (select(documents)
      ..where((d) => d.expiryDate.isNotNull())
      ..where((d) => d.expiryDate.isSmallerThanValue(cutoff)))
        .get();
  }

  /// All documents that haven't been synced to Supabase yet
  Future<List<Document>> getUnsynced() =>
      (select(documents)..where((d) => d.isSynced.equals(false))).get();

  // ── WRITE ─────────────────────────────────────────────────────────────────
  Future<void> insertDocument(DocumentsCompanion entry) =>
      into(documents).insert(entry, mode: InsertMode.insertOrReplace);

  Future<void> updateDocument(DocumentsCompanion entry) =>
      update(documents).replace(entry);

  Future<void> markAsSynced(String docId) =>
      (update(documents)..where((d) => d.id.equals(docId)))
          .write(const DocumentsCompanion(isSynced: Value(true)));

  Future<void> deleteDocument(String id) =>
      (delete(documents)..where((d) => d.id.equals(id))).go();
}
