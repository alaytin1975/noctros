import '../../core/constants/noctros_constants.dart';
import '../../data/local/database/noctros_database.dart';
import '../../data/local/seed/communication_seed.dart';
import '../../data/local/secure/secure_storage_service.dart';
import '../../engines/agents/agent_mesh.dart';
import '../di/service_locator.dart';
import '../platform/platform_storage.dart';

/// Application-wide initialization executed before [runApp].
///
/// Order matters:
///   1. Configure the sqflite factory + resolve the on-disk DB path.
///   2. Register core services with the resolved path.
///   3. Warm up secure storage (encryption key).
///   4. Open the database and seed communication tables.
///   5. Start the Agent Mesh (Hive).
abstract final class NoctrosBootstrap {
  static Future<void> initialize({String? databasePathOverride}) async {
    final databasePath = databasePathOverride ??
        await PlatformStorage.initializeAndResolvePath(
          databaseName: NoctrosConstants.databaseName,
        );

    await ServiceLocator.registerCoreServices(databasePath: databasePath);
    await ServiceLocator.get<SecureStorageService>().warmUp();

    final database = ServiceLocator.get<NoctrosDatabase>();
    await database.open();
    await CommunicationSeed.ensureSeeded(database);

    await ServiceLocator.get<AgentMesh>().start();
  }
}
