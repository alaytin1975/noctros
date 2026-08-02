import '../../domain/entities/noctros_entities.dart';
import '../../domain/entities/noctros_enums.dart';

abstract interface class AiEngine {
  Future<AiResponse> complete(AiRequest request);
  Future<AiExecutionMode> resolveMode(AiRequest request);
}

abstract interface class AiProvider {
  Future<AiResponse> complete(AiRequest request);
  bool canHandle(AiRequest request);
}
