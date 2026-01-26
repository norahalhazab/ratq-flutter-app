import 'package:cloud_firestore/cloud_firestore.dart';

class EmergencyContact {
  final String name;
  final String relationship;
  final String phone;
  final String? email;

  EmergencyContact({
    required this.name,
    required this.relationship,
    required this.phone,
    this.email,
  });

  factory EmergencyContact.fromMap(Map<String, dynamic> data) {
    return EmergencyContact(
      name: data['name'] ?? '',
      relationship: data['relationship'] ?? '',
      phone: data['phone'] ?? '',
      email: data['email'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'relationship': relationship,
      'phone': phone,
      'email': email,
    };
  }
}

class HealthIdModel {
  final String? id;
  final String userId;
  final String name;
  final String? phoneNumber; // Personal phone number for emergency lookup
  final String? age;
  final String? bloodGroup;
  final String? address;
  final List<String> allergies;
  final List<EmergencyContact> emergencyContacts;
  final List<String> activeMedications;
  final String? medicalConditions;
  final String? notes;
  final DateTime createdAt;
  final DateTime updatedAt;
  final bool isActive;

  HealthIdModel({
    this.id,
    required this.userId,
    required this.name,
    this.phoneNumber,
    this.age,
    this.bloodGroup,
    this.address,
    required this.allergies,
    required this.emergencyContacts,
    required this.activeMedications,
    this.medicalConditions,
    this.notes,
    required this.createdAt,
    required this.updatedAt,
    this.isActive = true,
  });

  factory HealthIdModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    
    List<EmergencyContact> contacts = [];
    if (data['emergencyContacts'] != null) {
      contacts = (data['emergencyContacts'] as List)
          .map((contact) => EmergencyContact.fromMap(contact))
          .toList();
    }

    return HealthIdModel(
      id: doc.id,
      userId: data['userId'] ?? '',
      name: data['name'] ?? '',
      phoneNumber: data['phoneNumber'],
      age: data['age'],
      bloodGroup: data['bloodGroup'],
      address: data['address'],
      allergies: data['allergies'] != null ? List<String>.from(data['allergies']) : [],
      emergencyContacts: contacts,
      activeMedications: data['activeMedications'] != null ? List<String>.from(data['activeMedications']) : [],
      medicalConditions: data['medicalConditions'],
      notes: data['notes'],
      createdAt: (data['createdAt'] as Timestamp).toDate(),
      updatedAt: (data['updatedAt'] as Timestamp).toDate(),
      isActive: data['isActive'] ?? true,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'userId': userId,
      'name': name,
      'phoneNumber': phoneNumber,
      'age': age,
      'bloodGroup': bloodGroup,
      'address': address,
      'allergies': allergies,
      'emergencyContacts': emergencyContacts.map((contact) => contact.toMap()).toList(),
      'activeMedications': activeMedications,
      'medicalConditions': medicalConditions,
      'notes': notes,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
      'isActive': isActive,
    };
  }

  // Generate JSON for QR code
  Map<String, dynamic> toQRData() {
    return {
      'userId': userId,
      'name': name,
      'phoneNumber': phoneNumber,
      'age': age,
      'bloodGroup': bloodGroup,
      'address': address,
      'allergies': allergies,
      'emergencyContacts': emergencyContacts.map((contact) => contact.toMap()).toList(),
      'activeMedications': activeMedications,
      'medicalConditions': medicalConditions,
      'notes': notes,
      'lastUpdated': updatedAt.toIso8601String(),
    };
  }

  // Generate summary text for sharing
  String generateSummary() {
    final buffer = StringBuffer();
    buffer.writeln('🏥 DIGITAL HEALTH ID');
    buffer.writeln('==================');
    buffer.writeln('Name: $name');
    if (phoneNumber != null) {
      buffer.writeln('Phone: $phoneNumber');
    }
    if (address != null) {
      buffer.writeln('Address: $address');
    }
    if (bloodGroup != null) {
      buffer.writeln('Blood Group: $bloodGroup');
    }
    
    if (allergies.isNotEmpty) {
      buffer.writeln('Allergies: ${allergies.join(', ')}');
    }
    
    if (activeMedications.isNotEmpty) {
      buffer.writeln('Active Medications: ${activeMedications.join(', ')}');
    }
    
    if (medicalConditions != null) {
      buffer.writeln('Medical Conditions: $medicalConditions');
    }
    
    if (emergencyContacts.isNotEmpty) {
      buffer.writeln('\nEmergency Contacts:');
      for (final contact in emergencyContacts) {
        buffer.writeln('• ${contact.name} (${contact.relationship}): ${contact.phone}');
      }
    }
    
    if (notes != null) {
      buffer.writeln('\nNotes: $notes');
    }
    
    buffer.writeln('\nLast Updated: ${updatedAt.toString().split('.')[0]}');
    
    return buffer.toString();
  }

  HealthIdModel copyWith({
    String? id,
    String? userId,
    String? name,
    String? phoneNumber,
    String? age,
    String? bloodGroup,
    String? address,
    List<String>? allergies,
    List<EmergencyContact>? emergencyContacts,
    List<String>? activeMedications,
    String? medicalConditions,
    String? notes,
    DateTime? createdAt,
    DateTime? updatedAt,
    bool? isActive,
  }) {
    return HealthIdModel(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      name: name ?? this.name,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      age: age ?? this.age,
      bloodGroup: bloodGroup ?? this.bloodGroup,
      address: address ?? this.address,
      allergies: allergies ?? this.allergies,
      emergencyContacts: emergencyContacts ?? this.emergencyContacts,
      activeMedications: activeMedications ?? this.activeMedications,
      medicalConditions: medicalConditions ?? this.medicalConditions,
      notes: notes ?? this.notes,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? DateTime.now(),
      isActive: isActive ?? this.isActive,
    );
  }
} 