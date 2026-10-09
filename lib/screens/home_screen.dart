import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart'; // To format the dates beautifully
import '../models/loan_model.dart';
import '../providers/dashboard_provider.dart';
import '../providers/theme_provider.dart';
import '../providers/database_providers.dart'; // Added to access the real-time streams
import '../widgets/new_log_sheet.dart';
import '../providers/loan_controller.dart';
import 'contacts_screen.dart';
import 'transaction_detail_screen.dart';
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final metrics = ref.watch(dashboardMetricsProvider);
    final moneyOut = metrics['net_positive'] ?? 0.0;
    final moneyOwe = metrics['net_negative'] ?? 0.0;
    
    final isDarkMode = ref.watch(themeProvider) == ThemeMode.dark;
    
    // Watch the real-time stream of loans
    final loansAsync = ref.watch(loansProvider);

    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      appBar: AppBar(
        title: const Text('Safi', style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1.2)),
        centerTitle: false,
        actions: [
          IconButton(
            icon: Icon(isDarkMode ? Icons.light_mode_rounded : Icons.dark_mode_rounded),
            tooltip: 'Toggle Theme',
            onPressed: () => ref.read(themeProvider.notifier).toggleTheme(),
          ),
         IconButton(
            icon: const Icon(Icons.people_alt_outlined),
            tooltip: 'Contacts',
            onPressed: () {
              Navigator.push(context, MaterialPageRoute(builder: (_) => const ContactsScreen()));
            },
          ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Your Ledger', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              
              Row(
                children: [
                  Expanded(
                    child: _buildSummaryCard(
                      context: context,
                      title: 'Money Out There',
                      amount: moneyOut,
                      color: Colors.green, 
                      icon: Icons.arrow_upward_rounded,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildSummaryCard(
                      context: context,
                      title: 'Money I Owe',
                      amount: moneyOwe,
                      color: Colors.redAccent,
                      icon: Icons.arrow_downward_rounded,
                    ),
                  ),
                ],
              ),
              
              const SizedBox(height: 32),
              
              const Text('Recent Activity', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              
              // --- The Real-Time List View ---
              Expanded(
                child: loansAsync.when(
                  loading: () => const Center(child: CircularProgressIndicator()),
                  error: (err, stack) => Center(child: Text('Error: $err')),
                  data: (loans) {
                    if (loans.isEmpty) {
                      return _buildEmptyState(context);
                    }
                    
                    return ListView.builder(
                      itemCount: loans.length,
                      itemBuilder: (context, index) {
                        final loan = loans[index];
                        return _buildTransactionTile(context, ref, loan);
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
      
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          showModalBottomSheet(
            context: context,
            isScrollControlled: true,
            shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
            builder: (context) => const NewLogSheet(),
          );
        },
        icon: const Icon(Icons.add),
        label: const Text('New Log'),
      ),
    );
  }

  // --- UI Components ---

  Widget _buildSummaryCard({required BuildContext context, required String title, required double amount, required Color color, required IconData icon}) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: isDark ? 0.2 : 0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: isDark ? 0.4 : 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 20),
              const SizedBox(width: 6),
              Expanded(child: Text(title, style: TextStyle(fontSize: 12, color: color, fontWeight: FontWeight.w600), maxLines: 1, overflow: TextOverflow.ellipsis)),
            ],
          ),
          const SizedBox(height: 12),
          Text('${amount.toStringAsFixed(0)} ETB', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold), maxLines: 1, overflow: TextOverflow.ellipsis),
        ],
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.check_circle_outline, size: 64, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.2)),
          const SizedBox(height: 16),
          Text('Your ledger is perfectly clear.', style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6), fontSize: 16)),
        ],
      ),
    );
  }

  // The sleek tile for each transaction
  Widget _buildTransactionTile(BuildContext context, WidgetRef ref, Loan loan) {
    final isLent = loan.type == LoanType.lent;
    
    // If settled, turn the tile grey so it visually looks "completed"
    final color = loan.isSettled ? Colors.grey : (isLent ? Colors.green : Colors.redAccent);
    final icon = loan.isSettled ? Icons.check_circle : (isLent ? Icons.arrow_upward_rounded : Icons.arrow_downward_rounded);
    
    final formattedDate = DateFormat('MMM d, yyyy').format(loan.timestamp);

    final contactsAsync = ref.watch(contactsProvider);
    final contactName = contactsAsync.maybeWhen(
      data: (contacts) {
        try {
          return contacts.firstWhere((c) => c.id == loan.contactId).name;
        } catch (e) {
          return 'Unknown Contact';
        }
      },
      orElse: () => 'Loading...',
    );

    return Dismissible(
      key: ValueKey(loan.id), // Unique key required for swiping
      direction: DismissDirection.horizontal,
      
      // Background when swiping Left-to-Right (Settle)
      background: Container(
        color: loan.isSettled ? Colors.orange : Colors.green,
        alignment: Alignment.centerLeft,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Icon(loan.isSettled ? Icons.undo : Icons.check, color: Colors.white),
      ),
      
      // Background when swiping Right-to-Left (Delete)
      secondaryBackground: Container(
        color: Colors.red,
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: const Icon(Icons.delete, color: Colors.white),
      ),
      
      // Intercept the swipe to perform logic
      confirmDismiss: (direction) async {
        if (direction == DismissDirection.startToEnd) {
          // User swiped to SETTLE. 
          // We trigger the database update, but return false so the tile doesn't vanish.
          // Riverpod's stream will instantly catch the change and redraw it as grey!
          await ref.read(loanControllerProvider).toggleSettled(loan.id, loan.isSettled);
          return false; 
        } else {
          // User swiped to DELETE. Show a modern confirmation dialog first.
          return await showDialog<bool>(
            context: context,
            builder: (ctx) => AlertDialog(
              title: const Text('Delete Log?'),
              content: const Text('This will permanently delete this transaction and its evidence files from your device.'),
              actions: [
                TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
                FilledButton(
                  style: FilledButton.styleFrom(backgroundColor: Colors.red),
                  onPressed: () => Navigator.pop(ctx, true), // Confirms the swipe
                  child: const Text('Delete'),
                ),
              ],
            ),
          );
        }
      },
      
      // If the delete was confirmed, actually execute the database deletion
      onDismissed: (direction) {
        if (direction == DismissDirection.endToStart) {
          ref.read(loanControllerProvider).deleteLog(loan.id, loan.receiptPhotoUrl, loan.voiceNoteUrl);
        }
      },
      
      child: Card(
        margin: const EdgeInsets.only(bottom: 12),
        elevation: 0,
        color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: loan.isSettled ? 0.1 : 0.3),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.1)),
        ),
        child: ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          leading: CircleAvatar(
            backgroundColor: color.withValues(alpha: 0.1),
            child: Icon(icon, color: color),
          ),
          title: Text(
            contactName, 
            style: TextStyle(
              fontWeight: FontWeight.bold,
              // Strikethrough the name if the debt is settled
              decoration: loan.isSettled ? TextDecoration.lineThrough : null, 
            ),
          ),
          subtitle: Row(
            children: [
              Text(formattedDate, style: const TextStyle(fontSize: 12)),
              if (loan.receiptPhotoUrl != null || loan.voiceNoteUrl != null) ...[
                const SizedBox(width: 8),
                const Icon(Icons.attachment, size: 14, color: Colors.grey),
              ]
            ],
          ),
          trailing: Text(
            '${isLent ? '+' : '-'}${loan.amount.toStringAsFixed(0)} ETB',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 16,
              color: color,
            ),
          ),
         onTap: () {
            Navigator.push(context, MaterialPageRoute(builder: (_) => TransactionDetailScreen(loan: loan, contactName: contactName)));
          },
        ),
      ),
    );
  }
}