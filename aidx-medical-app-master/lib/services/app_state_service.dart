import 'dart:async';
import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AppStateService extends ChangeNotifier {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final SharedPreferences _prefs;

  // Connectivity
  final Connectivity _connectivity = Connectivity();
  StreamSubscription<ConnectivityResult>? _connectivitySubscription;

  // Background sync timer
  Timer? _syncTimer;

  // App State
  bool _isInitialized = false;
  bool _isOnline = true;
  bool _isLoading = false;
  String _currentUserId = '';

  bool _isLightTheme = true;

  // Data Caches
  Map<String, dynamic> _userData = {};

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
  DateTime? get lastSyncTime => _lastSyncTime;
  bool get isSyncing => _isSyncing;
  List<String> get errors => List.unmodifiable(_errors);
  bool get isLightTheme => _isLightTheme;

  // ----------------------------
  // Init
  // ----------------------------
  Future<void> _initializeService() async {
    try {
      debugPrint('🔄 Initializing App State Service...');

      await _loadCachedData();
      await _initializeConnectivity();
      await _initializeUserState();
      await _loadFeatureStates();

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
      final userDataString = _prefs.getString('user_data');
      if (userDataString != null) {
        final decoded = jsonDecode(userDataString);
        if (decoded is Map) {
          _userData = Map<String, dynamic>.from(decoded);
        }
      }

      final offlineQueueString = _prefs.getString('offline_queue');
      if (offlineQueueString != null) {
        final decoded = jsonDecode(offlineQueueString);
        if (decoded is List) {
          _offlineQueue = decoded
              .map((item) => Map<String, dynamic>.from(item as Map))
              .toList();
        }
      }

      debugPrint('📱 Cached data loaded successfully');
    } catch (e) {
      debugPrint('❌ Error loading cached data: $e');
      _addError('Failed to load cached data: $e');
    }
  }

  Future<void> _initializeConnectivity() async {
    try {
      final connectivityResult = await _connectivity.checkConnectivity();
      _isOnline = connectivityResult != ConnectivityResult.none;

      _connectivitySubscription =
          _connectivity.onConnectivityChanged.listen((result) {
            final wasOnline = _isOnline;
            _isOnline = result != ConnectivityResult.none;

            if (!wasOnline && _isOnline) {
              // came back online
              _syncOfflineData();
              _loadUserDataFromFirebase(); // refresh once
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
      _isLightTheme = _prefs.getBool('is_light_theme') ?? true;
      debugPrint('⚙️ Feature states loaded');
    } catch (e) {
      debugPrint('❌ Error loading feature states: $e');
      _addError('Failed to load feature states: $e');
    }
  }

  // ----------------------------
  // Firebase load
  // ----------------------------
  Future<void> _loadUserDataFromFirebase() async {
    if (_currentUserId.isEmpty) return;
    if (!_isOnline) return;

    // prevent spam / overlapping calls
    if (_isLoading) return;
    _isLoading = true;

    try {
      final userDoc =
      await _firestore.collection('users').doc(_currentUserId).get();

      if (userDoc.exists) {
        _userData = userDoc.data() ?? {};
        await _cacheUserData(); // ✅ timestamp-safe now
      }

      _lastSyncTime = DateTime.now();
      debugPrint('📊 User data loaded from Firebase');
    } catch (e) {
      debugPrint('❌ Error loading user data from Firebase: $e');
      _addError('Failed to load user data: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // ----------------------------
  // JSON safe conversion (FIX)
  // ----------------------------
  dynamic _jsonSafe(dynamic v) {
    if (v == null) return null;

    if (v is Timestamp) return v.toDate().toIso8601String();
    if (v is DateTime) return v.toIso8601String();

    if (v is Map) {
      return v.map((k, val) => MapEntry(k.toString(), _jsonSafe(val)));
    }
    if (v is List) {
      return v.map(_jsonSafe).toList();
    }
    return v;
  }

  // ----------------------------
  // Caching
  // ----------------------------
  Future<void> _cacheUserData() async {
    try {
      final safe = _jsonSafe(_userData);
      await _prefs.setString('user_data', jsonEncode(safe));
    } catch (e) {
      debugPrint('❌ Error caching user data: $e');
      _addError('Failed to cache user data: $e');
    }
  }

  Future<void> _cacheOfflineQueue() async {
    try {
      await _prefs.setString('offline_queue', jsonEncode(_offlineQueue));
    } catch (e) {
      debugPrint('❌ Error caching offline queue: $e');
      _addError('Failed to cache offline queue: $e');
    }
  }

  // Theme preference
  Future<void> setLightTheme(bool value) async {
    _isLightTheme = value;
    await _prefs.setBool('is_light_theme', value);
    notifyListeners();
  }

  // ----------------------------
  // Offline queue
  // ----------------------------
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
    if (_isSyncing) return;

    _isSyncing = true;
    notifyListeners();

    try {
      debugPrint('🔄 Syncing offline data...');

      for (final item in _offlineQueue) {
        try {
          switch (item['type']) {
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
      await _firestore.collection('user_settings').doc(_currentUserId).set({
        'feature_states': {feature: active},
        'lastUpdated': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (e) {
      debugPrint('❌ Error saving feature state to Firebase: $e');
    }
  }

  // ----------------------------
  // Background sync
  // ----------------------------
  void _startBackgroundSync() {
    _syncTimer?.cancel();
    _syncTimer = Timer.periodic(const Duration(minutes: 5), (_) {
      if (_isOnline && _currentUserId.isNotEmpty) {
        _loadUserDataFromFirebase();
      }
    });
  }

  // ----------------------------
  // Error management
  // ----------------------------
  void _addError(String error) {
    _errors.add('${DateTime.now().toIso8601String()}: $error');
    if (_errors.length > 100) _errors.removeAt(0);
    // don’t notify too aggressively, but ok
    notifyListeners();
  }

  void clearErrors() {
    _errors.clear();
    notifyListeners();
  }

  // Data getters
  Map<String, dynamic> getUserData() => Map.unmodifiable(_userData);
  List<Map<String, dynamic>> getOfflineQueue() => List.unmodifiable(_offlineQueue);

  // Manual sync
  Future<void> manualSync() async {
    if (_isOnline) {
      await _loadUserDataFromFirebase();
      await _syncOfflineData();
    }
  }

  @override
  void dispose() {
    _syncTimer?.cancel();
    _connectivitySubscription?.cancel();
    super.dispose();
  }
}