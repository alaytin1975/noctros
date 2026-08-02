import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app/bootstrap/noctros_bootstrap.dart';
import 'app/noctros_app.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await NoctrosBootstrap.initialize();

  runApp(
    const ProviderScope(
      child: NoctrosApp(),
    ),
  );
}
