import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../domain/entities/agent_mesh_entities.dart';
import '../../../domain/entities/noctros_enums.dart';
import '../../providers/agent_mesh_providers.dart';
import '../../widgets/atmosphere_scaffold.dart';

class HiveScreen extends ConsumerStatefulWidget {
  const HiveScreen({super.key});

  static const routePath = '/assistant/hive';
  static const routeName = 'hive';

  @override
  ConsumerState<HiveScreen> createState() => _HiveScreenState();
}

class _HiveScreenState extends ConsumerState<HiveScreen> {
  final _controller = TextEditingController();
  final _scrollController = ScrollController();

  static const _prompts = [
    'Build a daily planner program',
    'Create a habit tracker app',
    'Write a reminders feature',
  ];

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _launch([String? preset]) async {
    final goal = (preset ?? _controller.text).trim();
    if (goal.isEmpty) {
      return;
    }
    if (preset != null) {
      _controller.text = preset;
    }
    await ref.read(hiveControllerProvider.notifier).launch(goal);
    _scrollToEnd();
  }

  void _scrollToEnd() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) {
        return;
      }
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 280),
        curve: Curves.easeOut,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final hive = ref.watch(hiveControllerProvider);
    final session = hive.session;
    final theme = Theme.of(context);

    ref.listen(hiveControllerProvider, (previous, next) {
      if ((next.session?.transcript.length ?? 0) !=
          (previous?.session?.transcript.length ?? 0)) {
        _scrollToEnd();
      }
    });

    return AtmosphereScaffold(
      appBar: AppBar(
        title: const Text('Hive'),
      ),
      child: Column(
        children: [
          Expanded(
            child: ListView(
              controller: _scrollController,
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
              children: [
                Text(
                  'One autonomous system',
                  style: theme.textTheme.headlineSmall,
                ),
                const SizedBox(height: 6),
                Text(
                  'Every Noctros agent shares a bus. Ask them to build a program and watch them talk.',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: hive.roster
                      .map(
                        (identity) => _AgentChip(
                          identity: identity,
                          activity: session?.activities[identity.role] ??
                              AgentActivity.idle,
                        ),
                      )
                      .toList(),
                ),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 8,
                  children: _prompts
                      .map(
                        (prompt) => ActionChip(
                          label: Text(prompt),
                          onPressed:
                              hive.isLaunching ? null : () => _launch(prompt),
                        ),
                      )
                      .toList(),
                ),
                if (session != null) ...[
                  const SizedBox(height: 20),
                  Text(session.goal, style: theme.textTheme.titleMedium),
                  const SizedBox(height: 4),
                  Text(
                    session.status.name,
                    style: theme.textTheme.labelLarge?.copyWith(
                      color: theme.colorScheme.primary,
                    ),
                  ),
                  const SizedBox(height: 12),
                  ...session.transcript.map(
                    (message) => _TranscriptTile(message: message),
                  ),
                  if (session.artifacts.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Text('Artifacts', style: theme.textTheme.titleMedium),
                    const SizedBox(height: 8),
                    ...session.artifacts.entries.map(
                      (entry) => _ArtifactTile(
                        name: entry.key,
                        body: entry.value,
                      ),
                    ),
                  ],
                  if (session.userSummary != null) ...[
                    const SizedBox(height: 12),
                    Text('Hive answer', style: theme.textTheme.titleMedium),
                    const SizedBox(height: 8),
                    Text(session.userSummary!),
                  ],
                ],
              ],
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _controller,
                      minLines: 1,
                      maxLines: 3,
                      textInputAction: TextInputAction.send,
                      enabled: !hive.isLaunching,
                      onSubmitted: (_) => _launch(),
                      decoration: const InputDecoration(
                        hintText: 'Build a program…',
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  FilledButton(
                    onPressed: hive.isLaunching ? null : () => _launch(),
                    child: hive.isLaunching
                        ? SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: theme.colorScheme.onPrimary,
                            ),
                          )
                        : const Icon(Icons.hub_rounded),
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

class _AgentChip extends StatelessWidget {
  const _AgentChip({
    required this.identity,
    required this.activity,
  });

  final AgentIdentity identity;
  final AgentActivity activity;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final active = activity != AgentActivity.idle;
    return Tooltip(
      message: identity.specialty,
      child: Chip(
        avatar: CircleAvatar(
          backgroundColor: active
              ? theme.colorScheme.primary
              : theme.colorScheme.surfaceContainerHighest,
          child: Text(
            identity.displayName.substring(0, 1),
            style: theme.textTheme.labelSmall?.copyWith(
              color: active
                  ? theme.colorScheme.onPrimary
                  : theme.colorScheme.onSurface,
            ),
          ),
        ),
        label: Text(identity.displayName),
      ),
    );
  }
}

class _TranscriptTile extends StatelessWidget {
  const _TranscriptTile({required this.message});

  final AgentMessage message;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: theme.colorScheme.surface.withValues(alpha: 0.72),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${message.routeLabel} · ${message.topic}',
                style: theme.textTheme.labelMedium?.copyWith(
                  color: theme.colorScheme.primary,
                ),
              ),
              const SizedBox(height: 4),
              Text(message.body, style: theme.textTheme.bodyMedium),
            ],
          ),
        ),
      ),
    );
  }
}

class _ArtifactTile extends StatelessWidget {
  const _ArtifactTile({
    required this.name,
    required this.body,
  });

  final String name;
  final String body;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: ExpansionTile(
        tilePadding: EdgeInsets.zero,
        title: Text(name),
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: SelectableText(
              body,
              style: theme.textTheme.bodySmall?.copyWith(
                fontFamily: 'monospace',
              ),
            ),
          ),
        ],
      ),
    );
  }
}
