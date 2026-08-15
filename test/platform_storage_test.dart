import 'package:flutter_test/flutter_test.dart';
import 'package:noctros/app/platform/platform_storage.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'PlatformStorage.initializeAndResolvePath returns a path under the app support dir',
    () async {
      PathProviderPlatform.instance = _StubPathProvider('/tmp/noctros-tests');

      final path = await PlatformStorage.initializeAndResolvePath(
        databaseName: 'noctros_test.db',
      );

      expect(path, startsWith('/tmp/noctros-tests'));
      expect(path.endsWith('noctros_test.db'), isTrue);
    },
  );
}

class _StubPathProvider extends PathProviderPlatform with MockPlatformInterfaceMixin {
  _StubPathProvider(this.supportPath);

  final String supportPath;

  @override
  Future<String?> getApplicationSupportPath() async => supportPath;

  @override
  Future<String?> getTemporaryPath() async => supportPath;

  @override
  Future<String?> getApplicationDocumentsPath() async => supportPath;

  @override
  Future<String?> getApplicationCachePath() async => supportPath;

  @override
  Future<String?> getLibraryPath() async => supportPath;
}
