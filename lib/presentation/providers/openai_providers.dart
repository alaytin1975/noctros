import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/di/service_locator.dart';
import '../../core/config/openai_config_service.dart';

class OpenAiSettingsState {
  const OpenAiSettingsState({
    this.apiKey = '',
    this.model = 'gpt-4o-mini',
    this.ttsEnabled = true,
    this.speechRate = 0.48,
    this.sttLocaleId = 'en_US',
    this.isConfigured = false,
    this.isLoading = true,
  });

  final String apiKey;
  final String model;
  final bool ttsEnabled;
  final double speechRate;
  final String sttLocaleId;
  final bool isConfigured;
  final bool isLoading;

  OpenAiSettingsState copyWith({
    String? apiKey,
    String? model,
    bool? ttsEnabled,
    double? speechRate,
    String? sttLocaleId,
    bool? isConfigured,
    bool? isLoading,
  }) {
    return OpenAiSettingsState(
      apiKey: apiKey ?? this.apiKey,
      model: model ?? this.model,
      ttsEnabled: ttsEnabled ?? this.ttsEnabled,
      speechRate: speechRate ?? this.speechRate,
      sttLocaleId: sttLocaleId ?? this.sttLocaleId,
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
    state = OpenAiSettingsState(
      apiKey: key,
      model: await _configService.getModel(),
      ttsEnabled: await _configService.isTtsEnabled(),
      speechRate: await _configService.getSpeechRate(),
      sttLocaleId: await _configService.getSttLocale(),
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

  Future<void> setSpeechRate(double rate) async {
    await _configService.setSpeechRate(rate);
    state = state.copyWith(speechRate: rate);
  }

  Future<void> setSttLocale(String localeId) async {
    await _configService.setSttLocale(localeId);
    state = state.copyWith(sttLocaleId: localeId);
  }
}

final openAiSettingsProvider =
    StateNotifierProvider<OpenAiSettingsController, OpenAiSettingsState>((ref) {
  return OpenAiSettingsController(ServiceLocator.get<OpenAiConfigService>());
});
