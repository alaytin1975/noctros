import 'package:flutter/material.dart';

import '../../widgets/main_shell.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  static const routePath = '/';
  static const routeName = 'home';

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Noctros'),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Your second brain.',
                style: theme.textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Voice-first AI that controls your phone, manages your life, and protects you in emergencies.',
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 24),
              Expanded(
                child: GridView.count(
                  crossAxisCount:
                      MediaQuery.sizeOf(context).width > 600 ? 3 : 2,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                  childAspectRatio: 0.82,
                  children: [
                    _FeatureTile(
                      icon: Icons.mic_rounded,
                      title: 'Talk to Noctros',
                      subtitle: 'Text and voice conversations',
                      onTap: () => MainShell.goToChat(context),
                    ),
                    _FeatureTile(
                      icon: Icons.psychology_alt_outlined,
                      title: 'Smart Memory',
                      subtitle: 'Permission-based recall',
                      onTap: () => MainShell.goToSettings(context),
                    ),
                    _FeatureTile(
                      icon: Icons.emergency_outlined,
                      title: 'Emergency',
                      subtitle: 'SOS and safety tools',
                      onTap: () => MainShell.goToEmergency(context),
                      accent: theme.colorScheme.error,
                    ),
                    _FeatureTile(
                      icon: Icons.phone_android_outlined,
                      title: 'Phone Control',
                      subtitle: 'Apps, calls, settings',
                      onTap: () => MainShell.goToChat(context),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => MainShell.goToChat(context),
        icon: const Icon(Icons.mic),
        label: const Text('Hey Noctros'),
      ),
    );
  }
}

class _FeatureTile extends StatelessWidget {
  const _FeatureTile({
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
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Icon(icon, color: color, size: 24),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
