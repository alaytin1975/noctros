import '../../../domain/entities/noctros_entities.dart';
import '../../../domain/entities/noctros_enums.dart';
import 'ai_engine.dart';

/// Routes requests between local and cloud providers based on task complexity,
/// connectivity requirements, and user execution mode preferences.
class HybridAiRouter implements AiEngine {
  HybridAiRouter({
    required AiProvider localProvider,
    required AiProvider cloudProvider,
  })  : _localProvider = localProvider,
        _cloudProvider = cloudProvider;

  final AiProvider _localProvider;
  final AiProvider _cloudProvider;

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
    if (_localProvider.canHandle(request)) {
      try {
        return await _localProvider.complete(request);
      } catch (_) {
        return _cloudProvider.complete(request);
      }
    }
    return _cloudProvider.complete(request);
  }

  @override
  Future<AiExecutionMode> resolveMode(AiRequest request) async {
    if (request.preferredMode != null) {
      return request.preferredMode!;
    }

    if (request.requiresInternet ||
        request.complexity == AiTaskComplexity.complex) {
      return AiExecutionMode.cloud;
    }

    if (request.complexity == AiTaskComplexity.lightweight) {
      return AiExecutionMode.local;
    }

    return AiExecutionMode.hybrid;
  }
}
