import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/contact_model.dart';
import '../models/loan_model.dart';
import '../providers/database_providers.dart';
import 'edit_contact_screen.dart';
import 'transaction_detail_screen.dart';

class ContactDetailScreen extends ConsumerWidget {
  final Contact contact;

  const ContactDetailScreen({super.key, required this.contact});

  // Automatically dials or draft emails safely!
  Future<void> _launchAction(String url, BuildContext context) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    } else {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Could not open dialer/email app.')));
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final loansAsync = ref.watch(loansProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Contact Profile'),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_outlined),
            tooltip: 'Edit Profile',
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => EditContactScreen(contact: contact))),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          // 1. Profile Header Badge
          Center(
            child: CircleAvatar(
              radius: 40,
              backgroundColor: Theme.of(context).colorScheme.primaryContainer,
              child: Text(contact.name.substring(0, min(2, contact.name.length)).toUpperCase(), 
                  style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.onPrimaryContainer)),
            ),
          ),
          const SizedBox(height: 16),
          Center(child: Text(contact.name, style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold))),
          if (contact.relationship != null)
            Center(
              child: Container(
                margin: const EdgeInsets.only(top: 4),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(color: Theme.of(context).colorScheme.surfaceContainerHighest, borderRadius: BorderRadius.circular(12)),
                child: Text(contact.relationship!, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.grey)),
              ),
            ),
          const SizedBox(height: 32),

          // 2. Info Cards with Action Support
          const Text('Details', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.teal)),
          const SizedBox(height: 8),
          
          if (contact.phoneNumber != null)
            ListTile(
              leading: const Icon(Icons.phone_outlined),
              title: Text(contact.phoneNumber!),
              subtitle: const Text('Phone Number'),
              trailing: const Icon(Icons.call, color: Colors.teal),
              onTap: () => _launchAction('tel:${contact.phoneNumber}', context),
            ),
          if (contact.email != null)
            ListTile(
              leading: const Icon(Icons.email_outlined),
              title: Text(contact.email!),
              subtitle: const Text('Email'),
              trailing: const Icon(Icons.email, color: Colors.teal),
              onTap: () => _launchAction('mailto:${contact.email}', context),
            ),
          if (contact.address != null)
            ListTile(
              leading: const Icon(Icons.location_on_outlined),
              title: Text(contact.address!),
              subtitle: const Text('Physical Address'),
              trailing: const Icon(Icons.map_outlined, color: Colors.teal),
              onTap: () => _launchAction('https://maps.google.com/?q=${Uri.encodeComponent(contact.address!)}', context),
            ),
          if (contact.notes != null)
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Notes', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey)),
                  const SizedBox(height: 4),
                  Text(contact.notes!, style: const TextStyle(fontSize: 15, height: 1.4)),
                ],
              ),
            ),

          const SizedBox(height: 32),
          const Text('Transaction Record with this Party', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.teal)),
          const SizedBox(height: 12),

          // 3. Transactions relating to this Contact
          loansAsync.when(
            loading: () => const Center(child: LinearProgressIndicator()),
            error: (e, _) => Text('Error loading history: $e'),
            data: (loans) {
              final contactLoans = loans.where((l) => l.contactId == contact.id).toList();

              if (contactLoans.isEmpty) {
                return const Padding(
                  padding: EdgeInsets.symmetric(vertical: 32),
                  child: Center(child: Text('No log records yet.', style: TextStyle(color: Colors.grey))),
                );
              }

              return ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: contactLoans.length,
                itemBuilder: (context, idx) {
                  final l = contactLoans[idx];
                  final isLent = l.type == LoanType.lent;
                  return Card(
                    margin: const EdgeInsets.only(bottom: 8),
                    child: ListTile(
                      title: Text(l.reason ?? 'No Reason Provided', style: TextStyle(decoration: l.isSettled ? TextDecoration.lineThrough : null)),
                      subtitle: Text(DateFormat('MMM d, yyyy').format(l.timestamp)),
                      trailing: Text(
                        '${l.isSettled ? '' : (isLent ? '+' : '-')}${l.remainingAmount.abs().toStringAsFixed(0)} ETB',
                        style: TextStyle(fontWeight: FontWeight.bold, color: l.isSettled ? Colors.grey : (isLent ? Colors.green : Colors.red)),
                      ),
                      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => TransactionDetailScreen(loan: l, contactName: contact.name))),
                    ),
                  );
                },
              );
            },
          )
        ],
      ),
    );
  }

  int min(int a, int b) => a < b ? a : b;
}