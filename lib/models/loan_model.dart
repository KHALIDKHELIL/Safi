import 'package:cloud_firestore/cloud_firestore.dart';

enum LoanType { lent, borrowed }

class Loan {
  final String id;
  final String contactId;
  final double amount;
  final double paidAmount;
  final LoanType type;
  final DateTime timestamp;
  final DateTime? dueDate;
  final DateTime? settledDate;
  final String? receiptPhotoUrl;
  final String? voiceNoteUrl;
  final bool isSettled;
  final String? reason; // NEW

  const Loan({
    required this.id,
    required this.contactId,
    required this.amount,
    this.paidAmount = 0.0,
    required this.type,
    required this.timestamp,
    this.dueDate,
    this.settledDate,
    this.receiptPhotoUrl,
    this.voiceNoteUrl,
    this.isSettled = false,
    this.reason, // NEW
  });

  double get remainingAmount {
    if (isSettled) return 0.0;
    final remaining = amount - paidAmount;
    return remaining < 0 ? 0.0 : remaining;
  }

  Map<String, dynamic> toMap() => {
    'id': id,
    'contact_id': contactId,
    'amount': amount,
    'paid_amount': paidAmount,
    'type': type.name,
    'timestamp': Timestamp.fromDate(timestamp),
    'due_date': dueDate != null ? Timestamp.fromDate(dueDate!) : null,
    'settled_date': settledDate != null ? Timestamp.fromDate(settledDate!) : null,
    'receipt_photo_url': receiptPhotoUrl,
    'voice_note_url': voiceNoteUrl,
    'is_settled': isSettled,
    'reason': reason, // NEW
  };

  factory Loan.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    return Loan(
      id: doc.id,
      contactId: data['contact_id'] ?? '',
      amount: (data['amount'] ?? 0).toDouble(),
      paidAmount: (data['paid_amount'] ?? 0).toDouble(),
      type: data['type'] == 'borrowed' ? LoanType.borrowed : LoanType.lent,
      timestamp: _parseDateTime(data['timestamp']),
      dueDate: data['due_date'] != null ? _parseDateTime(data['due_date']) : null,
      settledDate: data['settled_date'] != null ? _parseDateTime(data['settled_date']) : null,
      receiptPhotoUrl: data['receipt_photo_url'],
      voiceNoteUrl: data['voice_note_url'],
      isSettled: data['is_settled'] ?? false,
      reason: data['reason'], // NEW
    );
  }

  static DateTime _parseDateTime(dynamic value) {
    if (value is Timestamp) return value.toDate();
    if (value is String) return DateTime.tryParse(value) ?? DateTime.now();
    if (value is int) return DateTime.fromMillisecondsSinceEpoch(value);
    return DateTime.now();
  }
}