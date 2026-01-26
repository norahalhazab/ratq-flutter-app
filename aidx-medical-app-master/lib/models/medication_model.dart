import 'package:cloud_firestore/cloud_firestore.dart';

class MedicationModel {
  final String? id;
  final String userId;
  final String name;
  final String dosage;
  final String frequency; // 'daily', 'twice_daily', 'three_times_daily', 'weekly', 'as_needed'
  final DateTime startDate;
  final DateTime? endDate;
  final String? instructions;
  final String? prescribedBy;
  final String? pharmacy;
  final bool isActive;
  final DateTime createdAt;
  final DateTime updatedAt;
  final List<String>? sideEffects;
  final String? notes;
  final Map<String, dynamic>? schedule; // Detailed schedule information

  MedicationModel({
    this.id,
    required this.userId,
    required this.name,
    required this.dosage,
    required this.frequency,
    required this.startDate,
    this.endDate,
    this.instructions,
    this.prescribedBy,
    this.pharmacy,
    this.isActive = true,
    required this.createdAt,
    required this.updatedAt,
    this.sideEffects,
    this.notes,
    this.schedule,
  });

  factory MedicationModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return MedicationModel(
      id: doc.id,
      userId: data['userId'] ?? '',
      name: data['name'] ?? '',
      dosage: data['dosage'] ?? '',
      frequency: data['frequency'] ?? '',
      startDate: (data['startDate'] as Timestamp).toDate(),
      endDate: data['endDate'] != null ? (data['endDate'] as Timestamp).toDate() : null,
      instructions: data['instructions'],
      prescribedBy: data['prescribedBy'],
      pharmacy: data['pharmacy'],
      isActive: data['isActive'] ?? true,
      createdAt: (data['createdAt'] as Timestamp).toDate(),
      updatedAt: (data['updatedAt'] as Timestamp).toDate(),
      sideEffects: data['sideEffects'] != null ? List<String>.from(data['sideEffects']) : null,
      notes: data['notes'],
      schedule: data['schedule'],
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'userId': userId,
      'name': name,
      'dosage': dosage,
      'frequency': frequency,
      'startDate': Timestamp.fromDate(startDate),
      'endDate': endDate != null ? Timestamp.fromDate(endDate!) : null,
      'instructions': instructions,
      'prescribedBy': prescribedBy,
      'pharmacy': pharmacy,
      'isActive': isActive,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
      'sideEffects': sideEffects,
      'notes': notes,
      'schedule': schedule,
    };
  }

  MedicationModel copyWith({
    String? id,
    String? userId,
    String? name,
    String? dosage,
    String? frequency,
    DateTime? startDate,
    DateTime? endDate,
    String? instructions,
    String? prescribedBy,
    String? pharmacy,
    bool? isActive,
    DateTime? createdAt,
    DateTime? updatedAt,
    List<String>? sideEffects,
    String? notes,
    Map<String, dynamic>? schedule,
  }) {
    return MedicationModel(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      name: name ?? this.name,
      dosage: dosage ?? this.dosage,
      frequency: frequency ?? this.frequency,
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
      instructions: instructions ?? this.instructions,
      prescribedBy: prescribedBy ?? this.prescribedBy,
      pharmacy: pharmacy ?? this.pharmacy,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? DateTime.now(),
      sideEffects: sideEffects ?? this.sideEffects,
      notes: notes ?? this.notes,
      schedule: schedule ?? this.schedule,
    );
  }

  bool get isExpired => endDate != null && endDate!.isBefore(DateTime.now());
  bool get isActiveAndNotExpired => isActive && !isExpired;

  @override
  String toString() {
    return 'MedicationModel(id: $id, name: $name, dosage: $dosage, frequency: $frequency)';
  }
} 