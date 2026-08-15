import 'dart:io';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';

/// Registers VM test doubles so widget tests never hit missing plugins.
void installVmPluginFakes() {
  FlutterSecureStorage.setMockInitialValues({});
  PathProviderPlatform.instance = _FakePathProvider(
    Directory.systemTemp.path,
  );
}

class _FakePathProvider extends PathProviderPlatform {
  _FakePathProvider(this.supportPath);

  final String supportPath;

  @override
  Future<String?> getApplicationSupportPath() async => supportPath;
}
