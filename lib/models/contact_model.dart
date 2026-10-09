import 'package:cloud_firestore/cloud_firestore.dart';

class Contact {
  final String id;
  final String name;
  final String? phoneNumber;
  final int trustScore;

  const Contact({
    required this.id,
    required this.name,
    this.phoneNumber,
    this.trustScore = 5, // Default to 5 stars
  });

  // Used for saving data to Firebase
  Map<String, dynamic> toMap() => {
    'id': id,
    'name': name,
    'phone_number': phoneNumber,
    'trust_score': trustScore,
  };

  // Fixed: Added fromFirestore back so your Riverpod streams compile perfectly!
  factory Contact.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    return Contact(
      id: doc.id,
      name: data['name'] ?? 'Unknown',
      phoneNumber: data['phone_number'],
      trustScore: data['trust_score']?.toInt() ?? 5,
    );
  }

  // Kept fromMap just in case you use it for local caching later
  factory Contact.fromMap(Map<String, dynamic> map, String documentId) {
    return Contact(
      id: documentId,
      name: map['name'] ?? '',
      phoneNumber: map['phone_number'],
      trustScore: map['trust_score']?.toInt() ?? 5,
    );
  }
}