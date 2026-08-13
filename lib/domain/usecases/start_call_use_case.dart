import '../../app/di/service_locator.dart';
import '../../core/utils/result.dart';
import '../entities/communication_entities.dart';
import '../entities/noctros_enums.dart';
import '../repositories/communication_repository.dart';

class StartCallUseCase {
  StartCallUseCase({CommunicationRepository? repository})
      : _repository = repository ?? ServiceLocator.get();

  final CommunicationRepository _repository;

  Future<Result<CallRecord>> execute({
    required String contactId,
    CallKind kind = CallKind.audio,
  }) {
    return _repository.startCall(contactId: contactId, kind: kind);
  }
}
