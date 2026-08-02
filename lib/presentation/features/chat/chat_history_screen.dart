import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';

import '../../../domain/entities/noctros_entities.dart';
import '../../providers/noctros_providers.dart';

class ChatHistoryScreen extends ConsumerStatefulWidget {
  const ChatHistoryScreen({super.key});

  static const routePath = '/chat/history';
  static const routeName = 'chatHistory';

  @override
  ConsumerState<ChatHistoryScreen> createState() => _ChatHistoryScreenState();
}

class _ChatHistoryScreenState extends ConsumerState<ChatHistoryScreen> {
  final _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    Future.microtask(() => ref.read(conversationListProvider.notifier).load());
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(conversationListProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Chat history'),
        actions: [
          IconButton(
            tooltip: 'Favorites only',
            onPressed: () => ref
                .read(conversationListProvider.notifier)
                .load(favoritesOnly: !state.favoritesOnly),
            icon: Icon(
              state.favoritesOnly ? Icons.star : Icons.star_border,
            ),
          ),
          IconButton(
            tooltip: 'New chat',
            onPressed: () async {
              await ref.read(chatSessionProvider.notifier).createConversation();
              if (context.mounted) {
                Navigator.of(context).pop();
              }
            },
            icon: const Icon(Icons.add_comment_outlined),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: TextField(
              controller: _searchController,
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.search),
                hintText: 'Search conversations…',
              ),
              onChanged: (value) => ref
                  .read(conversationListProvider.notifier)
                  .load(query: value),
            ),
          ),
          Expanded(
            child: state.isLoading
                ? const Center(child: CircularProgressIndicator())
                : state.conversations.isEmpty
                    ? const Center(child: Text('No conversations found.'))
                    : ListView.separated(
                        padding: const EdgeInsets.all(16),
                        itemCount: state.conversations.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 8),
                        itemBuilder: (context, index) {
                          final conversation = state.conversations[index];
                          return _ConversationTile(
                            conversation: conversation,
                            onOpen: () async {
                              await ref
                                  .read(chatSessionProvider.notifier)
                                  .openConversation(conversation.id);
                              if (context.mounted) {
                                Navigator.of(context).pop();
                              }
                            },
                            onPin: () => ref
                                .read(conversationListProvider.notifier)
                                .togglePin(conversation),
                            onFavorite: () => ref
                                .read(conversationListProvider.notifier)
                                .toggleFavorite(conversation),
                            onExport: () async {
                              final exported = await ref
                                  .read(conversationListProvider.notifier)
                                  .export(conversation.id);
                              if (exported.content != null) {
                                await Share.share(
                                  exported.content!,
                                  subject: conversation.title,
                                );
                              } else if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      exported.error ?? 'Export failed',
                                    ),
                                  ),
                                );
                              }
                            },
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }
}

class _ConversationTile extends StatelessWidget {
  const _ConversationTile({
    required this.conversation,
    required this.onOpen,
    required this.onPin,
    required this.onFavorite,
    required this.onExport,
  });

  final Conversation conversation;
  final VoidCallback onOpen;
  final VoidCallback onPin;
  final VoidCallback onFavorite;
  final VoidCallback onExport;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: ListTile(
        onTap: onOpen,
        title: Text(conversation.title),
        subtitle: Text(
          conversation.updatedAt.toLocal().toString().split('.').first,
          style: theme.textTheme.bodySmall,
        ),
        leading: Icon(
          conversation.isPinned ? Icons.push_pin : Icons.chat_bubble_outline,
          color: conversation.isPinned ? theme.colorScheme.primary : null,
        ),
        trailing: Wrap(
          spacing: 0,
          children: [
            IconButton(
              tooltip: 'Favorite',
              onPressed: onFavorite,
              icon: Icon(
                conversation.isFavorite ? Icons.star : Icons.star_border,
              ),
            ),
            IconButton(
              tooltip: 'Pin',
              onPressed: onPin,
              icon: Icon(
                conversation.isPinned
                    ? Icons.push_pin
                    : Icons.push_pin_outlined,
              ),
            ),
            IconButton(
              tooltip: 'Export',
              onPressed: onExport,
              icon: const Icon(Icons.ios_share_outlined),
            ),
          ],
        ),
      ),
    );
  }
}
