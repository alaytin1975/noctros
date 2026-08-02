import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';

import '../../domain/entities/noctros_entities.dart';
import '../../domain/entities/noctros_enums.dart';

class ChatMarkdownBubble extends StatelessWidget {
  const ChatMarkdownBubble({
    super.key,
    required this.message,
    this.isStreaming = false,
    this.onSpeak,
  });

  final ChatMessage message;
  final bool isStreaming;
  final VoidCallback? onSpeak;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isUser = message.role == MessageRole.user;
    final maxWidth = MediaQuery.sizeOf(context).width *
        (MediaQuery.sizeOf(context).width > 700 ? 0.55 : 0.82);

    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOut,
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        constraints: BoxConstraints(maxWidth: maxWidth),
        decoration: BoxDecoration(
          gradient: isUser
              ? LinearGradient(
                  colors: [
                    theme.colorScheme.primary,
                    theme.colorScheme.primary.withValues(alpha: 0.85),
                  ],
                )
              : null,
          color: isUser
              ? null
              : theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.9),
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(20),
            topRight: const Radius.circular(20),
            bottomLeft: Radius.circular(isUser ? 20 : 6),
            bottomRight: Radius.circular(isUser ? 6 : 20),
          ),
          border: isUser
              ? null
              : Border.all(
                  color: theme.colorScheme.outlineVariant.withValues(alpha: 0.4),
                ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (isUser)
              Text(
                message.content,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onPrimary,
                  height: 1.35,
                ),
              )
            else
              MarkdownBody(
                data: message.content.isEmpty && isStreaming
                    ? '_Thinking…_'
                    : message.content,
                selectable: true,
                styleSheet: MarkdownStyleSheet.fromTheme(theme).copyWith(
                  p: theme.textTheme.bodyMedium?.copyWith(height: 1.4),
                  code: theme.textTheme.bodySmall?.copyWith(
                    fontFamily: 'monospace',
                    backgroundColor: theme.colorScheme.surface,
                  ),
                  codeblockDecoration: BoxDecoration(
                    color: theme.colorScheme.surface,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: theme.colorScheme.outlineVariant,
                    ),
                  ),
                ),
              ),
            if (isStreaming)
              const Padding(
                padding: EdgeInsets.only(top: 8),
                child: LinearProgressIndicator(minHeight: 2),
              ),
            if (onSpeak != null && !isUser) ...[
              const SizedBox(height: 8),
              InkWell(
                onTap: onSpeak,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.volume_up_outlined,
                      size: 16,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'Play',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
