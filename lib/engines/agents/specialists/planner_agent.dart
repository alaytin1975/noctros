import '../../../domain/entities/agent_mesh_entities.dart';
import '../../../domain/entities/noctros_enums.dart';
import '../agent.dart';
import '../agent_topics.dart';

/// Turns a user goal into an ordered build plan other agents can execute.
class PlannerAgent extends NoctrosAgent {
  @override
  AgentIdentity get identity => AgentIdentity.of(AgentRole.planner);

  @override
  Future<void> handle(AgentMessage message) async {
    if (message.topic != AgentTopics.sessionStart) {
      return;
    }

    await think(message.sessionId, 'Decomposing the goal into a build plan.');

    final memory = await ask(
      sessionId: message.sessionId,
      to: AgentRole.memory,
      topic: AgentTopics.memoryRecall,
      body: 'What should I remember while planning this program?',
    );

    final memoryNotes = memory?.body ?? 'No stored Hive memory yet.';
    final steps = _stepsFor(message.body);

    await publish(
      sessionId: message.sessionId,
      kind: AgentMessageKind.handoff,
      topic: AgentTopics.planReady,
      to: AgentRole.architect,
      body: _renderPlan(message.body, steps, memoryNotes),
      payload: {
        'goal': message.body,
        'steps': steps,
        'memoryNotes': memoryNotes,
      },
    );
  }

  List<String> _stepsFor(String goal) {
    return [
      'Clarify the program goal: $goal',
      'Design modules, data flow, and public contracts',
      'Implement the primary Dart feature module',
      'Review architecture against the generated code',
      'Remember the outcome and record the workflow',
    ];
  }

  String _renderPlan(String goal, List<String> steps, String memoryNotes) {
    final buffer = StringBuffer()
      ..writeln('Build plan for: $goal')
      ..writeln()
      ..writeln('Memory context: $memoryNotes')
      ..writeln();
    for (var i = 0; i < steps.length; i++) {
      buffer.writeln('${i + 1}. ${steps[i]}');
    }
    return buffer.toString().trim();
  }
}
