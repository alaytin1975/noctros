import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../providers/assistant_ui_provider.dart';
import '../../providers/noctros_providers.dart';
import '../../providers/openai_providers.dart';
import '../../providers/permission_providers.dart';
import '../../providers/voice_providers.dart';
import '../../widgets/ai_orb.dart';
import '../../widgets/energy_waves.dart';
import '../../widgets/glass_panel.dart';
import '../../widgets/voice_equalizer.dart';
import '../chat/chat_history_screen.dart';
import '../chat/chat_screen.dart';
import '../emergency/emergency_screen.dart';
import '../settings/settings_screen.dart';

// glass_panel provides PremiumBackground

/// Voice-first home — orb, equalizer, Settings/SOS only. No manual talk buttons.
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
      await ref.read(openAiSettingsProvider.notifier).load();
      // Do not fake "Listening" here — lifecycle sets it only when wake is live.
      final mic = ref.read(permissionsControllerProvider).microphoneGranted;
      final settings = ref.read(settingsControllerProvider).settings;
      final voiceActive = ref.read(voiceActivationProvider).isActive;
      if (!mic) {
        ref.read(assistantUiProvider.notifier).setIdle('Allow microphone');
      } else if (settings?.wakeWordEnabled == false) {
        ref.read(assistantUiProvider.notifier).setIdle('Wake word off');
      } else if (voiceActive) {
        ref.read(assistantUiProvider.notifier).setListening('Listening');
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final ui = ref.watch(assistantUiProvider);
    final settings = ref.watch(settingsControllerProvider).settings;
    final openAi = ref.watch(openAiSettingsProvider);
    final voice = ref.watch(voiceActivationProvider);
    final name = settings?.assistantName ?? 'Noctros';
    final theme = Theme.of(context);
    final alwaysOn = settings?.wakeWordEnabled ?? true;
    final statusTitle = _statusTitle(ui.visual, alwaysOn);
    final statusHint = alwaysOn
        ? "Say '$name' anytime."
        : 'Wake word is off — enable it in Settings.';

    return PremiumBackground(
      child: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 12, 0),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(name, style: theme.textTheme.headlineMedium),
                        const SizedBox(height: 2),
                        Text(
                          'Your private AI device assistant.',
                          style: theme.textTheme.bodyMedium,
                        ),
                      ],
                    ),
                  ),
                  _RoundAction(
                    icon: Icons.settings_rounded,
                    label: 'Settings',
                    onTap: () => context.push(SettingsScreen.routePath),
                  ),
                  const SizedBox(width: 8),
                  _RoundAction(
                    icon: Icons.sos_rounded,
                    label: 'SOS',
                    color: theme.colorScheme.error,
                    onTap: () => context.push(EmergencyScreen.routePath),
                  ),
                  PopupMenuButton<String>(
                    tooltip: 'More',
                    icon: const Icon(Icons.more_vert_rounded),
                    onSelected: (value) {
                      switch (value) {
                        case 'chat':
                          context.push(ChatScreen.routePath);
                        case 'history':
                          context.push(ChatHistoryScreen.routePath);
                        case 'settings':
                          context.push(SettingsScreen.routePath);
                        case 'sos':
                          context.push(EmergencyScreen.routePath);
                      }
                    },
                    itemBuilder: (context) => const [
                      PopupMenuItem(value: 'chat', child: Text('Chat')),
                      PopupMenuItem(value: 'history', child: Text('History')),
                      PopupMenuItem(value: 'settings', child: Text('Settings')),
                      PopupMenuItem(value: 'sos', child: Text('SOS')),
                    ],
                  ),
                ],
              ),
            ),
            const Spacer(flex: 2),
            SizedBox(
              height: MediaQuery.sizeOf(context).width * 0.78,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  EnergyWaves(state: ui.visual, height: 200),
                  AiOrb(
                    state: ui.visual,
                    size: MediaQuery.sizeOf(context).width * 0.68,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 280),
              child: Text(
                statusTitle,
                key: ValueKey(statusTitle),
                style: theme.textTheme.headlineSmall?.copyWith(
                  color: const Color(0xFFC4A8FF),
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              ui.partialTranscript.isNotEmpty
                  ? ui.partialTranscript
                  : statusHint,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium,
            ),
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(4, (index) {
                final colors = [
                  const Color(0xFFB388FF),
                  NoctrosThemeAccent.blue,
                  const Color(0xFFFF6AD5),
                  const Color(0xFF6EF3FF),
                ];
                return Container(
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  width: 7,
                  height: 7,
                  decoration: BoxDecoration(
                    color: colors[index].withValues(
                      alpha: ui.visual == AssistantVisualState.listening
                          ? 1
                          : 0.45,
                    ),
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: colors[index].withValues(alpha: 0.5),
                        blurRadius: 8,
                      ),
                    ],
                  ),
                );
              }),
            ),
            const Spacer(),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: VoiceEqualizer(state: ui.visual),
            ),
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                alignment: WrapAlignment.center,
                children: [
                  _StatusPill(
                    label: voice.isActive || alwaysOn
                        ? 'Always Listening'
                        : 'Listening Off',
                    ok: voice.isActive || alwaysOn,
                  ),
                  _StatusPill(
                    label: openAi.isConfigured ? 'AI Ready' : 'Offline AI',
                    ok: openAi.isConfigured,
                  ),
                  _StatusPill(
                    label: 'Voice Active',
                    ok: alwaysOn,
                  ),
                  const _StatusPill(label: 'Secure', ok: true),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _statusTitle(AssistantVisualState state, bool alwaysOn) {
    return switch (state) {
      AssistantVisualState.idle => alwaysOn ? 'Listening' : 'Ready',
      AssistantVisualState.listening => 'Listening',
      AssistantVisualState.thinking => 'Thinking',
      AssistantVisualState.speaking => 'Speaking',
    };
  }
}

/// Local accent tokens for status dots without importing theme internals.
class NoctrosThemeAccent {
  static const blue = Color(0xFF6EA8FF);
}

class _RoundAction extends StatelessWidget {
  const _RoundAction({
    required this.icon,
    required this.label,
    required this.onTap,
    this.color,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final c = color ?? Theme.of(context).colorScheme.primary;
    return Column(
      children: [
        Material(
          color: c.withValues(alpha: 0.14),
          shape: const CircleBorder(),
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Icon(icon, color: c, size: 22),
            ),
          ),
        ),
        const SizedBox(height: 4),
        Text(label, style: Theme.of(context).textTheme.labelSmall),
      ],
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.label, required this.ok});

  final String label;
  final bool ok;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        color: Colors.white.withValues(alpha: 0.06),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 7,
            height: 7,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: ok ? const Color(0xFF5CFFB1) : Colors.orangeAccent,
            ),
          ),
          const SizedBox(width: 8),
          Text(label, style: Theme.of(context).textTheme.labelMedium),
        ],
      ),
    );
  }
}
