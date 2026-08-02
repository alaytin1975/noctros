import 'package:dio/dio.dart';

import '../../../core/config/openai_config_service.dart';
import '../../../core/errors/noctros_failure.dart';
import '../../../domain/entities/noctros_entities.dart';
import '../../../domain/entities/noctros_enums.dart';
import '../ai_engine.dart';

/// OpenAI Chat Completions provider (cloud AI).
class OpenAiProvider implements AiProvider {
  OpenAiProvider({
    required OpenAiConfigService configService,
    Dio? dio,
  })  : _configService = configService,
        _dio = dio ??
            Dio(
              BaseOptions(
                connectTimeout: const Duration(seconds: 20),
                receiveTimeout: const Duration(seconds: 90),
                headers: {'Content-Type': 'application/json'},
              ),
            );

  final OpenAiConfigService _configService;
  final Dio _dio;

  @override
  bool canHandle(AiRequest request) => true;

  @override
  Future<AiResponse> complete(AiRequest request) async {
    final apiKey = await _configService.getApiKey();
    if (apiKey == null || apiKey.isEmpty) {
      throw const AiFailure(
        'OpenAI API key is missing. Add it to .env or Settings.',
      );
    }

    final model = await _configService.getModel();
    final baseUrl = _configService.baseUrl;

    final messages = <Map<String, String>>[
      {
        'role': 'system',
        'content':
            'You are Noctros, a voice-first personal AI assistant and second brain. '
            'Be concise, helpful, private-first, and action-oriented.',
      },
      ...request.contextMessages
          .where((message) => message.role != MessageRole.system)
          .map(
            (message) => {
              'role': message.role == MessageRole.user ? 'user' : 'assistant',
              'content': message.content,
            },
          ),
    ];

    // Ensure the latest user prompt is present even if history is empty.
    if (messages.length == 1 || messages.last['content'] != request.prompt) {
      messages.add({'role': 'user', 'content': request.prompt});
    }

    try {
      final response = await _dio.post<Map<String, dynamic>>(
        '$baseUrl/chat/completions',
        options: Options(
          headers: {'Authorization': 'Bearer $apiKey'},
        ),
        data: {
          'model': model,
          'messages': messages,
          'temperature': 0.7,
        },
      );

      final data = response.data;
      final choices = data?['choices'];
      if (choices is! List || choices.isEmpty) {
        throw const AiFailure('OpenAI returned an empty response.');
      }

      final message = choices.first['message'] as Map<String, dynamic>?;
      final content = message?['content'] as String?;
      if (content == null || content.trim().isEmpty) {
        throw const AiFailure('OpenAI returned an invalid message payload.');
      }

      final usage = data?['usage'] as Map<String, dynamic>?;
      return AiResponse(
        content: content.trim(),
        modeUsed: AiExecutionMode.cloud,
        processedLocally: false,
        tokenCount: usage?['total_tokens'] as int?,
      );
    } on DioException catch (error) {
      final status = error.response?.statusCode;
      if (status == 401) {
        throw AiFailure(
          'OpenAI rejected the API key. Check Settings or .env.',
          cause: error,
        );
      }
      if (error.type == DioExceptionType.connectionError ||
          error.type == DioExceptionType.connectionTimeout) {
        throw AiFailure(
          'Unable to reach OpenAI. Check your internet connection.',
          cause: error,
        );
      }
      final apiMessage = error.response?.data is Map<String, dynamic>
          ? (error.response!.data as Map<String, dynamic>)['error']
          : null;
      final detail = apiMessage is Map<String, dynamic>
          ? apiMessage['message'] as String?
          : null;
      throw AiFailure(
        detail ?? 'OpenAI request failed.',
        cause: error,
      );
    }
  }
}
