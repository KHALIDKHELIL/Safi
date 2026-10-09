import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/contact_model.dart';

final contactControllerProvider = Provider((ref) => ContactController());

class ContactController {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<void> updateContact(Contact contact) async {
    try {
      await _firestore.collection('contacts').doc(contact.id).update(contact.toMap());
    } catch (e) {
      throw Exception('Failed to update contact: $e');
    }
  }
}