import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/supabase_config.dart';

class SupabaseBackendService {
  
  // ==================== HEALTH DATA ====================
  
  /// Add health data to Supabase
  static Future<bool> addHealthData({
    required String userId,
    int? heartRate,
    int? bloodPressureSystolic,
    int? bloodPressureDiastolic,
    int? bloodOxygen,
    double? temperature,
    int? steps,
    int? calories,
    double? distance,
    double? sleepHours,
    String? notes,
  }) async {
    try {
      final response = await http.post(
        Uri.parse(SupabaseConfig.healthApi),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'userId': userId,
          'timestamp': DateTime.now().toIso8601String(),
          'heartRate': heartRate,
          'bloodPressureSystolic': bloodPressureSystolic,
          'bloodPressureDiastolic': bloodPressureDiastolic,
          'bloodOxygen': bloodOxygen,
          'temperature': temperature,
          'steps': steps,
          'calories': calories,
          'distance': distance,
          'sleepHours': sleepHours,
          'notes': notes,
        }),
      );
      
      return response.statusCode == 201;
    } catch (e) {
      print('Error adding health data: $e');
      return false;
    }
  }
  
  /// Get health data for a user
  static Future<List<Map<String, dynamic>>> getHealthData({
    required String userId,
    int limit = 100,
  }) async {
    try {
      final response = await http.get(
        Uri.parse('${SupabaseConfig.healthApi}?userId=$userId&limit=$limit'),
      );
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return List<Map<String, dynamic>>.from(data['data'] ?? []);
      }
      return [];
    } catch (e) {
      print('Error getting health data: $e');
      return [];
    }
  }
  
  /// Get health statistics
  static Future<Map<String, dynamic>?> getHealthStats({
    required String userId,
    int days = 7,
  }) async {
    try {
      final response = await http.get(
        Uri.parse('${SupabaseConfig.healthApi}/stats?userId=$userId&days=$days'),
      );
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['stats'];
      }
      return null;
    } catch (e) {
      print('Error getting health stats: $e');
      return null;
    }
  }
  
  // ==================== PERSON PROFILE ====================
  
  /// Create user profile
  static Future<bool> createUserProfile({
    required String userId,
    required String phoneNumber,
    String? firstName,
    String? lastName,
    String? email,
    String? bloodType,
  }) async {
    try {
      final response = await http.post(
        Uri.parse(SupabaseConfig.personApi),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'userId': userId,
          'phoneNumber': phoneNumber,
          'first_name': firstName,
          'last_name': lastName,
          'email': email,
          'blood_type': bloodType,
        }),
      );
      
      return response.statusCode == 201;
    } catch (e) {
      print('Error creating profile: $e');
      return false;
    }
  }
  
  /// Get user profile
  static Future<Map<String, dynamic>?> getUserProfile({
    required String userId,
  }) async {
    try {
      final response = await http.get(
        Uri.parse('${SupabaseConfig.personApi}?userId=$userId'),
      );
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['data'];
      }
      return null;
    } catch (e) {
      print('Error getting profile: $e');
      return null;
    }
  }
  
  /// Update user profile
  static Future<bool> updateUserProfile({
    required String userId,
    Map<String, dynamic>? updates,
  }) async {
    try {
      final body = {'userId': userId, ...?updates};
      final response = await http.put(
        Uri.parse(SupabaseConfig.personApi),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(body),
      );
      
      return response.statusCode == 200;
    } catch (e) {
      print('Error updating profile: $e');
      return false;
    }
  }
  
  // ==================== SUBSCRIPTION ====================
  
  /// Check subscription status (called by Applink)
  /// You don't call this directly - Applink calls your webhook
  static Future<Map<String, dynamic>?> checkSubscriptionStatus({
    required String phoneNumber,
    required String action, // "0" = unsubscribe, "1" = subscribe
  }) async {
    try {
      final response = await http.post(
        Uri.parse(SupabaseConfig.subscriptionApi),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'applicationId': 'APP_999999',
          'password': '95904999aa8edb0c038b3295fdd271de',
          'subscriberId': 'tel:$phoneNumber',
          'action': action,
        }),
      );
      
      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      }
      return null;
    } catch (e) {
      print('Error checking subscription: $e');
      return null;
    }
  }
}
