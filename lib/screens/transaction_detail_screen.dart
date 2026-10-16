import 'dart:io';
import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../models/loan_model.dart';
import '../providers/notification_provider.dart';
import '../providers/loan_controller.dart';

class TransactionDetailScreen extends ConsumerStatefulWidget {
  final Loan loan;
  final String contactName;

  const TransactionDetailScreen({super.key, required this.loan, required this.contactName});

  @override
  ConsumerState<TransactionDetailScreen> createState() => _TransactionDetailScreenState();
}

class _TransactionDetailScreenState extends ConsumerState<TransactionDetailScreen> {
  final AudioPlayer _audioPlayer = AudioPlayer();
  bool _isPlaying = false;
  bool _isProcessingPayment = false;

  @override
  void initState() {
    super.initState();
    _audioPlayer.onPlayerComplete.listen((_) {
      if (mounted) setState(() => _isPlaying = false);
    });
  }

  @override
  void dispose() {
    _audioPlayer.dispose();
    super.dispose();
  }

  Future<void> _toggleAudio() async {
    if (widget.loan.voiceNoteUrl == null) return;
    if (_isPlaying) {
      await _audioPlayer.pause();
      setState(() => _isPlaying = false);
    } else {
      await _audioPlayer.play(DeviceFileSource(widget.loan.voiceNoteUrl!));
      setState(() => _isPlaying = true);
    }
  }

