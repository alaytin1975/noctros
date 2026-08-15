import 'dart:async';

import '../../domain/entities/agent_mesh_entities.dart';
import '../../domain/entities/noctros_enums.dart';
import 'agent_bus.dart';
import 'agent_topics.dart';

/// A specialist that only talks to peers through [AgentBus].
abstract class NoctrosAgent {
  AgentIdentity get identity;
  AgentRole get role => identity.role;

  AgentBus? _bus;
  StreamSubscription<AgentMessage>? _subscription;

  AgentBus get bus {
    final connected = _bus;
    if (connected == null) {
      throw StateError('${identity.displayName} is not attached to the Hive bus.');
    }
    return connected;
  }

  Future<void> attach(AgentBus bus) async {
    await detach();
    _bus = bus;
    _subscription = bus.subscribe(role).listen((message) {
      if (message.from == role || message.kind == AgentMessageKind.reply) {
        return;
      }
      unawaited(handle(message));
    });
  }

  Future<void> detach() async {
    await _subscription?.cancel();
    _subscription = null;
  }

  Future<void> handle(AgentMessage message);

  Future<void> publish({
    required String sessionId,
    required AgentMessageKind kind,
    required String topic,
    required String body,
    AgentRole? to,
    Map<String, Object?> payload = const {},
    String? replyToId,
  }) {
    return bus.publish(
      bus.compose(
        sessionId: sessionId,
        from: role,
        to: to,
        kind: kind,
        topic: topic,
        body: body,
        payload: payload,
        replyToId: replyToId,
      ),
    );
  }

  Future<void> think(String sessionId, String body) {
    return publish(
      sessionId: sessionId,
      kind: AgentMessageKind.status,
      topic: AgentTopics.statusUpdate,
      body: body,
      payload: {'activity': AgentActivity.thinking.name},
    );
  }

  Future<AgentMessage?> ask({
    required String sessionId,
    required AgentRole to,
    required String topic,
    required String body,
    Map<String, Object?> payload = const {},
    Duration timeout = const Duration(seconds: 3),
  }) {
    return bus.request(
      bus.compose(
        sessionId: sessionId,
        from: role,
        to: to,
        kind: AgentMessageKind.query,
        topic: topic,
        body: body,
        payload: payload,
      ),
      timeout: timeout,
    );
  }
}
