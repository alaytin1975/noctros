import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../features/chat/chat_history_screen.dart';
import '../features/chat/chat_screen.dart';
import '../features/emergency/emergency_screen.dart';
import '../features/home/home_screen.dart';
import '../features/settings/settings_screen.dart';
import 'glass_panel.dart';

class MainShell extends StatelessWidget {
  const MainShell({
    super.key,
    required this.navigationShell,
  });

  final StatefulNavigationShell navigationShell;

  static const int homeIndex = 0;
  static const int chatIndex = 1;
  static const int historyIndex = 2;
  static const int settingsIndex = 3;

  void _onDestinationSelected(int index) {
    navigationShell.goBranch(
      index,
      initialLocation: index == navigationShell.currentIndex,
    );
  }

  @override
  Widget build(BuildContext context) {
    return PremiumBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: navigationShell,
        bottomNavigationBar: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(28),
            child: NavigationBar(
              selectedIndex: navigationShell.currentIndex,
              onDestinationSelected: _onDestinationSelected,
              destinations: const [
                NavigationDestination(
                  icon: Icon(Icons.home_outlined),
                  selectedIcon: Icon(Icons.home_rounded),
                  label: 'Home',
                ),
                NavigationDestination(
                  icon: Icon(Icons.chat_bubble_outline_rounded),
                  selectedIcon: Icon(Icons.chat_bubble_rounded),
                  label: 'Chat',
                ),
                NavigationDestination(
                  icon: Icon(Icons.history_rounded),
                  selectedIcon: Icon(Icons.history_edu_rounded),
                  label: 'History',
                ),
                NavigationDestination(
                  icon: Icon(Icons.settings_outlined),
                  selectedIcon: Icon(Icons.settings_rounded),
                  label: 'Settings',
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  static void goToChat(BuildContext context) {
    final shell = StatefulNavigationShell.maybeOf(context);
    if (shell != null) {
      shell.goBranch(chatIndex);
      return;
    }
    context.go(ChatScreen.routePath);
  }

  static void goToHome(BuildContext context) {
    final shell = StatefulNavigationShell.maybeOf(context);
    if (shell != null) {
      shell.goBranch(homeIndex);
      return;
    }
    context.go(HomeScreen.routePath);
  }

  static void goToHistory(BuildContext context) {
    final shell = StatefulNavigationShell.maybeOf(context);
    if (shell != null) {
      shell.goBranch(historyIndex);
      return;
    }
    context.go(ChatHistoryScreen.routePath);
  }

  static void goToEmergency(BuildContext context) {
    context.push(EmergencyScreen.routePath);
  }

  static void goToSettings(BuildContext context) {
    final shell = StatefulNavigationShell.maybeOf(context);
    if (shell != null) {
      shell.goBranch(settingsIndex);
      return;
    }
    context.go(SettingsScreen.routePath);
  }
}
