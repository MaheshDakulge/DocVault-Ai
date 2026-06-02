import 'package:flutter/foundation.dart';

/// Role of a chat participant.
enum ChatRole { user, assistant }

/// A single chat message in the AI Assistant conversation.
@immutable
class ChatMessageModel {
  final int? id;
  final ChatRole role;
  final String message;
  final DateTime createdAt;
  final bool isLoading; // Optimistic UI: true while waiting for response

  const ChatMessageModel({
    this.id,
    required this.role,
    required this.message,
    required this.createdAt,
    this.isLoading = false,
  });

  /// Create a user message (sent by the user).
  factory ChatMessageModel.user(String message) => ChatMessageModel(
        role: ChatRole.user,
        message: message,
        createdAt: DateTime.now(),
      );

  /// Create a loading placeholder while the assistant is thinking.
  factory ChatMessageModel.loading() => ChatMessageModel(
        role: ChatRole.assistant,
        message: '',
        createdAt: DateTime.now(),
        isLoading: true,
      );

  /// Create an assistant response message.
  factory ChatMessageModel.assistant(String message) => ChatMessageModel(
        role: ChatRole.assistant,
        message: message,
        createdAt: DateTime.now(),
      );

  bool get isUser => role == ChatRole.user;
  bool get isAssistant => role == ChatRole.assistant;

  ChatMessageModel copyWith({
    int? id,
    String? message,
    bool? isLoading,
  }) =>
      ChatMessageModel(
        id: id ?? this.id,
        role: role,
        message: message ?? this.message,
        createdAt: createdAt,
        isLoading: isLoading ?? this.isLoading,
      );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ChatMessageModel &&
          other.id == id &&
          other.createdAt == createdAt);

  @override
  int get hashCode => Object.hash(id, createdAt);
}
