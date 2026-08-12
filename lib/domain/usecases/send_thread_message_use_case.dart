import '../../app/di/service_locator.dart';
import '../../core/utils/result.dart';
import '../entities/communication_entities.dart';
import '../repositories/communication_repository.dart';

class SendThreadMessageUseCase {
  SendThreadMessageUseCase({CommunicationRepository? repository})
      : _repository = repository ?? ServiceLocator.get();

  final CommunicationRepository _repository;

  Future<Result<ThreadMessage>> execute({
    required String threadId,
    required String body,
  }) {
    return _repository.sendThreadMessage(threadId: threadId, body: body);
  }
}
