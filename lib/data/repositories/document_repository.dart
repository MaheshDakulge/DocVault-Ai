import 'dart:io';
import 'package:drift/drift.dart' as drift;
import '../../domain/models/document_model.dart';
import '../../domain/models/field_model.dart';
import '../../core/security/sha256_hasher.dart';
import '../local/daos/document_dao.dart';
import '../local/daos/field_dao.dart';
import '../local/daos/fts_dao.dart';
import '../local/daos/sync_queue_dao.dart';
import '../local/database.dart';
import '../local/file_system_service.dart';
import '../remote/api_service.dart';

/// Document repository — the single source of truth.
///
/// All reads are 100% offline (SQLite).
/// Writes go to SQLite first, then sync queue for background upload.
class DocumentRepository {
  final DocumentDao _documentDao;
  final FieldDao _fieldDao;
  final FtsDao _ftsDao;
  final SyncQueueDao _syncQueueDao;
  final ApiService _apiService;

  DocumentRepository({
    required DocumentDao documentDao,
    required FieldDao fieldDao,
    required FtsDao ftsDao,
    required SyncQueueDao syncQueueDao,
    required ApiService apiService,
  })  : _documentDao = documentDao,
        _fieldDao = fieldDao,
        _ftsDao = ftsDao,
        _syncQueueDao = syncQueueDao,
        _apiService = apiService;

  // ── READ (all offline) ────────────────────────────────────────────────────

  Stream<List<DocumentModel>> watchAll() =>
      _documentDao.watchAllDocuments().map(
            (list) => list.map(_toModel).toList(),
          );

  Future<List<DocumentModel>> getAll() async {
    final docs = await _documentDao.getAllDocuments();
    return docs.map(_toModel).toList();
  }

  Future<DocumentModel?> getById(String id) async {
    final doc = await _documentDao.getById(id);
    return doc != null ? _toModel(doc) : null;
  }

  Future<List<DocumentModel>> getByCategory(String category) async {
    final docs = await _documentDao.getByCategory(category);
    return docs.map(_toModel).toList();
  }

  Future<List<DocumentModel>> getExpiringSoon({int days = 30}) async {
    final docs = await _documentDao.getExpiringWithin(days);
    return docs.map(_toModel).toList();
  }

  Future<List<FieldModel>> getFieldsForDocument(String docId) async {
    final fields = await _fieldDao.getFieldsForDocument(docId);
    return fields.map(_toFieldModel).toList();
  }

  Future<List<DocumentModel>> search(String query) async {
    final ids = await _ftsDao.search(query);
    final results = <DocumentModel>[];
    for (final id in ids) {
      final doc = await getById(id);
      if (doc != null) results.add(doc);
    }
    return results;
  }

  // ── SCAN & SAVE ───────────────────────────────────────────────────────────

  /// Full scan flow:
  /// 1. Save image to device file system
  /// 2. Call FastAPI → Gemini Vision (needs internet)
  /// 3. Compute SHA-256 tamper hash
  /// 4. Save metadata + fields to SQLite (offline after this)
  /// 5. Enqueue for background cloud sync
  Future<DocumentModel> scanAndSave(String tempImagePath) async {
    // Step 1: persist image to permanent location
    final imageBytes = await File(tempImagePath).readAsBytes();
    final saved = await FileSystemService.saveScannedImage(imageBytes);

    // Step 2: Gemini API call
    final result = await _apiService.scanDocument(File(tempImagePath));
    final data = result;

    // Step 3: SHA-256 tamper hash
    final hash = Sha256Hasher.hashBytes(imageBytes);

    // Step 4: build companion and insert
    final companion = DocumentsCompanion(
      id: drift.Value(saved.docId),
      filename: drift.Value('doc_${saved.docId.substring(0, 8)}.jpg'),
      localPath: drift.Value(saved.imagePath),
      thumbPath: drift.Value(saved.thumbPath),
      category: drift.Value((data['category'] as String?) ?? 'Other'),
      subcategory: drift.Value(data['subcategory'] as String?),
      documentDate: drift.Value(data['document_date'] as String?),
      expiryDate: drift.Value(data['expiry_date'] as String?),
      confidence: drift.Value((data['confidence'] as num?)?.toDouble() ?? 0.0),
      fileHash: drift.Value(hash),
      rawText: drift.Value(data['raw_text'] as String?),
    );
    await _documentDao.insertDocument(companion);

    // Insert extracted fields
    final fields = ((data['fields'] as List?) ?? const [])
        .whereType<Map>()
        .map((field) => Map<String, dynamic>.from(field))
        .toList();
    if (fields.isNotEmpty) {
      await _fieldDao.insertAllFields(
        fields.map((field) => DocumentFieldsCompanion(
          documentId: drift.Value(saved.docId),
          label: drift.Value(field['label']?.toString() ?? ''),
          value: drift.Value(field['value']?.toString() ?? ''),
          confidence: drift.Value(
            (field['confidence'] as num?)?.toDouble() ?? 0.0,
          ),
        )).toList(),
      );
    }

    // Refresh FTS with all field text
    final allText = fields.map((field) => field['value']).join(' ');
    await _ftsDao.refreshFtsEntry(saved.docId, allText);

    // Step 5: enqueue sync
    await _syncQueueDao.enqueue(
      tableName: 'documents',
      recordId: saved.docId,
      operation: 'INSERT',
    );

    return (await getById(saved.docId))!;
  }

  // ── DELETE ────────────────────────────────────────────────────────────────

  Future<void> delete(String docId) async {
    final doc = await _documentDao.getById(docId);
    if (doc != null) {
      await FileSystemService.deleteDocumentFiles(docId);
    }
    await _ftsDao.deleteFtsEntry(docId);
    await _fieldDao.deleteFieldsForDocument(docId);
    await _documentDao.deleteDocument(docId);
    await _syncQueueDao.enqueue(
      tableName: 'documents',
      recordId: docId,
      operation: 'DELETE',
    );
  }

  // ── TAMPER CHECK ──────────────────────────────────────────────────────────

  /// Returns true if the local file matches its stored SHA-256 hash.
  Future<bool> verifyIntegrity(DocumentModel doc) async {
    if (doc.fileHash == null) return true; // not hashed — skip
    final bytes = await FileSystemService.readImageBytes(doc.localPath);
    if (bytes == null) return false;
    return Sha256Hasher.verify(bytes, doc.fileHash!);
  }

  // ── MAPPERS ───────────────────────────────────────────────────────────────

  DocumentModel _toModel(Document d) => DocumentModel(
        id: d.id,
        filename: d.filename,
        localPath: d.localPath,
        thumbPath: d.thumbPath,
        category: d.category,
        subcategory: d.subcategory,
        documentDate: d.documentDate != null
            ? DateTime.tryParse(d.documentDate!)
            : null,
        expiryDate: d.expiryDate != null
            ? DateTime.tryParse(d.expiryDate!)
            : null,
        confidence: d.confidence,
        fileHash: d.fileHash,
        isTampered: d.isTampered,
        rawText: d.rawText,
        isSynced: d.isSynced,
        createdAt: d.createdAt,
        updatedAt: d.updatedAt,
      );

  FieldModel _toFieldModel(DocumentField f) => FieldModel(
        id: f.id,
        documentId: f.documentId,
        label: f.label,
        value: f.value,
        confidence: f.confidence,
        isCopyable: f.isCopyable,
      );
}
