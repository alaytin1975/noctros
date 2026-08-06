import '../../core/errors/noctros_failure.dart';
import '../../core/utils/result.dart';
import '../../domain/entities/noctros_entities.dart';
import '../../domain/entities/noctros_enums.dart';
import '../../domain/repositories/noctros_repositories.dart';
import '../local/database/noctros_database.dart';
import '../local/secure/secure_storage_service.dart';

class SettingsRepositoryImpl implements SettingsRepository {
  SettingsRepositoryImpl({
    required SecureStorageService secureStorage,
    required NoctrosDatabase database,
  })  : _secureStorage = secureStorage,
        _database = database;

  static const _settingsKey = 'user_settings';

  final SecureStorageService _secureStorage;
  final NoctrosDatabase _database;

  @override
  Future<Result<UserSettings>> loadSettings() async {
    try {
      final stored = await _database.fetchSetting(_settingsKey);
      if (stored == null) {
        return Success(UserSettings.defaults());
      }
      return Success(_fromJson(stored));
    } catch (error) {
      return FailureResult(
        StorageFailure('Failed to load settings.', cause: error),
      );
    }
  }

  @override
  Future<Result<UserSettings>> saveSettings(UserSettings settings) async {
    try {
      await _database.upsertSetting(_settingsKey, _toJson(settings));
      await _secureStorage.write('cloud_policy', settings.cloudPolicy.name);
      return Success(settings);
    } catch (error) {
      return FailureResult(
        StorageFailure('Failed to save settings.', cause: error),
      );
    }
  }

  Map<String, Object?> _toJson(UserSettings settings) {
    return {
      'wakeWords': settings.wakeWords,
      'preferredLanguageCode': settings.preferredLanguageCode,
      'aiExecutionMode': settings.aiExecutionMode.name,
      'cloudPolicy': settings.cloudPolicy.name,
      'memoryEnabled': settings.memoryEnabled,
      'emergencyAutoDialEnabled': settings.emergencyAutoDialEnabled,
      'darkModeEnabled': settings.darkModeEnabled,
      'speechRate': settings.speechRate,
      'ttsEnabled': settings.ttsEnabled,
      'sttLocaleId': settings.sttLocaleId,
      'continuousVoiceEnabled': settings.continuousVoiceEnabled,
      'alwaysListeningPrepared': settings.alwaysListeningPrepared,
      'defaultNavigationApp': settings.defaultNavigationApp,
      'preferredBrowser': settings.preferredBrowser,
      'rememberPreferredContacts': settings.rememberPreferredContacts,
      'confirmDeviceActions': settings.confirmDeviceActions,
      'assistantName': settings.assistantName,
      'wakeWordEnabled': settings.wakeWordEnabled,
      'voiceGender': settings.voiceGender.name,
      'speechPitch': settings.speechPitch,
      'speechVolume': settings.speechVolume,
      'voiceIdEnabled': settings.voiceIdEnabled,
      'cloudSttFallbackEnabled': settings.cloudSttFallbackEnabled,
      'sttBackend': settings.sttBackend.name,
      'ttsBackend': settings.ttsBackend.name,
      'emergencyNumber': settings.emergencyNumber,
      'emergencyContacts': settings.emergencyContacts
          .map(
            (contact) => {
              'id': contact.id,
              'name': contact.name,
              'phoneNumber': contact.phoneNumber,
              'notifyOnEmergency': contact.notifyOnEmergency,
            },
          )
          .toList(),
    };
  }

  UserSettings _fromJson(Map<String, Object?> json) {
    final contacts = (json['emergencyContacts'] as List<Object?>? ?? [])
        .cast<Map<Object?, Object?>>()
        .map(
          (contact) => EmergencyContact(
            id: contact['id']! as String,
            name: contact['name']! as String,
            phoneNumber: contact['phoneNumber']! as String,
            notifyOnEmergency: contact['notifyOnEmergency'] as bool? ?? true,
          ),
        )
        .toList();

    return UserSettings(
      wakeWords: (json['wakeWords'] as List<Object?>).cast<String>(),
      preferredLanguageCode: json['preferredLanguageCode']! as String,
      aiExecutionMode:
          AiExecutionMode.values.byName(json['aiExecutionMode']! as String),
      cloudPolicy:
          PrivacyCloudPolicy.values.byName(json['cloudPolicy']! as String),
      memoryEnabled: json['memoryEnabled']! as bool,
      emergencyAutoDialEnabled: json['emergencyAutoDialEnabled']! as bool,
      emergencyContacts: contacts,
      darkModeEnabled: json['darkModeEnabled'] as bool? ?? false,
      speechRate: (json['speechRate'] as num?)?.toDouble() ?? 0.48,
      ttsEnabled: json['ttsEnabled'] as bool? ?? true,
      sttLocaleId: json['sttLocaleId'] as String? ?? 'en_US',
      continuousVoiceEnabled: json['continuousVoiceEnabled'] as bool? ?? false,
      alwaysListeningPrepared:
          json['alwaysListeningPrepared'] as bool? ?? true,
      defaultNavigationApp:
          json['defaultNavigationApp'] as String? ?? 'google_maps',
      preferredBrowser: json['preferredBrowser'] as String? ?? 'default',
      rememberPreferredContacts:
          json['rememberPreferredContacts'] as bool? ?? false,
      confirmDeviceActions: json['confirmDeviceActions'] as bool? ?? true,
      assistantName: json['assistantName'] as String? ?? 'Noctros',
      wakeWordEnabled: json['wakeWordEnabled'] as bool? ?? true,
      voiceGender: VoiceGender.values.byName(
        json['voiceGender'] as String? ?? VoiceGender.system.name,
      ),
      speechPitch: (json['speechPitch'] as num?)?.toDouble() ?? 1.0,
      speechVolume: (json['speechVolume'] as num?)?.toDouble() ?? 1.0,
      voiceIdEnabled: json['voiceIdEnabled'] as bool? ?? false,
      cloudSttFallbackEnabled:
          json['cloudSttFallbackEnabled'] as bool? ?? true,
      sttBackend: SttBackend.values.byName(
        json['sttBackend'] as String? ?? SttBackend.auto.name,
      ),
      ttsBackend: TtsBackend.values.byName(
        json['ttsBackend'] as String? ?? TtsBackend.offline.name,
      ),
      emergencyNumber: json['emergencyNumber'] as String? ?? '112',
    );
  }
}
