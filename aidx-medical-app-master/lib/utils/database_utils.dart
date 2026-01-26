import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

class DatabaseUtils {
  // Cache keys
  static const String _cachePrefix = 'medigay_cache_';
  static const String _lastSyncPrefix = 'last_sync_';
  static const int _defaultCacheDuration = 3600; // 1 hour in seconds

  // Data validation
  static bool isValidEmail(String email) {
    return RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(email);
  }

  static bool isValidPhone(String phone) {
    return RegExp(r'^\+?[\d\s\-\(\)]{10,}$').hasMatch(phone);
  }

  static bool isValidHealthValue(dynamic value, String type) {
    if (value == null) return false;

    switch (type) {
      case 'heart_rate':
        return value is num && value >= 30 && value <= 220;
      case 'blood_pressure_systolic':
        return value is num && value >= 70 && value <= 200;
      case 'blood_pressure_diastolic':
        return value is num && value >= 40 && value <= 130;
      case 'temperature':
        return value is num && value >= 35 && value <= 42;
      case 'weight':
        return value is num && value >= 20 && value <= 300;
      case 'height':
        return value is num && value >= 50 && value <= 250;
      case 'blood_sugar':
        return value is num && value >= 20 && value <= 600;
      case 'oxygen_saturation':
        return value is num && value >= 70 && value <= 100;
      default:
        return value is num || value is String;
    }
  }

  // Cache management
  static Future<void> cacheData(String key, dynamic data, {int? duration}) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cacheData = {
        'data': data,
        'timestamp': DateTime.now().millisecondsSinceEpoch,
        'duration': duration ?? _defaultCacheDuration,
      };
      
      await prefs.setString('$_cachePrefix$key', jsonEncode(cacheData));
    } catch (e) {
      print('Error caching data: $e');
    }
  }

  static Future<dynamic> getCachedData(String key) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cachedString = prefs.getString('$_cachePrefix$key');
      
      if (cachedString == null) return null;

      final cachedData = jsonDecode(cachedString);
      final timestamp = cachedData['timestamp'] as int;
      final duration = cachedData['duration'] as int;
      final cacheTime = DateTime.fromMillisecondsSinceEpoch(timestamp);
      final expiryTime = cacheTime.add(Duration(seconds: duration));

      if (DateTime.now().isAfter(expiryTime)) {
        // Cache expired, remove it
        await prefs.remove('$_cachePrefix$key');
        return null;
      }

      return cachedData['data'];
    } catch (e) {
      print('Error getting cached data: $e');
      return null;
    }
  }

  static Future<void> clearCache(String? key) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      if (key != null) {
        await prefs.remove('$_cachePrefix$key');
      } else {
        // Clear all cache
        final keys = prefs.getKeys();
        for (final cacheKey in keys) {
          if (cacheKey.startsWith(_cachePrefix)) {
            await prefs.remove(cacheKey);
          }
        }
      }
    } catch (e) {
      print('Error clearing cache: $e');
    }
  }

  // Last sync tracking
  static Future<void> setLastSync(String collection) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt('$_lastSyncPrefix$collection', DateTime.now().millisecondsSinceEpoch);
    } catch (e) {
      print('Error setting last sync: $e');
    }
  }

  static Future<DateTime?> getLastSync(String collection) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final timestamp = prefs.getInt('$_lastSyncPrefix$collection');
      
      if (timestamp == null) return null;
      
      return DateTime.fromMillisecondsSinceEpoch(timestamp);
    } catch (e) {
      print('Error getting last sync: $e');
      return null;
    }
  }

  // Error handling
  static String getErrorMessage(dynamic error) {
    if (error is FirebaseException) {
      switch (error.code) {
        case 'permission-denied':
          return 'Access denied. Please check your permissions.';
        case 'unavailable':
          return 'Service temporarily unavailable. Please try again.';
        case 'not-found':
          return 'Data not found.';
        case 'already-exists':
          return 'Data already exists.';
        case 'resource-exhausted':
          return 'Service quota exceeded. Please try again later.';
        case 'failed-precondition':
          return 'Operation failed due to invalid state.';
        case 'aborted':
          return 'Operation was aborted.';
        case 'out-of-range':
          return 'Value is out of valid range.';
        case 'unimplemented':
          return 'Operation not implemented.';
        case 'internal':
          return 'Internal server error. Please try again.';
        case 'data-loss':
          return 'Data loss occurred.';
        case 'unauthenticated':
          return 'Please sign in to continue.';
        default:
          return 'An error occurred: ${error.message}';
      }
    }
    
    return error.toString();
  }

  // Data formatting
  static String formatTimestamp(DateTime timestamp) {
    final now = DateTime.now();
    final difference = now.difference(timestamp);

    if (difference.inDays > 0) {
      return '${difference.inDays} day${difference.inDays > 1 ? 's' : ''} ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours} hour${difference.inHours > 1 ? 's' : ''} ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes} minute${difference.inMinutes > 1 ? 's' : ''} ago';
    } else {
      return 'Just now';
    }
  }

  static String formatHealthValue(dynamic value, String unit) {
    if (value == null) return '--';
    
    if (value is num) {
      return '${value.toStringAsFixed(1)} $unit';
    }
    
    return '$value $unit';
  }

  // Batch operations helper
  static List<List<T>> chunk<T>(List<T> list, int chunkSize) {
    final chunks = <List<T>>[];
    for (int i = 0; i < list.length; i += chunkSize) {
      chunks.add(list.sublist(i, i + chunkSize > list.length ? list.length : i + chunkSize));
    }
    return chunks;
  }

  // Data migration helper
  static Map<String, dynamic> migrateData(Map<String, dynamic> oldData, Map<String, dynamic> migrationRules) {
    final newData = <String, dynamic>{};
    
    for (final entry in oldData.entries) {
      final oldKey = entry.key;
      final newKey = migrationRules[oldKey] ?? oldKey;
      newData[newKey] = entry.value;
    }
    
    return newData;
  }

  // Offline support
  static Future<void> saveOfflineData(String key, Map<String, dynamic> data) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final offlineData = {
        'data': data,
        'timestamp': DateTime.now().millisecondsSinceEpoch,
        'synced': false,
      };
      
      await prefs.setString('offline_$key', jsonEncode(offlineData));
    } catch (e) {
      print('Error saving offline data: $e');
    }
  }

  static Future<List<Map<String, dynamic>>> getOfflineData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final keys = prefs.getKeys();
      final offlineData = <Map<String, dynamic>>[];
      
      for (final key in keys) {
        if (key.startsWith('offline_')) {
          final dataString = prefs.getString(key);
          if (dataString != null) {
            final data = jsonDecode(dataString);
            if (data['synced'] == false) {
              offlineData.add(data);
            }
          }
        }
      }
      
      return offlineData;
    } catch (e) {
      print('Error getting offline data: $e');
      return [];
    }
  }

  static Future<void> markDataAsSynced(String key) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final dataString = prefs.getString('offline_$key');
      
      if (dataString != null) {
        final data = jsonDecode(dataString);
        data['synced'] = true;
        await prefs.setString('offline_$key', jsonEncode(data));
      }
    } catch (e) {
      print('Error marking data as synced: $e');
    }
  }
} 