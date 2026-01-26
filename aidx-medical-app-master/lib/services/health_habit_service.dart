import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/health_habit_model.dart';
import 'notification_service.dart';
import 'package:flutter_tts/flutter_tts.dart';

class HealthHabitService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final NotificationService _notificationService = NotificationService();
  final FlutterTts _flutterTts = FlutterTts();
  
  // Available habits for elderly users
  static const List<String> _availableHabits = [
    'walk',
    'water',
    'medication',
    'exercise',
    'social_activity',
    'healthy_eating',
    'sleep_quality',
    'mental_health',
  ];

  // Badge definitions
  static const Map<String, Map<String, dynamic>> _badgeDefinitions = {
    'walk': {
      'walker_bronze': {'name': 'Walker', 'description': 'Walked for 7 days', 'requirement': 7},
      'walker_silver': {'name': 'Active Walker', 'description': 'Walked for 30 days', 'requirement': 30},
      'walker_gold': {'name': 'Marathon Walker', 'description': 'Walked for 100 days', 'requirement': 100},
    },
    'water': {
      'water_drinker_bronze': {'name': 'Hydrated', 'description': 'Drank water for 7 days', 'requirement': 7},
      'water_drinker_silver': {'name': 'Well Hydrated', 'description': 'Drank water for 30 days', 'requirement': 30},
      'water_drinker_gold': {'name': 'Water Master', 'description': 'Drank water for 100 days', 'requirement': 100},
    },
    'medication': {
      'medication_master_bronze': {'name': 'Medicine Taker', 'description': 'Took medication for 7 days', 'requirement': 7},
      'medication_master_silver': {'name': 'Medicine Expert', 'description': 'Took medication for 30 days', 'requirement': 30},
      'medication_master_gold': {'name': 'Medicine Master', 'description': 'Took medication for 100 days', 'requirement': 100},
    },
  };

  // Initialize TTS
  Future<void> initializeTTS() async {
    await _flutterTts.setLanguage("en-US");
    await _flutterTts.setSpeechRate(0.5); // Slower for elderly
    await _flutterTts.setVolume(1.0);
    await _flutterTts.setPitch(1.0);
  }

  // Mark a habit as completed
  Future<bool> markHabitCompleted(String habitType, {int? value, String? notes}) async {
    try {
      final userId = _auth.currentUser?.uid;
      if (userId == null) return false;

      final today = DateTime.now();
      final todayStart = DateTime(today.year, today.month, today.day);

      // Check if already completed today
      final existingHabit = await _firestore
          .collection('health_habits')
          .where('userId', isEqualTo: userId)
          .where('habitType', isEqualTo: habitType)
          .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(todayStart))
          .where('date', isLessThan: Timestamp.fromDate(todayStart.add(const Duration(days: 1))))
          .get();

      if (existingHabit.docs.isNotEmpty) {
        debugPrint('⚠️ Habit already completed today');
        return false;
      }

      // Get current streak
      final streak = await _getCurrentStreak(userId, habitType);

      // Create habit record
      final habit = HealthHabitModel(
        userId: userId,
        habitType: habitType,
        date: today,
        completed: true,
        value: value,
        notes: notes,
        streak: streak + 1,
        totalCompletions: await _getTotalCompletions(userId, habitType) + 1,
        completedAt: DateTime.now(),
      );

      await _firestore
          .collection('health_habits')
          .add(habit.toFirestore());

      // Check for badges
      await _checkAndAwardBadges(userId, habitType, streak + 1);

      // Provide positive reinforcement
      await _providePositiveReinforcement(habitType, streak + 1);

      debugPrint('✅ Habit marked as completed: $habitType');
      return true;

    } catch (e) {
      debugPrint('⚠️ Error marking habit as completed: $e');
      return false;
    }
  }

  // Get current streak for a habit
  Future<int> _getCurrentStreak(String userId, String habitType) async {
    try {
      final today = DateTime.now();
      final todayStart = DateTime(today.year, today.month, today.day);

      final habits = await _firestore
          .collection('health_habits')
          .where('userId', isEqualTo: userId)
          .where('habitType', isEqualTo: habitType)
          .where('completed', isEqualTo: true)
          .orderBy('date', descending: true)
          .limit(100)
          .get();

      int streak = 0;
      DateTime currentDate = todayStart;

      for (final doc in habits.docs) {
        final habit = HealthHabitModel.fromFirestore(doc);
        final habitDate = DateTime(habit.date.year, habit.date.month, habit.date.day);

        if (habitDate.isAtSameMomentAs(currentDate)) {
          streak++;
          currentDate = currentDate.subtract(const Duration(days: 1));
        } else {
          break;
        }
      }

      return streak;
    } catch (e) {
      debugPrint('⚠️ Error getting current streak: $e');
      return 0;
    }
  }

  // Get total completions for a habit
  Future<int> _getTotalCompletions(String userId, String habitType) async {
    try {
      final snapshot = await _firestore
          .collection('health_habits')
          .where('userId', isEqualTo: userId)
          .where('habitType', isEqualTo: habitType)
          .where('completed', isEqualTo: true)
          .count()
          .get();

      return snapshot.count ?? 0;
    } catch (e) {
      debugPrint('⚠️ Error getting total completions: $e');
      return 0;
    }
  }

  // Check and award badges
  Future<void> _checkAndAwardBadges(String userId, String habitType, int currentStreak) async {
    try {
      final badgeDefinitions = _badgeDefinitions[habitType];
      if (badgeDefinitions == null) return;

      for (final entry in badgeDefinitions.entries) {
        final badgeId = entry.key;
        final badgeData = entry.value;
        final requirement = badgeData['requirement'] as int;

        if (currentStreak >= requirement) {
          // Check if badge already awarded
          final existingBadge = await _firestore
              .collection('habit_badges')
              .where('userId', isEqualTo: userId)
              .where('badgeType', isEqualTo: badgeId)
              .get();

          if (existingBadge.docs.isEmpty) {
            // Award new badge
            final badge = HabitBadgeModel(
              userId: userId,
              badgeType: badgeId,
              badgeName: badgeData['name'],
              badgeDescription: badgeData['description'],
              badgeIcon: _getBadgeIcon(badgeId),
              earnedAt: DateTime.now(),
              level: _getBadgeLevel(badgeId),
            );

            await _firestore
                .collection('habit_badges')
                .add(badge.toFirestore());

            // Show badge notification
            await _showBadgeNotification(badge);
          }
        }
      }
    } catch (e) {
      debugPrint('⚠️ Error checking badges: $e');
    }
  }

  // Provide positive reinforcement
  Future<void> _providePositiveReinforcement(String habitType, int streak) async {
    try {
      String message = '';
      String voiceMessage = '';

      switch (habitType) {
        case 'walk':
          message = 'Great job walking today! 🌟';
          voiceMessage = 'Excellent! You walked today. Keep up the great work!';
          break;
        case 'water':
          message = 'Well done staying hydrated! 💧';
          voiceMessage = 'Wonderful! You drank water today. Your body thanks you!';
          break;
        case 'medication':
          message = 'Perfect! You took your medication on time! 💊';
          voiceMessage = 'Excellent! You took your medication. You are taking great care of yourself!';
          break;
        case 'exercise':
          message = 'Amazing! You exercised today! 💪';
          voiceMessage = 'Fantastic! You exercised today. You are getting stronger!';
          break;
        default:
          message = 'Great job completing your habit! 🌟';
          voiceMessage = 'Wonderful! You completed your habit today. Keep it up!';
      }

      if (streak > 1) {
        message += ' You\'re on a $streak day streak! 🔥';
        voiceMessage += ' You are on a $streak day streak! Amazing!';
      }

      // Show notification
      await _notificationService.showNotification(
        title: 'Habit Completed!',
        body: message,
        payload: 'habit_completed',
      );

      // Voice cheer
      await _flutterTts.speak(voiceMessage);

    } catch (e) {
      debugPrint('⚠️ Error providing positive reinforcement: $e');
    }
  }

  // Show badge notification
  Future<void> _showBadgeNotification(HabitBadgeModel badge) async {
    try {
      await _notificationService.showNotification(
        title: '🏆 New Badge Earned!',
        body: '${badge.badgeName}: ${badge.badgeDescription}',
        payload: 'badge_earned',
      );

      // Voice announcement
      await _flutterTts.speak('Congratulations! You earned the ${badge.badgeName} badge!');
    } catch (e) {
      debugPrint('⚠️ Error showing badge notification: $e');
    }
  }

  // Get badge icon
  String _getBadgeIcon(String badgeId) {
    switch (badgeId) {
      case 'walker_bronze':
      case 'walker_silver':
      case 'walker_gold':
        return '🚶';
      case 'water_drinker_bronze':
      case 'water_drinker_silver':
      case 'water_drinker_gold':
        return '💧';
      case 'medication_master_bronze':
      case 'medication_master_silver':
      case 'medication_master_gold':
        return '💊';
      default:
        return '🏆';
    }
  }

  // Get badge level
  int _getBadgeLevel(String badgeId) {
    if (badgeId.contains('gold')) return 3;
    if (badgeId.contains('silver')) return 2;
    return 1;
  }

  // Get user's habits for today
  Future<List<HealthHabitModel>> getTodayHabits() async {
    try {
      final userId = _auth.currentUser?.uid;
      if (userId == null) return [];

      final today = DateTime.now();
      final todayStart = DateTime(today.year, today.month, today.day);

      final snapshot = await _firestore
          .collection('health_habits')
          .where('userId', isEqualTo: userId)
          .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(todayStart))
          .where('date', isLessThan: Timestamp.fromDate(todayStart.add(const Duration(days: 1))))
          .get();

      return snapshot.docs
          .map((doc) => HealthHabitModel.fromFirestore(doc))
          .toList();

    } catch (e) {
      debugPrint('⚠️ Error getting today habits: $e');
      return [];
    }
  }

  // Get user's badges
  Future<List<HabitBadgeModel>> getUserBadges() async {
    try {
      final userId = _auth.currentUser?.uid;
      if (userId == null) return [];

      final snapshot = await _firestore
          .collection('habit_badges')
          .where('userId', isEqualTo: userId)
          .orderBy('earnedAt', descending: true)
          .get();

      return snapshot.docs
          .map((doc) => HabitBadgeModel.fromFirestore(doc))
          .toList();

    } catch (e) {
      debugPrint('⚠️ Error getting user badges: $e');
      return [];
    }
  }

  // Get habit statistics
  Future<Map<String, dynamic>> getHabitStatistics() async {
    try {
      final userId = _auth.currentUser?.uid;
      if (userId == null) return {};

      final stats = <String, dynamic>{};

      for (final habitType in _availableHabits) {
        final streak = await _getCurrentStreak(userId, habitType);
        final totalCompletions = await _getTotalCompletions(userId, habitType);

        stats[habitType] = {
          'currentStreak': streak,
          'totalCompletions': totalCompletions,
        };
      }

      return stats;

    } catch (e) {
      debugPrint('⚠️ Error getting habit statistics: $e');
      return {};
    }
  }

  // Get available habits
  List<String> getAvailableHabits() {
    return _availableHabits;
  }
} 