  Future<void> _pickReminderDate() async {
    final selectedDate = await showDatePicker(
      context: context, 
      initialDate: widget.loan.dueDate ?? DateTime.now().add(const Duration(days: 1)),
      firstDate: DateTime.now(), 
      lastDate: DateTime.now().add(const Duration(days: 3650)),
    );
    if (selectedDate == null || !mounted) return;

    final selectedTime = await showTimePicker(
      context: context, 
      initialTime: widget.loan.dueDate != null 
          ? TimeOfDay.fromDateTime(widget.loan.dueDate!) 
          : const TimeOfDay(hour: 9, minute: 0)
    );
    if (selectedTime == null || !mounted) return;

    final finalDateTime = DateTime(selectedDate.year, selectedDate.month, selectedDate.day, selectedTime.hour, selectedTime.minute);

    await ref.read(loanControllerProvider).setDueDate(widget.loan.id, finalDateTime);
    
    // FIXED: Now passes the loanId so the alarm can be found and deleted later!
    ref.read(notificationProvider).scheduleReminder(
      'Safi Ledger Due!',
      'Time to settle the remaining ${widget.loan.remainingAmount} ETB with ${widget.contactName}.',
      scheduledDate: finalDateTime,
      loanId: widget.loan.id,
    );
    
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Alarm set for ${DateFormat('MMM d @ h:mm a').format(finalDateTime)}'), behavior: SnackBarBehavior.floating)
      );
      Navigator.pop(context); 
    }
  }

  Future<void> _showPaymentDialog() async {
    final controller = TextEditingController();
    final amount = await showDialog<double>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Log Partial Payment'),
        content: TextField(
          controller: controller,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: InputDecoration(
            labelText: 'Amount Paid (ETB)',
            helperText: 'Remaining: ${widget.loan.remainingAmount} ETB',
            prefixIcon: const Icon(Icons.attach_money),
            border: const OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, null), child: const Text('Cancel')),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, double.tryParse(controller.text)),
            child: const Text('Confirm'),
          ),
        ],
      ),
    );

    if (amount != null && amount > 0 && mounted) {
      if (amount > widget.loan.remainingAmount) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Payment cannot exceed the remaining balance!')));
        return;
      }

      setState(() => _isProcessingPayment = true);
      try {
        await ref.read(loanControllerProvider).logPartialPayment(widget.loan, amount);
        if (mounted) Navigator.pop(context); 
      } catch (e) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
        setState(() => _isProcessingPayment = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final hasPhoto = widget.loan.receiptPhotoUrl != null;
    final hasAudio = widget.loan.voiceNoteUrl != null;
    final isLent = widget.loan.type == LoanType.lent;
    
    double progress = widget.loan.amount > 0 ? (widget.loan.paidAmount / widget.loan.amount) : 0.0;
    if (progress > 1.0) progress = 1.0;

    return Scaffold(
      appBar: AppBar(title: const Text('Ledger Details')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text(widget.contactName, style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold, decoration: widget.loan.isSettled ? TextDecoration.lineThrough : null)),
          
          // FIXED: Math format prevents "+0" or "-0" glitches
          Text(
            'Remaining: ${widget.loan.remainingAmount > 0 ? (isLent ? '+' : '-') : ''}${widget.loan.remainingAmount.abs().toStringAsFixed(0)} ETB', 
            style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: widget.loan.isSettled ? Colors.grey : (isLent ? Colors.green : Colors.red)),
          ),
          
          if (widget.loan.reason != null && widget.loan.reason!.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 8.0),
              child: Text('Reason: ${widget.loan.reason}', style: const TextStyle(fontSize: 18, color: Colors.grey)),
            ),
          
          const SizedBox(height: 12),
          LinearProgressIndicator(value: progress, minHeight: 8, borderRadius: BorderRadius.circular(4), color: Colors.teal),
          const SizedBox(height: 8),
          Text('Paid: ${widget.loan.paidAmount} / ${widget.loan.amount} ETB', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.grey)),

          // FIXED: Hide alarm box if the record is fully settled
          if (widget.loan.dueDate != null && !widget.loan.isSettled)
            Container(
              margin: const EdgeInsets.only(top: 16),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.orange.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.orange.withValues(alpha: 0.3)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.alarm_on, color: Colors.orange),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Due Date / Alarm Active', style: TextStyle(fontSize: 12, color: Colors.orange, fontWeight: FontWeight.bold)),
                        Text(DateFormat('MMM d, yyyy @ h:mm a').format(widget.loan.dueDate!), style: const TextStyle(fontWeight: FontWeight.w600)),
                      ],
                    ),
                  ),
                ],
              ),
            ),

          if (widget.loan.isSettled) 
             const Padding(padding: EdgeInsets.only(top: 16.0), child: Text('✅ This ledger has been settled in full.', style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold))),

          const SizedBox(height: 32),

          if (hasAudio) ...[
            const Text('Audio Evidence', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 12),
            Container(
              decoration: BoxDecoration(color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.4), borderRadius: BorderRadius.circular(16)),
              child: ListTile(
                leading: CircleAvatar(backgroundColor: _isPlaying ? Colors.redAccent : Colors.green, child: IconButton(icon: Icon(_isPlaying ? Icons.pause : Icons.play_arrow, color: Colors.white), onPressed: _toggleAudio)),
                title: Text(_isPlaying ? 'Playing Recording...' : 'Play Call File', style: const TextStyle(fontWeight: FontWeight.w600)),
              ),
            ),
            const SizedBox(height: 32),
          ],

          if (hasPhoto) ...[
            const Text('Document / Photo', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 12),
            ClipRRect(borderRadius: BorderRadius.circular(16), child: Image.file(File(widget.loan.receiptPhotoUrl!), fit: BoxFit.cover)),
            const SizedBox(height: 32),
          ],
          
          if (!widget.loan.isSettled) ...[
            FilledButton.icon(
              style: FilledButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16), backgroundColor: Colors.teal),
              onPressed: _isProcessingPayment ? null : _showPaymentDialog,
              icon: _isProcessingPayment ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white)) : const Icon(Icons.payments_outlined),
              label: const Text('Log Partial Payment', style: TextStyle(fontSize: 16)),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16)),
              onPressed: _pickReminderDate,
              icon: const Icon(Icons.edit_calendar_rounded),
              label: Text(widget.loan.dueDate != null ? 'Edit Due Date / Alarm' : 'Set Due Date / Alarm', style: const TextStyle(fontSize: 16)),
            ),
          ]
        ],
      ),
    );
  }
}