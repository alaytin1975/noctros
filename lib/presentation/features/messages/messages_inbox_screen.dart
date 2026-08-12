import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../domain/entities/communication_entities.dart';
import '../../providers/communication_providers.dart';
import '../../widgets/atmosphere_scaffold.dart';
import '../../widgets/contact_avatar.dart';
import 'compose_message_screen.dart';
import 'thread_screen.dart';

class MessagesInboxScreen extends ConsumerStatefulWidget {
  const MessagesInboxScreen({super.key});

  static const routePath = '/messages';
  static const routeName = 'messages';

  @override
  ConsumerState<MessagesInboxScreen> createState() =>
      _MessagesInboxScreenState();
}

class _MessagesInboxScreenState extends ConsumerState<MessagesInboxScreen> {
  final _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    Future.microtask(() => ref.read(inboxControllerProvider.notifier).load());
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(inboxControllerProvider);
    final theme = Theme.of(context);

    return AtmosphereScaffold(
      appBar: AppBar(
        title: const Text('Noctros'),
        actions: [
          IconButton(
            tooltip: 'New message',
            onPressed: () => context.push(ComposeMessageScreen.routePath),
            icon: const Icon(Icons.edit_square),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push(ComposeMessageScreen.routePath),
        icon: const Icon(Icons.add_comment_rounded),
        label: const Text('Message'),
      ),
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
              child: Text(
                'Messages',
                style: theme.textTheme.headlineMedium,
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
              child: Text(
                'Private conversations, ready on your iPhone.',
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: TextField(
                controller: _searchController,
                onChanged: ref.read(inboxControllerProvider.notifier).setQuery,
                decoration: const InputDecoration(
                  hintText: 'Search conversations',
                  prefixIcon: Icon(Icons.search_rounded),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: state.isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : state.filtered.isEmpty
                      ? const _EmptyInbox()
                      : RefreshIndicator(
                          onRefresh: () =>
                              ref.read(inboxControllerProvider.notifier).load(),
                          child: ListView.separated(
                            padding: const EdgeInsets.fromLTRB(12, 8, 12, 100),
                            itemCount: state.filtered.length,
                            separatorBuilder: (_, __) =>
                                const SizedBox(height: 4),
                            itemBuilder: (context, index) {
                              final item = state.filtered[index];
                              return _InboxTile(
                                item: item,
                                onTap: () async {
                                  await context.push(
                                    ThreadScreen.routePathFor(item.thread.id),
                                  );
                                  if (!context.mounted) {
                                    return;
                                  }
                                  await ref
                                      .read(inboxControllerProvider.notifier)
                                      .load();
                                },
                              );
                            },
                          ),
                        ),
            ),
          ],
        ),
      ),
    );
  }
}

class _InboxTile extends StatelessWidget {
  const _InboxTile({required this.item, required this.onTap});

  final InboxThreadView item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final thread = item.thread;
    final contact = item.primaryContact;
    final timeLabel = _formatTimestamp(thread.updatedAt);
    final unread = thread.unreadCount > 0;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(22),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
          child: Row(
            children: [
              if (contact != null)
                ContactAvatar(contact: contact)
              else
                CircleAvatar(
                  radius: 24,
                  backgroundColor: theme.colorScheme.primaryContainer,
                  child: Icon(
                    Icons.person_rounded,
                    color: theme.colorScheme.onPrimaryContainer,
                  ),
                ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            thread.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight:
                                  unread ? FontWeight.w800 : FontWeight.w600,
                            ),
                          ),
                        ),
                        Text(
                          timeLabel,
                          style: theme.textTheme.labelMedium?.copyWith(
                            color: unread
                                ? theme.colorScheme.primary
                                : theme.colorScheme.onSurfaceVariant,
                            fontWeight:
                                unread ? FontWeight.w700 : FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            thread.lastMessagePreview,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                              fontWeight:
                                  unread ? FontWeight.w600 : FontWeight.w400,
                            ),
                          ),
                        ),
                        if (unread) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: theme.colorScheme.primary,
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Text(
                              '${thread.unreadCount}',
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: theme.colorScheme.onPrimary,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatTimestamp(DateTime value) {
    final local = value.toLocal();
    final now = DateTime.now();
    if (DateUtils.isSameDay(local, now)) {
      return DateFormat.jm().format(local);
    }
    if (now.difference(local).inDays < 7) {
      return DateFormat.E().format(local);
    }
    return DateFormat.MMMd().format(local);
  }
}

class _EmptyInbox extends StatelessWidget {
  const _EmptyInbox();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.chat_bubble_outline_rounded,
              size: 48,
              color: theme.colorScheme.primary,
            ),
            const SizedBox(height: 16),
            Text('No conversations yet', style: theme.textTheme.titleLarge),
            const SizedBox(height: 8),
            Text(
              'Start a message to keep people close.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
