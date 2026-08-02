import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/di/service_locator.dart';
import '../../../domain/entities/noctros_entities.dart';
import '../../../domain/entities/noctros_enums.dart';
import '../../../domain/entities/permission_entities.dart';
import '../../../domain/usecases/send_chat_message_use_case.dart';
import '../../../engines/voice/voice_engine.dart';
import '../../providers/noctros_providers.dart';
import '../../providers/openai_providers.dart';
import '../../providers/permission_providers.dart';
import '../../widgets/permission_prompt_sheet.dart';
import 'chat_history_screen.dart';

class ChatScreen extends ConsumerStatefulWidget {
  const ChatScreen({super.key});

  static const routePath = '/chat';
  static const routeName = 'chat';

  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen> {
  final _controller = TextEditingController();
  final _scrollController = ScrollController();
  late final SendChatMessageUseCase _sendMessageUseCase;
  late final VoiceEngine _voiceEngine;
  bool _isListening = false;
  bool _isSpeaking = false;

  @override
  void initState() {
    super.initState();
    _sendMessageUseCase = SendChatMessageUseCase();
    _voiceEngine = ServiceLocator.get<VoiceEngine>();
    Future.microtask(() async {
      await ref.read(openAiSettingsProvider.notifier).load();
      await _ensureConversation();
    });
  }

  Future<void> _ensureConversation() async {
    final state = ref.read(chatSessionProvider);
    if (state.conversationId != null) {
      return;
    }
    await ref.read(chatSessionProvider.notifier).createConversation();
  }

  @override
  void dispose() {
    if (_isListening) {
      _voiceEngine.stopListening();
    }
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _toggleVoiceInput() async {
    final micGranted =
        ref.read(permissionsControllerProvider).microphoneGranted;
    if (!micGranted) {
      if (!mounted) {
        return;
      }
      await PermissionPromptSheet.show(
        context,
        permission: NoctrosPermission.microphone,
      );
      return;
    }

    if (_isListening) {
      await _voiceEngine.stopListening();
      setState(() => _isListening = false);
      return;
    }

    setState(() => _isListening = true);
    await _voiceEngine.startListening(
      onResult: (transcript) async {
        if (!mounted) {
          return;
        }
        setState(() => _isListening = false);
        if (transcript.isEmpty) {
          return;
        }
        _controller.text = transcript;
        await _sendMessage();
      },
      onPartial: (partial) {
        if (!mounted) {
          return;
        }
        _controller.text = partial;
      },
    );
  }

  Future<void> _sendMessage() async {
    final text = _controller.text.trim();
    if (text.isEmpty) {
      return;
    }

    final openAi = ref.read(openAiSettingsProvider);
    if (!openAi.isConfigured) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Add your OpenAI API key in Settings or .env to use cloud AI.',
          ),
        ),
      );
    }

    final session = ref.read(chatSessionProvider);
    final conversationId = session.conversationId;
    if (conversationId == null) {
      return;
    }

    _controller.clear();
    ref.read(chatSessionProvider.notifier).setSending(true);

    final result = await _sendMessageUseCase.execute(
      conversationId: conversationId,
      userMessage: text,
      complexity: AiTaskComplexity.moderate,
    );

    ref.read(chatSessionProvider.notifier).setSending(false);

    if (result.isSuccess) {
      await ref.read(chatSessionProvider.notifier).reloadMessages();
      _scrollToBottom();
      final reply = result.valueOrThrow;
      final ttsEnabled = ref.read(openAiSettingsProvider).ttsEnabled;
      if (ttsEnabled && reply.role == MessageRole.assistant) {
        await _speak(reply.content);
      }
      return;
    }

    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(result.failureOrNull?.message ?? 'Request failed')),
    );
  }

  Future<void> _speak(String text) async {
    setState(() => _isSpeaking = true);
    try {
      await _voiceEngine.speak(text);
    } finally {
      if (mounted) {
        setState(() => _isSpeaking = false);
      }
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) {
        return;
      }
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(chatSessionProvider);
    final openAi = ref.watch(openAiSettingsProvider);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Noctros Chat'),
        actions: [
          if (_isSpeaking)
            const Padding(
              padding: EdgeInsets.only(right: 8),
              child: Icon(Icons.volume_up_outlined),
            ),
          IconButton(
            tooltip: 'Chat history',
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => const ChatHistoryScreen(),
                ),
              );
            },
            icon: const Icon(Icons.history),
          ),
          IconButton(
            tooltip: 'New chat',
            onPressed: () =>
                ref.read(chatSessionProvider.notifier).createConversation(),
            icon: const Icon(Icons.add_comment_outlined),
          ),
        ],
      ),
      body: Column(
        children: [
          if (!openAi.isLoading && !openAi.isConfigured)
            Container(
              width: double.infinity,
              color: theme.colorScheme.secondaryContainer,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              child: Text(
                'OpenAI API key not configured. Add it in Settings or .env. Local fallback may be used.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSecondaryContainer,
                ),
              ),
            ),
          Expanded(
            child: session.isLoading
                ? const Center(child: CircularProgressIndicator())
                : session.messages.isEmpty
                    ? Center(
                        child: Text(
                          'Ask Noctros anything.\nTap the mic for speech-to-text.',
                          textAlign: TextAlign.center,
                          style: theme.textTheme.bodyLarge?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      )
                    : ListView.builder(
                        controller: _scrollController,
                        padding: const EdgeInsets.all(16),
                        itemCount: session.messages.length,
                        itemBuilder: (context, index) {
                          final message = session.messages[index];
                          return _MessageBubble(
                            message: message,
                            onSpeak: message.role == MessageRole.assistant
                                ? () => _speak(message.content)
                                : null,
                          );
                        },
                      ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Row(
                children: [
                  IconButton(
                    onPressed: session.isSending ? null : _toggleVoiceInput,
                    icon: Icon(
                      _isListening ? Icons.mic : Icons.mic_none_outlined,
                      color: _isListening
                          ? theme.colorScheme.primary
                          : theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  Expanded(
                    child: TextField(
                      controller: _controller,
                      minLines: 1,
                      maxLines: 4,
                      textInputAction: TextInputAction.send,
                      onSubmitted: (_) => _sendMessage(),
                      decoration: InputDecoration(
                        hintText: _isListening
                            ? 'Listening…'
                            : 'Message Noctros…',
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  FilledButton(
                    onPressed: session.isSending ? null : _sendMessage,
                    child: session.isSending
                        ? SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: theme.colorScheme.onPrimary,
                            ),
                          )
                        : const Icon(Icons.send_rounded),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MessageBubble extends StatelessWidget {
  const _MessageBubble({
    required this.message,
    this.onSpeak,
  });

  final ChatMessage message;
  final VoidCallback? onSpeak;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isUser = message.role == MessageRole.user;

    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.sizeOf(context).width * 0.78,
        ),
        decoration: BoxDecoration(
          color: isUser
              ? theme.colorScheme.primary
              : theme.cardTheme.color ??
                  theme.colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(18),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              message.content,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: isUser
                    ? theme.colorScheme.onPrimary
                    : theme.colorScheme.onSurface,
              ),
            ),
            if (onSpeak != null) ...[
              const SizedBox(height: 6),
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
