import '../../domain/entities/noctros_entities.dart';
import '../../domain/entities/noctros_enums.dart';

/// Centralized system prompts and conversation context shaping.
abstract final class PromptManager {
  static const systemPrompt =
      'You are Noctros, a voice-first personal AI operating system and second brain. '
      'Be concise, warm, and action-oriented. Prefer privacy-preserving suggestions. '
      'Use Markdown when helpful (lists, code fences). Never invent device actions you cannot perform.';

  static const maxContextMessages = 24;
  static const maxContextChars = 12000;

  static List<ChatMessage> optimizeContext(List<ChatMessage> messages) {
    if (messages.isEmpty) {
      return const [];
    }

    final trimmed = <ChatMessage>[];
    var totalChars = 0;

    for (final message in messages.reversed) {
      if (trimmed.length >= maxContextMessages) {
        break;
      }
      final length = message.content.length;
      if (totalChars + length > maxContextChars && trimmed.isNotEmpty) {
        break;
      }
      trimmed.add(message);
      totalChars += length;
    }

    return trimmed.reversed.toList(growable: false);
  }

  static List<Map<String, String>> toOpenAiMessages({
    required String prompt,
    required List<ChatMessage> contextMessages,
    String? memoryContext,
  }) {
    final system = StringBuffer(systemPrompt);
    if (memoryContext != null && memoryContext.trim().isNotEmpty) {
      system
        ..writeln()
        ..writeln()
        ..writeln('Known user memory (permission-granted):')
        ..writeln(memoryContext.trim());
    }

    final optimized = optimizeContext(contextMessages);
    final payload = <Map<String, String>>[
      {'role': 'system', 'content': system.toString()},
      ...optimized
          .where((message) => message.role != MessageRole.system)
          .map(
            (message) => {
              'role': message.role == MessageRole.user ? 'user' : 'assistant',
              'content': message.content,
            },
          ),
    ];

    if (payload.length == 1 || payload.last['content'] != prompt) {
      payload.add({'role': 'user', 'content': prompt});
    }
    return payload;
  }
}
