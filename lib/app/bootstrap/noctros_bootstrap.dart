import '../../core/config/env_config.dart';
import '../../data/local/database/noctros_database.dart';
import '../../data/local/secure/secure_storage_service.dart';
import '../di/service_locator.dart';

/// Application-wide initialization executed before [runApp].
abstract final class NoctrosBootstrap {
  static Future<void> initialize() async {
    await EnvConfig.load();
    await ServiceLocator.registerCoreServices();
    await ServiceLocator.get<SecureStorageService>().warmUp();
    await ServiceLocator.get<NoctrosDatabase>().open();
  }
}
