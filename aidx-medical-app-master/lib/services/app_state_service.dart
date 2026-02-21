import 'dart:async';
import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:connectivity_plus/connectivity_plus.dart';

import '../utils/constants.dart';

class AppStateService extends ChangeNotifier {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final SharedPreferences _prefs;
  
  // Connectivity
  final Connectivity _connectivity = Connectivity();
  StreamSubscription<ConnectivityResult>? _connectivitySubscription;
  
  // App State
  bool _isInitialized = false;
  bool _isOnline = true;
  final bool _isLoading = false;
  String _currentUserId = '';
  
  // Feature States
  bool _motionMonitoringActive = false;
  bool _sleepFallDetectionActive = false;
  bool _healthHabitsActive = false;
  bool _communitySupportActive = false;
  bool _isLightTheme = true; // theme preference
  
  // Data Caches
  Map<String, dynamic> _userData = {};
  Map<String, dynamic> _healthData = {};
  Map<String, dynamic> _motionData = {};
  Map<String, dynamic> _habitData = {};
  Map<String, dynamic> _sleepData = {};
  Map<String, dynamic> _communityData = {};
  
  // Offline Queue
  List<Map<String, dynamic>> _offlineQueue = [];
  
  // Sync Status
  DateTime? _lastSyncTime;
  bool _isSyncing = false;
  
  // Error Tracking
  final List<String> _errors = [];
  
  AppStateService(this._prefs) {
    _initializeService();
  }

  // Getters
  bool get isInitialized => _isInitialized;
  bool get isOnline => _isOnline;
  bool get isLoading => _isLoading;
  String get currentUserId => _currentUserId;
  bool get motionMonitoringActive => _motionMonitoringActive;
  bool get sleepFallDetectionActive => _sleepFallDetectionActive;
  bool get healthHabitsActive => _healthHabitsActive;
  bool get communitySupportActive => _communitySupportActive;
  DateTime? get lastSyncTime => _lastSyncTime;
  bool get isSyncing => _isSyncing;
  List<String> get errors => List.unmodifiable(_errors);
  bool get isLightTheme => _isLightTheme;

  void _initializeService() async {
    try {
      debugPrint('🔄 Initializing App State Service...');
      
      // Load cached data
      await _loadCachedData();
      
      // Initialize connectivity monitoring
      await _initializeConnectivity();
      
      // Initialize user state
      await _initializeUserState();
      
      // Load feature states
      await _loadFeatureStates();
      
      // Start background sync
      _startBackgroundSync();
      
      _isInitialized = true;
      notifyListeners();
      
      debugPrint('✅ App State Service initialized successfully');
    } catch (e) {
      debugPrint('❌ Error initializing App State Service: $e');
      _addError('Failed to initialize app state: $e');
    }
  }

  Future<void> _loadCachedData() async {
    try {
      // Load user data
      final userDataString = _prefs.getString('user_data');
      if (userDataString != null) {
        _userData = jsonDecode(userDataString);
      }
      
      // Load health data
      final healthDataString = _prefs.getString('health_data');
      if (healthDataString != null) {
        _healthData = jsonDecode(healthDataString);
      }
      
      // Load motion data
      final motionDataString = _prefs.getString('motion_data');
      if (motionDataString != null) {
        _motionData = jsonDecode(motionDataString);
      }
      
      // Load habit data
      final habitDataString = _prefs.getString('habit_data');
      if (habitDataString != null) {
        _habitData = jsonDecode(habitDataString);
      }
      
      // Load sleep data
      final sleepDataString = _prefs.getString('sleep_data');
      if (sleepDataString != null) {
        _sleepData = jsonDecode(sleepDataString);
      }
      
      // Load community data
      final communityDataString = _prefs.getString('community_data');
      if (communityDataString != null) {
        _communityData = jsonDecode(communityDataString);
      }
      
      // Load offline queue
      final offlineQueueString = _prefs.getString('offline_queue');
      if (offlineQueueString != null) {
        _offlineQueue = List<Map<String, dynamic>>.from(
          jsonDecode(offlineQueueString).map((item) => Map<String, dynamic>.from(item))
        );
      }
      
      debugPrint('📱 Cached data loaded successfully');
    } catch (e) {
      debugPrint('❌ Error loading cached data: $e');
      _addError('Failed to load cached data: $e');
    }
  }

