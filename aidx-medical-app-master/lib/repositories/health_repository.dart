import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import '../models/health_data_model.dart';

class HealthRepository {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  
  static const String _collection = 'health_data';

  // Get current user ID
  String? get _currentUserId => _auth.currentUser?.uid;

  // Add health data
  Future<void> addHealthData(HealthDataModel healthData) async {
    try {
      if (_currentUserId == null) {
        throw Exception('User not authenticated');
      }

      final data = healthData.copyWith(userId: _currentUserId!);
      await _firestore.collection(_collection).add(data.toFirestore());
      
      debugPrint('✅ Health data added successfully');
    } catch (e) {
      debugPrint('❌ Error adding health data: $e');
      rethrow;
    }
  }

  // Get health data stream
  Stream<List<HealthDataModel>> getHealthDataStream({String? type, int? limit}) {
    try {
      if (_currentUserId == null) {
        return Stream.value([]);
      }

      Query query = _firestore
          .collection(_collection)
          .where('userId', isEqualTo: _currentUserId)
          .orderBy('timestamp', descending: true);

      if (type != null) {
        query = query.where('type', isEqualTo: type);
      }

      if (limit != null) {
        query = query.limit(limit);
      }

      return query.snapshots().map((snapshot) {
        return snapshot.docs
            .map((doc) => HealthDataModel.fromFirestore(doc))
            .toList();
      });
    } catch (e) {
      debugPrint('❌ Error getting health data stream: $e');
      return Stream.value([]);
    }
  }

  // Get health data for specific date range
  Future<List<HealthDataModel>> getHealthDataForDateRange(
    DateTime startDate,
    DateTime endDate, {
    String? type,
  }) async {
    try {
      if (_currentUserId == null) {
        return [];
      }

      Query query = _firestore
          .collection(_collection)
          .where('userId', isEqualTo: _currentUserId)
          .where('timestamp', isGreaterThanOrEqualTo: Timestamp.fromDate(startDate))
          .where('timestamp', isLessThanOrEqualTo: Timestamp.fromDate(endDate))
          .orderBy('timestamp', descending: true);

      if (type != null) {
        query = query.where('type', isEqualTo: type);
      }

      final snapshot = await query.get();
      return snapshot.docs
          .map((doc) => HealthDataModel.fromFirestore(doc))
          .toList();
    } catch (e) {
      debugPrint('❌ Error getting health data for date range: $e');
      return [];
    }
  }

  // Get latest health data by type
  Future<HealthDataModel?> getLatestHealthData(String type) async {
    try {
      if (_currentUserId == null) {
        return null;
      }

      final snapshot = await _firestore
          .collection(_collection)
          .where('userId', isEqualTo: _currentUserId)
          .where('type', isEqualTo: type)
          .orderBy('timestamp', descending: true)
          .limit(1)
          .get();

      if (snapshot.docs.isNotEmpty) {
        return HealthDataModel.fromFirestore(snapshot.docs.first);
      }
      return null;
    } catch (e) {
      debugPrint('❌ Error getting latest health data: $e');
      return null;
    }
  }

  // Update health data
  Future<void> updateHealthData(String id, Map<String, dynamic> updates) async {
    try {
      await _firestore.collection(_collection).doc(id).update({
        ...updates,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      debugPrint('✅ Health data updated successfully');
    } catch (e) {
      debugPrint('❌ Error updating health data: $e');
      rethrow;
    }
  }

  // Delete health data
  Future<void> deleteHealthData(String id) async {
    try {
      await _firestore.collection(_collection).doc(id).delete();
      debugPrint('✅ Health data deleted successfully');
    } catch (e) {
      debugPrint('❌ Error deleting health data: $e');
      rethrow;
    }
  }

  // Get health summary
  Future<Map<String, dynamic>> getHealthSummary() async {
    try {
      if (_currentUserId == null) {
        return {};
      }

      final thirtyDaysAgo = DateTime.now().subtract(const Duration(days: 30));
      
      final snapshot = await _firestore
          .collection(_collection)
          .where('userId', isEqualTo: _currentUserId)
          .where('timestamp', isGreaterThan: Timestamp.fromDate(thirtyDaysAgo))
          .get();

      final healthData = snapshot.docs
          .map((doc) => HealthDataModel.fromFirestore(doc))
          .toList();

      // Group by type and calculate statistics
      final Map<String, List<HealthDataModel>> groupedData = {};
      for (final data in healthData) {
        groupedData.putIfAbsent(data.type, () => []).add(data);
      }

      final summary = <String, dynamic>{};
      for (final entry in groupedData.entries) {
        final type = entry.key;
        final dataList = entry.value;
        
        if (dataList.isNotEmpty) {
          final values = dataList
              .where((d) => d.value is num)
              .map((d) => d.value as num)
              .toList();
          
          if (values.isNotEmpty) {
            summary[type] = {
              'count': dataList.length,
              'latest': dataList.first.value,
              'average': values.reduce((a, b) => a + b) / values.length,
              'min': values.reduce((a, b) => a < b ? a : b),
              'max': values.reduce((a, b) => a > b ? a : b),
              'lastUpdated': dataList.first.timestamp,
            };
          }
        }
      }

      return summary;
    } catch (e) {
      debugPrint('❌ Error getting health summary: $e');
      return {};
    }
  }

  // Batch operations for better performance
  Future<void> addHealthDataBatch(List<HealthDataModel> healthDataList) async {
    try {
      if (_currentUserId == null) {
        throw Exception('User not authenticated');
      }

      final batch = _firestore.batch();
      
      for (final healthData in healthDataList) {
        final data = healthData.copyWith(userId: _currentUserId!);
        final docRef = _firestore.collection(_collection).doc();
        batch.set(docRef, data.toFirestore());
      }

      await batch.commit();
      debugPrint('✅ Batch health data added successfully');
    } catch (e) {
      debugPrint('❌ Error adding batch health data: $e');
      rethrow;
    }
  }
} 