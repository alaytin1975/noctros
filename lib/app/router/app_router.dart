import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../presentation/features/chat/chat_history_screen.dart';
import '../../presentation/features/chat/chat_screen.dart';
import '../../presentation/features/emergency/emergency_screen.dart';
import '../../presentation/features/home/home_screen.dart';
import '../../presentation/features/settings/settings_screen.dart';
import '../../presentation/features/settings/voice_settings_screen.dart';
import '../../presentation/widgets/main_shell.dart';

final _rootNavigatorKey = GlobalKey<NavigatorState>(debugLabel: 'root');
final _shellNavigatorHomeKey =
    GlobalKey<NavigatorState>(debugLabel: 'shellHome');
final _shellNavigatorChatKey =
    GlobalKey<NavigatorState>(debugLabel: 'shellChat');
final _shellNavigatorHistoryKey =
    GlobalKey<NavigatorState>(debugLabel: 'shellHistory');
final _shellNavigatorSettingsKey =
    GlobalKey<NavigatorState>(debugLabel: 'shellSettings');

final appRouterProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    navigatorKey: _rootNavigatorKey,
    initialLocation: HomeScreen.routePath,
    routes: [
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) {
          return MainShell(navigationShell: navigationShell);
        },
        branches: [
          StatefulShellBranch(
            navigatorKey: _shellNavigatorHomeKey,
            routes: [
              GoRoute(
                path: HomeScreen.routePath,
                name: HomeScreen.routeName,
                builder: (context, state) => const HomeScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            navigatorKey: _shellNavigatorChatKey,
            routes: [
              GoRoute(
                path: ChatScreen.routePath,
                name: ChatScreen.routeName,
                builder: (context, state) => const ChatScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            navigatorKey: _shellNavigatorHistoryKey,
            routes: [
              GoRoute(
                path: ChatHistoryScreen.routePath,
                name: ChatHistoryScreen.routeName,
                builder: (context, state) => const ChatHistoryScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            navigatorKey: _shellNavigatorSettingsKey,
            routes: [
              GoRoute(
                path: SettingsScreen.routePath,
                name: SettingsScreen.routeName,
                builder: (context, state) => const SettingsScreen(),
                routes: [
                  GoRoute(
                    path: 'voice',
                    name: VoiceSettingsScreen.routeName,
                    builder: (context, state) => const VoiceSettingsScreen(),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
      GoRoute(
        parentNavigatorKey: _rootNavigatorKey,
        path: EmergencyScreen.routePath,
        name: EmergencyScreen.routeName,
        builder: (context, state) => const EmergencyScreen(),
      ),
    ],
  );
});
