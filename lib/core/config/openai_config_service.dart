import 'env_config.dart';
import '../../data/local/secure/secure_storage_service.dart';

/// Resolves OpenAI credentials and voice-related AI preferences.
class OpenAiConfigService {
  OpenAiConfigService({required SecureStorageService secureStorage})
      : _secureStorage = secureStorage;

  static const apiKeyStorageKey = 'openai_api_key';
  static const modelStorageKey = 'openai_model';
  static const ttsEnabledStorageKey = 'openai_tts_enabled';
  static const speechRateStorageKey = 'speech_rate';
  static const sttLocaleStorageKey = 'stt_locale';

  static const supportedModels = [
    'gpt-4o-mini',
    'gpt-4o',
    'gpt-4.1-mini',
    'gpt-4.1',
    'o4-mini',
  ];

  static const supportedSttLocales = [
    'en_US',
    'en_GB',
    'de_DE',
    'fr_FR',
    'es_ES',
    'it_IT',
    'pt_BR',
    'tr_TR',
    'ar_SA',
  ];

  final SecureStorageService _secureStorage;

  Future<String?> getApiKey() async {
    final stored = await _secureStorage.read(apiKeyStorageKey);
    if (stored != null && stored.trim().isNotEmpty) {
      return stored.trim();
    }
    if (EnvConfig.hasOpenAiApiKey) {
      return EnvConfig.openAiApiKey;
    }
    return null;
  }

  Future<void> setApiKey(String? value) async {
    final trimmed = value?.trim() ?? '';
    if (trimmed.isEmpty) {
      await _secureStorage.delete(apiKeyStorageKey);
      return;
    }
    await _secureStorage.write(apiKeyStorageKey, trimmed);
  }

  Future<String> getModel() async {
    final stored = await _secureStorage.read(modelStorageKey);
    if (stored != null && stored.trim().isNotEmpty) {
      return stored.trim();
    }
    return EnvConfig.openAiModel;
  }

  Future<void> setModel(String model) async {
    await _secureStorage.write(modelStorageKey, model.trim());
  }

  Future<bool> isTtsEnabled() async {
    final stored = await _secureStorage.read(ttsEnabledStorageKey);
    if (stored == null) {
      return true;
    }
    return stored == 'true';
  }

  Future<void> setTtsEnabled(bool enabled) async {
    await _secureStorage.write(ttsEnabledStorageKey, enabled.toString());
  }

  Future<double> getSpeechRate() async {
    final stored = await _secureStorage.read(speechRateStorageKey);
    return double.tryParse(stored ?? '') ?? 0.48;
  }

  Future<void> setSpeechRate(double rate) async {
    await _secureStorage.write(speechRateStorageKey, rate.toString());
  }

  Future<String> getSttLocale() async {
    final stored = await _secureStorage.read(sttLocaleStorageKey);
    if (stored == null || stored.isEmpty) {
      return 'en_US';
    }
    return stored;
  }

  Future<void> setSttLocale(String localeId) async {
    await _secureStorage.write(sttLocaleStorageKey, localeId);
  }

  Future<bool> isConfigured() async {
    final key = await getApiKey();
    return key != null && key.isNotEmpty;
  }

  String get baseUrl => EnvConfig.openAiBaseUrl;
}
