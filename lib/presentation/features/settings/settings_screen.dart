import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/di/service_locator.dart';
import '../../../core/config/openai_config_service.dart';
import '../../../domain/entities/noctros_entities.dart';
import '../../../domain/entities/noctros_enums.dart';
import '../../../domain/usecases/manage_memory_use_case.dart';
import '../../../engines/voice/voice_engine.dart';
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

  Future<void> _syncVoiceEngine(OpenAiSettingsState openAi) async {
    final voice = ServiceLocator.get<VoiceEngine>();
    await voice.configureVoice(
      speechRate: openAi.speechRate,
      localeId: openAi.sttLocaleId,
    );
  }

  @override
  Widget build(BuildContext context) {
    final settingsState = ref.watch(settingsControllerProvider);
    final settings = settingsState.settings;
    final openAi = ref.watch(openAiSettingsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: settingsState.isLoading || settings == null || openAi.isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(20),
              children: [
                const _SectionHeader(title: 'Appearance'),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
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
                        : 'Not set — use Settings or .env',
                  ),
                  trailing: const Icon(Icons.key_outlined),
                  onTap: _editApiKey,
                ),
                DropdownMenu<String>(
                  initialSelection: openAi.model,
                  label: const Text('AI model'),
                  dropdownMenuEntries: OpenAiConfigService.supportedModels
                      .map(
                        (model) => DropdownMenuEntry(
                          value: model,
                          label: model,
                        ),
                      )
                      .toList(),
                  onSelected: (value) async {
                    if (value == null) {
                      return;
                    }
                    await ref
                        .read(openAiSettingsProvider.notifier)
                        .saveModel(value);
                  },
                ),
                const SizedBox(height: 8),
                const _SectionHeader(title: 'Voice'),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Speak replies (TTS)'),
                  value: openAi.ttsEnabled,
                  onChanged: (value) async {
                    await ref
                        .read(openAiSettingsProvider.notifier)
                        .setTtsEnabled(value);
                    await _update(settings.copyWith(ttsEnabled: value));
                  },
                ),
                Text('Speech speed', style: Theme.of(context).textTheme.bodyMedium),
                Slider(
                  value: openAi.speechRate.clamp(0.2, 1.0),
                  min: 0.2,
                  max: 1.0,
                  divisions: 16,
                  label: openAi.speechRate.toStringAsFixed(2),
                  onChanged: (value) async {
                    await ref
                        .read(openAiSettingsProvider.notifier)
                        .setSpeechRate(value);
                    await _syncVoiceEngine(
                      ref.read(openAiSettingsProvider),
                    );
                    await _update(settings.copyWith(speechRate: value));
                  },
                ),
                DropdownMenu<String>(
                  initialSelection: openAi.sttLocaleId,
                  label: const Text('STT language'),
                  dropdownMenuEntries: OpenAiConfigService.supportedSttLocales
                      .map(
                        (locale) => DropdownMenuEntry(
                          value: locale,
                          label: locale,
                        ),
                      )
                      .toList(),
                  onSelected: (value) async {
                    if (value == null) {
                      return;
                    }
                    await ref
                        .read(openAiSettingsProvider.notifier)
                        .setSttLocale(value);
                    await _syncVoiceEngine(
                      ref.read(openAiSettingsProvider),
                    );
                    await _update(settings.copyWith(sttLocaleId: value));
                  },
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Continuous voice conversation'),
                  subtitle: const Text('Keep listening after each reply'),
                  value: settings.continuousVoiceEnabled,
                  onChanged: (value) => _update(
                    settings.copyWith(continuousVoiceEnabled: value),
                  ),
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Prepare always-listening service'),
                  subtitle: const Text(
                    'Battery-aware wake architecture for future background mode',
                  ),
                  value: settings.alwaysListeningPrepared,
                  onChanged: (value) async {
                    await _update(
                      settings.copyWith(alwaysListeningPrepared: value),
                    );
                    if (value) {
                      await ServiceLocator.get<VoiceEngine>()
                          .prepareAlwaysListeningBackgroundService();
                    }
                  },
                ),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Wake words'),
                  subtitle: Text(settings.wakeWords.join(', ')),
                ),
                const SizedBox(height: 8),
                const _SectionHeader(title: 'Permissions'),
                ...corePermissions.map(
                  (permission) => PermissionTile(permission: permission),
                ),
                const SizedBox(height: 8),
                const _SectionHeader(title: 'AI & Privacy'),
                DropdownMenu<AiExecutionMode>(
                  initialSelection: settings.aiExecutionMode,
                  label: const Text('AI execution mode'),
                  dropdownMenuEntries: AiExecutionMode.values
                      .map(
                        (mode) => DropdownMenuEntry(
                          value: mode,
                          label: mode.name,
                        ),
                      )
                      .toList(),
                  onSelected: (value) {
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
                        (policy) => DropdownMenuEntry(
                          value: policy,
                          label: policy.name,
                        ),
                      )
                      .toList(),
                  onSelected: (value) {
                    if (value == null) {
                      return;
                    }
                    _update(settings.copyWith(cloudPolicy: value));
                  },
                ),
                const SizedBox(height: 8),
                const _SectionHeader(title: 'Memory'),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Enable local AI memory'),
                  subtitle: const Text(
                    'Remember preferences only with your permission',
                  ),
                  value: settings.memoryEnabled,
                  onChanged: (value) => _update(
                    settings.copyWith(memoryEnabled: value),
                  ),
                ),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Delete all memory'),
                  trailing: const Icon(Icons.delete_outline),
                  onTap: _confirmDeleteMemory,
                ),
                const SizedBox(height: 8),
                const _SectionHeader(title: 'Emergency'),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Automatic emergency calling'),
                  subtitle: const Text('Disabled by default'),
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
    final saved = await showDialog<String>(
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
            onPressed: () => Navigator.pop(context, null),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, ''),
            child: const Text('Clear'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, controller.text),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (saved != null) {
      await ref.read(openAiSettingsProvider.notifier).saveApiKey(saved);
    }
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
