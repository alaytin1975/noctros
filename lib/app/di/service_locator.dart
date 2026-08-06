import '../../core/config/openai_config_service.dart';
import '../../data/local/database/noctros_database.dart';
import '../../data/local/secure/secure_storage_service.dart';
import '../../data/repositories/action_log_repository_impl.dart';
import '../../data/repositories/ai_repository_impl.dart';
import '../../data/repositories/conversation_repository_impl.dart';
import '../../data/repositories/memory_repository_impl.dart';
import '../../data/repositories/permission_repository_impl.dart';
import '../../data/repositories/settings_repository_impl.dart';
import '../../data/services/permission_service.dart';
import '../../domain/repositories/action_log_repository.dart';
import '../../domain/repositories/noctros_repositories.dart';
import '../../domain/repositories/permission_repository.dart';
import '../../domain/usecases/handle_user_command_use_case.dart';
import '../../engines/ai/ai_engine.dart';
import '../../engines/ai/cloud/openai_provider.dart';
import '../../engines/ai/hybrid_ai_router.dart';
import '../../engines/ai/local/local_ai_provider.dart';
import '../../engines/automation/ai_orchestrator.dart';
import '../../engines/automation/device_action_engine.dart';
import '../../engines/automation/intent_parser.dart';
import '../../engines/emergency/emergency_engine.dart';
import '../../engines/memory/memory_engine.dart';
import '../../engines/security/voice_enrollment.dart';
import '../../engines/security/voice_print_manager.dart';
import '../../engines/security/voice_verification.dart';
import '../../engines/voice/speech_recognition_service.dart';
import '../../engines/voice/speech_synthesis_service.dart';
import '../../engines/voice/voice_ai_orchestrator.dart';
import '../../engines/voice/voice_engine.dart';
import '../../engines/voice/voice_permission_manager.dart';
import '../../engines/voice/wake_word_engine.dart';

typedef ServiceFactory<T> = T Function();

/// Lightweight service locator for core singletons.
/// Riverpod handles presentation-layer DI; this registers long-lived engines.
abstract final class ServiceLocator {
  static final Map<Type, Object> _instances = {};

  static Future<void> registerCoreServices() async {
    _registerSingleton<SecureStorageService>(SecureStorageService.new);
    _registerSingleton<NoctrosDatabase>(() => NoctrosDatabase());
    _registerSingleton<OpenAiConfigService>(
      () => OpenAiConfigService(secureStorage: get<SecureStorageService>()),
    );

    _registerSingleton<LocalAiProvider>(LocalAiProvider.new);
    _registerSingleton<OpenAiProvider>(
      () => OpenAiProvider(configService: get<OpenAiConfigService>()),
    );
    _registerSingleton<AiEngine>(
      () => HybridAiRouter(
        localProvider: get<LocalAiProvider>(),
        cloudProvider: get<OpenAiProvider>(),
        openAiConfigService: get<OpenAiConfigService>(),
      ),
    );

    _registerSingleton<AiRepository>(
      () => AiRepositoryImpl(engine: get<AiEngine>()),
    );
    _registerSingleton<ConversationRepository>(
      () => ConversationRepositoryImpl(database: get<NoctrosDatabase>()),
    );
    _registerSingleton<MemoryRepository>(
      () => MemoryRepositoryImpl(database: get<NoctrosDatabase>()),
    );
    _registerSingleton<SettingsRepository>(
      () => SettingsRepositoryImpl(
        secureStorage: get<SecureStorageService>(),
        database: get<NoctrosDatabase>(),
      ),
    );
    _registerSingleton<PermissionService>(PermissionService.new);
    _registerSingleton<PermissionRepository>(
      () => PermissionRepositoryImpl(service: get<PermissionService>()),
    );
    _registerSingleton<VoicePermissionManager>(
      () => VoicePermissionManager(
        permissionRepository: get<PermissionRepository>(),
      ),
    );

    _registerSingleton<MemoryEngine>(
      () => MemoryEngine(repository: get<MemoryRepository>()),
    );
    _registerSingleton<ActionLogRepository>(
      () => ActionLogRepositoryImpl(database: get<NoctrosDatabase>()),
    );
    _registerSingleton<IntentParser>(IntentParser.new);
    _registerSingleton<DeviceActionEngine>(
      () => DeviceActionEngine(
        settingsRepository: get<SettingsRepository>(),
      ),
    );
    _registerSingleton<AiOrchestrator>(
      () => AiOrchestrator(
        intentParser: get<IntentParser>(),
        deviceActionEngine: get<DeviceActionEngine>(),
        actionLogRepository: get<ActionLogRepository>(),
        memoryRepository: get<MemoryRepository>(),
        settingsRepository: get<SettingsRepository>(),
      ),
    );

    _registerSingleton<SpeechRecognitionService>(
      () => SpeechRecognitionService(
        openAiConfigService: get<OpenAiConfigService>(),
      ),
    );
    _registerSingleton<SpeechSynthesisService>(SpeechSynthesisService.new);
    _registerSingleton<WakeWordEngine>(
      () => WakeWordEngine(
        speechRecognition: get<SpeechRecognitionService>(),
      ),
    );
    _registerSingleton<VoiceEngine>(
      () => VoiceEngine(
        speechRecognition: get<SpeechRecognitionService>(),
        speechSynthesis: get<SpeechSynthesisService>(),
        wakeWordEngine: get<WakeWordEngine>(),
      ),
    );
    _registerSingleton<VoicePrintManager>(
      () => VoicePrintManager(secureStorage: get<SecureStorageService>()),
    );
    _registerSingleton<VoiceEnrollment>(
      () => VoiceEnrollment(voicePrintManager: get<VoicePrintManager>()),
    );
    _registerSingleton<VoiceVerification>(
      () => VoiceVerification(voicePrintManager: get<VoicePrintManager>()),
    );
    _registerSingleton<HandleUserCommandUseCase>(HandleUserCommandUseCase.new);
    _registerSingleton<VoiceAiOrchestrator>(
      () => VoiceAiOrchestrator(
        voiceEngine: get<VoiceEngine>(),
        voiceVerification: get<VoiceVerification>(),
        handleUserCommandUseCase: get<HandleUserCommandUseCase>(),
        settingsRepository: get<SettingsRepository>(),
      ),
    );
    _registerSingleton<EmergencyEngine>(EmergencyEngine.new);
  }

  static void _registerSingleton<T extends Object>(ServiceFactory<T> factory) {
    _instances[T] = factory();
  }

  static T get<T extends Object>() {
    final instance = _instances[T];
    if (instance == null) {
      throw StateError('Service of type $T is not registered.');
    }
    return instance as T;
  }
}
