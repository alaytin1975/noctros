import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../presentation/features/chat/chat_screen.dart';
import '../../presentation/features/emergency/emergency_screen.dart';
import '../../presentation/features/home/home_screen.dart';
import '../../presentation/features/settings/settings_screen.dart';

final appRouterProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: HomeScreen.routePath,
    routes: [
      GoRoute(
        path: HomeScreen.routePath,
        name: HomeScreen.routeName,
        builder: (context, state) => const HomeScreen(),
      ),
      GoRoute(
        path: ChatScreen.routePath,
        name: ChatScreen.routeName,
        builder: (context, state) => const ChatScreen(),
      ),
      GoRoute(
        path: SettingsScreen.routePath,
        name: SettingsScreen.routeName,
        builder: (context, state) => const SettingsScreen(),
      ),
      GoRoute(
        path: EmergencyScreen.routePath,
        name: EmergencyScreen.routeName,
        builder: (context, state) => const EmergencyScreen(),
      ),
    ],
  );
});
