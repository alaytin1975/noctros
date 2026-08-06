import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';

import '../../../domain/entities/noctros_entities.dart';
import '../../providers/noctros_providers.dart';
import '../../widgets/glass_panel.dart';
import '../../widgets/main_shell.dart';

class ChatHistoryScreen extends ConsumerStatefulWidget {
  const ChatHistoryScreen({super.key});

  static const routePath = '/history';
  static const routeName = 'history';

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

  Future<void> _rename(Conversation conversation) async {
    final controller = TextEditingController(text: conversation.title);
    final next = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Rename conversation'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(hintText: 'Title'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, controller.text),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (next != null) {
      await ref.read(conversationListProvider.notifier).rename(conversation, next);
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(conversationListProvider);
    final theme = Theme.of(context);

    return SafeArea(
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
            child: Row(
              children: [
                Text('History', style: theme.textTheme.headlineMedium),
                const Spacer(),
                IconButton(
                  tooltip: 'Favorites',
                  onPressed: () => ref
                      .read(conversationListProvider.notifier)
                      .load(favoritesOnly: !state.favoritesOnly),
                  icon: Icon(
                    state.favoritesOnly ? Icons.star_rounded : Icons.star_border_rounded,
                    color: theme.colorScheme.primary,
                  ),
                ),
                IconButton(
                  tooltip: 'New chat',
                  onPressed: () async {
                    await ref
                        .read(chatSessionProvider.notifier)
                        .createConversation();
                    if (context.mounted) {
                      MainShell.goToChat(context);
                    }
                  },
                  icon: const Icon(Icons.add_comment_rounded),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: TextField(
              controller: _searchController,
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.search_rounded),
                hintText: 'Search conversations',
              ),
              onChanged: (value) => ref
                  .read(conversationListProvider.notifier)
                  .load(query: value),
            ),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: state.isLoading
                ? const Center(child: CircularProgressIndicator())
                : state.conversations.isEmpty
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(32),
                          child: Text(
                            'No conversations yet.\nStart chatting with Noctros.',
                            textAlign: TextAlign.center,
                            style: theme.textTheme.bodyLarge,
                          ),
                        ),
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                        itemCount: state.conversations.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 10),
                        itemBuilder: (context, index) {
                          final conversation = state.conversations[index];
                          return GlassPanel(
                            padding: EdgeInsets.zero,
                            child: ListTile(
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 6,
                              ),
                              title: Text(
                                conversation.title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              subtitle: Text(
                                conversation.updatedAt
                                    .toLocal()
                                    .toString()
                                    .split('.')
                                    .first,
                              ),
                              leading: Icon(
                                conversation.isFavorite
                                    ? Icons.star_rounded
                                    : Icons.chat_bubble_outline_rounded,
                                color: theme.colorScheme.primary,
                              ),
                              trailing: PopupMenuButton<String>(
                                onSelected: (value) async {
                                  switch (value) {
                                    case 'favorite':
                                      await ref
                                          .read(conversationListProvider.notifier)
                                          .toggleFavorite(conversation);
                                    case 'rename':
                                      await _rename(conversation);
                                    case 'export':
                                      final exported = await ref
                                          .read(conversationListProvider.notifier)
                                          .export(conversation.id);
                                      if (exported.content != null) {
                                        await Share.share(exported.content!);
                                      }
                                    case 'delete':
                                      await ref
                                          .read(conversationListProvider.notifier)
                                          .delete(conversation.id);
                                  }
                                },
                                itemBuilder: (context) => [
                                  PopupMenuItem(
                                    value: 'favorite',
                                    child: Text(
                                      conversation.isFavorite
                                          ? 'Remove favorite'
                                          : 'Favorite',
                                    ),
                                  ),
                                  const PopupMenuItem(
                                    value: 'rename',
                                    child: Text('Rename'),
                                  ),
                                  const PopupMenuItem(
                                    value: 'export',
                                    child: Text('Export'),
                                  ),
                                  const PopupMenuItem(
                                    value: 'delete',
                                    child: Text('Delete'),
                                  ),
                                ],
                              ),
                              onTap: () async {
                                await ref
                                    .read(chatSessionProvider.notifier)
                                    .openConversation(conversation.id);
                                if (context.mounted) {
                                  MainShell.goToChat(context);
                                }
                              },
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }
}
