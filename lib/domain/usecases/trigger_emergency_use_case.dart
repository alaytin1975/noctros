import '../../app/di/service_locator.dart';
import '../../core/utils/result.dart';
import '../../engines/emergency/emergency_engine.dart';
import '../entities/noctros_entities.dart';
import '../entities/noctros_enums.dart';

class TriggerEmergencyUseCase {
  TriggerEmergencyUseCase({EmergencyEngine? emergencyEngine})
      : _emergencyEngine = emergencyEngine ?? ServiceLocator.get();

  final EmergencyEngine _emergencyEngine;

  Future<Result<EmergencyEvent>> execute({
    required String detectedPhrase,
    EmergencyTriggerType triggerType = EmergencyTriggerType.phrase,
    bool userConfirmed = false,
  }) {
    return _emergencyEngine.handleTrigger(
      detectedPhrase: detectedPhrase,
      triggerType: triggerType,
      userConfirmed: userConfirmed,
    );
  }
}
