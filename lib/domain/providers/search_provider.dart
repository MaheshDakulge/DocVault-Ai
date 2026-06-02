import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/remote/api_service.dart';

// ── Search query state ─────────────────────────────────────────────────────

final searchQueryProvider = StateProvider<String>((ref) => '');

// ── Search results (Backend API) ───────────────────────────────────────────

/// Debounced search results from the fast backend Search API
final searchResultsProvider = FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  final query = ref.watch(searchQueryProvider);
  if (query.trim().isEmpty) return [];

  // Debouncing logic could go here via Future.delayed, but keeping simple for now
  final api = ApiService();
  final response = await api.searchDocuments(query.trim());
  
  if (response['results'] != null) {
    return List<Map<String, dynamic>>.from(response['results']);
  }
  return [];
});

// ── Recent searches (in-memory, session only) ─────────────────────────────

class RecentSearchesNotifier extends Notifier<List<String>> {
  static const int _maxRecent = 8;

  @override
  List<String> build() => [];

  void add(String query) {
    if (query.trim().isEmpty) return;
    final updated = [
      query,
      ...state.where((s) => s != query),
    ].take(_maxRecent).toList();
    state = updated;
  }

  void clear() => state = [];

  void remove(String query) {
    state = state.where((s) => s != query).toList();
  }
}

final recentSearchesProvider = NotifierProvider<RecentSearchesNotifier, List<String>>(
  RecentSearchesNotifier.new,
);
