import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/di/service_locator.dart';
import '../../../core/config/openai_config_service.dart';
import '../../../domain/entities/noctros_entities.dart';
import '../../../domain/entities/noctros_enums.dart';
import '../../../domain/entities/permission_entities.dart';
import '../../../engines/security/voice_enrollment.dart';
import '../../../engines/security/voice_print_manager.dart';
import '../../../engines/voice/voice_engine.dart';
import '../../providers/noctros_providers.dart';
import '../../providers/openai_providers.dart';
import '../../providers/permission_providers.dart';
import '../../widgets/permission_prompt_sheet.dart';

class VoiceSettingsScreen extends ConsumerStatefulWidget {
  const VoiceSettingsScreen({super.key});

  static const routePath = '/settings/voice';
  static const routeName = 'voice-settings';

  @override
  ConsumerState<VoiceSettingsScreen> createState() =>
      _VoiceSettingsScreenState();
}

class _VoiceSettingsScreenState extends ConsumerState<VoiceSettingsScreen> {
  bool _enrolling = false;
  bool _hasVoicePrint = false;
  final _nameController = TextEditingController();
  final _emergencyController = TextEditingController();

  @override
  void initState() {
    super.initState();
    Future.microtask(() async {
      await ref.read(settingsControllerProvider.notifier).load();
      await ref.read(openAiSettingsProvider.notifier).load();
      await ref.read(permissionsControllerProvider.notifier).refresh();
      final settings = ref.read(settingsControllerProvider).settings;
      _nameController.text = settings?.assistantName ?? 'Noctros';
      _emergencyController.text = settings?.emergencyNumber ?? '112';
      _hasVoicePrint =
          await ServiceLocator.get<VoicePrintManager>().hasEnrollment();
      if (mounted) {
        setState(() {});
      }
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emergencyController.dispose();
    super.dispose();
  }

  Future<void> _save(UserSettings settings) async {
    await ref.read(settingsControllerProvider.notifier).save(settings);
    final voice = ServiceLocator.get<VoiceEngine>();
    await voice.configureVoice(
      speechRate: settings.speechRate,
      speechPitch: settings.speechPitch,
      speechVolume: settings.speechVolume,
      localeId: settings.sttLocaleId,
      wakeWords: settings.derivedWakeWords,
      voiceGender: settings.voiceGender,
      sttBackend: settings.sttBackend,
      cloudSttFallbackEnabled: settings.cloudSttFallbackEnabled,
    );
    await ref.read(openAiSettingsProvider.notifier).setSpeechRate(
          settings.speechRate,
        );
    await ref.read(openAiSettingsProvider.notifier).setSttLocale(
          settings.sttLocaleId,
        );
    await ref
        .read(openAiSettingsProvider.notifier)
        .setTtsEnabled(settings.ttsEnabled);
  }

  Future<void> _enrollVoice() async {
    final mic = ref.read(permissionsControllerProvider).microphoneGranted;
    if (!mic) {
      await PermissionPromptSheet.show(
        context,
        permission: NoctrosPermission.microphone,
      );
      return;
    }
    setState(() => _enrolling = true);
    try {
      final enrollment = ServiceLocator.get<VoiceEnrollment>();
      await enrollment.enroll(
        onSampleCaptured: (index) {
          if (!mounted) {
            return;
          }
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Captured sample $index of 3')),
          );
        },
      );
      final settings = ref.read(settingsControllerProvider).settings;
      if (settings != null) {
        await _save(settings.copyWith(voiceIdEnabled: true));
      }
      _hasVoicePrint = true;
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Owner voice enrolled securely.')),
        );
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Enrollment failed: $error')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _enrolling = false);
      }
    }
  }

  Future<void> _retrainVoice() async {
    setState(() => _enrolling = true);
    try {
      await ServiceLocator.get<VoiceEnrollment>().retrain();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Voice print updated.')),
        );
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Retrain failed: $error')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _enrolling = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final settingsState = ref.watch(settingsControllerProvider);
    final settings = settingsState.settings;

    return Scaffold(
      appBar: AppBar(title: const Text('Voice Settings')),
      body: settings == null || settingsState.isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(20),
              children: [
                Text(
                  'Voice Core',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Configure wake word, speech, Voice ID, and emergency voice behavior.',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                ),
                const SizedBox(height: 20),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Enable wake word'),
                  subtitle: const Text('Battery-aware hotword listening'),
                  value: settings.wakeWordEnabled,
                  onChanged: (value) => _save(
                    settings.copyWith(wakeWordEnabled: value),
                  ),
                ),
                TextField(
                  controller: _nameController,
                  decoration: const InputDecoration(
                    labelText: 'Assistant name / wake word',
                    helperText:
                        'Examples: Noctros, Nova, Friday, Motor, Jarvis',
                  ),
                  onSubmitted: (value) async {
                    final name = value.trim().isEmpty ? 'Noctros' : value.trim();
                    await _save(
                      settings.copyWith(
                        assistantName: name,
                        wakeWords: ['Hey $name', name],
                      ),
                    );
                  },
                ),
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton.icon(
                    onPressed: () async {
                      final name = _nameController.text.trim().isEmpty
                          ? 'Noctros'
                          : _nameController.text.trim();
                      await _save(
                        settings.copyWith(
                          assistantName: name,
                          wakeWords: ['Hey $name', name],
                        ),
                      );
                      if (!mounted) {
                        return;
                      }
                      ScaffoldMessenger.of(this.context).showSnackBar(
                        SnackBar(content: Text('Wake word set to $name')),
                      );
                    },
                    icon: const Icon(Icons.save_outlined),
                    label: const Text('Save name'),
                  ),
                ),
                Text(
                  'Active phrases: ${settings.derivedWakeWords.join(', ')}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: 16),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Speak replies (TTS)'),
                  value: settings.ttsEnabled,
                  onChanged: (value) => _save(
                    settings.copyWith(ttsEnabled: value),
                  ),
                ),
                DropdownMenu<VoiceGender>(
                  initialSelection: settings.voiceGender,
                  label: const Text('Voice gender'),
                  dropdownMenuEntries: VoiceGender.values
                      .map(
                        (gender) => DropdownMenuEntry(
                          value: gender,
                          label: gender.name,
                        ),
                      )
                      .toList(),
                  onSelected: (value) {
                    if (value == null) {
                      return;
                    }
                    _save(settings.copyWith(voiceGender: value));
                  },
                ),
                const SizedBox(height: 12),
                const Text('Speech speed'),
                Slider(
                  value: settings.speechRate.clamp(0.2, 1.0),
                  min: 0.2,
                  max: 1.0,
                  divisions: 16,
                  label: settings.speechRate.toStringAsFixed(2),
                  onChanged: (value) => _save(
                    settings.copyWith(speechRate: value),
                  ),
                ),
                const Text('Speech pitch'),
                Slider(
                  value: settings.speechPitch.clamp(0.5, 2.0),
                  min: 0.5,
                  max: 2.0,
                  divisions: 15,
                  label: settings.speechPitch.toStringAsFixed(2),
                  onChanged: (value) => _save(
                    settings.copyWith(speechPitch: value),
                  ),
                ),
                const Text('Speech volume'),
                Slider(
                  value: settings.speechVolume.clamp(0.0, 1.0),
                  min: 0.0,
                  max: 1.0,
                  divisions: 10,
                  label: settings.speechVolume.toStringAsFixed(2),
                  onChanged: (value) => _save(
                    settings.copyWith(speechVolume: value),
                  ),
                ),
                DropdownMenu<String>(
                  initialSelection: settings.sttLocaleId,
                  label: const Text('Voice language'),
                  dropdownMenuEntries: OpenAiConfigService.supportedSttLocales
                      .map(
                        (locale) => DropdownMenuEntry(
                          value: locale,
                          label: locale,
                        ),
                      )
                      .toList(),
                  onSelected: (value) {
                    if (value == null) {
                      return;
                    }
                    _save(settings.copyWith(sttLocaleId: value));
                  },
                ),
                const SizedBox(height: 12),
                DropdownMenu<SttBackend>(
                  initialSelection: settings.sttBackend,
                  label: const Text('Speech recognition'),
                  dropdownMenuEntries: SttBackend.values
                      .map(
                        (backend) => DropdownMenuEntry(
                          value: backend,
                          label: backend.name,
                        ),
                      )
                      .toList(),
                  onSelected: (value) {
                    if (value == null) {
                      return;
                    }
                    _save(settings.copyWith(sttBackend: value));
                  },
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Cloud STT fallback'),
                  subtitle: const Text('Use Whisper when offline STT fails'),
                  value: settings.cloudSttFallbackEnabled,
                  onChanged: (value) => _save(
                    settings.copyWith(cloudSttFallbackEnabled: value),
                  ),
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Continuous voice conversation'),
                  value: settings.continuousVoiceEnabled,
                  onChanged: (value) => _save(
                    settings.copyWith(continuousVoiceEnabled: value),
                  ),
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Prepare always-listening'),
                  subtitle: const Text(
                    'Battery-aware duty-cycled wake architecture',
                  ),
                  value: settings.alwaysListeningPrepared,
                  onChanged: (value) async {
                    await _save(
                      settings.copyWith(alwaysListeningPrepared: value),
                    );
                    if (value) {
                      await ServiceLocator.get<VoiceEngine>()
                          .prepareAlwaysListeningBackgroundService();
                    }
                  },
                ),
                const Divider(height: 32),
                Text(
                  'Voice ID',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Enable Voice ID'),
                  subtitle: Text(
                    _hasVoicePrint
                        ? 'Owner print enrolled — unknown voices get emergency-only access'
                        : 'Enroll your voice before enabling',
                  ),
                  value: settings.voiceIdEnabled,
                  onChanged: (value) async {
                    if (value && !_hasVoicePrint) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Enroll your voice first.'),
                        ),
                      );
                      return;
                    }
                    await _save(settings.copyWith(voiceIdEnabled: value));
                  },
                ),
                FilledButton.icon(
                  onPressed: _enrolling ? null : _enrollVoice,
                  icon: _enrolling
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.record_voice_over),
                  label: Text(
                    _hasVoicePrint ? 'Re-enroll owner voice' : 'Enroll my voice',
                  ),
                ),
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  onPressed: !_hasVoicePrint || _enrolling ? null : _retrainVoice,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Retrain voice'),
                ),
                TextButton(
                  onPressed: !_hasVoicePrint
                      ? null
                      : () async {
                          await ServiceLocator.get<VoicePrintManager>()
                              .deleteEnrollment();
                          await _save(
                            settings.copyWith(voiceIdEnabled: false),
                          );
                          setState(() => _hasVoicePrint = false);
                        },
                  child: const Text('Delete voice print'),
                ),
                const Divider(height: 32),
                Text(
                  'Emergency voice',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Auto emergency response'),
                  subtitle: const Text(
                    'Skip confirmation for emergency phrases when enabled',
                  ),
                  value: settings.emergencyAutoDialEnabled,
                  onChanged: (value) => _save(
                    settings.copyWith(emergencyAutoDialEnabled: value),
                  ),
                ),
                TextField(
                  controller: _emergencyController,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(
                    labelText: 'Emergency number',
                    helperText: 'Default 112 — opens dialer when confirmed',
                  ),
                  onSubmitted: (value) => _save(
                    settings.copyWith(
                      emergencyNumber: value.trim().isEmpty ? '112' : value.trim(),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'Privacy: voice prints stay encrypted in secure storage and are never uploaded.',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
    );
  }
}
