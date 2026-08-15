import '../../../domain/entities/agent_mesh_entities.dart';
import '../../../domain/entities/noctros_enums.dart';
import '../agent.dart';
import '../agent_topics.dart';

/// Reviews Coder output against Architect contracts. One revision loop max.
class ReviewerAgent extends NoctrosAgent {
  final Map<String, int> _rounds = {};

  @override
  AgentIdentity get identity => AgentIdentity.of(AgentRole.reviewer);

  @override
  Future<void> handle(AgentMessage message) async {
    if (message.topic != AgentTopics.codeReady) {
      return;
    }

    await think(message.sessionId, 'Reviewing the program with Hive peers.');

    final contract = await ask(
      sessionId: message.sessionId,
      to: AgentRole.architect,
      topic: AgentTopics.contractAsk,
      body: 'Confirm the public contract I should grade against.',
    );

    final artifact = (message.payload['artifact'] as String?) ?? '';
    final fileName = (message.payload['fileName'] as String?) ?? 'unknown.dart';
    final moduleName = (message.payload['moduleName'] as String?) ?? '';
    final revised = message.payload['revised'] == true;
    final round = _rounds[message.sessionId] ?? 0;

    final issues = _issues(
      artifact: artifact,
      moduleName: moduleName,
      contract: contract?.body ?? '',
    );

    final shouldRevise = !revised && round == 0 && issues.isNotEmpty;

    if (shouldRevise) {
      _rounds[message.sessionId] = round + 1;
      await publish(
        sessionId: message.sessionId,
        kind: AgentMessageKind.task,
        topic: AgentTopics.reviewChanges,
        to: AgentRole.coder,
        body: 'Please address: ${issues.join('; ')}',
        payload: {
          ...message.payload,
          'issues': issues,
        },
      );
      return;
    }

    final notes = issues.isEmpty
        ? 'Approved. Contract, artifact, and Hive handoff all line up.'
        : 'Approved after revision. Remaining notes: ${issues.join('; ')}';

    await publish(
      sessionId: message.sessionId,
      kind: AgentMessageKind.handoff,
      topic: AgentTopics.reviewApproved,
      to: AgentRole.conductor,
      body: notes,
      payload: {
        ...message.payload,
        'fileName': fileName,
        'issues': issues,
      },
    );
  }

  List<String> _issues({
    required String artifact,
    required String moduleName,
    required String contract,
  }) {
    final issues = <String>[];
    if (artifact.trim().isEmpty) {
      issues.add('Missing source artifact');
    }
    if (moduleName.isNotEmpty && !artifact.contains('class $moduleName')) {
      issues.add('Artifact does not declare class $moduleName');
    }
    if (!artifact.contains('snapshot()')) {
      issues.add('Public snapshot() API is missing');
    }
    if (!artifact.contains('execute(')) {
      issues.add('Public execute() API is missing');
    }
    if (contract.contains('class $moduleName') &&
        !artifact.contains('class $moduleName')) {
      issues.add('Code drifted from the Architect contract');
    }
    if (!artifact.contains('bool get isReady')) {
      issues.add('Add an isReady health check for Automation');
    }
    return issues;
  }
}
