import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/contact_model.dart';

final contactControllerProvider = Provider((ref) => ContactController());

class ContactController {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // NEW: Handles creating a contact from scratch
  Future<void> createContact(String name, String? phoneNumber, int trustScore) async {
    try {
      final docRef = _firestore.collection('contacts').doc();
      final newContact = Contact(
        id: docRef.id,
        name: name,
        phoneNumber: phoneNumber,
        trustScore: trustScore,
      );
      await docRef.set(newContact.toMap());
    } catch (e) {
      throw Exception('Failed to create contact: $e');
    }
  }

  Future<void> updateContact(Contact contact) async {
    try {
      await _firestore.collection('contacts').doc(contact.id).update(contact.toMap());
    } catch (e) {
      throw Exception('Failed to update contact: $e');
    }
  }

  Future<void> deleteContact(String contactId) async {
    try {
      await _firestore.collection('contacts').doc(contactId).delete();
    } catch (e) {
      throw Exception('Failed to delete contact: $e');
    }
  }
}