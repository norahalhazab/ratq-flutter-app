import 'dart:async';
import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import '../models/health_data_model.dart';

import '../models/health_habit_model.dart';
import '../models/sleep_fall_detection_model.dart';
import '../models/community_support_model.dart';

class DataPersistenceService {
  static final DataPersistenceService _instance = DataPersistenceService._internal();
  factory DataPersistenceService() => _instance;
  DataPersistenceService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final Connectivity _connectivity = Connectivity();
  
  SharedPreferences? _prefs;
  bool _isInitialized = false;
  bool _isOnline = true;
  
  // Data caches
  final Map<String, dynamic> _dataCache = {};
  final List<Map<String, dynamic>> _offlineQueue = [];
  
  // Sync status
  DateTime? _lastSyncTime;
  bool _isSyncing = false;
  
  // Stream controllers for real-time updates
  final StreamController<Map<String, dynamic>> _dataUpdateController = 
      StreamController<Map<String, dynamic>>.broadcast();
  
  Stream<Map<String, dynamic>> get dataUpdates => _dataUpdateController.stream;

  Future<void> initialize() async {
    if (_isInitialized) return;
    
    try {
      debugPrint('🔄 Initializing Data Persistence Service...');
      
      // Initialize SharedPreferences
      _prefs = await SharedPreferences.getInstance();
      
      // Initialize connectivity monitoring
      await _initializeConnectivity();
      
      // Load cached data
      await _loadCachedData();
      
      // Start background sync
      _startBackgroundSync();
      
      _isInitialized = true;
      debugPrint('✅ Data Persistence Service initialized successfully');
    } catch (e) {
      debugPrint('❌ Error initializing Data Persistence Service: $e');
    }
  }

  Future<void> _initializeConnectivity() async {
    try {
      final connectivityResult = await _connectivity.checkConnectivity();
      _isOnline = connectivityResult != ConnectivityResult.none;
      
      _connectivity.onConnectivityChanged.listen((result) {
        final wasOnline = _isOnline;
        _isOnline = result != ConnectivityResult.none;
        
        if (!wasOnline && _isOnline) {
          _syncOfflineData();
        }
        
        debugPrint('🌐 Connectivity changed: ${_isOnline ? 'Online' : 'Offline'}');
      });
    } catch (e) {
      debugPrint('❌ Error initializing connectivity: $e');
    }
  }

  Future<void> _loadCachedData() async {
    try {
      if (_prefs == null) return;
      
      // Load all cached data
      final keys = _prefs!.getKeys();
      for (final key in keys) {
        if (key.startsWith('cache_')) {
          final dataString = _prefs!.getString(key);
          if (dataString != null) {
            _dataCache[key] = jsonDecode(dataString);
          }
        }
      }
      
      // Load offline queue
      final offlineQueueString = _prefs!.getString('offline_queue');
      if (offlineQueueString != null) {
        final queue = jsonDecode(offlineQueueString) as List;
        _offlineQueue.clear();
        _offlineQueue.addAll(queue.map((item) => Map<String, dynamic>.from(item)));
      }
      
      debugPrint('📱 Cached data loaded: ${_dataCache.length} items');
    } catch (e) {
      debugPrint('❌ Error loading cached data: $e');
    }
  }

  // Generic save method
  Future<void> saveData(String collection, Map<String, dynamic> data, {String? documentId}) async {
    try {
      final userId = _auth.currentUser?.uid;
      if (userId == null) {
        debugPrint('❌ No user logged in');
        return;
      }
      
      // Add metadata
      final dataWithMetadata = {
        ...data,
        'userId': userId,
        'timestamp': FieldValue.serverTimestamp(),
        'lastUpdated': DateTime.now().toIso8601String(),
      };
      
      if (_isOnline) {
        // Save to Firebase
        if (documentId != null) {
          await _firestore.collection(collection).doc(documentId).set(dataWithMetadata);
        } else {
          final docRef = await _firestore.collection(collection).add(dataWithMetadata);
          dataWithMetadata['id'] = docRef.id;
        }
        
        // Update local cache
        await _updateCache(collection, dataWithMetadata);
        
        debugPrint('💾 Data saved to Firebase: $collection');
      } else {
        // Add to offline queue
        await _addToOfflineQueue(collection, dataWithMetadata);
        debugPrint('📦 Data queued for offline sync: $collection');
      }
      
      // Notify listeners
      _dataUpdateController.add({
        'collection': collection,
        'action': 'save',
        'data': dataWithMetadata,
      });
      
    } catch (e) {
      debugPrint('❌ Error saving data: $e');
      rethrow;
    }
  }

  // Generic load method
  Future<List<Map<String, dynamic>>> loadData(String collection, {
    String? userId,
    int limit = 50,
    String? orderBy,
    bool descending = true,
  }) async {
    try {
      final cacheKey = 'cache_${collection}_${userId ?? 'all'}';
      
      // Try to load from cache first
      if (_dataCache.containsKey(cacheKey)) {
        final cachedData = _dataCache[cacheKey] as List;
        debugPrint('📱 Loaded from cache: $collection (${cachedData.length} items)');
        return List<Map<String, dynamic>>.from(cachedData);
      }
      
      if (_isOnline) {
        // Load from Firebase
        Query query = _firestore.collection(collection);
        
        if (userId != null) {
          query = query.where('userId', isEqualTo: userId);
        }
        
        if (orderBy != null) {
          query = query.orderBy(orderBy, descending: descending);
        }
        
        query = query.limit(limit);
        
        final snapshot = await query.get();
        final data = snapshot.docs.map((doc) => {
          ...Map<String, dynamic>.from(doc.data() as Map<String, dynamic>? ?? {}),
          'id': doc.id,
        }).toList();
        
        // Cache the data
        _dataCache[cacheKey] = data;
        await _cacheData(cacheKey, data);
        
        debugPrint('📊 Loaded from Firebase: $collection (${data.length} items)');
        return data;
      } else {
        // Return cached data if available
        if (_dataCache.containsKey(cacheKey)) {
          return List<Map<String, dynamic>>.from(_dataCache[cacheKey]);
        }
        
        debugPrint('⚠️ No cached data available for: $collection');
        return [];
      }
    } catch (e) {
      debugPrint('❌ Error loading data: $e');
      return [];
    }
  }

