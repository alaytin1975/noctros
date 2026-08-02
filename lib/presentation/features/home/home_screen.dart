import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../providers/noctros_providers.dart';
import '../chat/chat_screen.dart';
import '../emergency/emergency_screen.dart';
import '../settings/settings_screen.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  static const routePath = '/';
  static const routeName = 'home';

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() => ref.read(conversationListProvider.notifier).load());
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final recent = ref.watch(recentConversationsProvider);
    final wide = MediaQuery.sizeOf(context).width > 700;

    return Scaffold(
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
              sliver: SliverToBoxAdapter(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Noctros',
                      style: theme.textTheme.headlineMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Your second brain — voice-first, private, ready.',
                      style: theme.textTheme.bodyLarge?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              sliver: SliverToBoxAdapter(
                child: _DailySummaryCard(
                  conversationCount: recent.length,
                ),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
              sliver: SliverToBoxAdapter(
                child: Text(
                  'Quick actions',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              sliver: SliverGrid(
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: wide ? 4 : 2,
                  mainAxisSpacing: 12,
                  crossAxisSpacing: 12,
                  childAspectRatio: wide ? 1.15 : 1.05,
                ),
                delegate: SliverChildListDelegate([
                  _QuickAction(
                    icon: Icons.mic_rounded,
                    title: 'Talk',
                    subtitle: 'Hey Noctros',
                    onTap: () => context.go(ChatScreen.routePath),
                  ),
                  _QuickAction(
                    icon: Icons.chat_bubble_outline,
                    title: 'Ask AI',
                    subtitle: 'Open chat',
                    onTap: () => context.go(ChatScreen.routePath),
                  ),
                  _QuickAction(
                    icon: Icons.emergency_outlined,
                    title: 'SOS',
                    subtitle: 'Emergency',
                    accent: theme.colorScheme.error,
                    onTap: () => context.go(EmergencyScreen.routePath),
                  ),
                  _QuickAction(
                    icon: Icons.settings_outlined,
                    title: 'Settings',
                    subtitle: 'AI & voice',
                    onTap: () => context.go(SettingsScreen.routePath),
                  ),
                ]),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 8),
              sliver: SliverToBoxAdapter(
                child: Row(
                  children: [
                    Text(
                      'Recent conversations',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const Spacer(),
                    TextButton(
                      onPressed: () => context.go(ChatScreen.routePath),
                      child: const Text('Open chat'),
                    ),
                  ],
                ),
              ),
            ),
            if (recent.isEmpty)
              const SliverPadding(
                padding: EdgeInsets.all(20),
                sliver: SliverToBoxAdapter(
                  child: Text('No recent chats yet. Start with “Hey Noctros”.'),
                ),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 100),
                sliver: SliverList.separated(
                  itemCount: recent.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (context, index) {
                    final conversation = recent[index];
                    return Card(
                      child: ListTile(
                        title: Text(conversation.title),
                        subtitle: Text(
                          conversation.updatedAt
                              .toLocal()
                              .toString()
                              .split('.')
                              .first,
                        ),
                        trailing: conversation.isFavorite
                            ? const Icon(Icons.star, size: 18)
                            : null,
                        onTap: () async {
                          await ref
                              .read(chatSessionProvider.notifier)
                              .openConversation(conversation.id);
                          if (context.mounted) {
                            context.go(ChatScreen.routePath);
                          }
                        },
                      ),
                    );
                  },
                ),
              ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.go(ChatScreen.routePath),
        icon: const Icon(Icons.mic),
        label: const Text('Hey Noctros'),
      ),
    );
  }
}

class _DailySummaryCard extends StatelessWidget {
  const _DailySummaryCard({required this.conversationCount});

  final int conversationCount;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: LinearGradient(
          colors: [
            theme.colorScheme.primaryContainer,
            theme.colorScheme.secondaryContainer.withValues(alpha: 0.8),
          ],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Daily summary',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            conversationCount == 0
                ? 'No conversations yet today. Ask Noctros to plan your day.'
                : 'You have $conversationCount recent conversation${conversationCount == 1 ? '' : 's'}. '
                    'Tap Talk to continue, or open SOS if you need help.',
            style: theme.textTheme.bodyMedium,
          ),
        ],
      ),
    );
  }
}

class _QuickAction extends StatelessWidget {
  const _QuickAction({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.accent,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final Color? accent;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = accent ?? theme.colorScheme.primary;
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(22),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, color: color),
              const Spacer(),
              Text(
                title,
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              Text(
                subtitle,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
