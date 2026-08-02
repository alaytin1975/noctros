import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/di/service_locator.dart';
import '../../../core/constants/noctros_constants.dart';
import '../../../domain/entities/noctros_entities.dart';
import '../../../domain/entities/noctros_enums.dart';
import '../../../domain/entities/permission_entities.dart';
import '../../../domain/entities/device_action_entities.dart';
import '../../../domain/usecases/handle_user_command_use_case.dart';
import '../../../engines/voice/voice_engine.dart';
import '../../providers/noctros_providers.dart';
import '../../providers/openai_providers.dart';
import '../../providers/permission_providers.dart';
import '../../widgets/chat_markdown_bubble.dart';
import '../../widgets/permission_prompt_sheet.dart';
import '../emergency/emergency_screen.dart';
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
  late final HandleUserCommandUseCase _handleCommandUseCase;
  late final VoiceEngine _voiceEngine;
  bool _isListening = false;
  bool _isSpeaking = false;
  bool _continuous = false;

  @override
  void initState() {
    super.initState();
    _handleCommandUseCase = HandleUserCommandUseCase();
    _voiceEngine = ServiceLocator.get<VoiceEngine>();
    Future.microtask(() async {
      await ref.read(openAiSettingsProvider.notifier).load();
      await ref.read(settingsControllerProvider.notifier).load();
      final openAi = ref.read(openAiSettingsProvider);
      await _voiceEngine.configureVoice(
        speechRate: openAi.speechRate,
        localeId: openAi.sttLocaleId,
      );
      await _ensureConversation();
      await _consumePendingCommand();
    });
  }

  Future<void> _consumePendingCommand() async {
    final pending = ref.read(pendingCommandProvider);
    if (pending == null || pending.isEmpty) {
      return;
    }
    ref.read(pendingCommandProvider.notifier).state = null;
    final conversationId = ref.read(chatSessionProvider).conversationId;
    if (conversationId == null) {
      return;
    }
    await _processCommand(
      conversationId: conversationId,
      userMessage: pending,
    );
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

  Future<void> _toggleVoiceInput({bool continuous = false}) async {
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
      setState(() {
        _isListening = false;
        _continuous = false;
      });
      return;
    }

    await _voiceEngine.interruptSpeech();
    setState(() {
      _isListening = true;
      _continuous = continuous;
    });

    await _voiceEngine.startListening(
      continuous: continuous,
      onResult: (transcript) async {
        if (!mounted) {
          return;
        }
        if (!_continuous) {
          setState(() => _isListening = false);
        }
        if (transcript.isEmpty) {
          return;
        }
        if (NoctrosConstants.emergencyPhrases
            .any((phrase) => transcript.toLowerCase().contains(phrase))) {
          if (mounted) {
            unawaited(
              Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => const EmergencyScreen(),
                ),
              ),
            );
          }
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

    final session = ref.read(chatSessionProvider);
    final conversationId = session.conversationId;
    if (conversationId == null) {
      return;
    }

    await _voiceEngine.interruptSpeech();
    _controller.clear();
    await _processCommand(
      conversationId: conversationId,
      userMessage: text,
    );
  }

  Future<void> _processCommand({
    required String conversationId,
    required String userMessage,
    bool userConfirmed = false,
    ParsedDeviceIntent? confirmedIntent,
  }) async {
    ref.read(chatSessionProvider.notifier).setSending(true);
    ref.read(chatSessionProvider.notifier).setStreamingContent('');

    final result = await _handleCommandUseCase.execute(
      conversationId: conversationId,
      userMessage: userMessage,
      userConfirmed: userConfirmed,
      confirmedIntent: confirmedIntent,
      onStreamChunk: (partial) {
        ref.read(chatSessionProvider.notifier).setStreamingContent(partial);
        _scrollToBottom();
      },
    );

    ref.read(chatSessionProvider.notifier).setSending(false);
    ref.read(chatSessionProvider.notifier).setStreamingContent(null);

    if (!result.isSuccess) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result.failureOrNull?.message ?? 'Request failed'),
        ),
      );
      return;
    }

    final handled = result.valueOrThrow;
    if (handled.kind == HandleCommandKind.needsConfirmation) {
      final confirmed = await _confirmDeviceAction(
        handled.confirmationMessage ??
            handled.pendingIntent?.displaySummary ??
            'Perform this device action?',
      );
      if (confirmed == true && handled.pendingIntent != null) {
        await _processCommand(
          conversationId: conversationId,
          userMessage: handled.pendingUserMessage ?? userMessage,
          userConfirmed: true,
          confirmedIntent: handled.pendingIntent,
        );
      }
      return;
    }

    await ref.read(chatSessionProvider.notifier).reloadMessages();
    ref.invalidate(recentActionsProvider);
    _scrollToBottom();

    if (handled.enableVoiceMode) {
      final settings = ref.read(settingsControllerProvider).settings;
      if (settings != null) {
        await ref.read(settingsControllerProvider.notifier).save(
              settings.copyWith(continuousVoiceEnabled: true),
            );
      }
      if (!_continuous) {
        await _toggleVoiceInput(continuous: true);
      }
    }

    final reply = handled.assistantMessage;
    final ttsEnabled = ref.read(openAiSettingsProvider).ttsEnabled;
    if (ttsEnabled && reply != null && reply.role == MessageRole.assistant) {
      await _speak(reply.content);
    }

    final continuousSetting = ref
            .read(settingsControllerProvider)
            .settings
            ?.continuousVoiceEnabled ??
        false;
    if (continuousSetting && !_continuous && !_isListening) {
      await _toggleVoiceInput(continuous: true);
    }
  }

  Future<bool?> _confirmDeviceAction(String message) {
    if (!mounted) {
      return Future.value(false);
    }
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirm action'),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Allow'),
          ),
        ],
      ),
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
        _scrollController.position.maxScrollExtent + 80,
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOut,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(chatSessionProvider);
    final openAi = ref.watch(openAiSettingsProvider);
    final theme = Theme.of(context);
    final messages = [
      ...session.messages,
      if (session.streamingContent != null)
        ChatMessage(
          id: 'streaming',
          conversationId: session.conversationId ?? '',
          role: MessageRole.assistant,
          content: session.streamingContent!,
          createdAt: DateTime.now().toUtc(),
        ),
    ];

    return Scaffold(
      appBar: AppBar(
        title: const Text('Noctros Chat'),
        actions: [
          if (_isSpeaking || session.isSending)
            const Padding(
              padding: EdgeInsets.only(right: 4),
              child: SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          IconButton(
            tooltip: _continuous ? 'Stop continuous voice' : 'Continuous voice',
            onPressed: () => _toggleVoiceInput(continuous: !_continuous),
            icon: Icon(
              _continuous ? Icons.record_voice_over : Icons.hearing,
              color: _continuous ? theme.colorScheme.primary : null,
            ),
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
                'OpenAI not configured — offline fallback is active. Add a key in Settings.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSecondaryContainer,
                ),
              ),
            ),
          Expanded(
            child: session.isLoading
                ? const Center(child: CircularProgressIndicator())
                : messages.isEmpty
                    ? Center(
                        child: Text(
                          'Ask Noctros or give a device command.\n'
                          'Try “Open Camera”, “Call Mom”, or “Navigate to home”.',
                          textAlign: TextAlign.center,
                          style: theme.textTheme.bodyLarge?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      )
                    : ListView.builder(
                        controller: _scrollController,
                        padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                        itemCount: messages.length,
                        itemBuilder: (context, index) {
                          final message = messages[index];
                          final streaming = message.id == 'streaming';
                          return ChatMarkdownBubble(
                            message: message,
                            isStreaming: streaming,
                            onSpeak: message.role == MessageRole.assistant &&
                                    !streaming
                                ? () => _speak(message.content)
                                : null,
                          );
                        },
                      ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
              child: Row(
                children: [
                  IconButton.filledTonal(
                    onPressed: session.isSending
                        ? null
                        : () => _toggleVoiceInput(continuous: false),
                    icon: Icon(
                      _isListening ? Icons.mic : Icons.mic_none_outlined,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: _controller,
                      minLines: 1,
                      maxLines: 5,
                      textInputAction: TextInputAction.send,
                      onSubmitted: (_) => _sendMessage(),
                      decoration: InputDecoration(
                        hintText: _isListening
                            ? (_continuous
                                ? 'Continuous listening…'
                                : 'Listening…')
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
