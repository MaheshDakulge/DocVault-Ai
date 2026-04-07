import 'package:drift/drift.dart';
import '../database.dart';

part 'sync_queue_dao.g.dart';

/// Manages the sync_queue table — the change log for background Supabase sync
/// Device-wins conflict resolution: local edits always override cloud.
@DriftAccessor(tables: [SyncQueue])
class SyncQueueDao extends DatabaseAccessor<AppDatabase> with _$SyncQueueDaoMixin {
  SyncQueueDao(super.db);

  /// Get all pending operations waiting to be pushed to Supabase
  Future<List<SyncQueueData>> getPending() =>
      (select(syncQueue)..where((s) => s.isPending.equals(true))).get();

  /// Log a new change event (called automatically by DocumentRepository)
  Future<void> enqueue({
    required String tableName,
    required String recordId,
    required String operation, // INSERT | UPDATE | DELETE
  }) =>
      into(syncQueue).insert(SyncQueueCompanion.insert(
        targetTable: tableName,
        recordId: recordId,
        operation: operation,
      ));

  /// Mark a queued item as synced (remove from pending)
  Future<void> markDone(int id) =>
      (update(syncQueue)..where((s) => s.id.equals(id)))
          .write(const SyncQueueCompanion(isPending: Value(false)));

  /// Bulk mark all items as done after successful sync batch
  Future<void> markAllDone(List<int> ids) =>
      batch((b) {
        for (final id in ids) {
          b.update(
            syncQueue,
            const SyncQueueCompanion(isPending: Value(false)),
            where: (s) => s.id.equals(id),
          );
        }
      });

  /// Delete all completed sync entries (housekeeping)
  Future<void> clearCompleted() =>
      (delete(syncQueue)..where((s) => s.isPending.equals(false))).go();
}
