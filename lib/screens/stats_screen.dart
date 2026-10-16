import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/database_providers.dart';
import '../models/loan_model.dart';
import '../services/pdf_service.dart';

class StatsScreen extends ConsumerWidget {
  const StatsScreen({super.key});

  Future<void> _exportReport(BuildContext context, WidgetRef ref) async {
    // Fetch the data
    final allLoans = await ref.read(loansProvider.future);
    final allContacts = await ref.read(contactsProvider.future);

    if (!context.mounted) return;

    // Ask user for All-Time vs Date Range
    final action = await showDialog<String>(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: const Text('Export Master Audit'),
        children: [
          SimpleDialogOption(
            onPressed: () => Navigator.pop(ctx, 'all'),
            child: const Row(children: [Icon(Icons.all_inclusive), SizedBox(width: 12), Text('All-Time Records')]),
          ),
          SimpleDialogOption(
            onPressed: () => Navigator.pop(ctx, 'range'),
            child: const Row(children: [Icon(Icons.date_range), SizedBox(width: 12), Text('Custom Date Range')]),
          ),
        ],
      ),
    );

    if (action == null) return;

    DateTimeRange? chosenRange;
    if (action == 'range' && context.mounted) {
      // Launch the Date Range Picker (e.g., Aug 1 - Sep 30)
      chosenRange = await showDateRangePicker(
        context: context,
        firstDate: DateTime(2020),
        lastDate: DateTime.now().add(const Duration(days: 365)),
        helpText: 'Select Date Range',
      );
      if (chosenRange == null) return; // User canceled
    }

    // Generate the filtered PDF!
    await PdfService.generateMasterReport(
      loans: allLoans,
      contacts: allContacts,
      dateRange: chosenRange,
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final loansAsync = ref.watch(loansProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('All-Time Statistics')),
      body: loansAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (loans) {
          double totalLent = 0;
          double totalBorrowed = 0;
          double totalCollected = 0;
          int totalActive = 0;
          int totalSettled = 0;

          for (var l in loans) {
            if (l.type == LoanType.lent) {
              totalLent += l.amount;
              totalCollected += l.isSettled ? l.amount : l.paidAmount;
            } else {
              totalBorrowed += l.amount;
            }
            if (l.isSettled) {
              totalSettled++;
            } else {
              totalActive++;
            }
          }

          final completionRate = loans.isEmpty ? 0.0 : (totalSettled / loans.length) * 100;

          return GridView.count(
            crossAxisCount: 2,
            padding: const EdgeInsets.all(16),
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: 1.2,
            children: [
              _buildStatCard(context, 'Total Lent', '${totalLent.toStringAsFixed(0)} ETB', Colors.teal, Icons.account_balance_wallet),
              _buildStatCard(context, 'Total Borrowed', '${totalBorrowed.toStringAsFixed(0)} ETB', Colors.orange, Icons.money_off),
              _buildStatCard(context, 'Total Collected', '${totalCollected.toStringAsFixed(0)} ETB', Colors.green, Icons.download_done_rounded),
              _buildStatCard(context, 'Pending Active', '$totalActive Records', Colors.blue, Icons.pending_actions),
              _buildStatCard(context, 'Settled In Full', '$totalSettled Records', Colors.purple, Icons.handshake),
              _buildStatCard(context, 'Completion Rate', '${completionRate.toStringAsFixed(1)}%', Colors.indigo, Icons.analytics),
            ],
          );
        },
      ),
      // NEW: Floating Action Button to trigger the Date Range PDF
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _exportReport(context, ref),
        icon: const Icon(Icons.picture_as_pdf_rounded),
        label: const Text('Export Report'),
        backgroundColor: Colors.teal,
        foregroundColor: Colors.white,
      ),
    );
  }

  Widget _buildStatCard(BuildContext context, String title, String value, Color color, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: color, size: 28),
          const Spacer(),
          Text(value, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          Text(title, style: TextStyle(fontSize: 12, color: color.withValues(alpha: 0.8), fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}