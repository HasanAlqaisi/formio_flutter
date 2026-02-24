/// Conversation message model for the chat interface.
///
/// Represents a single message in the voice-chat conversation,
/// which can originate from the bot, user, or system.
library;

enum MessageSender { bot, user, system }

class ConversationMessage {
  /// Who sent the message.
  final MessageSender sender;

  /// Display text of the message.
  final String text;

  /// When the message was created.
  final DateTime timestamp;

  /// The Form.io component key associated with this message (if any).
  final String? componentKey;

  /// The Form.io component type associated with this message (if any).
  final String? componentType;

  const ConversationMessage({
    required this.sender,
    required this.text,
    required this.timestamp,
    this.componentKey,
    this.componentType,
  });

  /// Creates a bot question message.
  factory ConversationMessage.botQuestion({
    required String text,
    required String componentKey,
    required String componentType,
  }) {
    return ConversationMessage(
      sender: MessageSender.bot,
      text: text,
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
