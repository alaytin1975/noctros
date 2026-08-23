import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';

import '../../../app/di/service_locator.dart';
import '../../../core/config/openai_config_service.dart';
import '../../../core/constants/noctros_constants.dart';
import '../../../domain/entities/noctros_entities.dart';
import '../../../domain/entities/noctros_enums.dart';
import '../../../domain/usecases/manage_local_data_use_case.dart';
import '../../../domain/usecases/manage_memory_use_case.dart';
import '../../../engines/voice/voice_engine.dart';
import '../../providers/noctros_providers.dart';
import '../../providers/openai_providers.dart';
import '../../providers/permission_providers.dart';
import '../../widgets/glass_panel.dart';
import '../../widgets/permission_prompt_sheet.dart';
import 'voice_settings_screen.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  static const routePath = '/settings';
  static const routeName = 'settings';

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  late final ManageMemoryUseCase _manageMemoryUseCase;
  late final ManageLocalDataUseCase _manageLocalDataUseCase;

  @override
  void initState() {
    super.initState();
    _manageMemoryUseCase = ManageMemoryUseCase();
    _manageLocalDataUseCase = ManageLocalDataUseCase();
    Future.microtask(() async {
      await ref.read(settingsControllerProvider.notifier).load();
      await ref.read(permissionsControllerProvider.notifier).refresh();
      await ref.read(openAiSettingsProvider.notifier).load();
    });
  }

  Future<void> _update(UserSettings settings) {
    return ref.read(settingsControllerProvider.notifier).save(settings);
  }

  @override
  Widget build(BuildContext context) {
    final settingsState = ref.watch(settingsControllerProvider);
    final settings = settingsState.settings;
    final openAi = ref.watch(openAiSettingsProvider);
    final theme = Theme.of(context);

    if (settingsState.isLoading || settings == null || openAi.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(12, 8, 20, 32),
        children: [
          Row(
            children: [
              IconButton(
                onPressed: () {
                  if (context.canPop()) {
                    context.pop();
                  } else {
                    context.go('/');
                  }
                },
                icon: const Icon(Icons.arrow_back_rounded),
              ),
              Text('Settings', style: theme.textTheme.headlineMedium),
            ],
          ),
          Padding(
            padding: const EdgeInsets.only(left: 12),
            child: Text(
              'Noctros v${NoctrosConstants.appVersion}+${NoctrosConstants.appBuild}',
              style: theme.textTheme.bodyMedium,
            ),
          ),
          const SizedBox(height: 20),
          GlassPanel(
            child: Column(
              children: [
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.record_voice_over_rounded),
                  title: const Text('Voice & wake word'),
                  subtitle: Text('Assistant: ${settings.assistantName}'),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => const VoiceSettingsScreen(),
                      ),
                    );
                  },
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  secondary: const Icon(Icons.hearing_rounded),
                  title: const Text('Always listening'),
                  subtitle: const Text('Keep wake-word detection active'),
                  value: settings.wakeWordEnabled,
                  onChanged: (value) => _update(
                    settings.copyWith(wakeWordEnabled: value),
                  ),
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  secondary: const Icon(Icons.battery_saver_rounded),
                  title: const Text('Battery-optimized listening'),
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
              ],
            ),
          ),
          const SizedBox(height: 14),
          GlassPanel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Appearance', style: theme.textTheme.titleMedium),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Dark theme'),
                  value: settings.darkModeEnabled,
                  onChanged: (value) =>
                      _update(settings.copyWith(darkModeEnabled: value)),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          GlassPanel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('AI provider', style: theme.textTheme.titleMedium),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('API key'),
                  subtitle: Text(
                    openAi.isConfigured ? 'Configured securely' : 'Not set',
                  ),
                  trailing: const Icon(Icons.key_rounded),
                  onTap: _editApiKey,
                ),
                DropdownMenu<String>(
                  initialSelection: openAi.model,
                  label: const Text('Model'),
                  dropdownMenuEntries: OpenAiConfigService.supportedModels
                      .map(
                        (model) => DropdownMenuEntry(value: model, label: model),
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
                const SizedBox(height: 12),
                DropdownMenu<AiExecutionMode>(
                  initialSelection: settings.aiExecutionMode,
                  label: const Text('Execution mode'),
                  dropdownMenuEntries: AiExecutionMode.values
                      .map(
                        (mode) =>
                            DropdownMenuEntry(value: mode, label: mode.name),
                      )
                      .toList(),
                  onSelected: (value) {
                    if (value != null) {
                      _update(settings.copyWith(aiExecutionMode: value));
                    }
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          GlassPanel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Speech', style: theme.textTheme.titleMedium),
                Text('Speed', style: theme.textTheme.bodyMedium),
                Slider(
                  value: settings.speechRate.clamp(0.2, 1.0),
                  min: 0.2,
                  max: 1.0,
                  onChanged: (value) =>
                      _update(settings.copyWith(speechRate: value)),
                ),
                Text('Volume', style: theme.textTheme.bodyMedium),
                Slider(
                  value: settings.speechVolume.clamp(0.0, 1.0),
                  min: 0.0,
                  max: 1.0,
                  onChanged: (value) =>
                      _update(settings.copyWith(speechVolume: value)),
                ),
                DropdownMenu<String>(
                  initialSelection: settings.sttLocaleId,
                  label: const Text('Language'),
                  dropdownMenuEntries: OpenAiConfigService.supportedSttLocales
                      .map(
                        (locale) =>
                            DropdownMenuEntry(value: locale, label: locale),
                      )
                      .toList(),
                  onSelected: (value) {
                    if (value != null) {
                      _update(settings.copyWith(sttLocaleId: value));
                    }
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          GlassPanel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Notifications & privacy', style: theme.textTheme.titleMedium),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Local memory'),
                  value: settings.memoryEnabled,
                  onChanged: (value) =>
                      _update(settings.copyWith(memoryEnabled: value)),
                ),
                DropdownMenu<PrivacyCloudPolicy>(
                  initialSelection: settings.cloudPolicy,
                  label: const Text('Cloud policy'),
                  dropdownMenuEntries: PrivacyCloudPolicy.values
                      .map(
                        (policy) => DropdownMenuEntry(
                          value: policy,
                          label: policy.name,
                        ),
                      )
                      .toList(),
                  onSelected: (value) {
                    if (value != null) {
                      _update(settings.copyWith(cloudPolicy: value));
                    }
                  },
                ),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Export local data'),
                  trailing: const Icon(Icons.upload_rounded),
                  onTap: () async {
                    final result =
                        await _manageLocalDataUseCase.exportLocalData();
                    if (result.isSuccess) {
                      await Share.share(result.valueOrThrow);
                    }
                  },
                ),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Delete local data'),
                  trailing: const Icon(Icons.delete_forever_rounded),
                  onTap: () async {
                    final ok = await showDialog<bool>(
                      context: context,
                      builder: (context) => AlertDialog(
                        title: const Text('Delete local data?'),
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
                    if (ok == true) {
                      await _manageLocalDataUseCase.deleteLocalData();
                      await _manageMemoryUseCase.forgetAll();
                      await ref.read(settingsControllerProvider.notifier).load();
                    }
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          GlassPanel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Permissions', style: theme.textTheme.titleMedium),
                const SizedBox(height: 8),
                ...corePermissions.map(
                  (permission) => PermissionTile(permission: permission),
                ),
              ],
            ),
          ),
        ],
      ),
    );
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
          decoration: const InputDecoration(hintText: 'sk-...'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
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
}
