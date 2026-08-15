import '../../../domain/entities/agent_mesh_entities.dart';
import '../../../domain/entities/noctros_enums.dart';
import '../agent.dart';
import '../agent_topics.dart';

/// Designs module boundaries and answers contract questions from Coder.
class ArchitectAgent extends NoctrosAgent {
  final Map<String, String> _contracts = {};

  @override
  AgentIdentity get identity => AgentIdentity.of(AgentRole.architect);

  @override
  Future<void> handle(AgentMessage message) async {
    if (message.topic == AgentTopics.contractAsk) {
      await publish(
        sessionId: message.sessionId,
        kind: AgentMessageKind.reply,
        topic: AgentTopics.contractAsk,
        to: message.from,
        replyToId: message.id,
        body: _contracts[message.sessionId] ??
            'No contract is on file yet. Use a single feature class with a clear public API.',
      );
      return;
    }

    if (message.topic != AgentTopics.planReady) {
      return;
    }

    await think(message.sessionId, 'Designing modules and public contracts.');

    final goal = (message.payload['goal'] as String?) ?? message.body;
    final moduleName = _moduleNameFor(goal);
    final contract = _contractFor(goal, moduleName);
    _contracts[message.sessionId] = contract;

    await publish(
      sessionId: message.sessionId,
      kind: AgentMessageKind.handoff,
      topic: AgentTopics.designReady,
      to: AgentRole.coder,
      body: contract,
      payload: {
        'goal': goal,
        'moduleName': moduleName,
        'fileName': 'lib/hive_generated/${_fileName(moduleName)}.dart',
      },
    );
  }

  String _moduleNameFor(String goal) {
    final words = goal
        .replaceAll(RegExp(r'[^A-Za-z0-9\s]'), ' ')
        .split(RegExp(r'\s+'))
        .where((word) => word.length > 2)
        .take(3)
        .map(
          (word) => word[0].toUpperCase() + word.substring(1).toLowerCase(),
        )
        .toList();
    if (words.isEmpty) {
      return 'HiveFeature';
    }
    return '${words.join()}Feature';
  }

  String _fileName(String moduleName) {
    final buffer = StringBuffer();
    for (var i = 0; i < moduleName.length; i++) {
      final char = moduleName[i];
      final isUpper = char.toUpperCase() == char && char.toLowerCase() != char;
      if (isUpper && i > 0) {
        buffer.write('_');
      }
      buffer.write(char.toLowerCase());
    }
    return buffer.toString();
  }

  String _contractFor(String goal, String moduleName) {
    return '''
Architecture for: $goal

Modules
- $moduleName — domain + application service for the requested program
- ${moduleName}View — presentation adapter the Hive can show later
- ${moduleName}Store — in-memory persistence until a repository is wired

Public contract
- class $moduleName
- void execute()
- Map<String, Object?> snapshot()

Data flow
Planner → Architect → Coder → Reviewer → Memory / Automation
'''.trim();
  }
}
