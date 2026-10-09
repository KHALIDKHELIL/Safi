import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import '../providers/database_providers.dart';
import 'edit_contact_screen.dart';

class ContactsScreen extends ConsumerWidget {
  const ContactsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final contactsAsync = ref.watch(contactsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Network & Profiles')),
      body: contactsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(child: Text('Error: $err')),
        data: (contacts) {
          if (contacts.isEmpty) return const Center(child: Text('No contacts yet.'));

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: contacts.length,
            itemBuilder: (context, index) {
              final contact = contacts[index];

              return Card(
                elevation: 0,
                color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.2),
                margin: const EdgeInsets.only(bottom: 12),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
                    child: Text(contact.name[0].toUpperCase(), style: TextStyle(color: Theme.of(context).colorScheme.primary, fontWeight: FontWeight.bold)),
                  ),
                  title: Text(contact.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                  
                  // Now showing the manually editable Trust Score!
                  subtitle: Row(
                    children: List.generate(5, (i) => Icon(
                      i < contact.trustScore ? Icons.star_rounded : Icons.star_border_rounded,
                      size: 16,
                      color: Colors.amber,
                    )),
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Opens the new Edit Screen
                      IconButton(
                        icon: const Icon(Icons.edit_outlined),
                        tooltip: 'Edit Profile',
                        onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => EditContactScreen(contact: contact))),
                      ),
                      // SMS button (Only shows if they have a phone number)
                      if (contact.phoneNumber != null)
                        IconButton(
                          icon: const Icon(Icons.sms_outlined, color: Colors.green),
                          tooltip: 'Send SMS Nudge',
                          onPressed: () async {
                            final uri = Uri.parse('sms:${contact.phoneNumber}?body=Hey ${contact.name}, just a polite reminder about our pending Safi ledger record!');
                            if (await canLaunchUrl(uri)) await launchUrl(uri);
                          },
                        ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),

      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          // Calling the screen with NO contact triggers "Create Mode"
          Navigator.push(context, MaterialPageRoute(builder: (_) => const EditContactScreen()));
        },
        icon: const Icon(Icons.person_add_alt_1_rounded),
        label: const Text('Add Contact'),
      ),
    );
  }
}