import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../../core/theme/colors.dart';
import '../../../domain/models/chat_message_model.dart';

/// A single chat bubble — user (right-aligned, primary) or
/// assistant (left-aligned, surface).
class ChatBubble extends StatelessWidget {
  final ChatMessageModel message;

  const ChatBubble({super.key, required this.message});

  @override
  Widget build(BuildContext context) {
    final isUser = message.isUser;
    final theme  = Theme.of(context);

    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.78,
        ),
        child: Container(
          margin: EdgeInsets.only(
            top: 4,
            bottom: 4,
            left: isUser ? 48 : 0,
            right: isUser ? 0 : 48,
          ),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: isUser ? AppColors.primary : AppColors.surfaceContainerLowest,
            borderRadius: BorderRadius.only(
              topLeft: const Radius.circular(18),
              topRight: const Radius.circular(18),
              bottomLeft: Radius.circular(isUser ? 18 : 4),
              bottomRight: Radius.circular(isUser ? 4 : 18),
            ),
            boxShadow: [
              BoxShadow(
                color: AppColors.onSurface.withValues(alpha: 0.04),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: message.isLoading
              ? _ThinkingIndicator()
              : Text(
                  message.message,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: isUser ? AppColors.onPrimary : AppColors.onSurface,
                    height: 1.45,
                  ),
                ),
        ),
      ),
    )
        .animate()
        .fadeIn(duration: 200.ms)
        .slideY(begin: 0.08, end: 0, duration: 200.ms, curve: Curves.easeOut);
  }
}

/// Animated three-dot typing indicator shown while the AI is responding.
class _ThinkingIndicator extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(3, (i) {
        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 3),
          width: 7,
          height: 7,
          decoration: const BoxDecoration(
            color: AppColors.onSurfaceVariant,
            shape: BoxShape.circle,
          ),
        )
            .animate(onPlay: (c) => c.repeat(reverse: true))
            .scaleXY(
              begin: 0.6,
              end: 1.0,
              duration: 500.ms,
              delay: Duration(milliseconds: i * 140),
              curve: Curves.easeInOut,
            );
      }),
    );
  }
}
