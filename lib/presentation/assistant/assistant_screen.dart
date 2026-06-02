import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/colors.dart';
import '../../core/router/route_names.dart';
import '../../domain/providers/assistant_provider.dart';
import '../../domain/models/chat_message_model.dart';
import '../common_widgets/vault_app_bar.dart';
import 'widgets/chat_bubble.dart';

class AssistantScreen extends ConsumerStatefulWidget {
  const AssistantScreen({super.key});

  @override
  ConsumerState<AssistantScreen> createState() => _AssistantScreenState();
}

class _AssistantScreenState extends ConsumerState<AssistantScreen> {
  final _ctrl       = TextEditingController();
  final _scrollCtrl = ScrollController();
  bool _sending     = false;

  static const _suggestions = [
    'What is my Aadhaar number?',
    'When does my passport expire?',
    'Show me all Identity documents',
    'Which documents expire this year?',
  ];

  @override
  void dispose() {
    _ctrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final text = _ctrl.text.trim();
    if (text.isEmpty || _sending) return;

    _ctrl.clear();
    setState(() => _sending = true);
    await ref.read(assistantProvider.notifier).sendMessage(text);
    setState(() => _sending = false);
    _scrollToBottom();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollCtrl.hasClients) {
        _scrollCtrl.animateTo(
          _scrollCtrl.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final messages = ref.watch(assistantProvider);
    final theme    = Theme.of(context);

    // Scroll when new messages arrive
    ref.listen<List<ChatMessageModel>>(assistantProvider, (_, __) {
      _scrollToBottom();
    });

    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: VaultAppBar(
        title: 'AI Assistant',
        subtitle: 'Powered by Gemini 1.5 Flash',
        showBackButton: false,
        actions: [
          if (messages.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.delete_sweep_rounded,
                  color: AppColors.onSurfaceVariant),
              onPressed: () =>
                  ref.read(assistantProvider.notifier).clear(),
              tooltip: 'Clear conversation',
            ),
          IconButton(
            icon: const Icon(Icons.auto_awesome_motion_rounded,
                color: AppColors.primary),
            onPressed: () => context.push(RouteNames.eligibility),
            tooltip: 'Check scheme eligibility',
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: Column(
        children: [
          // ── Chat area ──────────────────────────────────────────────────
          Expanded(
            child: messages.isEmpty
                ? _WelcomeView(
                    suggestions: _suggestions,
                    onSuggestion: (s) {
                      _ctrl.text = s;
                      _send();
                    },
                  )
                : ListView.builder(
                    controller: _scrollCtrl,
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                    itemCount: messages.length,
                    itemBuilder: (_, i) => ChatBubble(message: messages[i]),
                  ),
          ),

          // ── Input bar ──────────────────────────────────────────────────
          Container(
            color: AppColors.glass,
            padding: EdgeInsets.only(
              left: 16,
              right: 16,
              top: 10,
              bottom: MediaQuery.of(context).viewInsets.bottom + 16,
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _ctrl,
                    minLines: 1,
                    maxLines: 4,
                    textInputAction: TextInputAction.send,
                    onSubmitted: (_) => _send(),
                    decoration: InputDecoration(
                      hintText: 'Ask about your documents…',
                      filled: true,
                      fillColor: AppColors.surfaceContainerLow,
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 12),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  child: Material(
                    color: _sending
                        ? AppColors.outlineVariant
                        : AppColors.primary,
                    borderRadius: BorderRadius.circular(24),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(24),
                      onTap: _sending ? null : _send,
                      child: const Padding(
                        padding: EdgeInsets.all(14),
                        child: Icon(Icons.send_rounded,
                            color: Colors.white, size: 20),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _WelcomeView extends StatelessWidget {
  final List<String> suggestions;
  final ValueChanged<String> onSuggestion;

  const _WelcomeView({
    required this.suggestions,
    required this.onSuggestion,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 32, 20, 16),
      children: [
        // ── Hero ──────────────────────────────────────────────────────────
        Center(
          child: Container(
            width: 72,
            height: 72,
            decoration: const BoxDecoration(
              color: AppColors.primaryFixed,
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.auto_awesome_rounded,
                color: AppColors.primary, size: 36),
          ),
        ),
        const SizedBox(height: 16),
        Text(
          'Ask me anything\nabout your documents',
          textAlign: TextAlign.center,
          style: theme.textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.w800,
            height: 1.2,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Works offline for basic queries.\nNeeds internet for eligibility checks.',
          textAlign: TextAlign.center,
          style: theme.textTheme.bodySmall?.copyWith(
            color: AppColors.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 32),

        // ── Suggestion chips ──────────────────────────────────────────────
        Text(
          'Try asking',
          style: theme.textTheme.labelMedium?.copyWith(
            fontWeight: FontWeight.w600,
            color: AppColors.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 12),
        ...suggestions.map((s) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Material(
                color: AppColors.surfaceContainerLowest,
                borderRadius: BorderRadius.circular(12),
                child: InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: () => onSuggestion(s),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 14),
                    child: Row(
                      children: [
                        const Icon(Icons.chat_bubble_outline_rounded,
                            size: 16, color: AppColors.primary),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(s,
                              style: theme.textTheme.bodyMedium),
                        ),
                        const Icon(Icons.arrow_forward_ios_rounded,
                            size: 14,
                            color: AppColors.outlineVariant),
                      ],
                    ),
                  ),
                ),
              ),
            )),
      ],
    );
  }
}
