import 'dart:io';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../local/daos/document_dao.dart';
import '../local/daos/field_dao.dart';
import '../local/daos/sync_queue_dao.dart';
import '../local/database.dart';
import 'supabase_client.dart';
import 'dart:developer' as dev;

/// Background sync service — pushes pending SQLite changes to Supabase.
///
/// Strategy: Device wins. Local edits always override cloud.
/// Called by [SyncProvider] when connectivity is restored.
class SupabaseSyncService {
  final DocumentDao _documentDao;
  final FieldDao _fieldDao;
  final SyncQueueDao _syncQueueDao;

  SupabaseSyncService({
    required DocumentDao documentDao,
    required FieldDao fieldDao,
    required SyncQueueDao syncQueueDao,
  })  : _documentDao = documentDao,
        _fieldDao = fieldDao,
        _syncQueueDao = syncQueueDao;

  final _client = SupabaseClientWrapper.client;

  /// Run a full sync cycle. Returns number of items synced.
  Future<int> sync() async {
    final userId = SupabaseClientWrapper.currentUser?.id;
    if (userId == null) return 0;

    final pending = await _syncQueueDao.getPending();
    if (pending.isEmpty) return 0;

    int synced = 0;
    final doneIds = <int>[];

    for (final item in pending) {
      try {
        await _processQueueItem(item, userId);
        doneIds.add(item.id);
        synced++;
      } catch (e) {
        dev.log('Sync failed for ${item.recordId}: $e', name: 'DocsVault/Sync');
      }
    }

    if (doneIds.isNotEmpty) {
      await _syncQueueDao.markAllDone(doneIds);
    }

    return synced;
  }

  Future<void> _processQueueItem(SyncQueueData item, String userId) async {
    switch (item.targetTable) {
      case 'documents':
        await _syncDocument(item, userId);
        break;
      case 'document_fields':
        await _syncField(item, userId);
        break;
    }
  }

  Future<void> _syncDocument(SyncQueueData item, String userId) async {
    switch (item.operation) {
      case 'INSERT':
      case 'UPDATE':
        final doc = await _documentDao.getById(item.recordId);
        if (doc == null) return;
        await _client.from('documents').upsert({
          ...doc.toJson(),
          'user_id': userId,
        });
        await _documentDao.markAsSynced(doc.id);
        break;
      case 'DELETE':
        await _client
            .from('documents')
            .delete()
            .eq('id', item.recordId)
            .eq('user_id', userId);
        break;
    }
  }

  Future<void> _syncField(SyncQueueData item, String userId) async {
    // Fields are synced by document, not individually
    final fields = await _fieldDao.getFieldsForDocument(item.recordId);
    if (fields.isEmpty) return;

    await _client.from('document_fields').upsert(
      fields.map((f) => f.toJson()).toList(),
    );
  }

  /// Upload a document image file to Supabase Storage.
  /// [localPath] → cloud path `{userId}/{docId}.jpg`
  Future<String?> uploadDocumentFile({
    required String userId,
    required String docId,
    required String localPath,
  }) async {
    try {
      final file  = File(localPath);
      if (!await file.exists()) return null;

      final cloudPath = '$userId/$docId.jpg';
      await SupabaseClientWrapper.docsBucket.upload(
        cloudPath,
        file,
        fileOptions: const FileOptions(upsert: true),
      );

      final signedUrl = await SupabaseClientWrapper.docsBucket
          .createSignedUrl(cloudPath, 60 * 60 * 24 * 7); // 7 days

      return signedUrl;
    } catch (e) {
      dev.log('File upload failed for $docId: $e', name: 'DocsVault/Sync');
      return null;
    }
  }
}
