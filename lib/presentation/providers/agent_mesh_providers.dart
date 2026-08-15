import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/di/service_locator.dart';
import '../../domain/entities/agent_mesh_entities.dart';
import '../../domain/entities/noctros_enums.dart';
import '../../domain/usecases/launch_agent_mesh_use_case.dart';
import '../../engines/agents/agent_mesh.dart';

class HiveViewState {
  const HiveViewState({
    required this.roster,
    this.session,
    this.isLaunching = false,
    this.errorMessage,
  });

  final List<AgentIdentity> roster;
  final AgentSession? session;
  final bool isLaunching;
  final String? errorMessage;

  HiveViewState copyWith({
    AgentSession? session,
    bool? isLaunching,
    String? errorMessage,
  }) {
    return HiveViewState(
      roster: roster,
      session: session ?? this.session,
      isLaunching: isLaunching ?? this.isLaunching,
      errorMessage: errorMessage,
    );
  }
}

class HiveController extends StateNotifier<HiveViewState> {
  HiveController(this._mesh)
      : _launch = LaunchAgentMeshUseCase(mesh: _mesh),
        super(
          HiveViewState(
            roster: _mesh.roster,
            session: _mesh.latestSession,
          ),
        ) {
    _subscription = _mesh.snapshots.listen((session) {
      state = state.copyWith(
        session: session,
        isLaunching: session.status == AgentSessionStatus.running,
        errorMessage: session.errorMessage,
      );
    });
  }

  final AgentMesh _mesh;
  final LaunchAgentMeshUseCase _launch;
  StreamSubscription<AgentSession>? _subscription;

  Future<void> launch(String goal) async {
    final trimmed = goal.trim();
    if (trimmed.isEmpty) {
      return;
    }
    state = state.copyWith(isLaunching: true, errorMessage: null);
    final result = await _launch.execute(goal: trimmed);
    if (result.isFailure) {
      state = state.copyWith(
        isLaunching: false,
        errorMessage: result.failureOrNull?.message,
      );
    }
  }

  @override
  void dispose() {
    final subscription = _subscription;
    if (subscription != null) {
      unawaited(subscription.cancel());
    }
    super.dispose();
  }
}

final agentMeshProvider = Provider<AgentMesh>((ref) {
  return ServiceLocator.get<AgentMesh>();
});

final hiveControllerProvider =
    StateNotifierProvider<HiveController, HiveViewState>((ref) {
  return HiveController(ref.watch(agentMeshProvider));
});
