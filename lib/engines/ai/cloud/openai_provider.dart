import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';

import '../../../core/ai/prompt_manager.dart';
import '../../../core/config/openai_config_service.dart';
import '../../../core/errors/noctros_failure.dart';
import '../../../domain/entities/noctros_entities.dart';
import '../../../domain/entities/noctros_enums.dart';
import '../ai_engine.dart';

/// OpenAI Chat Completions provider with streaming support.
class OpenAiProvider implements AiProvider {
  OpenAiProvider({
    required OpenAiConfigService configService,
    Dio? dio,
  })  : _configService = configService,
        _dio = dio ??
            Dio(
              BaseOptions(
                connectTimeout: const Duration(seconds: 20),
                receiveTimeout: const Duration(seconds: 120),
                headers: {'Content-Type': 'application/json'},
              ),
            );

  final OpenAiConfigService _configService;
  final Dio _dio;

  @override
  bool canHandle(AiRequest request) => true;

  Future<String> _requireApiKey() async {
    final apiKey = await _configService.getApiKey();
    if (apiKey == null || apiKey.isEmpty) {
      throw const AiFailure(
        'OpenAI API key is missing. Add it to .env or Settings.',
      );
    }
    return apiKey;
  }

  Map<String, dynamic> _buildBody(AiRequest request, {required bool stream}) {
    return {
      'model': null, // filled async below
      'messages': PromptManager.toOpenAiMessages(
        prompt: request.prompt,
        contextMessages: request.contextMessages,
        memoryContext: request.memoryContext,
      ),
      'temperature': 0.7,
      'stream': stream,
    };
  }

  @override
  Future<AiResponse> complete(AiRequest request) async {
    final apiKey = await _requireApiKey();
    final model = await _configService.getModel();
    final baseUrl = _configService.baseUrl;
    final body = _buildBody(request, stream: false)..['model'] = model;

    try {
      final response = await _dio.post<Map<String, dynamic>>(
        '$baseUrl/chat/completions',
        options: Options(headers: {'Authorization': 'Bearer $apiKey'}),
        data: body,
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
      throw _mapDioError(error);
    }
  }

  @override
  Stream<String> streamComplete(AiRequest request) async* {
    final apiKey = await _requireApiKey();
    final model = await _configService.getModel();
    final baseUrl = _configService.baseUrl;
    final body = _buildBody(request, stream: true)..['model'] = model;

    try {
      final response = await _dio.post<ResponseBody>(
        '$baseUrl/chat/completions',
        options: Options(
          headers: {'Authorization': 'Bearer $apiKey'},
          responseType: ResponseType.stream,
        ),
        data: body,
      );

      final stream = response.data?.stream;
      if (stream == null) {
        throw const AiFailure('OpenAI stream was empty.');
      }

      var buffer = '';
      await for (final chunk in stream.cast<List<int>>()) {
        buffer += utf8.decode(chunk, allowMalformed: true);
        final lines = buffer.split('\n');
        buffer = lines.removeLast();

        for (final rawLine in lines) {
          final line = rawLine.trim();
          if (line.isEmpty || !line.startsWith('data:')) {
            continue;
          }
          final payload = line.substring(5).trim();
          if (payload == '[DONE]') {
            return;
          }
          try {
            final json = jsonDecode(payload) as Map<String, dynamic>;
            final choices = json['choices'] as List<dynamic>?;
            if (choices == null || choices.isEmpty) {
              continue;
            }
            final delta = choices.first['delta'] as Map<String, dynamic>?;
            final content = delta?['content'] as String?;
            if (content != null && content.isNotEmpty) {
              yield content;
            }
          } catch (_) {
            // Ignore malformed SSE chunks.
          }
        }
      }
    } on DioException catch (error) {
      throw _mapDioError(error);
    }
  }

  AiFailure _mapDioError(DioException error) {
    final status = error.response?.statusCode;
    if (status == 401) {
      return AiFailure(
        'OpenAI rejected the API key. Check Settings or .env.',
        cause: error,
      );
    }
    if (error.type == DioExceptionType.connectionError ||
        error.type == DioExceptionType.connectionTimeout) {
      return AiFailure(
        'Unable to reach OpenAI. Switching to offline mode when possible.',
        cause: error,
      );
    }
    final apiMessage = error.response?.data;
    String? detail;
    if (apiMessage is Map<String, dynamic>) {
      final err = apiMessage['error'];
      if (err is Map<String, dynamic>) {
        detail = err['message'] as String?;
      }
    }
    return AiFailure(detail ?? 'OpenAI request failed.', cause: error);
  }
}
