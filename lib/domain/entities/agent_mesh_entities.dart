import 'noctros_enums.dart';

/// Who an agent is inside the Hive, including how it should be shown in UI.
class AgentIdentity {
  const AgentIdentity({
    required this.role,
    required this.displayName,
    required this.specialty,
  });

  final AgentRole role;
  final String displayName;
  final String specialty;

  static AgentIdentity of(AgentRole role) {
    return switch (role) {
      AgentRole.conductor => const AgentIdentity(
          role: AgentRole.conductor,
          displayName: 'Conductor',
          specialty: 'One voice for the whole Hive',
        ),
      AgentRole.planner => const AgentIdentity(
          role: AgentRole.planner,
          displayName: 'Planner',
          specialty: 'Breaks goals into build steps',
        ),
      AgentRole.architect => const AgentIdentity(
          role: AgentRole.architect,
          displayName: 'Architect',
          specialty: 'Designs modules and contracts',
        ),
      AgentRole.coder => const AgentIdentity(
          role: AgentRole.coder,
          displayName: 'Coder',
          specialty: 'Writes program artifacts',
        ),
      AgentRole.reviewer => const AgentIdentity(
          role: AgentRole.reviewer,
          displayName: 'Reviewer',
          specialty: 'Checks design and code together',
        ),
      AgentRole.memory => const AgentIdentity(
          role: AgentRole.memory,
          displayName: 'Memory',
          specialty: 'Recalls and stores Hive knowledge',
        ),
      AgentRole.voice => const AgentIdentity(
          role: AgentRole.voice,
          displayName: 'Voice',
          specialty: 'Speaks Hive progress aloud',
        ),
      AgentRole.emergency => const AgentIdentity(
          role: AgentRole.emergency,
          displayName: 'Emergency',
          specialty: 'Watches for safety phrases',
        ),
      AgentRole.inference => const AgentIdentity(
          role: AgentRole.inference,
          displayName: 'Inference',
          specialty: 'Local/cloud language reasoning',
        ),
      AgentRole.automation => const AgentIdentity(
          role: AgentRole.automation,
          displayName: 'Automation',
          specialty: 'Records finished workflows',
        ),
    };
  }
}

/// Envelope every agent uses to talk to every other agent.
class AgentMessage {
  const AgentMessage({
    required this.id,
    required this.sessionId,
    required this.from,
    required this.kind,
    required this.topic,
    required this.body,
    required this.createdAt,
    this.to,
    this.payload = const {},
    this.replyToId,
  });

  final String id;
  final String sessionId;
  final AgentRole from;
  final AgentRole? to;
  final AgentMessageKind kind;
  final String topic;
  final String body;
  final Map<String, Object?> payload;
  final String? replyToId;
  final DateTime createdAt;

  bool get isBroadcast => to == null;

  String get routeLabel {
    final sender = AgentIdentity.of(from).displayName;
    if (to == null) {
      return '$sender → Hive';
    }
    return '$sender → ${AgentIdentity.of(to!).displayName}';
  }
}

class AgentSession {
  const AgentSession({
    required this.id,
    required this.goal,
    required this.status,
    required this.startedAt,
    this.completedAt,
    this.transcript = const [],
    this.artifacts = const {},
    this.activities = const {},
    this.userSummary,
    this.errorMessage,
  });

  final String id;
  final String goal;
  final AgentSessionStatus status;
  final DateTime startedAt;
  final DateTime? completedAt;
  final List<AgentMessage> transcript;
  final Map<String, String> artifacts;
  final Map<AgentRole, AgentActivity> activities;
  final String? userSummary;
  final String? errorMessage;

  AgentSession copyWith({
    AgentSessionStatus? status,
    DateTime? completedAt,
    List<AgentMessage>? transcript,
    Map<String, String>? artifacts,
    Map<AgentRole, AgentActivity>? activities,
    String? userSummary,
    String? errorMessage,
  }) {
    return AgentSession(
      id: id,
      goal: goal,
      status: status ?? this.status,
      startedAt: startedAt,
      completedAt: completedAt ?? this.completedAt,
      transcript: transcript ?? this.transcript,
      artifacts: artifacts ?? this.artifacts,
      activities: activities ?? this.activities,
      userSummary: userSummary ?? this.userSummary,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }
}
