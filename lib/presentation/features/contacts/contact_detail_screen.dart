import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../app/di/service_locator.dart';
import '../../../domain/entities/noctros_enums.dart';
import '../../../domain/repositories/communication_repository.dart';
import '../../providers/communication_providers.dart';
import '../../widgets/atmosphere_scaffold.dart';
import '../../widgets/contact_avatar.dart';
import '../calls/active_call_screen.dart';
import '../messages/thread_screen.dart';

class ContactDetailScreen extends ConsumerStatefulWidget {
  const ContactDetailScreen({super.key, required this.contactId});

  static const routeName = 'contactDetail';
  static String routePathFor(String contactId) => '/contacts/$contactId';

  final String contactId;

  @override
  ConsumerState<ContactDetailScreen> createState() =>
      _ContactDetailScreenState();
}

class _ContactDetailScreenState extends ConsumerState<ContactDetailScreen> {
  @override
  void initState() {
    super.initState();
    Future.microtask(
      () => ref.read(contactsControllerProvider.notifier).load(),
    );
  }

  Future<void> _message() async {
    final repository = ServiceLocator.get<CommunicationRepository>();
    final contacts = ref.read(contactsControllerProvider).contacts;
    final contact = contacts.where((item) => item.id == widget.contactId);
    if (contact.isEmpty) {
      return;
    }
    final selected = contact.first;
    final inbox = ref.read(inboxControllerProvider).threads;
    final existing = inbox.where(
      (item) =>
          item.thread.participantIds.length == 1 &&
          item.thread.participantIds.first == selected.id,
    );
    if (existing.isNotEmpty) {
      await context.push(ThreadScreen.routePathFor(existing.first.thread.id));
      return;
    }
    final created = await repository.createThread(
      title: selected.displayName,
      participantIds: [selected.id],
    );
    if (created.isFailure || !mounted) {
      return;
    }
    await ref.read(inboxControllerProvider.notifier).load();
    if (!mounted) {
      return;
    }
    await context.push(ThreadScreen.routePathFor(created.valueOrThrow.id));
  }

  Future<void> _call(CallKind kind) async {
    final call = await ref.read(callsControllerProvider.notifier).startCall(
          contactId: widget.contactId,
          kind: kind,
        );
    if (call == null || !mounted) {
      return;
    }
    await context.push(
      ActiveCallScreen.routePath,
      extra: ActiveCallArgs(call: call, contactId: widget.contactId),
    );
  }

  Future<void> _openPhone(String phoneNumber) async {
    final uri = Uri(scheme: 'tel', path: phoneNumber.replaceAll(' ', ''));
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  @override
  Widget build(BuildContext context) {
    final contacts = ref.watch(contactsControllerProvider).contacts;
    final match = contacts.where((item) => item.id == widget.contactId);
    if (match.isEmpty) {
      return const AtmosphereScaffold(
        child: Center(child: CircularProgressIndicator()),
      );
    }
    final contact = match.first;
    final theme = Theme.of(context);

    return AtmosphereScaffold(
      appBar: AppBar(title: Text(contact.displayName)),
      child: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
          children: [
            Center(child: ContactAvatar(contact: contact, size: 96)),
            const SizedBox(height: 16),
            Text(
              contact.displayName,
              textAlign: TextAlign.center,
              style: theme.textTheme.headlineMedium,
            ),
            const SizedBox(height: 6),
            Text(
              contact.phoneNumber,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyLarge?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _ActionChip(
                  icon: Icons.message_rounded,
                  label: 'Message',
                  onTap: _message,
                ),
                _ActionChip(
                  icon: Icons.call_rounded,
                  label: 'Call',
                  onTap: () => _call(CallKind.audio),
                ),
                _ActionChip(
                  icon: Icons.videocam_rounded,
                  label: 'Video',
                  onTap: () => _call(CallKind.video),
                ),
              ],
            ),
            const SizedBox(height: 28),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.phone_iphone_rounded),
              title: const Text('Phone'),
              subtitle: Text(contact.phoneNumber),
              onTap: () => _openPhone(contact.phoneNumber),
            ),
            if (contact.email != null)
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.mail_outline_rounded),
                title: const Text('Email'),
                subtitle: Text(contact.email!),
              ),
            if (contact.notes != null)
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.notes_rounded),
                title: const Text('Notes'),
                subtitle: Text(contact.notes!),
              ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Favorite'),
              value: contact.isFavorite,
              onChanged: (value) {
                ref.read(contactsControllerProvider.notifier).save(
                      contact.copyWith(isFavorite: value),
                    );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _ActionChip extends StatelessWidget {
  const _ActionChip({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: onTap,
      child: Ink(
        width: 96,
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: theme.colorScheme.primary.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          children: [
            Icon(icon, color: theme.colorScheme.primary),
            const SizedBox(height: 6),
            Text(
              label,
              style: theme.textTheme.labelLarge?.copyWith(
                color: theme.colorScheme.primary,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
