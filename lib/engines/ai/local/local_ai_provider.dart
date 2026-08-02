import '../../../core/errors/noctros_failure.dart';
import '../../../domain/entities/noctros_entities.dart';
import '../../../domain/entities/noctros_enums.dart';
import '../ai_engine.dart';

/// On-device offline fallback provider.
class LocalAiProvider implements AiProvider {
  @override
  bool canHandle(AiRequest request) => true;

  @override
  Future<AiResponse> complete(AiRequest request) async {
    return AiResponse(
      content: _inferIntentResponse(request.prompt),
      modeUsed: AiExecutionMode.local,
      processedLocally: true,
    );
  }

  @override
  Stream<String> streamComplete(AiRequest request) async* {
    final content = _inferIntentResponse(request.prompt);
    // Simulate lightweight streaming for UI consistency offline.
    const chunkSize = 48;
    for (var i = 0; i < content.length; i += chunkSize) {
      final end = (i + chunkSize < content.length) ? i + chunkSize : content.length;
      yield content.substring(i, end);
      await Future<void>.delayed(const Duration(milliseconds: 12));
    }
  }

  String _inferIntentResponse(String prompt) {
    final normalized = prompt.toLowerCase();

    if (normalized.contains('cold')) {
      return '**Offline mode**\n\nYou may be cold. I can suggest warm clothing, '
          'remind you to close windows, or help adjust heating when smart home is connected.';
    }
    if (normalized.contains('tired')) {
      return '**Offline mode**\n\nYou sound tired. I can reduce interruptions, '
          'start a wind-down routine, or play calming audio when online services return.';
    }
    if (normalized.contains('plan my day') || normalized.contains('summary')) {
      return '**Offline mode**\n\nI can outline a day plan from local reminders once sync is available. '
          'Meanwhile: prioritize your top 3 tasks, block focus time, and schedule a short break.';
    }
    if (normalized.contains('emergency') || normalized.contains('help')) {
      return '**Offline mode**\n\nIf this is an emergency, open the **Emergency** tab and use Quick SOS. '
          'I can still guide you without cloud AI.';
    }

    if (prompt.trim().isEmpty) {
      throw const AiFailure('Empty prompt.');
    }

    return '**Offline mode**\n\nCloud AI is unavailable, so Noctros answered locally.\n\n'
        'I understood: "$prompt"\n\n'
        'I can still help with phone control, notes, and emergency tools. '
        'Reconnect or check your OpenAI key in Settings for full cloud reasoning.';
  }
}