  // Feature-specific save methods


  Future<void> saveHealthData(HealthDataModel healthData) async {
    await saveData('health_data', healthData.toFirestore());
  }

  Future<void> saveHabitData(HealthHabitModel habit) async {
    await saveData('health_habits', habit.toFirestore());
  }

  Future<void> saveSleepData(SleepFallDetectionModel sleepData) async {
    await saveData('sleep_fall_detection', sleepData.toFirestore());
  }

  Future<void> saveCommunityData(CommunityPostModel post) async {
    await saveData('community_posts', post.toFirestore());
  }

  // Feature-specific load methods


  Future<List<HealthDataModel>> loadHealthData({String? userId}) async {
    final data = await loadData('health_data', userId: userId);
    return data.map((item) => HealthDataModel.fromMap(item)).toList();
  }

  Future<List<HealthHabitModel>> loadHabitData({String? userId}) async {
    final data = await loadData('health_habits', userId: userId);
    return data.map((item) => HealthHabitModel.fromMap(item)).toList();
  }

  Future<List<SleepFallDetectionModel>> loadSleepData({String? userId}) async {
    final data = await loadData('sleep_fall_detection', userId: userId);
    return data.map((item) => SleepFallDetectionModel.fromMap(item)).toList();
  }

  Future<List<CommunityPostModel>> loadCommunityData() async {
    final data = await loadData('community_posts');
    return data.map((item) => CommunityPostModel.fromMap(item)).toList();
  }

  // Cache management
  Future<void> _updateCache(String collection, Map<String, dynamic> data) async {
    final userId = _auth.currentUser?.uid ?? 'all';
    final cacheKey = 'cache_${collection}_$userId';
    
    if (!_dataCache.containsKey(cacheKey)) {
      _dataCache[cacheKey] = [];
    }
    
    final cache = _dataCache[cacheKey] as List;
    cache.insert(0, data);
    
    // Keep only the latest 100 items
    if (cache.length > 100) {
      cache.removeRange(100, cache.length);
    }
    
    await _cacheData(cacheKey, cache);
  }

  Future<void> _cacheData(String key, dynamic data) async {
    if (_prefs == null) return;
    
    try {
      await _prefs!.setString(key, jsonEncode(data));
    } catch (e) {
      debugPrint('❌ Error caching data: $e');
    }
  }

  // Offline queue management
  Future<void> _addToOfflineQueue(String collection, Map<String, dynamic> data) async {
    _offlineQueue.add({
      'collection': collection,
      'data': data,
      'timestamp': DateTime.now().toIso8601String(),
    });
    
    await _cacheOfflineQueue();
    debugPrint('📦 Added to offline queue: $collection');
  }

  Future<void> _cacheOfflineQueue() async {
    if (_prefs == null) return;
    
    try {
      await _prefs!.setString('offline_queue', jsonEncode(_offlineQueue));
    } catch (e) {
      debugPrint('❌ Error caching offline queue: $e');
    }
  }

  Future<void> _syncOfflineData() async {
    if (_offlineQueue.isEmpty) return;
    
    _isSyncing = true;
    
    try {
      debugPrint('🔄 Syncing offline data...');
      
      for (final item in _offlineQueue) {
        try {
          await saveData(
            item['collection'],
            item['data'],
          );
        } catch (e) {
          debugPrint('❌ Error syncing item: $e');
        }
      }
      
      _offlineQueue.clear();
      await _cacheOfflineQueue();
      
      _lastSyncTime = DateTime.now();
      debugPrint('✅ Offline data synced successfully');
    } catch (e) {
      debugPrint('❌ Error syncing offline data: $e');
    } finally {
      _isSyncing = false;
    }
  }

  // Background sync
  void _startBackgroundSync() {
    Timer.periodic(const Duration(minutes: 5), (timer) {
      if (_isOnline && _auth.currentUser != null) {
        _syncOfflineData();
      }
    });
  }

  // Manual sync
  Future<void> manualSync() async {
    if (_isOnline) {
      await _syncOfflineData();
    }
  }

  // Clear cache
  Future<void> clearCache() async {
    if (_prefs == null) return;
    
    try {
      final keys = _prefs!.getKeys();
      for (final key in keys) {
        if (key.startsWith('cache_')) {
          await _prefs!.remove(key);
        }
      }
      
      _dataCache.clear();
      debugPrint('🗑️ Cache cleared');
    } catch (e) {
      debugPrint('❌ Error clearing cache: $e');
    }
  }

  // Getters
  bool get isOnline => _isOnline;
  bool get isSyncing => _isSyncing;
  DateTime? get lastSyncTime => _lastSyncTime;
  int get offlineQueueSize => _offlineQueue.length;
  int get cacheSize => _dataCache.length;

  // Cleanup
  void dispose() {
    _dataUpdateController.close();
  }
} 