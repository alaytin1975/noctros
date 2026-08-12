import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';

import '../../../domain/entities/communication_entities.dart';
import '../../providers/communication_providers.dart';
import '../../widgets/atmosphere_scaffold.dart';
import '../../widgets/contact_avatar.dart';
import 'contact_detail_screen.dart';

class ContactsScreen extends ConsumerStatefulWidget {
  const ContactsScreen({super.key});

  static const routePath = '/contacts';
  static const routeName = 'contacts';

  @override
  ConsumerState<ContactsScreen> createState() => _ContactsScreenState();
}

class _ContactsScreenState extends ConsumerState<ContactsScreen> {
  final _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    Future.microtask(
      () => ref.read(contactsControllerProvider.notifier).load(),
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _addContact() async {
    final nameController = TextEditingController();
    final phoneController = TextEditingController();
    final emailController = TextEditingController();

    final contact = await showModalBottomSheet<Contact>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) {
        return Padding(
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 8,
            bottom: MediaQuery.viewInsetsOf(context).bottom + 20,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'New contact',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 16),
              TextField(
                controller: nameController,
                decoration: const InputDecoration(hintText: 'Full name'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: phoneController,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(hintText: 'Phone number'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: emailController,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(hintText: 'Email (optional)'),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
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
                        email: emailController.text.trim().isEmpty
                            ? null
                            : emailController.text.trim(),
                        avatarColor: 0xFF2F5D8C,
                      ),
                    );
                  },
                  child: const Text('Save contact'),
                ),
              ),
            ],
          ),
        );
      },
    );

    nameController.dispose();
    phoneController.dispose();
    emailController.dispose();

    if (contact != null) {
      await ref.read(contactsControllerProvider.notifier).save(contact);
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(contactsControllerProvider);
    final theme = Theme.of(context);
    final favorites =
        state.filtered.where((contact) => contact.isFavorite).toList();
    final others =
        state.filtered.where((contact) => !contact.isFavorite).toList();

    return AtmosphereScaffold(
      appBar: AppBar(
        title: const Text('Contacts'),
        actions: [
          IconButton(
            onPressed: _addContact,
            icon: const Icon(Icons.person_add_alt_1_rounded),
          ),
        ],
      ),
      child: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
              child: TextField(
                controller: _searchController,
                onChanged:
                    ref.read(contactsControllerProvider.notifier).setQuery,
                decoration: const InputDecoration(
                  hintText: 'Search contacts',
                  prefixIcon: Icon(Icons.search_rounded),
                ),
              ),
            ),
            Expanded(
              child: state.isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : ListView(
                      padding: const EdgeInsets.fromLTRB(12, 0, 12, 24),
                      children: [
                        if (favorites.isNotEmpty) ...[
                          Padding(
                            padding: const EdgeInsets.fromLTRB(8, 8, 8, 8),
                            child: Text(
                              'Favorites',
                              style: theme.textTheme.titleMedium,
                            ),
                          ),
                          ...favorites.map(
                            (contact) => _ContactTile(
                              contact: contact,
                              onTap: () => context.push(
                                ContactDetailScreen.routePathFor(contact.id),
                              ),
                            ),
                          ),
                        ],
                        Padding(
                          padding: const EdgeInsets.fromLTRB(8, 16, 8, 8),
                          child: Text(
                            'All contacts',
                            style: theme.textTheme.titleMedium,
                          ),
                        ),
                        ...others.map(
                          (contact) => _ContactTile(
                            contact: contact,
                            onTap: () => context.push(
                              ContactDetailScreen.routePathFor(contact.id),
                            ),
                          ),
                        ),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ContactTile extends StatelessWidget {
  const _ContactTile({required this.contact, required this.onTap});

  final Contact contact;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      onTap: onTap,
      leading: ContactAvatar(contact: contact, size: 46),
      title: Text(contact.displayName),
      subtitle: Text(contact.phoneNumber),
      trailing: const Icon(Icons.chevron_right_rounded),
    );
  }
}
