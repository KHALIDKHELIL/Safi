import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/contact_model.dart';
import '../models/loan_model.dart';

/// Provides a real-time stream of all contacts
final contactsProvider = StreamProvider.autoDispose<List<Contact>>((ref) {
  return FirebaseFirestore.instance
      .collection('contacts')
      .snapshots()
      .map((snapshot) => snapshot.docs.map((doc) => Contact.fromFirestore(doc)).toList());
});

/// Provides a real-time stream of all loans, ordered by the newest first
final loansProvider = StreamProvider.autoDispose<List<Loan>>((ref) {
  return FirebaseFirestore.instance
      .collection('loans')
      .orderBy('timestamp', descending: true)
      .snapshots()
      .map((snapshot) => snapshot.docs.map((doc) => Loan.fromFirestore(doc)).toList());
});