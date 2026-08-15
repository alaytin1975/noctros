import 'package:flutter_test/flutter_test.dart';
import 'package:noctros/core/utils/result.dart';
import 'package:noctros/domain/entities/noctros_entities.dart';
import 'package:noctros/domain/entities/noctros_enums.dart';
import 'package:noctros/domain/repositories/noctros_repositories.dart';
import 'package:noctros/engines/agents/agent_bus.dart';
import 'package:noctros/engines/agents/agent_mesh.dart';
import 'package:noctros/engines/agents/agent_topics.dart';
import 'package:noctros/engines/ai/cloud/cloud_ai_provider.dart';
import 'package:noctros/engines/ai/hybrid_ai_router.dart';
import 'package:noctros/engines/ai/local/local_ai_provider.dart';
import 'package:noctros/engines/automation/automation_engine.dart';
import 'package:noctros/engines/emergency/emergency_engine.dart';
import 'package:noctros/engines/memory/memory_engine.dart';
import 'package:noctros/engines/voice/voice_engine.dart';

class _MemoryRepository implements MemoryRepository {
  final List<MemoryEntry> entries = [];

  @override
  Future<Result<void>> deleteAll() async {
    entries.clear();
    return const Success(null);
  }

  @override
  Future<Result<void>> deleteEntry(String id) async {
    entries.removeWhere((entry) => entry.id == id);
    return const Success(null);
  }

  @override
  Future<Result<List<MemoryEntry>>> listEntries() async => Success(entries);

  @override
  Future<Result<MemoryEntry>> upsertEntry(MemoryEntry entry) async {
    entries.removeWhere((existing) => existing.id == entry.id);
    entries.add(entry);
    return Success(entry);
  }
}

class _SettingsRepository implements SettingsRepository {
  @override
  Future<Result<UserSettings>> loadSettings() async {
    return Success(UserSettings.defaults());
  }

  @override
  Future<Result<UserSettings>> saveSettings(UserSettings settings) async {
    return Success(settings);
  }
}

Future<AgentMesh> _startMesh({
  _MemoryRepository? memoryRepository,
  AutomationEngine? automationEngine,
}) async {
  final memory = MemoryEngine(
    repository: memoryRepository ?? _MemoryRepository(),
  );
  final mesh = AgentMesh.bootstrap(
    memoryEngine: memory,
    voiceEngine: VoiceEngine(),
    emergencyEngine: EmergencyEngine(settingsRepository: _SettingsRepository()),
    aiEngine: HybridAiRouter(
      localProvider: LocalAiProvider(),
      cloudProvider: CloudAiProvider(),
    ),
    automationEngine: automationEngine ?? AutomationEngine(),
    announceVoice: false,
  );
  await mesh.start();
  return mesh;
}

void main() {
  test('agent bus delivers a direct reply to the requester', () async {
    final bus = AgentBus();
    final query = bus.compose(
      sessionId: 'session-1',
      from: AgentRole.planner,
      to: AgentRole.memory,
      kind: AgentMessageKind.query,
      topic: AgentTopics.memoryRecall,
      body: 'What do you know?',
    );

    bus.subscribe(AgentRole.memory).listen((message) async {
      if (message.kind != AgentMessageKind.query) {
        return;
      }
      await bus.publish(
        bus.compose(
          sessionId: message.sessionId,
          from: AgentRole.memory,
          to: message.from,
          kind: AgentMessageKind.reply,
          topic: message.topic,
          body: 'Nothing yet.',
          replyToId: message.id,
        ),
      );
    });

    final reply = await bus.request(query);
    expect(reply, isNotNull);
    expect(reply!.body, 'Nothing yet.');
    expect(reply.from, AgentRole.memory);
    await bus.dispose();
  });

  test('looksLikeProgramBuild detects program-building requests', () {
    expect(
      AgentMesh.looksLikeProgramBuild('Build a daily planner program'),
      isTrue,
    );
    expect(AgentMesh.looksLikeProgramBuild('What is the weather?'), isFalse);
  });

  test('Hive agents communicate and complete a program build', () async {
    final memoryRepository = _MemoryRepository();
    final automation = AutomationEngine();
    final mesh = await _startMesh(
      memoryRepository: memoryRepository,
      automationEngine: automation,
    );

    final session = await mesh.launchBuild(
      goal: 'Build a daily planner program',
    );

    expect(session.status, AgentSessionStatus.completed);
    expect(session.userSummary, contains('Noctros Hive completed'));
    expect(session.artifacts.containsKey('plan.md'), isTrue);
    expect(session.artifacts.containsKey('architecture.md'), isTrue);
    expect(session.artifacts.containsKey('review.md'), isTrue);
    expect(
      session.artifacts.keys.any((name) => name.endsWith('.dart')),
      isTrue,
    );

    final speakers = session.transcript.map((message) => message.from).toSet();
    expect(
      speakers,
      containsAll([
        AgentRole.conductor,
        AgentRole.planner,
        AgentRole.memory,
        AgentRole.architect,
        AgentRole.coder,
        AgentRole.inference,
        AgentRole.reviewer,
        AgentRole.automation,
      ]),
    );

    final topics = session.transcript.map((message) => message.topic).toSet();
    expect(topics, contains(AgentTopics.memoryRecall));
    expect(topics, contains(AgentTopics.contractAsk));
    expect(topics, contains(AgentTopics.inferenceAsk));
    expect(topics, contains(AgentTopics.reviewChanges));
    expect(topics, contains(AgentTopics.reviewApproved));
    expect(topics, contains(AgentTopics.sessionComplete));

    final dartSource = session.artifacts.entries
        .firstWhere((entry) => entry.key.endsWith('.dart'))
        .value;
    expect(dartSource, contains('bool get isReady'));
    expect(dartSource, contains('snapshot()'));

    expect(memoryRepository.entries, isNotEmpty);
    expect(automation.recipes, isNotEmpty);

    await mesh.dispose();
  });
}
