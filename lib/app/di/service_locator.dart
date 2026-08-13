import '../../data/local/database/noctros_database.dart';
import '../../data/local/secure/secure_storage_service.dart';
import '../../data/repositories/ai_repository_impl.dart';
import '../../data/repositories/communication_repository_impl.dart';
import '../../data/repositories/conversation_repository_impl.dart';
import '../../data/repositories/memory_repository_impl.dart';
import '../../data/repositories/settings_repository_impl.dart';
import '../../domain/repositories/communication_repository.dart';
import '../../domain/repositories/noctros_repositories.dart';
import '../../engines/ai/ai_engine.dart';
import '../../engines/ai/cloud/cloud_ai_provider.dart';
import '../../engines/ai/hybrid_ai_router.dart';
import '../../engines/ai/local/local_ai_provider.dart';
import '../../engines/emergency/emergency_engine.dart';
import '../../engines/memory/memory_engine.dart';
import '../../engines/voice/voice_engine.dart';

typedef ServiceFactory<T> = T Function();

/// Lightweight service locator for core singletons.
/// Riverpod handles presentation-layer DI; this registers long-lived engines.
abstract final class ServiceLocator {
  static final Map<Type, Object> _instances = {};

  static Future<void> registerCoreServices() async {
    _registerSingleton<SecureStorageService>(SecureStorageService.new);
    _registerSingleton<NoctrosDatabase>(() => NoctrosDatabase());

    _registerSingleton<LocalAiProvider>(LocalAiProvider.new);
    _registerSingleton<CloudAiProvider>(CloudAiProvider.new);
    _registerSingleton<AiEngine>(
      () => HybridAiRouter(
        localProvider: get<LocalAiProvider>(),
        cloudProvider: get<CloudAiProvider>(),
      ),
    );

    _registerSingleton<AiRepository>(
      () => AiRepositoryImpl(engine: get<AiEngine>()),
    );
    _registerSingleton<ConversationRepository>(
      () => ConversationRepositoryImpl(database: get<NoctrosDatabase>()),
    );
    _registerSingleton<CommunicationRepository>(
      () => CommunicationRepositoryImpl(database: get<NoctrosDatabase>()),
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

    _registerSingleton<MemoryEngine>(
      () => MemoryEngine(repository: get<MemoryRepository>()),
    );
    _registerSingleton<VoiceEngine>(VoiceEngine.new);
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
