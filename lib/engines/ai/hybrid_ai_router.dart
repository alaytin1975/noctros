import '../../core/config/openai_config_service.dart';
import '../../core/errors/noctros_failure.dart';
import '../../domain/entities/noctros_entities.dart';
import '../../domain/entities/noctros_enums.dart';
import 'ai_engine.dart';

/// Routes between OpenAI cloud and local offline providers.
class HybridAiRouter implements AiEngine {
  HybridAiRouter({
    required AiProvider localProvider,
    required AiProvider cloudProvider,
    required OpenAiConfigService openAiConfigService,
  })  : _localProvider = localProvider,
        _cloudProvider = cloudProvider,
        _openAiConfigService = openAiConfigService;

  final AiProvider _localProvider;
  final AiProvider _cloudProvider;
  final OpenAiConfigService _openAiConfigService;

  @override
  Future<AiResponse> complete(AiRequest request) async {
    final mode = await resolveMode(request);
    try {
      return switch (mode) {
        AiExecutionMode.local => await _localProvider.complete(request),
        AiExecutionMode.cloud => await _cloudProvider.complete(request),
        AiExecutionMode.hybrid => await _completeHybrid(request),
      };
    } on AiFailure {
      if (mode != AiExecutionMode.local) {
        return _localProvider.complete(request);
      }
      rethrow;
    } catch (error) {
      if (mode != AiExecutionMode.local) {
        return _localProvider.complete(request);
      }
      throw AiFailure('AI request failed.', cause: error);
    }
  }

  @override
  Stream<String> streamComplete(AiRequest request) async* {
    final mode = await resolveMode(request);
    try {
      final stream = switch (mode) {
        AiExecutionMode.local => _localProvider.streamComplete(request),
        AiExecutionMode.cloud => _cloudProvider.streamComplete(request),
        AiExecutionMode.hybrid => _streamHybrid(request),
      };
      await for (final chunk in stream) {
        yield chunk;
      }
    } catch (_) {
      await for (final chunk in _localProvider.streamComplete(request)) {
        yield chunk;
      }
    }
  }

  Future<AiResponse> _completeHybrid(AiRequest request) async {
    final configured = await _openAiConfigService.isConfigured();
    if (configured) {
      try {
        return await _cloudProvider.complete(request);
      } catch (_) {
        return _localProvider.complete(request);
      }
    }
    return _localProvider.complete(request);
  }

  Stream<String> _streamHybrid(AiRequest request) async* {
    final configured = await _openAiConfigService.isConfigured();
    if (!configured) {
      yield* _localProvider.streamComplete(request);
      return;
    }
    try {
      var yielded = false;
      await for (final chunk in _cloudProvider.streamComplete(request)) {
        yielded = true;
        yield chunk;
      }
      if (!yielded) {
        yield* _localProvider.streamComplete(request);
      }
    } catch (_) {
      yield* _localProvider.streamComplete(request);
    }
  }

  @override
  Future<AiExecutionMode> resolveMode(AiRequest request) async {
    if (request.preferredMode != null) {
      return request.preferredMode!;
    }

    final configured = await _openAiConfigService.isConfigured();
    if (!configured) {
      return AiExecutionMode.local;
    }

    if (request.requiresInternet ||
        request.complexity == AiTaskComplexity.complex) {
      return AiExecutionMode.cloud;
    }

    if (request.complexity == AiTaskComplexity.lightweight) {
      return AiExecutionMode.hybrid;
    }

    return AiExecutionMode.hybrid;
  }
}
