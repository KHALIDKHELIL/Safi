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
    required String contactName,
    required double amount,
    required LoanType type,
    Uint8List? receiptPhotoBytes,
    Uint8List? voiceNoteBytes,
    String? voiceNoteExt,
  }) async {
    try {
      final contactRef = _firestore.collection('contacts').doc();
      final newContact = Contact(id: contactRef.id, name: contactName);
      
      final loanRef = _firestore.collection('loans').doc();
      String? localPhotoPath;
      String? localAudioPath;

      // Ensure we only try to save local files if running on Android/iOS (Web doesn't have a normal file system)
      if (!kIsWeb) {
        // Get the secure folder on your Android device
        final directory = await getApplicationDocumentsDirectory();

        // 1. Save Photo Locally
        if (receiptPhotoBytes != null) {
          final photoFile = File('${directory.path}/${loanRef.id}.jpg');
          await photoFile.writeAsBytes(receiptPhotoBytes);
          localPhotoPath = photoFile.path;
        }

        // 2. Save Audio Locally
        if (voiceNoteBytes != null) {
          final ext = voiceNoteExt ?? 'm4a';
          final audioFile = File('${directory.path}/${loanRef.id}.$ext');
          await audioFile.writeAsBytes(voiceNoteBytes);
          localAudioPath = audioFile.path;
        }
      }

      // 3. Save the text database entry with the local device paths included
      final newLoan = Loan(
        id: loanRef.id,
        contactId: contactRef.id,
        amount: amount,
        type: type,
        timestamp: DateTime.now(),
        receiptPhotoUrl: localPhotoPath, // Now saving a local phone path like /data/user/0/...
        voiceNoteUrl: localAudioPath,    
      );

      final batch = _firestore.batch();
      batch.set(contactRef, newContact.toMap());
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