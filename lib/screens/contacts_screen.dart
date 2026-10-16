import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import '../providers/database_providers.dart';
import '../models/loan_model.dart';
import '../services/pdf_service.dart'; // REQUIRED for the PDF button
import 'edit_contact_screen.dart';

class ContactsScreen extends ConsumerWidget {
  const ContactsScreen({super.key});

  /// The Automatic Trust Algorithm
  double _calculateTrustScore(List<Loan> contactLoans) {
    final settledLoans = contactLoans.where((l) => l.isSettled).toList();
    if (settledLoans.isEmpty) return 5.0; 

    int onTime = 0;
    for (var loan in settledLoans) {
      if (loan.dueDate == null) {
        onTime++; 
      } else if (loan.settledDate != null && loan.settledDate!.isBefore(loan.dueDate!.add(const Duration(days: 1)))) {
        onTime++; 
      }
    }
    final ratio = onTime / settledLoans.length;
    return 1.0 + (ratio * 4.0); 
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final contactsAsync = ref.watch(contactsProvider);
    final loansAsync = ref.watch(loansProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Network & Auto-Ratings')),
      body: contactsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (contacts) {
          if (contacts.isEmpty) return const Center(child: Text('No contacts yet.'));

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: contacts.length,
            itemBuilder: (context, index) {
              final contact = contacts[index];

              final contactLoans = loansAsync.asData?.value.where((l) => l.contactId == contact.id).toList() ?? [];
              final trustScore = _calculateTrustScore(contactLoans);

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
                  subtitle: Row(
                    children: List.generate(5, (i) => Icon(
                      i < trustScore.round() ? Icons.star_rounded : Icons.star_border_rounded,
                      size: 16, color: Colors.amber,
                    )),
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // 1. Edit Profile Button
                      IconButton(
                        icon: const Icon(Icons.edit_outlined),
                        onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => EditContactScreen(contact: contact))),
                      ),
                      
                      // 2. RESTORED: PDF Export Button!
                      IconButton(
                        icon: const Icon(Icons.picture_as_pdf_outlined, color: Colors.teal),
                        tooltip: 'Export PDF Statement',
                        onPressed: () async {
                          final allLoans = await ref.read(loansProvider.future);
                          final cLoans = allLoans.where((l) => l.contactId == contact.id).toList();
                          
                          if (cLoans.isEmpty) {
                            if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No transaction history to export.')));
                            return;
                          }
                          await PdfService.generateAndShareStatement(contact, cLoans);
                        },
                      ),

                      // 3. SMS Nudge Button
                      if (contact.phoneNumber != null)
                        IconButton(
                          icon: const Icon(Icons.sms_outlined, color: Colors.green),
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
        onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const EditContactScreen())),
        icon: const Icon(Icons.person_add_alt_1_rounded),
        label: const Text('Add Contact'),
      ),
    );
  }
}