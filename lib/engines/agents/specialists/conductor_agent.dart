import '../../../domain/entities/agent_mesh_entities.dart';
import '../../../domain/entities/noctros_enums.dart';
import '../agent.dart';
import '../agent_topics.dart';

/// User-facing coordinator: starts a session, then speaks as one system at the end.
class ConductorAgent extends NoctrosAgent {
  @override
  AgentIdentity get identity => AgentIdentity.of(AgentRole.conductor);

  @override
  Future<void> handle(AgentMessage message) async {
    if (message.topic != AgentTopics.reviewApproved &&
        message.topic != AgentTopics.sessionFailed) {
      return;
    }

    if (message.topic == AgentTopics.sessionFailed) {
      return;
    }

    await think(message.sessionId, 'Collecting peer results into one Noctros answer.');

    final fileName = (message.payload['fileName'] as String?) ?? 'generated.dart';
    final artifact = (message.payload['artifact'] as String?) ?? '';
    final goal = (message.payload['goal'] as String?) ?? '';

    await ask(
      sessionId: message.sessionId,
      to: AgentRole.memory,
      topic: AgentTopics.memoryStore,
      body: 'Remember this Hive build: $goal → $fileName',
      payload: {
        'key': 'last_hive_build',
        'value': '$goal ($fileName)',
      },
    );

    await ask(
      sessionId: message.sessionId,
      to: AgentRole.automation,
      topic: AgentTopics.automationRecord,
      body: 'Record the Hive build workflow for "$goal".',
      payload: {
        'goal': goal,
        'fileName': fileName,
      },
    );

    final summary = _summary(
      goal: goal,
      fileName: fileName,
      review: message.body,
      artifact: artifact,
    );

    await publish(
      sessionId: message.sessionId,
      kind: AgentMessageKind.broadcast,
      topic: AgentTopics.sessionComplete,
      body: summary,
      payload: {
        ...message.payload,
        'userSummary': summary,
      },
    );

    await publish(
      sessionId: message.sessionId,
      kind: AgentMessageKind.task,
      topic: AgentTopics.voiceAnnounce,
      to: AgentRole.voice,
      body: 'The Hive finished building $fileName.',
    );
  }

  String _summary({
    required String goal,
    required String fileName,
    required String review,
    required String artifact,
  }) {
    final preview = artifact.trim().isEmpty
        ? '(no source)'
        : artifact.trim().split('\n').take(12).join('\n');
    return '''
Noctros Hive completed this as one system.

Goal: $goal
Artifact: $fileName
Review: $review

Agents planned, designed, coded, reviewed, remembered, and recorded this together.

$preview
'''.trim();
  }
}
