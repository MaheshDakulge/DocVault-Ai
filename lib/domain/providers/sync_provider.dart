import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/remote/supabase_sync_service.dart';
import 'database_providers.dart';

// ── Service provider ───────────────────────────────────────────────────────

final syncServiceProvider = Provider<SupabaseSyncService>((ref) {
  return SupabaseSyncService(
    documentDao: ref.watch(documentDaoProvider),
    fieldDao: ref.watch(fieldDaoProvider),
    syncQueueDao: ref.watch(databaseProvider).syncQueueDao,
  );
});

// ── Sync state ─────────────────────────────────────────────────────────────

enum SyncStatus { idle, syncing, success, error }

class SyncState {
  final SyncStatus status;
  final int lastSyncedCount;
  final String? errorMessage;
  final DateTime? lastSyncTime;

  const SyncState({
    this.status = SyncStatus.idle,
    this.lastSyncedCount = 0,
    this.errorMessage,
    this.lastSyncTime,
  });

  SyncState copyWith({
    SyncStatus? status,
    int? lastSyncedCount,
    String? errorMessage,
    DateTime? lastSyncTime,
  }) =>
      SyncState(
        status: status ?? this.status,
        lastSyncedCount: lastSyncedCount ?? this.lastSyncedCount,
        errorMessage: errorMessage ?? this.errorMessage,
        lastSyncTime: lastSyncTime ?? this.lastSyncTime,
      );

  bool get isSyncing => status == SyncStatus.syncing;
}

// ── Sync notifier ──────────────────────────────────────────────────────────

class SyncNotifier extends Notifier<SyncState> {
  @override
  SyncState build() => const SyncState();

  /// Trigger a background sync cycle. Safe to call multiple times.
  Future<void> sync() async {
    if (state.isSyncing) return;

    state = state.copyWith(status: SyncStatus.syncing);

    try {
      final service = ref.read(syncServiceProvider);
      final count = await service.sync();
      state = state.copyWith(
        status: SyncStatus.success,
        lastSyncedCount: count,
        lastSyncTime: DateTime.now(),
        errorMessage: null,
      );
    } catch (e) {
      state = state.copyWith(
        status: SyncStatus.error,
        errorMessage: e.toString(),
      );
    }
  }

  void reset() => state = const SyncState();
}

final syncProvider = NotifierProvider<SyncNotifier, SyncState>(
  SyncNotifier.new,
);

/// Pending sync count — badge number on the settings icon.
final pendingSyncCountProvider = FutureProvider<int>((ref) async {
  final db = ref.watch(databaseProvider);
  final pending = await db.syncQueueDao.getPending();
  return pending.length;
});
