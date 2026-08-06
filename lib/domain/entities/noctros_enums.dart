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

enum VoiceGender {
  system,
  female,
  male,
}

enum VoiceAccessLevel {
  owner,
  guest,
  unknown,
  emergencyOnly,
}

enum SttBackend {
  offline,
  cloud,
  auto,
}

enum TtsBackend {
  offline,
  cloud,
  auto,
}
