import 'package:cloud_firestore/cloud_firestore.dart';

class AppointmentModel {
  final String? id;
  final String userId;
  final String title;
  final String? description;
  final DateTime dateTime;
  final int duration; // in minutes
  final String? location;
  final String? doctor;
  final String type; // 'general', 'specialist', 'emergency', 'follow_up', 'surgery'
  final String status; // 'scheduled', 'confirmed', 'completed', 'cancelled', 'rescheduled'
  final int? reminderTime; // minutes before appointment
  final DateTime createdAt;
  final DateTime? updatedAt;
  final String? notes;
  final Map<String, dynamic>? metadata; // Additional data like insurance, cost, etc.

  AppointmentModel({
    this.id,
    required this.userId,
    required this.title,
    this.description,
    required this.dateTime,
    this.duration = 60,
    this.location,
    this.doctor,
    this.type = 'general',
    this.status = 'scheduled',
    this.reminderTime,
    required this.createdAt,
    this.updatedAt,
    this.notes,
    this.metadata,
  });

  factory AppointmentModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return AppointmentModel(
      id: doc.id,
      userId: data['userId'] ?? '',
      title: data['title'] ?? '',
      description: data['description'],
      dateTime: (data['dateTime'] as Timestamp).toDate(),
      duration: data['duration'] ?? 60,
      location: data['location'],
      doctor: data['doctor'],
      type: data['type'] ?? 'general',
      status: data['status'] ?? 'scheduled',
      reminderTime: data['reminderTime'],
      createdAt: (data['createdAt'] as Timestamp).toDate(),
      updatedAt: data['updatedAt'] != null ? (data['updatedAt'] as Timestamp).toDate() : null,
      notes: data['notes'],
      metadata: data['metadata'],
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'userId': userId,
      'title': title,
      'description': description,
      'dateTime': Timestamp.fromDate(dateTime),
      'duration': duration,
      'location': location,
      'doctor': doctor,
      'type': type,
      'status': status,
      'reminderTime': reminderTime,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': updatedAt != null ? Timestamp.fromDate(updatedAt!) : null,
      'notes': notes,
      'metadata': metadata,
    };
  }

  AppointmentModel copyWith({
    String? id,
    String? userId,
    String? title,
    String? description,
    DateTime? dateTime,
    int? duration,
    String? location,
    String? doctor,
    String? type,
    String? status,
    int? reminderTime,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? notes,
    Map<String, dynamic>? metadata,
  }) {
    return AppointmentModel(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      title: title ?? this.title,
      description: description ?? this.description,
      dateTime: dateTime ?? this.dateTime,
      duration: duration ?? this.duration,
      location: location ?? this.location,
      doctor: doctor ?? this.doctor,
      type: type ?? this.type,
      status: status ?? this.status,
      reminderTime: reminderTime ?? this.reminderTime,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? DateTime.now(),
      notes: notes ?? this.notes,
      metadata: metadata ?? this.metadata,
    );
  }

  bool get isUpcoming => dateTime.isAfter(DateTime.now()) && status != 'cancelled';
  bool get isToday => dateTime.day == DateTime.now().day && 
                     dateTime.month == DateTime.now().month && 
                     dateTime.year == DateTime.now().year;
  bool get isPast => dateTime.isBefore(DateTime.now());
  bool get isCompleted => status == 'completed';
  bool get isCancelled => status == 'cancelled';

  DateTime get endTime => dateTime.add(Duration(minutes: duration));

  @override
  String toString() {
    return 'AppointmentModel(id: $id, title: $title, dateTime: $dateTime, status: $status)';
  }
} 