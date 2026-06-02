import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/remote/api_service.dart';
import '../models/chat_message_model.dart';
import 'document_provider.dart';

// ── Chat history notifier ──────────────────────────────────────────────────

class AssistantNotifier extends Notifier<List<ChatMessageModel>> {
  @override
  List<ChatMessageModel> build() => [];

  Future<void> sendMessage(String userMessage) async {
    if (userMessage.trim().isEmpty) return;

    // Add user bubble
    state = [...state, ChatMessageModel.user(userMessage)];

    // Add loading placeholder
    state = [...state, ChatMessageModel.loading()];

    try {
      // Collect all document fields as context
      final repo = ref.read(documentRepositoryProvider);
      final docs = await repo.getAll();
      final allFields = <Map<String, dynamic>>[];
      for (final doc in docs) {
        final fields = await repo.getFieldsForDocument(doc.id);
        allFields.addAll(
          fields.map((f) => {'label': f.label, 'value': f.value}),
        );
      }

      final apiService = ApiService();
      final result = await apiService.chatAssistant(userMessage, allFields);
      final answer = result['reply'] as String? ?? 'Sorry, I could not answer that.';

      // Replace loading with real response
      final updated = List<ChatMessageModel>.from(state)
        ..removeLast()
        ..add(ChatMessageModel.assistant(answer));
      state = updated;
    } catch (e) {
      final updated = List<ChatMessageModel>.from(state)
        ..removeLast()
        ..add(ChatMessageModel.assistant(
          'I could not reach the server. Please check your connection and try again.',
        ));
      state = updated;
    }
  }

  void clear() => state = [];
}

final assistantProvider =
    NotifierProvider<AssistantNotifier, List<ChatMessageModel>>(
  AssistantNotifier.new,
);

// ── Eligibility notifier ───────────────────────────────────────────────────

class EligibilityNotifier extends AsyncNotifier<List<Map<String, dynamic>>> {
  @override
  Future<List<Map<String, dynamic>>> build() async => [];

  Future<void> checkEligibility() async {
    state = const AsyncLoading();

    try {
      final repo = ref.read(documentRepositoryProvider);
      final docs = await repo.getAll();
      final allFields = <Map<String, dynamic>>[];
      for (final doc in docs) {
        final fields = await repo.getFieldsForDocument(doc.id);
        allFields.addAll(
          fields.map((f) => {'label': f.label, 'value': f.value}),
        );
      }

      final apiService = ApiService();
      final result = await apiService.checkEligibility(allFields);
      final schemes =
          (result['schemes'] as List?)?.cast<Map<String, dynamic>>() ?? [];
      state = AsyncData(schemes);
    } catch (e) {
      state = AsyncError(e, StackTrace.current);
    }
  }
}

final eligibilityProvider =
    AsyncNotifierProvider<EligibilityNotifier, List<Map<String, dynamic>>>(
  EligibilityNotifier.new,
);
