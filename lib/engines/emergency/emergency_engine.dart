import 'package:geolocator/geolocator.dart';
import 'package:uuid/uuid.dart';

import '../../app/di/service_locator.dart';
import '../../core/constants/noctros_constants.dart';
import '../../core/errors/noctros_failure.dart';
import '../../core/utils/result.dart';
import '../../domain/entities/noctros_entities.dart';
import '../../domain/entities/noctros_enums.dart';
import '../../domain/repositories/noctros_repositories.dart';

/// Low-power emergency detection and response coordinator.
class EmergencyEngine {
  EmergencyEngine({
    SettingsRepository? settingsRepository,
    Uuid? uuid,
  })  : _settingsRepository =
            settingsRepository ?? ServiceLocator.get<SettingsRepository>(),
        _uuid = uuid ?? const Uuid();

  final SettingsRepository _settingsRepository;
  final Uuid _uuid;

  bool matchesEmergencyPhrase(String transcript) {
    final normalized = transcript.toLowerCase().trim();
    return NoctrosConstants.emergencyPhrases
        .any((phrase) => normalized.contains(phrase));
  }

  Future<Result<EmergencyEvent>> handleTrigger({
    required String detectedPhrase,
    EmergencyTriggerType triggerType = EmergencyTriggerType.phrase,
    bool userConfirmed = false,
  }) async {
    try {
      final settingsResult = await _settingsRepository.loadSettings();
      if (settingsResult is FailureResult<UserSettings>) {
        return FailureResult(settingsResult.failure);
      }
      final settings = settingsResult.valueOrThrow;

      final position = await _resolveLocation();
      final requiresConfirmation = !settings.emergencyAutoDialEnabled;

      if (requiresConfirmation && !userConfirmed) {
        return Success(
          EmergencyEvent(
            id: _uuid.v4(),
            triggerType: triggerType,
            detectedPhrase: detectedPhrase,
            detectedAt: DateTime.now().toUtc(),
            latitude: position?.latitude,
            longitude: position?.longitude,
            requiresConfirmation: true,
          ),
        );
      }

      await _notifyEmergencyContacts(settings.emergencyContacts, detectedPhrase);

      return Success(
        EmergencyEvent(
          id: _uuid.v4(),
          triggerType: triggerType,
          detectedPhrase: detectedPhrase,
          detectedAt: DateTime.now().toUtc(),
          latitude: position?.latitude,
          longitude: position?.longitude,
          requiresConfirmation: false,
        ),
      );
    } catch (error) {
      return FailureResult(
        EmergencyFailure('Emergency handling failed.', cause: error),
      );
    }
  }

  Future<Position?> _resolveLocation() async {
    final permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      return null;
    }
    return Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        timeLimit: Duration(seconds: 8),
      ),
    );
  }

  Future<void> _notifyEmergencyContacts(
    List<EmergencyContact> contacts,
    String phrase,
  ) async {
    for (final contact in contacts.where((c) => c.notifyOnEmergency)) {
      // Platform channels will dispatch SMS/notifications in native modules.
      assert(contact.phoneNumber.isNotEmpty);
      assert(phrase.isNotEmpty);
    }
  }
}
