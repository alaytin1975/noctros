import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../widgets/atmosphere_scaffold.dart';
import '../chat/chat_screen.dart';
import '../emergency/emergency_screen.dart';
import '../hive/hive_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  static const routePath = '/assistant';
  static const routeName = 'assistant';

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AtmosphereScaffold(
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 28, 24, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Noctros', style: theme.textTheme.displaySmall),
              const SizedBox(height: 8),
              Text(
                'Your communication companion — message people, place calls, and ask for help by voice.',
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const Spacer(),
              Center(
                child: TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0.92, end: 1),
                  duration: const Duration(milliseconds: 1200),
                  curve: Curves.easeInOut,
                  builder: (context, value, child) {
                    return Transform.scale(scale: value, child: child);
                  },
                  child: Container(
                    width: 180,
                    height: 180,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(
                        colors: [
                          theme.colorScheme.primary.withValues(alpha: 0.85),
                          theme.colorScheme.primary.withValues(alpha: 0.15),
                          Colors.transparent,
                        ],
                      ),
                    ),
                    child: Icon(
                      Icons.mic_none_rounded,
                      size: 64,
                      color: theme.colorScheme.onPrimary,
                    ),
                  ),
                ),
              ),
              const Spacer(),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: () => context.push(ChatScreen.routePath),
                  icon: const Icon(Icons.chat_rounded),
                  label: const Text('Talk to Noctros'),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: FilledButton.tonalIcon(
                  onPressed: () => context.push(HiveScreen.routePath),
                  icon: const Icon(Icons.hub_rounded),
                  label: const Text('Open the Hive'),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () => context.push(EmergencyScreen.routePath),
                  icon: const Icon(Icons.emergency_outlined),
                  label: const Text('Emergency tools'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
