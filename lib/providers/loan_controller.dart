import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart'; // Allows us to check if you are on Web or Android
import 'package:path_provider/path_provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/loan_model.dart';
import '../models/contact_model.dart';

final loanControllerProvider = Provider((ref) => LoanController());

class LoanController {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<void> createLog({
    String? existingContactId, // NEW: Pass this if they picked from the dropdown
    String? newContactName,    // NEW: Pass this if it's a brand new person
    required double amount,
    required LoanType type,
    Uint8List? receiptPhotoBytes,
    Uint8List? voiceNoteBytes,
    String? voiceNoteExt,
  }) async {
    try {
      final batch = _firestore.batch();
      final loanRef = _firestore.collection('loans').doc();
      String finalContactId;

      // 1. Determine if we are using an existing contact or creating a new one
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

      // ... The rest of your local file saving logic stays EXACTLY the same ...
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

      // 2. Save the loan with the correct Contact ID
      final newLoan = Loan(
        id: loanRef.id,
        contactId: finalContactId, // Uses the matched or new ID!
        amount: amount,
        type: type,
        timestamp: DateTime.now(),
        receiptPhotoUrl: localPhotoPath,
        voiceNoteUrl: localAudioPath,
      );

      batch.set(loanRef, newLoan.toMap());
      await batch.commit();
    } catch (e) {
      throw Exception('Failed to save log: $e');
    }
  }

  /// Toggles a loan between active and settled
  Future<void> toggleSettled(String loanId, bool currentStatus) async {
    try {
      await _firestore.collection('loans').doc(loanId).update({
        'is_settled': !currentStatus,
      });
    } catch (e) {
      throw Exception('Failed to update status: $e');
    }
  }

  /// Permanently deletes the log AND cleans up the local phone storage
  Future<void> deleteLog(String loanId, String? localPhotoPath, String? localAudioPath) async {
    try {
      // 1. Delete from Firebase
      await _firestore.collection('loans').doc(loanId).delete();
      
      // 2. Safely delete the local evidence files from the phone to free up space
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