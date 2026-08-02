import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../domain/entities/noctros_entities.dart';
import '../../../domain/entities/noctros_enums.dart';
import '../../../domain/usecases/manage_memory_use_case.dart';
import '../../providers/noctros_providers.dart';
import '../../providers/openai_providers.dart';
import '../../providers/permission_providers.dart';
import '../../widgets/permission_prompt_sheet.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  static const routePath = '/settings';
  static const routeName = 'settings';

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  late final ManageMemoryUseCase _manageMemoryUseCase;

  @override
  void initState() {
    super.initState();
    _manageMemoryUseCase = ManageMemoryUseCase();
    Future.microtask(() async {
      await ref.read(settingsControllerProvider.notifier).load();
      await ref.read(permissionsControllerProvider.notifier).refresh();
      await ref.read(openAiSettingsProvider.notifier).load();
    });
  }

  @override
  Widget build(BuildContext context) {
    final settingsState = ref.watch(settingsControllerProvider);
    final settings = settingsState.settings;
    final openAi = ref.watch(openAiSettingsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: settingsState.isLoading || settings == null
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(20),
              children: [
                const _SectionHeader(title: 'Appearance'),
                SwitchListTile(
                  title: const Text('Dark mode'),
                  subtitle: const Text('Use Noctros dark theme'),
                  value: settings.darkModeEnabled,
                  onChanged: (value) => _update(
                    settings.copyWith(darkModeEnabled: value),
                  ),
                ),
                const SizedBox(height: 8),
                const _SectionHeader(title: 'OpenAI'),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('API key'),
                  subtitle: Text(
                    openAi.isConfigured
                        ? 'Configured (${_maskKey(openAi.apiKey)})'
                        : 'Not set — add via Settings or .env',
                  ),
                  trailing: const Icon(Icons.key_outlined),
                  onTap: _editApiKey,
                ),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Model'),
                  subtitle: Text(openAi.model),
                  trailing: const Icon(Icons.tune),
                  onTap: _editModel,
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Speak replies (TTS)'),
                  subtitle: const Text('Read assistant responses aloud'),
                  value: openAi.ttsEnabled,
                  onChanged: (value) => ref
                      .read(openAiSettingsProvider.notifier)
                      .setTtsEnabled(value),
                ),
                const SizedBox(height: 8),
                const _SectionHeader(title: 'Permissions'),
                ...corePermissions.map(
                  (permission) => PermissionTile(permission: permission),
                ),
                const SizedBox(height: 8),
                const _SectionHeader(title: 'Voice'),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Wake words'),
                  subtitle: Text(settings.wakeWords.join(', ')),
                ),
                const SizedBox(height: 8),
                const _SectionHeader(title: 'AI & Privacy'),
                DropdownMenu<AiExecutionMode>(
                  initialSelection: settings.aiExecutionMode,
                  label: const Text('AI execution mode'),
                  dropdownMenuEntries: AiExecutionMode.values
                      .map(
                        (AiExecutionMode mode) => DropdownMenuEntry(
                          value: mode,
                          label: mode.name,
                        ),
                      )
                      .toList(),
                  onSelected: (AiExecutionMode? value) {
                    if (value == null) {
                      return;
                    }
                    _update(settings.copyWith(aiExecutionMode: value));
                  },
                ),
                const SizedBox(height: 12),
                DropdownMenu<PrivacyCloudPolicy>(
                  initialSelection: settings.cloudPolicy,
                  label: const Text('Cloud data policy'),
                  dropdownMenuEntries: PrivacyCloudPolicy.values
                      .map(
                        (PrivacyCloudPolicy policy) => DropdownMenuEntry(
                          value: policy,
                          label: policy.name,
                        ),
                      )
                      .toList(),
                  onSelected: (PrivacyCloudPolicy? value) {
                    if (value == null) {
                      return;
                    }
                    _update(settings.copyWith(cloudPolicy: value));
                  },
                ),
                const SizedBox(height: 8),
                const _SectionHeader(title: 'Smart Memory'),
                SwitchListTile(
                  title: const Text('Enable memory'),
                  subtitle: const Text('Noctros remembers only with your permission.'),
                  value: settings.memoryEnabled,
                  onChanged: (value) => _update(
                    settings.copyWith(memoryEnabled: value),
                  ),
                ),
                ListTile(
                  title: const Text('Delete all memory'),
                  subtitle: const Text('Permanently erase stored preferences and habits.'),
                  trailing: const Icon(Icons.delete_outline),
                  onTap: _confirmDeleteMemory,
                ),
                const SizedBox(height: 8),
                const _SectionHeader(title: 'Emergency'),
                SwitchListTile(
                  title: const Text('Automatic emergency calling'),
                  subtitle: const Text('Disabled by default. Requires explicit opt-in.'),
                  value: settings.emergencyAutoDialEnabled,
                  onChanged: (value) => _update(
                    settings.copyWith(emergencyAutoDialEnabled: value),
                  ),
                ),
              ],
            ),
    );
  }

  Future<void> _update(UserSettings settings) {
    return ref.read(settingsControllerProvider.notifier).save(settings);
  }

  String _maskKey(String key) {
    if (key.length <= 8) {
      return '••••';
    }
    return '${key.substring(0, 3)}••••${key.substring(key.length - 4)}';
  }

  Future<void> _editApiKey() async {
    final controller = TextEditingController(
      text: ref.read(openAiSettingsProvider).apiKey,
    );
    final saved = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('OpenAI API key'),
        content: TextField(
          controller: controller,
          obscureText: true,
          decoration: const InputDecoration(
            hintText: 'sk-...',
            helperText: 'Stored securely on device. You can also use .env.',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              await ref
                  .read(openAiSettingsProvider.notifier)
                  .saveApiKey('');
              if (context.mounted) {
                Navigator.pop(context, true);
              }
            },
            child: const Text('Clear'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Save'),
          ),
        ],
      ),
    );

    if (saved == true) {
      await ref
          .read(openAiSettingsProvider.notifier)
          .saveApiKey(controller.text);
    }
    controller.dispose();
  }

  Future<void> _editModel() async {
    final controller = TextEditingController(
      text: ref.read(openAiSettingsProvider).model,
    );
    final saved = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('OpenAI model'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            hintText: 'gpt-4o-mini',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Save'),
          ),
        ],
      ),
    );

    if (saved == true && controller.text.trim().isNotEmpty) {
      await ref
          .read(openAiSettingsProvider.notifier)
          .saveModel(controller.text.trim());
    }
    controller.dispose();
  }

  Future<void> _confirmDeleteMemory() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete all memory?'),
        content: const Text(
          'This removes all stored preferences, routines, and habits from Noctros.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) {
      return;
    }

    final result = await _manageMemoryUseCase.forgetAll();
    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          result.isSuccess
              ? 'All memory deleted.'
              : result.failureOrNull?.message ?? 'Failed to delete memory.',
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8, top: 8),
      child: Text(
        title,
        style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
            ),
      ),
    );
  }
}