  Future<void> _initializeConnectivity() async {
    try {
      // Get initial connectivity status
      final connectivityResult = await _connectivity.checkConnectivity();
      _isOnline = connectivityResult != ConnectivityResult.none;
      
      // Listen to connectivity changes
      _connectivitySubscription = _connectivity.onConnectivityChanged.listen((result) {
        final wasOnline = _isOnline;
        _isOnline = result != ConnectivityResult.none;
        
        if (!wasOnline && _isOnline) {
          // Came back online - sync data
          _syncOfflineData();
        }
        
        notifyListeners();
        debugPrint('🌐 Connectivity changed: ${_isOnline ? 'Online' : 'Offline'}');
      });
      
      debugPrint('📡 Connectivity monitoring initialized');
    } catch (e) {
      debugPrint('❌ Error initializing connectivity: $e');
      _addError('Failed to initialize connectivity: $e');
    }
  }

  Future<void> _initializeUserState() async {
    try {
      final user = _auth.currentUser;
      if (user != null) {
        _currentUserId = user.uid;
        
        // Load user data from Firebase
        if (_isOnline) {
          await _loadUserDataFromFirebase();
        }
        
        debugPrint('👤 User state initialized: ${user.email}');
      } else {
        debugPrint('👤 No user logged in');
      }
    } catch (e) {
      debugPrint('❌ Error initializing user state: $e');
      _addError('Failed to initialize user state: $e');
    }
  }

  Future<void> _loadFeatureStates() async {
    try {
      _motionMonitoringActive = _prefs.getBool('motion_monitoring_active') ?? false;
      _sleepFallDetectionActive = _prefs.getBool('sleep_fall_detection_active') ?? false;
      _healthHabitsActive = _prefs.getBool('health_habits_active') ?? false;
      _communitySupportActive = _prefs.getBool('community_support_active') ?? false;
      _isLightTheme = _prefs.getBool('is_light_theme') ?? true;
      
      debugPrint('⚙️ Feature states loaded');
    } catch (e) {
      debugPrint('❌ Error loading feature states: $e');
      _addError('Failed to load feature states: $e');
    }
  }

  Future<void> _loadUserDataFromFirebase() async {
    try {
      if (_currentUserId.isEmpty) return;
      
      // Load user profile
      final userDoc = await _firestore.collection('users').doc(_currentUserId).get();
      if (userDoc.exists) {
        _userData = userDoc.data() ?? {};
        await _cacheUserData();
      }
      
      // Load health data
      await _loadHealthDataFromFirebase();
      
      // Load motion data
      await _loadMotionDataFromFirebase();
      
      // Load habit data
      await _loadHabitDataFromFirebase();
      
      // Load sleep data
      await _loadSleepDataFromFirebase();
      
      // Load community data
      await _loadCommunityDataFromFirebase();
      
      _lastSyncTime = DateTime.now();
      debugPrint('📊 User data loaded from Firebase');
    } catch (e) {
      debugPrint('❌ Error loading user data from Firebase: $e');
      _addError('Failed to load user data: $e');
    }
  }

  Future<void> _loadHealthDataFromFirebase() async {
    try {
      final healthSnapshot = await _firestore
          .collection('health_data')
          .where('userId', isEqualTo: _currentUserId)
          .orderBy('timestamp', descending: true)
          .limit(100)
          .get();
      
      _healthData = {
        'records': healthSnapshot.docs.map((doc) => doc.data()).toList(),
        'lastUpdated': DateTime.now().toIso8601String(),
      };
      
      await _cacheHealthData();
    } catch (e) {
      debugPrint('❌ Error loading health data: $e');
    }
  }

