import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../providers/assistant_ui_provider.dart';
import '../../providers/noctros_providers.dart';
import '../../providers/permission_providers.dart';
import '../../widgets/ai_orb.dart';
import '../../widgets/glass_panel.dart';
import '../../widgets/main_shell.dart';
import '../chat/chat_screen.dart';
import '../emergency/emergency_screen.dart';
import '../settings/voice_settings_screen.dart';

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
      await ref.read(settingsControllerProvider.notifier).load();
      await ref.read(permissionsControllerProvider.notifier).refresh();
    });
  }

  @override
  Widget build(BuildContext context) {
    final ui = ref.watch(assistantUiProvider);
    final settings = ref.watch(settingsControllerProvider).settings;
    final name = settings?.assistantName ?? 'Noctros';
    final theme = Theme.of(context);

    return PremiumBackground(
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
          child: Column(
            children: [
              Row(
                children: [
                  Text(
                    name,
                    style: theme.textTheme.headlineMedium,
                  ),
                  const Spacer(),
                  IconButton(
                    tooltip: 'Voice settings',
                    onPressed: () {
                      Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => const VoiceSettingsScreen(),
                        ),
                      );
                    },
                    icon: const Icon(Icons.tune_rounded),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                _welcomeLine(ui.visual, name),
                style: theme.textTheme.bodyLarge,
                textAlign: TextAlign.center,
              ),
              const Spacer(flex: 2),
              AiOrb(state: ui.visual, size: MediaQuery.sizeOf(context).width * 0.62),
              const SizedBox(height: 18),
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 280),
                child: Text(
                  ui.statusLabel,
                  key: ValueKey(ui.statusLabel),
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: theme.colorScheme.primary,
                  ),
                ),
              ),
              if (ui.partialTranscript.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  ui.partialTranscript,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyMedium,
                ),
              ],
              const Spacer(),
              GlassPanel(
                padding: const EdgeInsets.all(14),
                child: Row(
                  children: [
                    _QuickAction(
                      icon: Icons.mic_none_rounded,
                      label: 'Talk',
                      onTap: () => MainShell.goToChat(context),
                    ),
                    _QuickAction(
                      icon: Icons.chat_bubble_outline_rounded,
                      label: 'Chat',
                      onTap: () => context.go(ChatScreen.routePath),
                    ),
                    _QuickAction(
                      icon: Icons.history_rounded,
                      label: 'History',
                      onTap: () => MainShell.goToHistory(context),
                    ),
                    _QuickAction(
                      icon: Icons.sos_rounded,
                      label: 'SOS',
                      onTap: () => context.push(EmergencyScreen.routePath),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              Text(
                settings?.wakeWordEnabled == false
                    ? 'Wake word is off — open Voice Settings to enable.'
                    : 'Say “$name” anytime. I’m listening quietly.',
                style: theme.textTheme.bodySmall,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }

  String _welcomeLine(AssistantVisualState state, String name) {
    return switch (state) {
      AssistantVisualState.idle => 'Your private AI device assistant',
      AssistantVisualState.listening => 'I’m listening…',
      AssistantVisualState.thinking => 'One moment…',
      AssistantVisualState.speaking => 'Here’s what I found',
    };
  }
}

class _QuickAction extends StatelessWidget {
  const _QuickAction({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Column(
            children: [
              Icon(icon, color: Theme.of(context).colorScheme.primary),
              const SizedBox(height: 6),
              Text(label, style: Theme.of(context).textTheme.labelLarge),
            ],
          ),
        ),
      ),
    );
  }
}
