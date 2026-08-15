enum AiExecutionMode {
  local,
  cloud,
  hybrid,
}

enum AiTaskComplexity {
  lightweight,
  moderate,
  complex,
}

enum MessageRole {
  user,
  assistant,
  system,
}

enum MemoryCategory {
  preference,
  contact,
  place,
  routine,
  habit,
  schedule,
}

enum EmergencyTriggerType {
  phrase,
  fall,
  crash,
  manual,
}

enum PrivacyCloudPolicy {
  never,
  askEveryTime,
  whenRequired,
}

/// Specialist roles in the Noctros Hive — one autonomous system.
enum AgentRole {
  conductor,
  planner,
  architect,
  coder,
  reviewer,
  memory,
  voice,
  emergency,
  inference,
  automation,
}

enum AgentMessageKind {
  broadcast,
  task,
  query,
  reply,
  status,
  artifact,
  handoff,
}

enum AgentSessionStatus {
  idle,
  running,
  completed,
  failed,
}

enum AgentActivity {
  idle,
  listening,
  thinking,
  speaking,
}

enum ThreadMessageStatus {
  sending,
  sent,
  delivered,
  read,
  failed,
}

enum CallDirection {
  outgoing,
  incoming,
  missed,
}

enum CallKind {
  audio,
  video,
}
