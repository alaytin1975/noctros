import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';

import '../../../app/di/service_locator.dart';
import '../../../domain/entities/communication_entities.dart';
import '../../../domain/repositories/communication_repository.dart';
import '../../providers/communication_providers.dart';
import '../../widgets/atmosphere_scaffold.dart';
import '../../widgets/contact_avatar.dart';
import 'thread_screen.dart';

class ComposeMessageScreen extends ConsumerStatefulWidget {
  const ComposeMessageScreen({super.key});

  static const routePath = '/messages/compose';
  static const routeName = 'compose';

  @override
  ConsumerState<ComposeMessageScreen> createState() =>
      _ComposeMessageScreenState();
}

class _ComposeMessageScreenState extends ConsumerState<ComposeMessageScreen> {
  final _messageController = TextEditingController();
  Contact? _selected;
  bool _isCreating = false;

  @override
  void initState() {
    super.initState();
    Future.microtask(
      () => ref.read(contactsControllerProvider.notifier).load(),
    );
  }

  @override
  void dispose() {
    _messageController.dispose();
    super.dispose();
  }

  Future<void> _startConversation() async {
    final contact = _selected;
    final body = _messageController.text.trim();
    if (contact == null || body.isEmpty || _isCreating) {
      return;
    }

    setState(() => _isCreating = true);
    final repository = ServiceLocator.get<CommunicationRepository>();
    final inbox = ref.read(inboxControllerProvider).threads;
    final existing = inbox.where(
      (item) =>
          item.thread.participantIds.length == 1 &&
          item.thread.participantIds.first == contact.id,
    );

    String threadId;
    if (existing.isNotEmpty) {
      threadId = existing.first.thread.id;
    } else {
      final created = await repository.createThread(
        title: contact.displayName,
        participantIds: [contact.id],
      );
      if (created.isFailure) {
        setState(() => _isCreating = false);
        return;
      }
      threadId = created.valueOrThrow.id;
    }

    final sent = await repository.sendThreadMessage(
      threadId: threadId,
      body: body,
    );
    setState(() => _isCreating = false);
    if (sent.isFailure || !mounted) {
      return;
    }

    await ref.read(inboxControllerProvider.notifier).load();
    if (!mounted) {
      return;
    }
    context.replace(ThreadScreen.routePathFor(threadId));
  }

  Future<void> _createContactAndMessage() async {
    final nameController = TextEditingController();
    final phoneController = TextEditingController();
    final created = await showDialog<Contact>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('New contact'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: const InputDecoration(hintText: 'Name'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: phoneController,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(hintText: 'Phone'),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                final name = nameController.text.trim();
                final phone = phoneController.text.trim();
                if (name.isEmpty || phone.isEmpty) {
                  return;
                }
                Navigator.pop(
                  context,
                  Contact(
                    id: const Uuid().v4(),
                    displayName: name,
                    phoneNumber: phone,
                    avatarColor: 0xFF1F6B5A,
                  ),
                );
              },
              child: const Text('Save'),
            ),
          ],
        );
      },
    );

    nameController.dispose();
    phoneController.dispose();

    if (created == null) {
      return;
    }
    final saved =
        await ref.read(contactsControllerProvider.notifier).save(created);
    if (saved && mounted) {
      setState(() => _selected = created);
    }
  }

  @override
  Widget build(BuildContext context) {
    final contactsState = ref.watch(contactsControllerProvider);
    final theme = Theme.of(context);

    return AtmosphereScaffold(
      appBar: AppBar(
        title: const Text('New Message'),
        actions: [
          TextButton(
            onPressed: _isCreating ? null : _startConversation,
            child: _isCreating
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Send'),
          ),
        ],
      ),
      child: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
              child: Row(
                children: [
                  Text('To:', style: theme.textTheme.titleMedium),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      _selected?.displayName ?? 'Choose a contact',
                      style: theme.textTheme.bodyLarge?.copyWith(
                        color: _selected == null
                            ? theme.colorScheme.onSurfaceVariant
                            : theme.colorScheme.onSurface,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: _createContactAndMessage,
                    icon: const Icon(Icons.person_add_alt_1_rounded),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: contactsState.isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : ListView.builder(
                      itemCount: contactsState.contacts.length,
                      itemBuilder: (context, index) {
                        final contact = contactsState.contacts[index];
                        final selected = _selected?.id == contact.id;
                        return ListTile(
                          leading: ContactAvatar(contact: contact, size: 42),
                          title: Text(contact.displayName),
                          subtitle: Text(contact.phoneNumber),
                          trailing: selected
                              ? Icon(
                                  Icons.check_circle_rounded,
                                  color: theme.colorScheme.primary,
                                )
                              : null,
                          onTap: () => setState(() => _selected = contact),
                        );
                      },
                    ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              child: TextField(
                controller: _messageController,
                minLines: 2,
                maxLines: 5,
                decoration: const InputDecoration(
                  hintText: 'Write your first message…',
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
