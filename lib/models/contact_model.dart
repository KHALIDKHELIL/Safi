
class Contact {
  final String id;
  final String name;
  final String? phoneNumber;
  final String? email;          // NEW
  final String? address;        // NEW
  final String? relationship;   // NEW
  final String? notes;          // NEW

  const Contact({
    required this.id,
    required this.name,
    this.phoneNumber,
    this.email,
    this.address,
    this.relationship,
    this.notes,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'phone_number': phoneNumber,
      'email': email,
      'address': address,
      'relationship': relationship,
      'notes': notes,
    };
  }

  factory Contact.fromMap(Map<String, dynamic> map, String id) {
    return Contact(
      id: id,
      name: map['name'] ?? 'Unknown',
      phoneNumber: map['phone_number'],
      email: map['email'],
      address: map['address'],
      relationship: map['relationship'],
      notes: map['notes'],
    );
  }
}