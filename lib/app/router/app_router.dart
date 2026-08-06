import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../presentation/features/chat/chat_history_screen.dart';
import '../../presentation/features/chat/chat_screen.dart';
import '../../presentation/features/emergency/emergency_screen.dart';
import '../../presentation/features/home/home_screen.dart';
import '../../presentation/features/settings/settings_screen.dart';
import '../../presentation/features/settings/voice_settings_screen.dart';
import '../../presentation/widgets/glass_panel.dart';

final _rootNavigatorKey = GlobalKey<NavigatorState>(debugLabel: 'root');

final appRouterProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    navigatorKey: _rootNavigatorKey,
    initialLocation: HomeScreen.routePath,
    routes: [
      ShellRoute(
        builder: (context, state, child) {
          return PremiumBackground(
            child: Scaffold(
              backgroundColor: Colors.transparent,
              body: child,
            ),
          );
        },
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
            path: ChatHistoryScreen.routePath,
            name: ChatHistoryScreen.routeName,
            builder: (context, state) => const ChatHistoryScreen(),
          ),
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
          GoRoute(
            path: EmergencyScreen.routePath,
            name: EmergencyScreen.routeName,
            builder: (context, state) => const EmergencyScreen(),
          ),
        ],
      ),
    ],
  );
});
