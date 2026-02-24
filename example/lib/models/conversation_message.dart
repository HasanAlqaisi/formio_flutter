/// Conversation message model for the chat interface.
///
/// Represents a single message in the voice-chat conversation,
/// which can originate from the bot, user, or system.
library;

enum MessageSender { bot, user, system }

class ConversationMessage {
  /// Who sent the message.
  final MessageSender sender;

  /// Display text of the message (shown in chat bubble).
  final String text;

  /// Optional shorter text for TTS. When non-null, TTS speaks this
  /// instead of [text]. Useful for long option lists where the full
  /// list is shown in the bubble but not read aloud.
  final String? ttsText;

  /// When the message was created.
  final DateTime timestamp;

  /// The Form.io component key associated with this message (if any).
  final String? componentKey;

  /// The Form.io component type associated with this message (if any).
  final String? componentType;

  const ConversationMessage({
    required this.sender,
    required this.text,
    this.ttsText,
    required this.timestamp,
    this.componentKey,
    this.componentType,
  });

  /// Creates a bot question message.
  factory ConversationMessage.botQuestion({
    required String text,
    String? ttsText,
    required String componentKey,
    required String componentType,
  }) {
    return ConversationMessage(
      sender: MessageSender.bot,
      text: text,
      ttsText: ttsText,
      timestamp: DateTime.now(),
      componentKey: componentKey,
      componentType: componentType,
    );
  }

  /// Creates a user answer message.
  factory ConversationMessage.userAnswer({required String text}) {
    return ConversationMessage(
      sender: MessageSender.user,
      text: text,
      timestamp: DateTime.now(),
    );
  }

  /// Creates a system notification message.
  factory ConversationMessage.system({required String text}) {
    return ConversationMessage(
      sender: MessageSender.system,
      text: text,
      timestamp: DateTime.now(),
    );
  }
}
