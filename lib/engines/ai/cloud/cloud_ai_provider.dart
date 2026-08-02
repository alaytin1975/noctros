import 'package:dio/dio.dart';

import '../../../core/errors/noctros_failure.dart';
import '../../../domain/entities/noctros_entities.dart';
import '../../../domain/entities/noctros_enums.dart';
import '../ai_engine.dart';

/// Cloud inference provider using a secure REST API backend.
class CloudAiProvider implements AiProvider {
  CloudAiProvider({Dio? dio})
      : _dio = dio ??
            Dio(
              BaseOptions(
                connectTimeout: const Duration(seconds: 20),
                receiveTimeout: const Duration(seconds: 60),
                headers: {'Content-Type': 'application/json'},
              ),
            );

  final Dio _dio;

  @override
  bool canHandle(AiRequest request) => true;

  @override
  Future<AiResponse> complete(AiRequest request) async {
    try {
      final response = await _dio.post<Map<String, dynamic>>(
        const String.fromEnvironment(
          'NOCTROS_CLOUD_API_URL',
          defaultValue: 'https://api.noctros.app/v1/chat/completions',
        ),
        data: {
          'prompt': request.prompt,
          'conversationId': request.conversationId,
          'complexity': request.complexity.name,
          'context': request.contextMessages
              .map(
                (ChatMessage message) => {
                  'role': message.role.name,
                  'content': message.content,
                },
              )
              .toList(),
        },
      );

      final data = response.data;
      if (data == null || data['content'] is! String) {
        throw const AiFailure('Cloud provider returned an invalid response.');
      }

      return AiResponse(
        content: data['content'] as String,
        modeUsed: AiExecutionMode.cloud,
        processedLocally: false,
        tokenCount: data['tokenCount'] as int?,
      );
    } on DioException catch (error) {
      if (error.type == DioExceptionType.connectionError ||
          error.type == DioExceptionType.connectionTimeout) {
        throw AiFailure(
          'Cloud AI unavailable. Check your connection or switch to local mode.',
          cause: error,
        );
      }
      throw AiFailure('Cloud AI request failed.', cause: error);
    }
  }
}
