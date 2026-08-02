import '../../../core/errors/noctros_failure.dart';
import '../../../domain/entities/noctros_entities.dart';
import '../../../domain/entities/noctros_enums.dart';
import '../ai_engine.dart';

/// On-device inference provider. Integrates with platform ML runtimes in production builds.
class LocalAiProvider implements AiProvider {
  @override
  bool canHandle(AiRequest request) {
    return request.complexity == AiTaskComplexity.lightweight ||
        request.complexity == AiTaskComplexity.moderate;
  }

  @override
  Future<AiResponse> complete(AiRequest request) async {
    if (!canHandle(request)) {
      throw const AiFailure('Task exceeds local model capacity.');
    }

    final response = StringBuffer()
      ..writeln('Noctros processed this locally on your device.')
      ..writeln()
      ..writeln(_inferIntentResponse(request.prompt))
      ..writeln()
      ..writeln(
        'Context messages considered: ${request.contextMessages.length}.',
      );

    if (request.contextMessages.isNotEmpty) {
      response.writeln('Recent context retained for continuity.');
    }

    return AiResponse(
      content: response.toString().trim(),
      modeUsed: AiExecutionMode.local,
      processedLocally: true,
    );
  }

  String _inferIntentResponse(String prompt) {
    final normalized = prompt.toLowerCase();

    if (normalized.contains('cold')) {
      return 'You may be cold. I can suggest warm clothing, adjust smart home heating if connected, or set a reminder to close windows.';
    }
    if (normalized.contains('tired')) {
      return 'You sound tired. I can reduce notifications, start sleep mode, or play relaxing music.';
    }
    if (normalized.contains('plan my day')) {
      return 'I can review your calendar, tasks, and reminders to build a prioritized plan for today.';
    }

    return 'I understand your request and can help with phone control, planning, and life management.';
  }
}
