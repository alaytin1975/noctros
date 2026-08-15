import '../../core/platform/optional_env_loader.dart';
import '../../core/platform/storage_bindings.dart';
import '../../data/local/database/noctros_database.dart';
import '../../data/local/seed/communication_seed.dart';
import '../../data/local/secure/secure_storage_service.dart';
import '../../engines/agents/agent_mesh.dart';
import '../di/service_locator.dart';

/// Application-wide initialization executed before [runApp].
abstract final class NoctrosBootstrap {
  static Future<void> initialize({
    required StorageConfigurator configureStorage,
    required DatabasePathResolver resolveDatabasePath,
    required SecureKvStoreFactory createSecureStore,
  }) async {
    configureStorage();
    await OptionalEnvLoader.load();
    await ServiceLocator.registerCoreServices(
      resolveDatabasePath: resolveDatabasePath,
      createSecureStore: createSecureStore,
    );
    await ServiceLocator.get<SecureStorageService>().warmUp();
    final database = ServiceLocator.get<NoctrosDatabase>();
    await database.open();
    await CommunicationSeed.ensureSeeded(database);
    await ServiceLocator.get<AgentMesh>().start();
  }
}
