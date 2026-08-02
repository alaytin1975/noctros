import 'package:flutter_dotenv/flutter_dotenv.dart';

/// Loads OpenAI configuration from `.env` / `.env.example` assets.
abstract final class EnvConfig {
  static const defaultModel = 'gpt-4o-mini';
  static const defaultBaseUrl = 'https://api.openai.com/v1';

  static Future<void> load() async {
    // Prefer a local `.env` asset when present; fall back to the example template.
    for (final fileName in ['.env', '.env.example']) {
      try {
        await dotenv.load(fileName: fileName);
        return;
      } catch (_) {
        // Try next candidate.
      }
    }
  }

  static String get openAiApiKey =>
      dotenv.env['OPENAI_API_KEY']?.trim() ?? '';

  static String get openAiModel {
    final model = dotenv.env['OPENAI_MODEL']?.trim();
    if (model == null || model.isEmpty) {
      return defaultModel;
    }
    return model;
  }

  static String get openAiBaseUrl {
    final url = dotenv.env['OPENAI_BASE_URL']?.trim();
    if (url == null || url.isEmpty) {
      return defaultBaseUrl;
    }
    return url.endsWith('/') ? url.substring(0, url.length - 1) : url;
  }

  static bool get hasOpenAiApiKey => openAiApiKey.isNotEmpty;
}
