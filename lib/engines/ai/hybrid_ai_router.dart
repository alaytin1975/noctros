import '../../core/config/openai_config_service.dart';
import '../../domain/entities/noctros_entities.dart';
import '../../domain/entities/noctros_enums.dart';
import 'ai_engine.dart';

/// Routes requests between local and OpenAI cloud providers.
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

    return switch (mode) {
      AiExecutionMode.local => _localProvider.complete(request),
      AiExecutionMode.cloud => _cloudProvider.complete(request),
      AiExecutionMode.hybrid => _completeHybrid(request),
    };
  }

  Future<AiResponse> _completeHybrid(AiRequest request) async {
    final configured = await _openAiConfigService.isConfigured();
    if (configured) {
      try {
        return await _cloudProvider.complete(request);
      } catch (_) {
        if (_localProvider.canHandle(request)) {
          return _localProvider.complete(request);
        }
        rethrow;
      }
    }

    if (_localProvider.canHandle(request)) {
      return _localProvider.complete(request);
    }
    return _cloudProvider.complete(request);
  }

  @override
  Future<AiExecutionMode> resolveMode(AiRequest request) async {
    if (request.preferredMode != null) {
      return request.preferredMode!;
    }

    final configured = await _openAiConfigService.isConfigured();

    if (request.requiresInternet ||
        request.complexity == AiTaskComplexity.complex) {
      return configured ? AiExecutionMode.cloud : AiExecutionMode.local;
    }

    if (request.complexity == AiTaskComplexity.lightweight && !configured) {
      return AiExecutionMode.local;
    }

    if (configured) {
      return AiExecutionMode.hybrid;
    }

    return AiExecutionMode.local;
  }
}
