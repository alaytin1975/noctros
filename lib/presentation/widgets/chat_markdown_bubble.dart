import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_markdown/flutter_markdown.dart';

import '../../domain/entities/noctros_entities.dart';
import '../../domain/entities/noctros_enums.dart';
import '../theme/noctros_theme.dart';

class ChatMarkdownBubble extends StatelessWidget {
  const ChatMarkdownBubble({
    super.key,
    required this.message,
    this.isStreaming = false,
    this.onSpeak,
    this.onRegenerate,
  });

  final ChatMessage message;
  final bool isStreaming;
  final VoidCallback? onSpeak;
  final VoidCallback? onRegenerate;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isUser = message.role == MessageRole.user;
    final maxWidth = MediaQuery.sizeOf(context).width *
        (MediaQuery.sizeOf(context).width > 700 ? 0.55 : 0.78);

    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        mainAxisAlignment:
            isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        children: [
          if (!isUser) ...[
            const _Avatar(
              icon: Icons.auto_awesome_rounded,
              color: NoctrosTheme.accent,
            ),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Column(
              crossAxisAlignment:
                  isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
                  constraints: BoxConstraints(maxWidth: maxWidth),
                  decoration: BoxDecoration(
                    gradient: isUser
                        ? const LinearGradient(
                            colors: [
                              Color(0xFF3D7BFF),
                              Color(0xFF6EA8FF),
                            ],
                          )
                        : null,
                    color: isUser
                        ? null
                        : Colors.white.withValues(
                            alpha: theme.brightness == Brightness.dark
                                ? 0.08
                                : 0.9,
                          ),
                    borderRadius: BorderRadius.only(
                      topLeft: const Radius.circular(22),
                      topRight: const Radius.circular(22),
                      bottomLeft: Radius.circular(isUser ? 22 : 8),
                      bottomRight: Radius.circular(isUser ? 8 : 22),
                    ),
                    border: isUser
                        ? null
                        : Border.all(
                            color: Colors.white.withValues(alpha: 0.1),
                          ),
                  ),
                  child: isUser
                      ? Text(
                          message.content,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: Colors.white,
                            height: 1.4,
                          ),
                        )
                      : MarkdownBody(
                          data: message.content.isEmpty && isStreaming
                              ? '_Thinking…_'
                              : message.content,
                          selectable: true,
                          styleSheet:
                              MarkdownStyleSheet.fromTheme(theme).copyWith(
                            p: theme.textTheme.bodyMedium?.copyWith(height: 1.45),
                          ),
                        ),
                ),
                if (!isUser && !isStreaming)
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        tooltip: 'Copy',
                        visualDensity: VisualDensity.compact,
                        onPressed: () async {
                          await Clipboard.setData(
                            ClipboardData(text: message.content),
                          );
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Copied')),
                            );
                          }
                        },
                        icon: const Icon(Icons.copy_rounded, size: 18),
                      ),
                      if (onSpeak != null)
                        IconButton(
                          tooltip: 'Speak',
                          visualDensity: VisualDensity.compact,
                          onPressed: onSpeak,
                          icon: const Icon(Icons.volume_up_rounded, size: 18),
                        ),
                      if (onRegenerate != null)
                        IconButton(
                          tooltip: 'Regenerate',
                          visualDensity: VisualDensity.compact,
                          onPressed: onRegenerate,
                          icon: const Icon(Icons.refresh_rounded, size: 18),
                        ),
                    ],
                  ),
              ],
            ),
          ),
          if (isUser) ...[
            const SizedBox(width: 8),
            _Avatar(
              icon: Icons.person_rounded,
              color: theme.colorScheme.secondary,
            ),
          ],
        ],
      ),
    );
  }
}

class _Avatar extends StatelessWidget {
  const _Avatar({required this.icon, required this.color});

  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return CircleAvatar(
      radius: 16,
      backgroundColor: color.withValues(alpha: 0.2),
      child: Icon(icon, size: 16, color: color),
    );
  }
}
