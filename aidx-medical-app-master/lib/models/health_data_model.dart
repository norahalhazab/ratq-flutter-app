import 'package:cloud_firestore/cloud_firestore.dart';

class HealthDataModel {
  final String? id;
  final String userId;
  final String type; // 'blood_pressure', 'heart_rate', 'temperature', 'weight', 'height', 'blood_sugar', 'oxygen_saturation'
  final dynamic value; // Can be number, string, or map for complex data
  final String unit;
  final DateTime timestamp;
  final String source; // 'manual', 'wearable', 'doctor', 'lab'
  final String? notes;
  final Map<String, dynamic>? metadata; // Additional data like device info, location, etc.

  HealthDataModel({
    this.id,
    required this.userId,
    required this.type,
    required this.value,
    required this.unit,
    required this.timestamp,
    required this.source,
    this.notes,
    this.metadata,
  });

  factory HealthDataModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return HealthDataModel(
      id: doc.id,
      userId: data['userId'] ?? '',
      type: data['type'] ?? '',
      value: data['value'],
      unit: data['unit'] ?? '',
      timestamp: (data['timestamp'] as Timestamp).toDate(),
      source: data['source'] ?? 'manual',
      notes: data['notes'],
      metadata: data['metadata'],
    );
  }

  factory HealthDataModel.fromMap(Map<String, dynamic> data) {
    return HealthDataModel(
      id: data['id'],
      userId: data['userId'] ?? '',
      type: data['type'] ?? '',
      value: data['value'],
      unit: data['unit'] ?? '',
      timestamp: data['timestamp'] is Timestamp 
          ? (data['timestamp'] as Timestamp).toDate()
          : DateTime.parse(data['timestamp']),
      source: data['source'] ?? 'manual',
      notes: data['notes'],
      metadata: data['metadata'],
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'userId': userId,
      'type': type,
      'value': value,
      'unit': unit,
      'timestamp': Timestamp.fromDate(timestamp),
      'source': source,
      'notes': notes,
      'metadata': metadata,
    };
  }

  HealthDataModel copyWith({
    String? id,
    String? userId,
    String? type,
    dynamic value,
    String? unit,
    DateTime? timestamp,
    String? source,
    String? notes,
    Map<String, dynamic>? metadata,
  }) {
    return HealthDataModel(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      type: type ?? this.type,
      value: value ?? this.value,
      unit: unit ?? this.unit,
      timestamp: timestamp ?? this.timestamp,
      source: source ?? this.source,
      notes: notes ?? this.notes,
      metadata: metadata ?? this.metadata,
    );
  }

  @override
  String toString() {
    return 'HealthDataModel(id: $id, type: $type, value: $value, unit: $unit, timestamp: $timestamp)';
  }
} 