  Future<void> _loadMotionDataFromFirebase() async {
    try {
      final motionSnapshot = await _firestore
          .collection('motion_monitoring')
          .where('userId', isEqualTo: _currentUserId)
          .orderBy('timestamp', descending: true)
          .limit(50)
          .get();
      
      _motionData = {
        'activities': motionSnapshot.docs.map((doc) => doc.data()).toList(),
        'lastUpdated': DateTime.now().toIso8601String(),
      };
      
      await _cacheMotionData();
    } catch (e) {
      debugPrint('❌ Error loading motion data: $e');
    }
  }

  Future<void> _loadHabitDataFromFirebase() async {
    try {
      final habitSnapshot = await _firestore
          .collection('health_habits')
          .where('userId', isEqualTo: _currentUserId)
          .orderBy('timestamp', descending: true)
          .limit(50)
          .get();
      
      _habitData = {
        'habits': habitSnapshot.docs.map((doc) => doc.data()).toList(),
        'lastUpdated': DateTime.now().toIso8601String(),
      };
      
      await _cacheHabitData();
    } catch (e) {
      debugPrint('❌ Error loading habit data: $e');
    }
  }

  Future<void> _loadSleepDataFromFirebase() async {
    try {
      final sleepSnapshot = await _firestore
          .collection('sleep_fall_detection')
          .where('userId', isEqualTo: _currentUserId)
          .orderBy('timestamp', descending: true)
          .limit(50)
          .get();
      
      _sleepData = {
        'events': sleepSnapshot.docs.map((doc) => doc.data()).toList(),
        'lastUpdated': DateTime.now().toIso8601String(),
      };
      
      await _cacheSleepData();
    } catch (e) {
      debugPrint('❌ Error loading sleep data: $e');
    }
  }

  Future<void> _loadCommunityDataFromFirebase() async {
    try {
      final communitySnapshot = await _firestore
          .collection('community_stories')
          .orderBy('timestamp', descending: true)
          .limit(100)
          .get();
      
      _communityData = {
        'stories': communitySnapshot.docs.map((doc) => doc.data()).toList(),
        'lastUpdated': DateTime.now().toIso8601String(),
      };
      
      await _cacheCommunityData();
    } catch (e) {
      debugPrint('❌ Error loading community data: $e');
    }
  }

  // Caching Methods
  Future<void> _cacheUserData() async {
    await _prefs.setString('user_data', jsonEncode(_userData));
  }

  Future<void> _cacheHealthData() async {
    await _prefs.setString('health_data', jsonEncode(_healthData));
  }

  Future<void> _cacheMotionData() async {
    await _prefs.setString('motion_data', jsonEncode(_motionData));
  }

  Future<void> _cacheHabitData() async {
    await _prefs.setString('habit_data', jsonEncode(_habitData));
  }

  Future<void> _cacheSleepData() async {
    await _prefs.setString('sleep_data', jsonEncode(_sleepData));
  }

  Future<void> _cacheCommunityData() async {
    await _prefs.setString('community_data', jsonEncode(_communityData));
  }

  Future<void> _cacheOfflineQueue() async {
    await _prefs.setString('offline_queue', jsonEncode(_offlineQueue));
  }

  // Theme preference
  Future<void> setLightTheme(bool value) async {
    _isLightTheme = value;
    await _prefs.setBool('is_light_theme', value);
    notifyListeners();
  }

  // Feature State Management
  Future<void> setMotionMonitoringActive(bool active) async {
    _motionMonitoringActive = active;
    await _prefs.setBool('motion_monitoring_active', active);
    notifyListeners();
    
    if (_isOnline) {
      await _saveFeatureStateToFirebase('motion_monitoring', active);
    } else {
      await _addToOfflineQueue('feature_state', {
        'feature': 'motion_monitoring',
        'active': active,
        'timestamp': DateTime.now().toIso8601String(),
      });
    }
  }

  Future<void> setSleepFallDetectionActive(bool active) async {
    _sleepFallDetectionActive = active;
    await _prefs.setBool('sleep_fall_detection_active', active);
    notifyListeners();
    
    if (_isOnline) {
      await _saveFeatureStateToFirebase('sleep_fall_detection', active);
    } else {
      await _addToOfflineQueue('feature_state', {
        'feature': 'sleep_fall_detection',
        'active': active,
        'timestamp': DateTime.now().toIso8601String(),
      });
    }
  }

