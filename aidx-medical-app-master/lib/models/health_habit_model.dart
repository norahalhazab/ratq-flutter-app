import 'package:cloud_firestore/cloud_firestore.dart';

class HealthHabitModel {
  final String? id;
  final String userId;
  final String habitType; // walk, water, medication, exercise, etc.
  final DateTime date;
  final bool completed;
  final int? value; // for habits like water glasses (6), steps (5000), etc.
  final String? notes;
  final int streak; // current streak for this habit
  final int totalCompletions; // total times completed
  final DateTime? completedAt;
  final Map<String, dynamic>? metadata;

  HealthHabitModel({
    this.id,
    required this.userId,
    required this.habitType,
    required this.date,
    required this.completed,
    this.value,
    this.notes,
    this.streak = 0,
    this.totalCompletions = 0,
    this.completedAt,
    this.metadata,
  });

  factory HealthHabitModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return HealthHabitModel(
      id: doc.id,
      userId: data['userId'] ?? '',
      habitType: data['habitType'] ?? '',
      date: (data['date'] as Timestamp).toDate(),
      completed: data['completed'] ?? false,
      value: data['value'],
      notes: data['notes'],
      streak: data['streak'] ?? 0,
      totalCompletions: data['totalCompletions'] ?? 0,
      completedAt: data['completedAt'] != null 
          ? (data['completedAt'] as Timestamp).toDate() 
          : null,
      metadata: data['metadata'],
    );
  }

  factory HealthHabitModel.fromMap(Map<String, dynamic> data) {
    return HealthHabitModel(
      id: data['id'],
      userId: data['userId'] ?? '',
      habitType: data['habitType'] ?? '',
      date: data['date'] is Timestamp 
          ? (data['date'] as Timestamp).toDate()
          : DateTime.parse(data['date']),
      completed: data['completed'] ?? false,
      value: data['value'],
      notes: data['notes'],
      streak: data['streak'] ?? 0,
      totalCompletions: data['totalCompletions'] ?? 0,
      completedAt: data['completedAt'] != null 
          ? (data['completedAt'] is Timestamp 
              ? (data['completedAt'] as Timestamp).toDate()
              : DateTime.parse(data['completedAt']))
          : null,
      metadata: data['metadata'],
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'userId': userId,
      'habitType': habitType,
      'date': Timestamp.fromDate(date),
      'completed': completed,
      'value': value,
      'notes': notes,
      'streak': streak,
      'totalCompletions': totalCompletions,
      'completedAt': completedAt != null ? Timestamp.fromDate(completedAt!) : null,
      'metadata': metadata,
    };
  }

  HealthHabitModel copyWith({
    String? id,
    String? userId,
    String? habitType,
    DateTime? date,
    bool? completed,
    int? value,
    String? notes,
    int? streak,
    int? totalCompletions,
    DateTime? completedAt,
    Map<String, dynamic>? metadata,
  }) {
    return HealthHabitModel(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      habitType: habitType ?? this.habitType,
      date: date ?? this.date,
      completed: completed ?? this.completed,
      value: value ?? this.value,
      notes: notes ?? this.notes,
      streak: streak ?? this.streak,
      totalCompletions: totalCompletions ?? this.totalCompletions,
      completedAt: completedAt ?? this.completedAt,
      metadata: metadata ?? this.metadata,
    );
  }
}

class HabitBadgeModel {
  final String? id;
  final String userId;
  final String badgeType; // walker, water_drinker, medication_master, etc.
  final String badgeName;
  final String badgeDescription;
  final String badgeIcon;
  final DateTime earnedAt;
  final int level; // 1, 2, 3 for bronze, silver, gold
  final Map<String, dynamic>? metadata;

  HabitBadgeModel({
    this.id,
    required this.userId,
    required this.badgeType,
    required this.badgeName,
    required this.badgeDescription,
    required this.badgeIcon,
    required this.earnedAt,
    this.level = 1,
    this.metadata,
  });

  factory HabitBadgeModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return HabitBadgeModel(
      id: doc.id,
      userId: data['userId'] ?? '',
      badgeType: data['badgeType'] ?? '',
      badgeName: data['badgeName'] ?? '',
      badgeDescription: data['badgeDescription'] ?? '',
      badgeIcon: data['badgeIcon'] ?? '',
      earnedAt: (data['earnedAt'] as Timestamp).toDate(),
      level: data['level'] ?? 1,
      metadata: data['metadata'],
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'userId': userId,
      'badgeType': badgeType,
      'badgeName': badgeName,
      'badgeDescription': badgeDescription,
      'badgeIcon': badgeIcon,
      'earnedAt': Timestamp.fromDate(earnedAt),
      'level': level,
      'metadata': metadata,
    };
  }
} 