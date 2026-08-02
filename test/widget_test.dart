import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:noctros/core/ai/prompt_manager.dart';
import 'package:noctros/domain/entities/noctros_entities.dart';
import 'package:noctros/domain/entities/noctros_enums.dart';
import 'package:noctros/presentation/widgets/chat_markdown_bubble.dart';

void main() {
  test('PromptManager keeps recent context within limits', () {
    final messages = List<ChatMessage>.generate(
      40,
      (index) => ChatMessage(
        id: '$index',
        conversationId: 'c1',
        role: index.isEven ? MessageRole.user : MessageRole.assistant,
        content: 'Message $index',
        createdAt: DateTime.utc(2026, 1, 1).add(Duration(minutes: index)),
      ),
    );

    final optimized = PromptManager.optimizeContext(messages);
    expect(optimized.length, lessThanOrEqualTo(PromptManager.maxContextMessages));
    expect(optimized.last.content, 'Message 39');
  });

  testWidgets('Chat markdown bubble renders assistant content', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ChatMarkdownBubble(
            message: ChatMessage(
              id: '1',
              conversationId: 'c1',
              role: MessageRole.assistant,
              content: '**Hello** from Noctros',
              createdAt: DateTime.now().toUtc(),
            ),
          ),
        ),
      ),
    );

    expect(find.textContaining('Hello'), findsOneWidget);
  });
}
