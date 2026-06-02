import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/remote/api_service.dart';
import '../../data/repositories/document_repository.dart';
import '../models/document_model.dart';
import '../models/field_model.dart';
import 'database_providers.dart';

// ── Repository provider ────────────────────────────────────────────────────

final documentRepositoryProvider = Provider<DocumentRepository>((ref) {
  return DocumentRepository(
    documentDao: ref.watch(documentDaoProvider),
    fieldDao: ref.watch(fieldDaoProvider),
    ftsDao: ref.watch(ftsDaoProvider),
    syncQueueDao: ref.watch(databaseProvider).syncQueueDao,
    apiService: ApiService(),
  );
});

// ── Document list stream ───────────────────────────────────────────────────

/// Reactive stream of all documents (offline, always available).
final documentsStreamProvider = StreamProvider<List<DocumentModel>>((ref) {
  return ref.watch(documentRepositoryProvider).watchAll();
});

/// Documents filtered by category.
final documentsByCategoryProvider =
    StreamProvider.family<List<DocumentModel>, String?>((ref, category) {
  return ref.watch(documentRepositoryProvider).watchAll().map(
        (docs) => category == null
            ? docs
            : docs.where((d) => d.category == category).toList(),
      );
});

// ── Single document ────────────────────────────────────────────────────────

final documentByIdProvider =
    FutureProvider.family<DocumentModel?, String>((ref, id) async {
  return ref.watch(documentRepositoryProvider).getById(id);
});

final documentFieldsProvider =
    FutureProvider.family<List<FieldModel>, String>((ref, docId) async {
  return ref.watch(documentRepositoryProvider).getFieldsForDocument(docId);
});

// ── Expiry alerts ──────────────────────────────────────────────────────────

final expiringDocumentsProvider =
    FutureProvider<List<DocumentModel>>((ref) async {
  return ref.watch(documentRepositoryProvider).getExpiringSoon(days: 30);
});

// ── Scan notifier ──────────────────────────────────────────────────────────

class ScanNotifier extends AsyncNotifier<DocumentModel?> {
  @override
  Future<DocumentModel?> build() async => null;

  Future<DocumentModel?> scan(String tempImagePath) async {
    state = const AsyncLoading();
    final repo = ref.read(documentRepositoryProvider);
    state = await AsyncValue.guard(() => repo.scanAndSave(tempImagePath));
    return state.valueOrNull;
  }

  void reset() => state = const AsyncData(null);
}

final scanNotifierProvider =
    AsyncNotifierProvider<ScanNotifier, DocumentModel?>(ScanNotifier.new);

// ── Document deletion ──────────────────────────────────────────────────────

class DocumentDeleteNotifier extends AsyncNotifier<void> {
  @override
  Future<void> build() async {}

  Future<void> delete(String docId) async {
    state = const AsyncLoading();
    final repo = ref.read(documentRepositoryProvider);
    state = await AsyncValue.guard(() => repo.delete(docId));
  }
}

final documentDeleteProvider =
    AsyncNotifierProvider<DocumentDeleteNotifier, void>(
  DocumentDeleteNotifier.new,
);

// ── Category summary ───────────────────────────────────────────────────────

/// Map of {category → count} for the home screen header stats.
final categoryCountsProvider =
    Provider<Map<String, int>>((ref) {
  final docs = ref.watch(documentsStreamProvider).valueOrNull ?? [];
  final counts = <String, int>{};
  for (final doc in docs) {
    counts[doc.category] = (counts[doc.category] ?? 0) + 1;
  }
  return counts;
});
