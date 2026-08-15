import '../../core/platform/storage_factory.dart';
import '../../data/local/database/noctros_database.dart';
import '../../data/local/seed/communication_seed.dart';
import '../../data/local/secure/secure_storage_service.dart';
import '../../engines/agents/agent_mesh.dart';
import '../di/service_locator.dart';

/// Application-wide initialization executed before [runApp].
abstract final class NoctrosBootstrap {
  static Future<void> initialize() async {
    configureStorageFactory();
    await ServiceLocator.registerCoreServices();
    await ServiceLocator.get<SecureStorageService>().warmUp();
    final database = ServiceLocator.get<NoctrosDatabase>();
    await database.open();
    await CommunicationSeed.ensureSeeded(database);
    await ServiceLocator.get<AgentMesh>().start();
  }
}
