import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../domain/entities/communication_entities.dart';
import '../../../domain/entities/noctros_enums.dart';
import '../../providers/communication_providers.dart';
import '../../widgets/atmosphere_scaffold.dart';
import '../../widgets/contact_avatar.dart';
import '../contacts/contact_detail_screen.dart';
import 'active_call_screen.dart';

class CallsScreen extends ConsumerStatefulWidget {
  const CallsScreen({super.key});

  static const routePath = '/calls';
  static const routeName = 'calls';

  @override
  ConsumerState<CallsScreen> createState() => _CallsScreenState();
}

class _CallsScreenState extends ConsumerState<CallsScreen> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() => ref.read(callsControllerProvider.notifier).load());
  }

  Future<void> _redial(String contactId) async {
    final call = await ref.read(callsControllerProvider.notifier).startCall(
          contactId: contactId,
        );
    if (call == null || !mounted) {
      return;
    }
    await context.push(
      ActiveCallScreen.routePath,
      extra: ActiveCallArgs(call: call, contactId: contactId),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(callsControllerProvider);
    final theme = Theme.of(context);

    return AtmosphereScaffold(
      appBar: AppBar(title: const Text('Calls')),
      child: SafeArea(
        child: state.isLoading
            ? const Center(child: CircularProgressIndicator())
            : state.calls.isEmpty
                ? Center(
                    child: Text(
                      'No recent calls',
                      style: theme.textTheme.titleMedium,
                    ),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.fromLTRB(12, 8, 12, 24),
                    itemCount: state.calls.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final call = state.calls[index];
                      final contact = state.contactsById[call.contactId];
                      final title = contact?.displayName ?? 'Unknown';
                      final subtitle = _subtitle(call);
                      final missed = call.wasMissed;

                      return ListTile(
                        leading: contact == null
                            ? const CircleAvatar(child: Icon(Icons.person))
                            : ContactAvatar(contact: contact, size: 46),
                        title: Text(
                          title,
                          style: theme.textTheme.titleMedium?.copyWith(
                            color: missed ? theme.colorScheme.error : null,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        subtitle: Text(subtitle),
                        trailing: IconButton(
                          onPressed: () => _redial(call.contactId),
                          icon: Icon(
                            call.kind == CallKind.video
                                ? Icons.videocam_rounded
                                : Icons.call_rounded,
                          ),
                        ),
                        onTap: () => context.push(
                          ContactDetailScreen.routePathFor(call.contactId),
                        ),
                      );
                    },
                  ),
      ),
    );
  }

  String _subtitle(CallRecord call) {
    final started = DateFormat.MMMd().add_jm().format(call.startedAt.toLocal());
    final direction = switch (call.direction) {
      CallDirection.outgoing => 'Outgoing',
      CallDirection.incoming => 'Incoming',
      CallDirection.missed => 'Missed',
    };
    if (call.durationSeconds > 0) {
      final minutes = call.durationSeconds ~/ 60;
      final seconds = call.durationSeconds % 60;
      return '$direction · ${minutes}m ${seconds}s · $started';
    }
    return '$direction · $started';
  }
}