  Future<void> setHealthHabitsActive(bool active) async {
    _healthHabitsActive = active;
    await _prefs.setBool('health_habits_active', active);
    notifyListeners();
    
    if (_isOnline) {
      await _saveFeatureStateToFirebase('health_habits', active);
    } else {
      await _addToOfflineQueue('feature_state', {
        'feature': 'health_habits',
        'active': active,
        'timestamp': DateTime.now().toIso8601String(),
      });
    }
  }

  Future<void> setCommunitySupportActive(bool active) async {
    _communitySupportActive = active;
    await _prefs.setBool('community_support_active', active);
    notifyListeners();
    
    if (_isOnline) {
      await _saveFeatureStateToFirebase('community_support', active);
    } else {
      await _addToOfflineQueue('feature_state', {
        'feature': 'community_support',
        'active': active,
        'timestamp': DateTime.now().toIso8601String(),
      });
    }
  }

  // Data Management
  Future<void> saveHealthData(Map<String, dynamic> data) async {
    try {
      if (_isOnline) {
        await _firestore.collection('health_data').add({
          ...data,
          'userId': _currentUserId,
          'timestamp': FieldValue.serverTimestamp(),
        });
        
        // Update local cache
        if (_healthData['records'] == null) {
          _healthData['records'] = [];
        }
        _healthData['records'].insert(0, {
          ...data,
          'userId': _currentUserId,
          'timestamp': DateTime.now().toIso8601String(),
        });
        await _cacheHealthData();
      } else {
        await _addToOfflineQueue('health_data', data);
      }
    } catch (e) {
      debugPrint('❌ Error saving health data: $e');
      _addError('Failed to save health data: $e');
    }
  }

  Future<void> saveMotionData(Map<String, dynamic> data) async {
    try {
      if (_isOnline) {
        await _firestore.collection('motion_monitoring').add({
          ...data,
          'userId': _currentUserId,
          'timestamp': FieldValue.serverTimestamp(),
        });
        
        // Update local cache
        if (_motionData['activities'] == null) {
          _motionData['activities'] = [];
        }
        _motionData['activities'].insert(0, {
          ...data,
          'userId': _currentUserId,
          'timestamp': DateTime.now().toIso8601String(),
        });
        await _cacheMotionData();
      } else {
        await _addToOfflineQueue('motion_data', data);
      }
    } catch (e) {
      debugPrint('❌ Error saving motion data: $e');
      _addError('Failed to save motion data: $e');
    }
  }

  Future<void> saveHabitData(Map<String, dynamic> data) async {
    try {
      if (_isOnline) {
        await _firestore.collection('health_habits').add({
          ...data,
          'userId': _currentUserId,
          'timestamp': FieldValue.serverTimestamp(),
        });
        
        // Update local cache
        if (_habitData['habits'] == null) {
          _habitData['habits'] = [];
        }
        _habitData['habits'].insert(0, {
          ...data,
          'userId': _currentUserId,
          'timestamp': DateTime.now().toIso8601String(),
        });
        await _cacheHabitData();
      } else {
        await _addToOfflineQueue('habit_data', data);
      }
    } catch (e) {
      debugPrint('❌ Error saving habit data: $e');
      _addError('Failed to save habit data: $e');
    }
  }

  Future<void> saveSleepData(Map<String, dynamic> data) async {
    try {
      if (_isOnline) {
        await _firestore.collection('sleep_fall_detection').add({
          ...data,
          'userId': _currentUserId,
          'timestamp': FieldValue.serverTimestamp(),
        });
        
        // Update local cache
        if (_sleepData['events'] == null) {
          _sleepData['events'] = [];
        }
        _sleepData['events'].insert(0, {
          ...data,
          'userId': _currentUserId,
          'timestamp': DateTime.now().toIso8601String(),
        });
        await _cacheSleepData();
      } else {
        await _addToOfflineQueue('sleep_data', data);
      }
    } catch (e) {
      debugPrint('❌ Error saving sleep data: $e');
      _addError('Failed to save sleep data: $e');
    }
  }

