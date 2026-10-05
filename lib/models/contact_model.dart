import 'package:cloud_firestore/cloud_firestore.dart';

class Contact {
  final String id;
  final String name;
  final String? phoneNumber;
  final String? address;
  final double trustScore; // Starts at 5.0, goes up/down based on payback history

  const Contact({
    required this.id,
    required this.name,
    this.phoneNumber,
    this.address,
    this.trustScore = 5.0,
  });

  /// Safely converts Firestore data into a perfectly typed Dart object
  factory Contact.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>?;
    
    if (data == null) {
      return Contact(id: doc.id, name: 'Unknown');
    }

    return Contact(
      id: doc.id,
      name: data['name'] as String? ?? 'Unknown',
      phoneNumber: data['phone_number'] as String?,
      address: data['address'] as String?,
      // Use num? to safely handle both int and double from Firestore
      trustScore: (data['trust_score'] as num?)?.toDouble() ?? 5.0, 
    );
  }

  /// Converts the Dart object back to JSON for Firebase
  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'phone_number': phoneNumber,
      'address': address,
      'trust_score': trustScore,
    };
  }
}