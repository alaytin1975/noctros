import '../../app/di/service_locator.dart';
import '../../core/errors/noctros_failure.dart';
import '../../core/utils/result.dart';
import '../../engines/agents/agent_mesh.dart';
import '../entities/agent_mesh_entities.dart';
import '../entities/noctros_enums.dart';

class LaunchAgentMeshUseCase {
  LaunchAgentMeshUseCase({AgentMesh? mesh})
      : _mesh = mesh ?? ServiceLocator.get();

  final AgentMesh _mesh;

  Future<Result<AgentSession>> execute({required String goal}) async {
    try {
      final session = await _mesh.launchBuild(goal: goal);
      if (session.status == AgentSessionStatus.failed) {
        return FailureResult(
          AgentFailure(session.errorMessage ?? 'Hive build failed.'),
        );
      }
      return Success(session);
    } on AgentFailure catch (failure) {
      return FailureResult(failure);
    } catch (error) {
      return FailureResult(
        AgentFailure('Hive could not start this build.', cause: error),
      );
    }
  }
}
