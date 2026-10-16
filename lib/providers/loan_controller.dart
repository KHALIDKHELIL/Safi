import 'dart:io';
import 'package:flutter/foundation.dart'; 
import 'package:path_provider/path_provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/loan_model.dart';
import '../models/contact_model.dart';
import 'notification_provider.dart'; // REQUIRED to access alarms

// FIXED: Now injects the NotificationController into the LoanController
final loanControllerProvider = Provider((ref) {
  final notifController = ref.read(notificationProvider);
  return LoanController(notifController);
});

class LoanController {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final NotificationController _notificationController; // NEW

  LoanController(this._notificationController);

  Future<void> createLog({
    String? existingContactId, 
    String? newContactName,    
    required double amount,
    required LoanType type,
    Uint8List? receiptPhotoBytes,
    Uint8List? voiceNoteBytes,
    String? voiceNoteExt,
    String? reason,
  }) async {
    try {
      final batch = _firestore.batch();
      final loanRef = _firestore.collection('loans').doc();
      String finalContactId;

      if (existingContactId != null) {
        finalContactId = existingContactId;
      } else if (newContactName != null && newContactName.isNotEmpty) {
        final contactRef = _firestore.collection('contacts').doc();
        finalContactId = contactRef.id;
        final newContact = Contact(id: contactRef.id, name: newContactName);
        batch.set(contactRef, newContact.toMap());
      } else {
        throw Exception('Must provide a contact name.');
      }

      String? localPhotoPath;
      String? localAudioPath;

      if (!kIsWeb) {
        final directory = await getApplicationDocumentsDirectory();
        if (receiptPhotoBytes != null) {
          final photoFile = File('${directory.path}/${loanRef.id}.jpg');
          await photoFile.writeAsBytes(receiptPhotoBytes);
          localPhotoPath = photoFile.path;
        }
        if (voiceNoteBytes != null) {
          final ext = voiceNoteExt ?? 'm4a';
          final audioFile = File('${directory.path}/${loanRef.id}.$ext');
          await audioFile.writeAsBytes(voiceNoteBytes);
          localAudioPath = audioFile.path;
        }
      }

      final newLoan = Loan(
        id: loanRef.id,
        contactId: finalContactId, 
        amount: amount,
        type: type,
        timestamp: DateTime.now(),
        receiptPhotoUrl: localPhotoPath,
        voiceNoteUrl: localAudioPath,
        reason: reason,
      );

      batch.set(loanRef, newLoan.toMap());
      await batch.commit();
    } catch (e) {
      throw Exception('Failed to save log: $e');
    }
  }

  Future<void> toggleSettled(String loanId, bool currentStatus) async {
    try {
      final isNowSettled = !currentStatus;
      await _firestore.collection('loans').doc(loanId).update({
        'is_settled': isNowSettled,
        'settled_date': isNowSettled ? FieldValue.serverTimestamp() : null,
      });

      // FIXED: Cancel the native OS alarm if swiped to settle!
      if (isNowSettled) {
        _notificationController.cancelReminder(loanId);
      }
    } catch (e) {
      throw Exception('Failed to update status: $e');
    }
  }

  Future<void> logPartialPayment(Loan loan, double paymentAmount) async {
    try {
      final newPaidAmount = loan.paidAmount + paymentAmount;
      final isNowSettled = newPaidAmount >= loan.amount;

      await _firestore.collection('loans').doc(loan.id).update({
        'paid_amount': newPaidAmount,
        'is_settled': isNowSettled,
        if (isNowSettled) 'settled_date': FieldValue.serverTimestamp(),
      });

      // FIXED: Cancel the native OS alarm if paid in full!
      if (isNowSettled) {
        _notificationController.cancelReminder(loan.id);
      }
    } catch (e) {
      throw Exception('Failed to log payment: $e');
    }
  }
  
  Future<void> setDueDate(String loanId, DateTime dueDate) async {
    await _firestore.collection('loans').doc(loanId).update({
      'due_date': Timestamp.fromDate(dueDate),
    });
  }

  Future<void> deleteLog(String loanId, String? localPhotoPath, String? localAudioPath) async {
    try {
      await _firestore.collection('loans').doc(loanId).delete();
      
      // FIXED: Delete the native OS alarm if the record is trashed!
      _notificationController.cancelReminder(loanId);
      
      if (!kIsWeb) {
        if (localPhotoPath != null) {
          final photoFile = File(localPhotoPath);
          if (await photoFile.exists()) await photoFile.delete();
        }
        if (localAudioPath != null) {
          final audioFile = File(localAudioPath);
          if (await audioFile.exists()) await audioFile.delete();
        }
      }
    } catch (e) {
      throw Exception('Failed to delete log: $e');
    }
  }
}