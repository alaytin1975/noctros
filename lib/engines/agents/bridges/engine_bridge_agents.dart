import '../../../core/utils/result.dart';
import '../../../domain/entities/agent_mesh_entities.dart';
import '../../../domain/entities/noctros_entities.dart';
import '../../../domain/entities/noctros_enums.dart';
import '../../ai/ai_engine.dart';
import '../../automation/automation_engine.dart';
import '../../emergency/emergency_engine.dart';
import '../../memory/memory_engine.dart';
import '../../voice/voice_engine.dart';
import '../agent.dart';
import '../agent_topics.dart';

/// Memory engine as a Hive peer that other agents can query and write to.
class MemoryAgent extends NoctrosAgent {
  MemoryAgent({required MemoryEngine memoryEngine}) : _memory = memoryEngine;

  final MemoryEngine _memory;

  @override
  AgentIdentity get identity => AgentIdentity.of(AgentRole.memory);

  @override
  Future<void> handle(AgentMessage message) async {
    if (message.topic == AgentTopics.memoryRecall) {
      await think(message.sessionId, 'Recalling Hive memory for a peer.');
      final context = await _memory.buildContextPrompt();
      final body = context.isSuccess && context.valueOrThrow.isNotEmpty
          ? context.valueOrThrow
          : 'No stored Hive memory yet.';
      await publish(
        sessionId: message.sessionId,
        kind: AgentMessageKind.reply,
        topic: AgentTopics.memoryRecall,
        to: message.from,
        replyToId: message.id,
        body: body,
      );
      return;
    }

    if (message.topic == AgentTopics.memoryStore) {
      await think(message.sessionId, 'Storing the Hive build outcome.');
      final key = (message.payload['key'] as String?) ?? 'hive_build';
      final value = (message.payload['value'] as String?) ?? message.body;
      await _memory.remember(
        category: MemoryCategory.routine,
        key: key,
        value: value,
        sourceConversationId: message.sessionId,
      );
      if (message.kind == AgentMessageKind.query) {
        await publish(
          sessionId: message.sessionId,
          kind: AgentMessageKind.reply,
          topic: AgentTopics.memoryStore,
          to: message.from,
          replyToId: message.id,
          body: 'Stored $key',
        );
      }
    }
  }
}

/// Optional spoken announcements when the Hive finishes a build.
class VoiceAgent extends NoctrosAgent {
  VoiceAgent({
    required VoiceEngine voiceEngine,
    this.announceCompletions = true,
  }) : _voice = voiceEngine;

  final VoiceEngine _voice;
  final bool announceCompletions;

  @override
  AgentIdentity get identity => AgentIdentity.of(AgentRole.voice);

  @override
  Future<void> handle(AgentMessage message) async {
    if (!announceCompletions || message.topic != AgentTopics.voiceAnnounce) {
      return;
    }
    try {
      await _voice.speak(message.body);
    } catch (_) {
      // Voice output is optional; the Hive continues without a speaker.
    }
  }
}

/// Watches the original user goal for emergency phrases.
class EmergencyAgent extends NoctrosAgent {
  EmergencyAgent({required EmergencyEngine emergencyEngine})
      : _emergency = emergencyEngine;

  final EmergencyEngine _emergency;

  @override
  AgentIdentity get identity => AgentIdentity.of(AgentRole.emergency);

  @override
  Future<void> handle(AgentMessage message) async {
    if (message.topic != AgentTopics.sessionStart) {
      return;
    }
    if (!_emergency.matchesEmergencyPhrase(message.body)) {
      return;
    }
    await publish(
      sessionId: message.sessionId,
      kind: AgentMessageKind.broadcast,
      topic: AgentTopics.emergencyAlert,
      body:
          'Emergency phrase detected while the Hive was working: ${message.body}',
      payload: {'source': message.from.name},
    );
  }
}

/// Language reasoning peer backed by the hybrid AI router.
class InferenceAgent extends NoctrosAgent {
  InferenceAgent({required AiEngine aiEngine}) : _aiEngine = aiEngine;

  final AiEngine _aiEngine;

  @override
  AgentIdentity get identity => AgentIdentity.of(AgentRole.inference);

  @override
  Future<void> handle(AgentMessage message) async {
    if (message.topic != AgentTopics.inferenceAsk) {
      return;
    }

    await think(message.sessionId, 'Running local inference for a peer.');

    var answer =
        'Focus on a small, testable Dart module with a clear public API.';
    try {
      final response = await _aiEngine.complete(
        AiRequest(
          prompt: message.body,
          conversationId: message.sessionId,
          complexity: AiTaskComplexity.lightweight,
          preferredMode: AiExecutionMode.local,
        ),
      );
      if (response.content.trim().isNotEmpty) {
        answer = response.content.trim();
      }
    } catch (_) {
      // Local heuristic fallback keeps the Hive moving.
    }

    await publish(
      sessionId: message.sessionId,
      kind: AgentMessageKind.reply,
      topic: AgentTopics.inferenceAsk,
      to: message.from,
      replyToId: message.id,
      body: answer,
    );
  }
}

/// Records completed Hive workflows so they can be replayed later.
class AutomationAgent extends NoctrosAgent {
  AutomationAgent({required AutomationEngine automationEngine})
      : _automation = automationEngine;

  final AutomationEngine _automation;

  @override
  AgentIdentity get identity => AgentIdentity.of(AgentRole.automation);

  @override
  Future<void> handle(AgentMessage message) async {
    if (message.topic != AgentTopics.automationRecord) {
      return;
    }

    await think(message.sessionId, 'Recording the Hive workflow.');
    final goal = (message.payload['goal'] as String?) ?? message.body;
    final fileName =
        (message.payload['fileName'] as String?) ?? 'generated.dart';
    _automation.record(
      AutomationRecipe(
        id: message.sessionId,
        name: goal,
        steps: const [
          AgentTopics.sessionStart,
          AgentTopics.planReady,
          AgentTopics.designReady,
          AgentTopics.codeReady,
          AgentTopics.reviewApproved,
          AgentTopics.sessionComplete,
        ],
        artifactFileName: fileName,
      ),
    );
    if (message.kind == AgentMessageKind.query) {
      await publish(
        sessionId: message.sessionId,
        kind: AgentMessageKind.reply,
        topic: AgentTopics.automationRecord,
        to: message.from,
        replyToId: message.id,
        body: 'Recorded workflow for $fileName',
      );
    }
  }
}
