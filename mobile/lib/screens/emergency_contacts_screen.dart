import 'package:flutter/material.dart';

import '../models/emergency_contact.dart';
import '../services/emergency_contact_service.dart';

class EmergencyContactsScreen extends StatelessWidget {
  const EmergencyContactsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: StreamBuilder<List<EmergencyContact>>(
        stream: EmergencyContactService.instance.watchContacts(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(
              child: Text('Failed to load contacts: ${snapshot.error}'),
            );
          }
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final contacts = snapshot.data!;
          if (contacts.isEmpty) {
            return const Center(
              child: Text('No emergency contacts yet. Add trusted contacts.'),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: contacts.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (context, index) {
              final contact = contacts[index];
              return Card(
                child: ListTile(
                  leading: contact.isLinkedAppUser
                      ? const CircleAvatar(
                          child: Icon(Icons.verified_user_outlined),
                        )
                      : const CircleAvatar(
                          child: Icon(Icons.phone),
                        ),
                  title: Text(contact.name),
                  subtitle: Text(
                    '${contact.phone.isEmpty ? 'No phone' : contact.phone} - ${contact.relation}',
                  ),
                  trailing: PopupMenuButton<String>(
                    onSelected: (value) async {
                      if (value == 'edit') {
                        await _showContactDialog(
                          context,
                          existing: contact,
                        );
                        return;
                      }
                      final shouldDelete = await showDialog<bool>(
                            context: context,
                            builder: (context) => AlertDialog(
                              title: const Text('Delete contact?'),
                              content: Text(
                                'Remove ${contact.name} from emergency contacts?',
                              ),
                              actions: [
                                TextButton(
                                  onPressed: () =>
                                      Navigator.pop(context, false),
                                  child: const Text('Cancel'),
                                ),
                                FilledButton(
                                  onPressed: () => Navigator.pop(context, true),
                                  child: const Text('Delete'),
                                ),
                              ],
                            ),
                          ) ??
                          false;

                      if (!shouldDelete) {
                        return;
                      }
                      await EmergencyContactService.instance
                          .deleteContact(contact.id);
                    },
                    itemBuilder: (context) => const [
                      PopupMenuItem(value: 'edit', child: Text('Edit')),
                      PopupMenuItem(value: 'delete', child: Text('Delete')),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showContactDialog(context),
        icon: const Icon(Icons.person_add_alt_1),
        label: const Text('Add Contact'),
      ),
    );
  }

  Future<void> _showContactDialog(
    BuildContext context, {
    EmergencyContact? existing,
  }) async {
    final nameController = TextEditingController(text: existing?.name ?? '');
    final phoneController = TextEditingController(text: existing?.phone ?? '');
    final appEmailController =
        TextEditingController(text: existing?.contactEmail ?? '');
    final relationController =
        TextEditingController(text: existing?.relation ?? '');
    final formKey = GlobalKey<FormState>();
    var linkToAppUser = existing?.isLinkedAppUser ?? false;

    final save = await showDialog<bool>(
          context: context,
          builder: (context) => StatefulBuilder(
            builder: (context, setDialogState) => AlertDialog(
              title: Text(
                existing == null ? 'Add Emergency Contact' : 'Edit Contact',
              ),
              content: Form(
                key: formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      value: linkToAppUser,
                      title: const Text('Link app user'),
                      subtitle: const Text(
                        'Use an existing Suraksha Setu account as this contact.',
                      ),
                      onChanged: (value) {
                        setDialogState(() => linkToAppUser = value);
                      },
                    ),
                    if (linkToAppUser)
                      TextFormField(
                        controller: appEmailController,
                        decoration:
                            const InputDecoration(labelText: 'App user email'),
                        keyboardType: TextInputType.emailAddress,
                        validator: (value) {
                          if (!linkToAppUser) {
                            return null;
                          }
                          return (value == null || value.trim().isEmpty)
                              ? 'Email is required for app user contact'
                              : null;
                        },
                      ),
                    TextFormField(
                      controller: nameController,
                      decoration: InputDecoration(
                        labelText: linkToAppUser
                            ? 'Contact name (optional override)'
                            : 'Name',
                      ),
                      validator: (value) {
                        if (linkToAppUser) {
                          return null;
                        }
                        return (value == null || value.trim().isEmpty)
                            ? 'Name is required'
                            : null;
                      },
                    ),
                    TextFormField(
                      controller: phoneController,
                      decoration: InputDecoration(
                        labelText: linkToAppUser
                            ? 'Phone (optional fallback)'
                            : 'Phone',
                      ),
                      keyboardType: TextInputType.phone,
                      validator: (value) {
                        if (linkToAppUser) {
                          return null;
                        }
                        return (value == null || value.trim().isEmpty)
                            ? 'Phone is required'
                            : null;
                      },
                    ),
                    TextFormField(
                      controller: relationController,
                      decoration: const InputDecoration(labelText: 'Relation'),
                      validator: (value) =>
                          (value == null || value.trim().isEmpty)
                              ? 'Relation is required'
                              : null,
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: () {
                    if (!(formKey.currentState?.validate() ?? false)) {
                      return;
                    }
                    Navigator.pop(context, true);
                  },
                  child: const Text('Save'),
                ),
              ],
            ),
          ),
        ) ??
        false;

    if (!save) {
      return;
    }

    try {
      if (linkToAppUser) {
        final profile = await EmergencyContactService.instance.findAppUserByEmail(
          appEmailController.text,
        );
        final resolvedName =
            nameController.text.trim().isEmpty ? profile.name : nameController.text;
        final resolvedPhone = profile.phone.trim().isNotEmpty
            ? profile.phone
            : phoneController.text.trim();
        if (resolvedPhone.isEmpty) {
          throw StateError(
            'Linked user has no phone in profile. Add a fallback phone.',
          );
        }

        if (existing == null) {
          await EmergencyContactService.instance.addContact(
            name: resolvedName,
            phone: resolvedPhone,
            relation: relationController.text,
            contactUserId: profile.userId,
            contactEmail: profile.email,
          );
        } else {
          await EmergencyContactService.instance.updateContact(
            contactId: existing.id,
            name: resolvedName,
            phone: resolvedPhone,
            relation: relationController.text,
            contactUserId: profile.userId,
            contactEmail: profile.email,
          );
        }
      } else if (existing == null) {
        await EmergencyContactService.instance.addContact(
          name: nameController.text,
          phone: phoneController.text,
          relation: relationController.text,
        );
      } else {
        await EmergencyContactService.instance.updateContact(
          contactId: existing.id,
          name: nameController.text,
          phone: phoneController.text,
          relation: relationController.text,
          contactUserId: null,
          contactEmail: null,
        );
      }
    } catch (e) {
      if (!context.mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to save contact: $e')),
      );
      return;
    }

    if (!context.mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(existing == null ? 'Contact added.' : 'Contact updated.'),
      ),
    );
  }
}
