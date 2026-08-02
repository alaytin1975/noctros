import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'router/app_router.dart';
import '../presentation/theme/noctros_theme.dart';

class NoctrosApp extends ConsumerWidget {
  const NoctrosApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(appRouterProvider);

    return MaterialApp.router(
      title: 'Noctros',
      debugShowCheckedModeBanner: false,
      theme: NoctrosTheme.light,
      darkTheme: NoctrosTheme.dark,
      themeMode: ThemeMode.system,
      routerConfig: router,
    );
  }
}
