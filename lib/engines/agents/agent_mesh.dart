import 'dart:async';

import 'package:uuid/uuid.dart';

import '../../domain/entities/agent_mesh_entities.dart';
import '../../domain/entities/noctros_enums.dart';
import '../ai/ai_engine.dart';
import '../automation/automation_engine.dart';
import '../emergency/emergency_engine.dart';
import '../memory/memory_engine.dart';
import '../voice/voice_engine.dart';
import 'agent.dart';
import 'agent_bus.dart';
import 'agent_topics.dart';
import 'bridges/engine_bridge_agents.dart';
import 'specialists/architect_agent.dart';
import 'specialists/coder_agent.dart';
import 'specialists/conductor_agent.dart';
import 'specialists/planner_agent.dart';
import 'specialists/reviewer_agent.dart';

/// The one autonomous system: every Noctros agent shares this mesh.
class AgentMesh {
  AgentMesh({
    required this.bus,
    required List<NoctrosAgent> agents,
    Uuid? uuid,
  })  : _agents = List.unmodifiable(agents),
        _uuid = uuid ?? const Uuid();

  factory AgentMesh.bootstrap({
    required MemoryEngine memoryEngine,
    required VoiceEngine voiceEngine,
    required EmergencyEngine emergencyEngine,
    required AiEngine aiEngine,
    required AutomationEngine automationEngine,
    AgentBus? bus,
    bool announceVoice = true,
    Uuid? uuid,
  }) {
    final hiveBus = bus ?? AgentBus(uuid: uuid);
    return AgentMesh(
      bus: hiveBus,
      uuid: uuid,
      agents: [
        ConductorAgent(),
        PlannerAgent(),
        ArchitectAgent(),
        CoderAgent(),
        ReviewerAgent(),
        MemoryAgent(memoryEngine: memoryEngine),
        VoiceAgent(
          voiceEngine: voiceEngine,
          announceCompletions: announceVoice,
        ),
        EmergencyAgent(emergencyEngine: emergencyEngine),
        InferenceAgent(aiEngine: aiEngine),
        AutomationAgent(automationEngine: automationEngine),
      ],
    );
  }

  final AgentBus bus;
  final List<NoctrosAgent> _agents;
  final Uuid _uuid;
  final Map<String, AgentSession> _sessions = {};
  final Map<String, Completer<AgentSession>> _waiters = {};
  final StreamController<AgentSession> _snapshots =
      StreamController<AgentSession>.broadcast();
  StreamSubscription<AgentMessage>? _subscription;

  List<NoctrosAgent> get agents => _agents;

  List<AgentIdentity> get roster =>
      AgentRole.values.map(AgentIdentity.of).toList();

  static bool looksLikeProgramBuild(String text) {
    final normalized = text.toLowerCase();
    const verbs = ['build', 'create', 'write', 'generate', 'make'];
    const nouns = [
      'program',
      'app',
      'feature',
      'software',
      'module',
      'widget',
    ];
    return verbs.any(normalized.contains) && nouns.any(normalized.contains);
  }

  Stream<AgentSession> get snapshots => _snapshots.stream;

  AgentSession? get latestSession {
    if (_sessions.isEmpty) {
      return null;
    }
    return _sessions.values.last;
  }

  Future<void> start() async {
    _subscription ??= bus.messages.listen(_onBusMessage);
    for (final agent in _agents) {
      await agent.attach(bus);
    }
  }

  Future<AgentSession> launchBuild({required String goal}) async {
    final trimmed = goal.trim();
    if (trimmed.isEmpty) {
      throw ArgumentError('Hive builds need a program goal.');
    }

    final session = AgentSession(
      id: _uuid.v4(),
      goal: trimmed,
      status: AgentSessionStatus.running,
      startedAt: DateTime.now().toUtc(),
      activities: {
        for (final role in AgentRole.values) role: AgentActivity.idle,
      },
    );
    _sessions[session.id] = session;
    final waiter = Completer<AgentSession>();
    _waiters[session.id] = waiter;
    _emit(session);

    await bus.publish(
      bus.compose(
        sessionId: session.id,
        from: AgentRole.conductor,
        kind: AgentMessageKind.broadcast,
        topic: AgentTopics.sessionStart,
        body: trimmed,
      ),
    );

    return waiter.future.timeout(
      const Duration(seconds: 20),
      onTimeout: () {
        return _finish(
          session.id,
          status: AgentSessionStatus.failed,
          errorMessage: 'The Hive timed out waiting for agents to finish.',
        );
      },
    );
  }

  Future<void> dispose() async {
    await _subscription?.cancel();
    for (final agent in _agents) {
      await agent.detach();
    }
    await _snapshots.close();
    await bus.dispose();
  }

  void _onBusMessage(AgentMessage message) {
    final session = _sessions[message.sessionId];
    if (session == null) {
      return;
    }

    final activities = Map<AgentRole, AgentActivity>.from(session.activities);
    activities[message.from] = message.kind == AgentMessageKind.status
        ? AgentActivity.thinking
        : AgentActivity.speaking;

    final artifacts = Map<String, String>.from(session.artifacts);
    if (message.topic == AgentTopics.planReady) {
      artifacts['plan.md'] = message.body;
    }
    if (message.topic == AgentTopics.designReady) {
      artifacts['architecture.md'] = message.body;
    }
    if (message.topic == AgentTopics.codeReady ||
        message.kind == AgentMessageKind.artifact) {
      final fileName =
          (message.payload['fileName'] as String?) ?? 'generated.dart';
      final source = (message.payload['artifact'] as String?) ?? message.body;
      artifacts[fileName] = source;
    }
    if (message.topic == AgentTopics.reviewApproved) {
      artifacts['review.md'] = message.body;
    }

    var status = session.status;
    String? summary = session.userSummary;
    String? error = session.errorMessage;
    DateTime? completedAt = session.completedAt;

    if (message.topic == AgentTopics.sessionComplete) {
      status = AgentSessionStatus.completed;
      summary = (message.payload['userSummary'] as String?) ?? message.body;
      completedAt = DateTime.now().toUtc();
    }
    if (message.topic == AgentTopics.sessionFailed) {
      status = AgentSessionStatus.failed;
      error = message.body;
      completedAt = DateTime.now().toUtc();
    }

    final next = session.copyWith(
      status: status,
      completedAt: completedAt,
      transcript: [...session.transcript, message],
      artifacts: artifacts,
      activities: activities,
      userSummary: summary,
      errorMessage: error,
    );
    _sessions[message.sessionId] = next;
    _emit(next);

    if (status == AgentSessionStatus.completed ||
        status == AgentSessionStatus.failed) {
      final waiter = _waiters.remove(message.sessionId);
      if (waiter != null && !waiter.isCompleted) {
        waiter.complete(next);
      }
    }
  }

  AgentSession _finish(
    String sessionId, {
    required AgentSessionStatus status,
    String? errorMessage,
  }) {
    final session = _sessions[sessionId];
    if (session == null) {
      throw StateError('Unknown Hive session $sessionId');
    }
    if (session.status == AgentSessionStatus.completed ||
        session.status == AgentSessionStatus.failed) {
      return session;
    }
    final next = session.copyWith(
      status: status,
      completedAt: DateTime.now().toUtc(),
      errorMessage: errorMessage,
    );
    _sessions[sessionId] = next;
    _emit(next);
    final waiter = _waiters.remove(sessionId);
    if (waiter != null && !waiter.isCompleted) {
      waiter.complete(next);
    }
    return next;
  }

  void _emit(AgentSession session) {
    if (!_snapshots.isClosed) {
      _snapshots.add(session);
    }
  }
}
