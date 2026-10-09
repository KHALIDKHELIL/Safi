import 'dart:io';
import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../models/loan_model.dart';
import '../providers/notification_provider.dart';

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

  // The new custom Date & Time picker for reminders
  Future<void> _pickReminderDate() async {
    final selectedDate = await showDatePicker(
      context: context,
      initialDate: DateTime.now().add(const Duration(days: 1)),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 3650)),
    );

    if (selectedDate == null || !mounted) return;

    final selectedTime = await showTimePicker(
      context: context,
      initialTime: const TimeOfDay(hour: 9, minute: 0), // Defaults to 9 AM
    );

    if (selectedTime == null || !mounted) return;

    final finalDateTime = DateTime(
      selectedDate.year,
      selectedDate.month,
      selectedDate.day,
      selectedTime.hour,
      selectedTime.minute,
    );

    // Schedule the native OS alarm for the exact time chosen
    ref.read(notificationProvider).scheduleReminder(
      'Safi Ledger Due!',
      'Time to settle the ${widget.loan.amount} ETB ledger with ${widget.contactName}.',
      scheduledDate: finalDateTime,
    );

    final formattedStr = DateFormat('MMM d, yyyy @ h:mm a').format(finalDateTime);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Alarm set for $formattedStr'), behavior: SnackBarBehavior.floating),
    );
  }

  @override
  Widget build(BuildContext context) {
    final hasPhoto = widget.loan.receiptPhotoUrl != null;
    final hasAudio = widget.loan.voiceNoteUrl != null;
    final isLent = widget.loan.type == LoanType.lent;

    return Scaffold(
      appBar: AppBar(title: const Text('Ledger Details')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text(
            widget.contactName, 
            style: TextStyle(
              fontSize: 32, 
              fontWeight: FontWeight.bold,
              decoration: widget.loan.isSettled ? TextDecoration.lineThrough : null, // Strikethrough if settled
            )
          ),
          Text(
            '${isLent ? '+' : '-'}${widget.loan.amount.toStringAsFixed(0)} ETB', 
            style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: widget.loan.isSettled ? Colors.grey : (isLent ? Colors.green : Colors.red)),
          ),
          
          if (widget.loan.isSettled)
             const Padding(
               padding: EdgeInsets.only(top: 8.0),
               child: Text('✅ This ledger has been settled.', style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold)),
             ),

          const SizedBox(height: 32),

          if (hasAudio) ...[
            const Text('Audio Evidence', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 12),
            Container(
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
                borderRadius: BorderRadius.circular(16),
              ),
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: _isPlaying ? Colors.redAccent : Colors.green,
                  child: IconButton(
                    icon: Icon(_isPlaying ? Icons.pause : Icons.play_arrow, color: Colors.white),
                    onPressed: _toggleAudio,
                  ),
                ),
                title: Text(_isPlaying ? 'Playing Recording...' : 'Play Call File', style: const TextStyle(fontWeight: FontWeight.w600)),
              ),
            ),
            const SizedBox(height: 32),
          ],

          if (hasPhoto) ...[
            const Text('Document / Photo', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Image.file(File(widget.loan.receiptPhotoUrl!), fit: BoxFit.cover),
            ),
            const SizedBox(height: 32),
          ],
          
          // The Reminder Button completely disappears if the debt is settled!
          if (!widget.loan.isSettled)
            FilledButton.icon(
              style: FilledButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16)),
              onPressed: _pickReminderDate,
              icon: const Icon(Icons.edit_calendar_rounded),
              label: const Text('Set Custom Due Date Reminder', style: TextStyle(fontSize: 16)),
            ),
        ],
      ),
    );
  }
}