import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../providers/noctros_providers.dart';
import '../../providers/openai_providers.dart';
import '../../providers/permission_providers.dart';
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
    Future.microtask(() async {
      await ref.read(conversationListProvider.notifier).load();
      await ref.read(settingsControllerProvider.notifier).load();
      await ref.read(permissionsControllerProvider.notifier).refresh();
      await ref.read(openAiSettingsProvider.notifier).load();
      ref.invalidate(recentActionsProvider);
      ref.invalidate(favoriteMemoryProvider);
    });
  }

  Future<void> _runShortcut(String command) async {
    await ref.read(chatSessionProvider.notifier).createConversation();
    ref.read(pendingCommandProvider.notifier).state = command;
    if (!mounted) {
      return;
    }
    context.go(ChatScreen.routePath);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final recent = ref.watch(recentConversationsProvider);
    final actionsAsync = ref.watch(recentActionsProvider);
    final favoritesAsync = ref.watch(favoriteMemoryProvider);
    final permissions = ref.watch(permissionsControllerProvider);
    final openAi = ref.watch(openAiSettingsProvider);
    final settings = ref.watch(settingsControllerProvider).settings;
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
                      'AI device assistant — ask, command, stay in control.',
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
                child: _DeviceStatusRow(
                  micReady: permissions.microphoneGranted,
                  aiReady: openAi.isConfigured,
                  memoryOn: settings?.memoryEnabled ?? false,
                  voiceOn: settings?.continuousVoiceEnabled ?? false,
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
                    title: 'Voice',
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
                    subtitle: 'Privacy & device',
                    onTap: () => context.go(SettingsScreen.routePath),
                  ),
                ]),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 8),
              sliver: SliverToBoxAdapter(
                child: Text(
                  'Favorite shortcuts',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              sliver: SliverToBoxAdapter(
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final shortcut in defaultDeviceShortcuts)
                      ActionChip(
                        avatar: Icon(_shortcutIcon(shortcut.iconName), size: 18),
                        label: Text(shortcut.label),
                        onPressed: () => _runShortcut(shortcut.command),
                      ),
                    ...favoritesAsync.maybeWhen(
                      data: (entries) => entries.take(4).map(
                            (entry) => ActionChip(
                              avatar: const Icon(Icons.star_outline, size: 18),
                              label: Text(entry.value),
                              onPressed: () => _runShortcut(
                                entry.key == 'favorite_destination'
                                    ? 'Navigate to ${entry.value}'
                                    : entry.key == 'favorite_app'
                                        ? 'Open ${entry.value}'
                                        : entry.value,
                              ),
                            ),
                          ),
                      orElse: () => const <Widget>[],
                    ),
                  ],
                ),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 8),
              sliver: SliverToBoxAdapter(
                child: Text(
                  'Recent AI actions',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              sliver: SliverToBoxAdapter(
                child: actionsAsync.when(
                  loading: () => const LinearProgressIndicator(),
                  error: (_, __) => const Text('Unable to load recent actions.'),
                  data: (logs) {
                    if (logs.isEmpty) {
                      return Text(
                        'No device actions yet. Try “Open Camera” in chat.',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      );
                    }
                    return Column(
                      children: [
                        for (final log in logs)
                          ListTile(
                            contentPadding: EdgeInsets.zero,
                            leading: Icon(
                              log.success
                                  ? Icons.check_circle_outline
                                  : Icons.error_outline,
                              color: log.success
                                  ? theme.colorScheme.primary
                                  : theme.colorScheme.error,
                            ),
                            title: Text(log.summary),
                            subtitle: Text(
                              log.createdAt.toLocal().toString().split('.').first,
                            ),
                            dense: true,
                          ),
                      ],
                    );
                  },
                ),
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
                  child: Text(
                    'No recent chats yet. Start with “Hey Noctros”.',
                  ),
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
        label: const Text('Voice command'),
      ),
    );
  }

  IconData _shortcutIcon(String name) {
    return switch (name) {
      'camera' => Icons.photo_camera_outlined,
      'map' => Icons.map_outlined,
      'chat' => Icons.chat_outlined,
      'settings' => Icons.settings_outlined,
      _ => Icons.bolt_outlined,
    };
  }
}

class _DeviceStatusRow extends StatelessWidget {
  const _DeviceStatusRow({
    required this.micReady,
    required this.aiReady,
    required this.memoryOn,
    required this.voiceOn,
  });

  final bool micReady;
  final bool aiReady;
  final bool memoryOn;
  final bool voiceOn;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        _StatusChip(label: 'Mic', ok: micReady),
        _StatusChip(label: 'Cloud AI', ok: aiReady),
        _StatusChip(label: 'Memory', ok: memoryOn),
        _StatusChip(label: 'Voice mode', ok: voiceOn),
      ],
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.label, required this.ok});

  final String label;
  final bool ok;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Chip(
      avatar: Icon(
        ok ? Icons.check_circle : Icons.cancel_outlined,
        size: 16,
        color: ok ? theme.colorScheme.primary : theme.colorScheme.outline,
      ),
      label: Text(label),
      visualDensity: VisualDensity.compact,
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
