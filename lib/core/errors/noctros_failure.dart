sealed class NoctrosFailure implements Exception {
  const NoctrosFailure(this.message, {this.cause});

  final String message;
  final Object? cause;

  @override
  String toString() => 'NoctrosFailure: $message';
}

final class NetworkFailure extends NoctrosFailure {
  const NetworkFailure(super.message, {super.cause});
}

final class StorageFailure extends NoctrosFailure {
  const StorageFailure(super.message, {super.cause});
}

final class PermissionFailure extends NoctrosFailure {
  const PermissionFailure(super.message, {super.cause});
}

final class AiFailure extends NoctrosFailure {
  const AiFailure(super.message, {super.cause});
}

final class VoiceFailure extends NoctrosFailure {
  const VoiceFailure(super.message, {super.cause});
}

final class EmergencyFailure extends NoctrosFailure {
  const EmergencyFailure(super.message, {super.cause});
}

final class AgentFailure extends NoctrosFailure {
  const AgentFailure(super.message, {super.cause});
}
