import 'dart:async';

import 'package:uuid/uuid.dart';

import '../../domain/entities/agent_mesh_entities.dart';
import '../../domain/entities/noctros_enums.dart';

/// In-process mesh: every agent publishes, subscribes, and can request/reply.
class AgentBus {
  AgentBus({Uuid? uuid}) : _uuid = uuid ?? const Uuid();

  final Uuid _uuid;
  final StreamController<AgentMessage> _controller =
      StreamController<AgentMessage>.broadcast();
  final Map<String, Completer<AgentMessage>> _pendingReplies = {};
  final List<AgentMessage> _log = [];

  Stream<AgentMessage> get messages => _controller.stream;

  List<AgentMessage> get log => List.unmodifiable(_log);

  AgentMessage compose({
    required String sessionId,
    required AgentRole from,
    required AgentMessageKind kind,
    required String topic,
    required String body,
    AgentRole? to,
    Map<String, Object?> payload = const {},
    String? replyToId,
  }) {
    return AgentMessage(
      id: _uuid.v4(),
      sessionId: sessionId,
      from: from,
      to: to,
      kind: kind,
      topic: topic,
      body: body,
      payload: payload,
      replyToId: replyToId,
      createdAt: DateTime.now().toUtc(),
    );
  }

  /// Messages addressed to [role], plus Hive-wide broadcasts.
  Stream<AgentMessage> subscribe(AgentRole role) {
    return _controller.stream.where(
      (message) => message.to == null || message.to == role,
    );
  }

  Future<void> publish(AgentMessage message) async {
    _log.add(message);
    final replyToId = message.replyToId;
    if (replyToId != null && _pendingReplies.containsKey(replyToId)) {
      _pendingReplies.remove(replyToId)!.complete(message);
    }
    _controller.add(message);
  }

  Future<AgentMessage?> request(
    AgentMessage message, {
    Duration timeout = const Duration(seconds: 3),
  }) async {
    final completer = Completer<AgentMessage>();
    _pendingReplies[message.id] = completer;
    await publish(message);
    try {
      return await completer.future.timeout(timeout);
    } on TimeoutException {
      _pendingReplies.remove(message.id);
      return null;
    }
  }

  Future<void> dispose() async {
    for (final pending in _pendingReplies.values) {
      if (!pending.isCompleted) {
        pending.completeError(StateError('Agent bus closed.'));
      }
    }
    _pendingReplies.clear();
    await _controller.close();
  }
}
