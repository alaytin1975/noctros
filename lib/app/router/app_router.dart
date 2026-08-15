import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../presentation/features/calls/active_call_screen.dart';
import '../../presentation/features/calls/calls_screen.dart';
import '../../presentation/features/chat/chat_screen.dart';
import '../../presentation/features/contacts/contact_detail_screen.dart';
import '../../presentation/features/contacts/contacts_screen.dart';
import '../../presentation/features/emergency/emergency_screen.dart';
import '../../presentation/features/hive/hive_screen.dart';
import '../../presentation/features/home/home_screen.dart';
import '../../presentation/features/messages/compose_message_screen.dart';
import '../../presentation/features/messages/messages_inbox_screen.dart';
import '../../presentation/features/messages/thread_screen.dart';
import '../../presentation/features/settings/settings_screen.dart';
import '../../presentation/features/shell/app_shell.dart';

final _rootNavigatorKey = GlobalKey<NavigatorState>(debugLabel: 'root');

final appRouterProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    navigatorKey: _rootNavigatorKey,
    initialLocation: MessagesInboxScreen.routePath,
    routes: [
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) {
          return AppShell(navigationShell: navigationShell);
        },
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: MessagesInboxScreen.routePath,
                name: MessagesInboxScreen.routeName,
                builder: (context, state) => const MessagesInboxScreen(),
                routes: [
                  GoRoute(
                    path: 'compose',
                    name: ComposeMessageScreen.routeName,
                    parentNavigatorKey: _rootNavigatorKey,
                    builder: (context, state) => const ComposeMessageScreen(),
                  ),
                  GoRoute(
                    path: ':threadId',
                    name: ThreadScreen.routeName,
                    parentNavigatorKey: _rootNavigatorKey,
                    builder: (context, state) {
                      final threadId = state.pathParameters['threadId']!;
                      return ThreadScreen(threadId: threadId);
                    },
                  ),
                ],
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: CallsScreen.routePath,
                name: CallsScreen.routeName,
                builder: (context, state) => const CallsScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: ContactsScreen.routePath,
                name: ContactsScreen.routeName,
                builder: (context, state) => const ContactsScreen(),
                routes: [
                  GoRoute(
                    path: ':contactId',
                    name: ContactDetailScreen.routeName,
                    parentNavigatorKey: _rootNavigatorKey,
                    builder: (context, state) {
                      final contactId = state.pathParameters['contactId']!;
                      return ContactDetailScreen(contactId: contactId);
                    },
                  ),
                ],
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: HomeScreen.routePath,
                name: HomeScreen.routeName,
                builder: (context, state) => const HomeScreen(),
                routes: [
                  GoRoute(
                    path: 'chat',
                    name: ChatScreen.routeName,
                    parentNavigatorKey: _rootNavigatorKey,
                    builder: (context, state) => const ChatScreen(),
                  ),
                  GoRoute(
                    path: 'hive',
                    name: HiveScreen.routeName,
                    parentNavigatorKey: _rootNavigatorKey,
                    builder: (context, state) => const HiveScreen(),
                  ),
                  GoRoute(
                    path: 'emergency',
                    name: EmergencyScreen.routeName,
                    parentNavigatorKey: _rootNavigatorKey,
                    builder: (context, state) => const EmergencyScreen(),
                  ),
                ],
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: SettingsScreen.routePath,
                name: SettingsScreen.routeName,
                builder: (context, state) => const SettingsScreen(),
              ),
            ],
          ),
        ],
      ),
      GoRoute(
        path: ActiveCallScreen.routePath,
        name: ActiveCallScreen.routeName,
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) {
          final args = state.extra;
          if (args is! ActiveCallArgs) {
            return const Scaffold(
              body: Center(child: Text('Call unavailable')),
            );
          }
          return ActiveCallScreen(args: args);
        },
      ),
    ],
  );
});
