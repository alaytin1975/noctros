import 'env_config.dart';
import '../../data/local/secure/secure_storage_service.dart';

/// Resolves OpenAI credentials from secure storage first, then `.env`.
class OpenAiConfigService {
  OpenAiConfigService({required SecureStorageService secureStorage})
      : _secureStorage = secureStorage;

  static const apiKeyStorageKey = 'openai_api_key';
  static const modelStorageKey = 'openai_model';
  static const ttsEnabledStorageKey = 'openai_tts_enabled';

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

  Future<bool> isConfigured() async {
    final key = await getApiKey();
    return key != null && key.isNotEmpty;
  }

  String get baseUrl => EnvConfig.openAiBaseUrl;
}
