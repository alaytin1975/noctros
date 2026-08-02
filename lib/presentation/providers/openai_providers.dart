import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/di/service_locator.dart';
import '../../core/config/openai_config_service.dart';

class OpenAiSettingsState {
  const OpenAiSettingsState({
    this.apiKey = '',
    this.model = 'gpt-4o-mini',
    this.ttsEnabled = true,
    this.isConfigured = false,
    this.isLoading = true,
  });

  final String apiKey;
  final String model;
  final bool ttsEnabled;
  final bool isConfigured;
  final bool isLoading;

  OpenAiSettingsState copyWith({
    String? apiKey,
    String? model,
    bool? ttsEnabled,
    bool? isConfigured,
    bool? isLoading,
  }) {
    return OpenAiSettingsState(
      apiKey: apiKey ?? this.apiKey,
      model: model ?? this.model,
      ttsEnabled: ttsEnabled ?? this.ttsEnabled,
      isConfigured: isConfigured ?? this.isConfigured,
      isLoading: isLoading ?? this.isLoading,
    );
  }
}

class OpenAiSettingsController extends StateNotifier<OpenAiSettingsState> {
  OpenAiSettingsController(this._configService)
      : super(const OpenAiSettingsState());

  final OpenAiConfigService _configService;

  Future<void> load() async {
    state = state.copyWith(isLoading: true);
    final key = await _configService.getApiKey() ?? '';
    final model = await _configService.getModel();
    final tts = await _configService.isTtsEnabled();
    state = OpenAiSettingsState(
      apiKey: key,
      model: model,
      ttsEnabled: tts,
      isConfigured: key.isNotEmpty,
      isLoading: false,
    );
  }

  Future<void> saveApiKey(String apiKey) async {
    await _configService.setApiKey(apiKey);
    await load();
  }

  Future<void> saveModel(String model) async {
    await _configService.setModel(model);
    await load();
  }

  Future<void> setTtsEnabled(bool enabled) async {
    await _configService.setTtsEnabled(enabled);
    state = state.copyWith(ttsEnabled: enabled);
  }
}

final openAiSettingsProvider =
    StateNotifierProvider<OpenAiSettingsController, OpenAiSettingsState>((ref) {
  return OpenAiSettingsController(ServiceLocator.get<OpenAiConfigService>());
});
