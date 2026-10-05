import 'package:cloud_firestore/cloud_firestore.dart';

/// Sticking to strict Enums prevents typo bugs in the database
enum LoanType { lent, borrowed, repayment }

class Loan {
  final String id;
  final String contactId;
  final double amount;
  final LoanType type;
  final String? notes;
  final String? receiptPhotoUrl; // Evidence: Photo of transfer/receipt
  final String? voiceNoteUrl;    // Evidence: Audio recording
  final DateTime? dueDate;
  final DateTime timestamp;
  final bool isSettled;

  const Loan({
    required this.id,
    required this.contactId,
    required this.amount,
    required this.type,
    this.notes,
    this.receiptPhotoUrl,
    this.voiceNoteUrl,
    this.dueDate,
    required this.timestamp,
    this.isSettled = false,
  });

  factory Loan.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>?;

    if (data == null) {
      throw StateError('Missing data for loan document: ${doc.id}');
    }

    // Safely parse the enum from a string
    final typeString = data['type'] as String? ?? 'lent';
    final parsedType = LoanType.values.firstWhere(
      (e) => e.name == typeString,
      orElse: () => LoanType.lent,
    );

    return Loan(
      id: doc.id,
      contactId: data['contact_id'] as String? ?? '',
      amount: (data['amount'] as num?)?.toDouble() ?? 0.0,
      type: parsedType,
      notes: data['notes'] as String?,
      receiptPhotoUrl: data['receipt_photo_url'] as String?,
      voiceNoteUrl: data['voice_note_url'] as String?,
      dueDate: (data['due_date'] as Timestamp?)?.toDate(),
      timestamp: (data['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now(),
      isSettled: data['is_settled'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'contact_id': contactId,
      'amount': amount,
      'type': type.name, // Saves 'lent', 'borrowed', or 'repayment' as a string
      'notes': notes,
      'receipt_photo_url': receiptPhotoUrl,
      'voice_note_url': voiceNoteUrl,
      'due_date': dueDate != null ? Timestamp.fromDate(dueDate!) : null,
      'timestamp': Timestamp.fromDate(timestamp),
      'is_settled': isSettled,
    };
  }
}