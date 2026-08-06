import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../features/chat/chat_history_screen.dart';
import '../features/chat/chat_screen.dart';
import '../features/emergency/emergency_screen.dart';
import '../features/home/home_screen.dart';
import '../features/settings/settings_screen.dart';

/// Navigation helpers for the voice-first shell (no bottom bar).
class MainShell {
  const MainShell._();

  static void goToChat(BuildContext context) {
    context.push(ChatScreen.routePath);
  }

  static void goToHome(BuildContext context) {
    context.go(HomeScreen.routePath);
  }

  static void goToHistory(BuildContext context) {
    context.push(ChatHistoryScreen.routePath);
  }

  static void goToEmergency(BuildContext context) {
    context.push(EmergencyScreen.routePath);
  }

  static void goToSettings(BuildContext context) {
    context.push(SettingsScreen.routePath);
  }
}
