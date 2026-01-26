import 'package:cloud_firestore/cloud_firestore.dart';

class SleepFallDetectionModel {
  final String? id;
  final String userId;
  final DateTime timestamp;
  final String eventType; // sleep_start, sleep_end, fall_detected, inactivity_alert
  final String? location; // bed, bathroom, kitchen, etc.
  final double? accelerationX;
  final double? accelerationY;
  final double? accelerationZ;
  final int? durationMinutes; // for sleep events
  final bool isAlertTriggered;
  final String? alertMessage;
  final bool isFalsePositive;
  final Map<String, dynamic>? metadata;

  SleepFallDetectionModel({
    this.id,
    required this.userId,
    required this.timestamp,
    required this.eventType,
    this.location,
    this.accelerationX,
    this.accelerationY,
    this.accelerationZ,
    this.durationMinutes,
    this.isAlertTriggered = false,
    this.alertMessage,
    this.isFalsePositive = false,
    this.metadata,
  });

  factory SleepFallDetectionModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return SleepFallDetectionModel(
      id: doc.id,
      userId: data['userId'] ?? '',
      timestamp: (data['timestamp'] as Timestamp).toDate(),
      eventType: data['eventType'] ?? '',
      location: data['location'],
      accelerationX: (data['accelerationX'] as num?)?.toDouble(),
      accelerationY: (data['accelerationY'] as num?)?.toDouble(),
      accelerationZ: (data['accelerationZ'] as num?)?.toDouble(),
      durationMinutes: data['durationMinutes'],
      isAlertTriggered: data['isAlertTriggered'] ?? false,
      alertMessage: data['alertMessage'],
      isFalsePositive: data['isFalsePositive'] ?? false,
      metadata: data['metadata'],
    );
  }

  factory SleepFallDetectionModel.fromMap(Map<String, dynamic> data) {
    return SleepFallDetectionModel(
      id: data['id'],
      userId: data['userId'] ?? '',
      timestamp: data['timestamp'] is Timestamp 
          ? (data['timestamp'] as Timestamp).toDate()
          : DateTime.parse(data['timestamp']),
      eventType: data['eventType'] ?? '',
      location: data['location'],
      accelerationX: (data['accelerationX'] as num?)?.toDouble(),
      accelerationY: (data['accelerationY'] as num?)?.toDouble(),
      accelerationZ: (data['accelerationZ'] as num?)?.toDouble(),
      durationMinutes: data['durationMinutes'],
      isAlertTriggered: data['isAlertTriggered'] ?? false,
      alertMessage: data['alertMessage'],
      isFalsePositive: data['isFalsePositive'] ?? false,
      metadata: data['metadata'],
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'userId': userId,
      'timestamp': Timestamp.fromDate(timestamp),
      'eventType': eventType,
      'location': location,
      'accelerationX': accelerationX,
      'accelerationY': accelerationY,
      'accelerationZ': accelerationZ,
      'durationMinutes': durationMinutes,
      'isAlertTriggered': isAlertTriggered,
      'alertMessage': alertMessage,
      'isFalsePositive': isFalsePositive,
      'metadata': metadata,
    };
  }

  SleepFallDetectionModel copyWith({
    String? id,
    String? userId,
    DateTime? timestamp,
    String? eventType,
    String? location,
    double? accelerationX,
    double? accelerationY,
    double? accelerationZ,
    int? durationMinutes,
    bool? isAlertTriggered,
    String? alertMessage,
    bool? isFalsePositive,
    Map<String, dynamic>? metadata,
  }) {
    return SleepFallDetectionModel(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      timestamp: timestamp ?? this.timestamp,
      eventType: eventType ?? this.eventType,
      location: location ?? this.location,
      accelerationX: accelerationX ?? this.accelerationX,
      accelerationY: accelerationY ?? this.accelerationY,
      accelerationZ: accelerationZ ?? this.accelerationZ,
      durationMinutes: durationMinutes ?? this.durationMinutes,
      isAlertTriggered: isAlertTriggered ?? this.isAlertTriggered,
      alertMessage: alertMessage ?? this.alertMessage,
      isFalsePositive: isFalsePositive ?? this.isFalsePositive,
      metadata: metadata ?? this.metadata,
    );
  }
} 