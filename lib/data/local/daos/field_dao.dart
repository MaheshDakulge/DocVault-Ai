import 'package:drift/drift.dart';
import '../database.dart';

part 'field_dao.g.dart';

/// CRUD for document_fields table (extracted key-value pairs from Gemini)
@DriftAccessor(tables: [DocumentFields])
class FieldDao extends DatabaseAccessor<AppDatabase> with _$FieldDaoMixin {
  FieldDao(super.db);

  /// Get all fields for a given document
  Future<List<DocumentField>> getFieldsForDocument(String docId) =>
      (select(documentFields)..where((f) => f.documentId.equals(docId))).get();

  /// Stream fields for real-time document viewer
  Stream<List<DocumentField>> watchFieldsForDocument(String docId) =>
      (select(documentFields)..where((f) => f.documentId.equals(docId))).watch();

  /// Insert a single extracted field
  Future<void> insertField(DocumentFieldsCompanion entry) =>
      into(documentFields).insert(entry, mode: InsertMode.insertOrReplace);

  /// Bulk insert all fields for a document at once (after Gemini scan)
  Future<void> insertAllFields(List<DocumentFieldsCompanion> entries) =>
      batch((b) => b.insertAll(documentFields, entries, mode: InsertMode.insertOrReplace));

  /// Delete all fields for a document (used when re-scanning)
  Future<void> deleteFieldsForDocument(String docId) =>
      (delete(documentFields)..where((f) => f.documentId.equals(docId))).go();
}
