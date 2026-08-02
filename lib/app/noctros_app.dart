import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'router/app_router.dart';
import '../presentation/providers/voice_providers.dart';
import '../presentation/theme/noctros_theme.dart';
import '../presentation/widgets/noctros_lifecycle_coordinator.dart';

class NoctrosApp extends ConsumerWidget {
  const NoctrosApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(appRouterProvider);
    final themeMode = ref.watch(themeModeProvider);

    return MaterialApp.router(
      title: 'Noctros',
      debugShowCheckedModeBanner: false,
      theme: NoctrosTheme.light,
      darkTheme: NoctrosTheme.dark,
      themeMode: themeMode,
      routerConfig: router,
      builder: (context, child) => NoctrosLifecycleCoordinator(
        child: child ?? const SizedBox.shrink(),
      ),
    );
  }
}