  Future<void> saveCommunityData(Map<String, dynamic> data) async {
    try {
      if (_isOnline) {
        await _firestore.collection('community_stories').add({
          ...data,
          'timestamp': FieldValue.serverTimestamp(),
        });
        
        // Update local cache
        if (_communityData['stories'] == null) {
          _communityData['stories'] = [];
        }
        _communityData['stories'].insert(0, {
          ...data,
          'timestamp': DateTime.now().toIso8601String(),
        });
        await _cacheCommunityData();
      } else {
        await _addToOfflineQueue('community_data', data);
      }
    } catch (e) {
      debugPrint('❌ Error saving community data: $e');
      _addError('Failed to save community data: $e');
    }
  }

  // Offline Queue Management
  Future<void> _addToOfflineQueue(String type, Map<String, dynamic> data) async {
    _offlineQueue.add({
      'type': type,
      'data': data,
      'timestamp': DateTime.now().toIso8601String(),
    });
    await _cacheOfflineQueue();
    debugPrint('📦 Added to offline queue: $type');
  }

  Future<void> _syncOfflineData() async {
    if (_offlineQueue.isEmpty) return;
    
    _isSyncing = true;
    notifyListeners();
    
    try {
      debugPrint('🔄 Syncing offline data...');
      
      for (final item in _offlineQueue) {
        try {
          switch (item['type']) {
            case 'health_data':
              await saveHealthData(item['data']);
              break;
            case 'motion_data':
              await saveMotionData(item['data']);
              break;
            case 'habit_data':
              await saveHabitData(item['data']);
              break;
            case 'sleep_data':
              await saveSleepData(item['data']);
              break;
            case 'community_data':
              await saveCommunityData(item['data']);
              break;
            case 'feature_state':
              await _saveFeatureStateToFirebase(
                item['data']['feature'],
                item['data']['active'],
              );
              break;
          }
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
      _addError('Failed to sync offline data: $e');
    } finally {
      _isSyncing = false;
      notifyListeners();
    }
  }

  Future<void> _saveFeatureStateToFirebase(String feature, bool active) async {
    try {
      await _firestore
          .collection('user_settings')
          .doc(_currentUserId)
          .set({
        'feature_states': {
          feature: active,
        },
        'lastUpdated': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (e) {
      debugPrint('❌ Error saving feature state to Firebase: $e');
    }
  }

  // Background Sync
  void _startBackgroundSync() {
    Timer.periodic(const Duration(minutes: 5), (timer) {
      if (_isOnline && _currentUserId.isNotEmpty) {
        _loadUserDataFromFirebase();
      }
    });
  }

  // Error Management
  void _addError(String error) {
    _errors.add('${DateTime.now().toIso8601String()}: $error');
    if (_errors.length > 100) {
      _errors.removeAt(0);
    }
    notifyListeners();
  }

  void clearErrors() {
    _errors.clear();
    notifyListeners();
  }

  // Data Getters
  Map<String, dynamic> getUserData() => Map.unmodifiable(_userData);
  Map<String, dynamic> getHealthData() => Map.unmodifiable(_healthData);
  Map<String, dynamic> getMotionData() => Map.unmodifiable(_motionData);
  Map<String, dynamic> getHabitData() => Map.unmodifiable(_habitData);
  Map<String, dynamic> getSleepData() => Map.unmodifiable(_sleepData);
  Map<String, dynamic> getCommunityData() => Map.unmodifiable(_communityData);
  List<Map<String, dynamic>> getOfflineQueue() => List.unmodifiable(_offlineQueue);

  // Manual Sync
  Future<void> manualSync() async {
    if (_isOnline) {
      await _loadUserDataFromFirebase();
      await _syncOfflineData();
    }
  }

  // Cleanup
  @override
  void dispose() {
    _connectivitySubscription?.cancel();
    super.dispose();
  }
} 