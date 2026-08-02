import '../../core/errors/noctros_failure.dart';
import '../../core/utils/result.dart';
import '../../domain/entities/noctros_entities.dart';
import '../../domain/entities/noctros_enums.dart';
import '../../domain/repositories/noctros_repositories.dart';
import '../../engines/ai/ai_engine.dart';

class AiRepositoryImpl implements AiRepository {
  AiRepositoryImpl({required AiEngine engine}) : _engine = engine;

  final AiEngine _engine;

  @override
  Future<Result<AiResponse>> complete(AiRequest request) async {
    try {
      final response = await _engine.complete(request);
      return Success(response);
    } on NoctrosFailure catch (failure) {
      return FailureResult(failure);
    } catch (error) {
      return FailureResult(AiFailure('AI request failed.', cause: error));
    }
  }

  @override
  Stream<String> streamComplete(AiRequest request) {
    return _engine.streamComplete(request);
  }

  @override
  Future<Result<AiExecutionMode>> resolveMode(AiRequest request) async {
    try {
      final mode = await _engine.resolveMode(request);
      return Success(mode);
    } on NoctrosFailure catch (failure) {
      return FailureResult(failure);
    } catch (error) {
      return FailureResult(
        AiFailure('Failed to resolve AI mode.', cause: error),
      );
    }
  }
}
