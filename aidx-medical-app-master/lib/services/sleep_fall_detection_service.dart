import 'dart:async';
import 'dart:math';
import 'dart:io' show Platform;
import 'package:flutter/foundation.dart';
import 'package:sensors_plus/sensors_plus.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/sleep_fall_detection_model.dart';
import 'notification_service.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../utils/theme.dart';
import '../utils/constants.dart';
import 'sos_service.dart';
import 'package:geolocator/geolocator.dart';
import 'telegram_service.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:android_intent_plus/android_intent.dart';
import 'package:permission_handler/permission_handler.dart';

class SleepFallDetectionService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final NotificationService _notificationService = NotificationService();
  final FlutterTts _flutterTts = FlutterTts();
  final TelegramService _telegramService = TelegramService();
  
  // Notification service
  final FlutterLocalNotificationsPlugin _notifications = FlutterLocalNotificationsPlugin();
  
  // Sensor streams
  StreamSubscription<AccelerometerEvent>? _accelerometerSubscription;
  StreamSubscription<GyroscopeEvent>? _gyroscopeSubscription;
  
  // Detection variables
  DateTime? _lastMovementTime;
  bool _isMonitoring = false;
  bool _isNotificationActive = false;
  Timer? _checkTimer;
  
  // Fall detection specific variables
  bool _isFallDetectionActive = false;
  bool _isSleepTrackingActive = false;
  final List<double> _recentAccelerations = [];
  final double _fallThreshold = 2.5; // Lower threshold for more sensitive detection
  final int _fallDetectionWindow = 3; // Seconds to monitor after potential fall
  // Free-fall threshold (near-zero g)
  final double _freeFallThreshold = 0.5;

  // Debounce emergency trigger to avoid spamming
  DateTime? _lastEmergencyTime;
  
  // Persistence
  SharedPreferences? _prefs;
  
  // Notification ID for persistent notification
  static const int _persistentNotificationId = 1001;
  static const String _persistentChannelId = 'sleep_fall_monitoring';
  static const String _persistentChannelName = 'Sleep & Fall Monitoring';
  static const String _persistentChannelDescription = 'Persistent notification for sleep and fall detection monitoring';

  SleepFallDetectionService() {
    _initializeNotifications();
    _initializeTts();
    _initializePersistence();
  }

  void _initializeNotifications() {
    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    
    const InitializationSettings initializationSettings =
        InitializationSettings(android: initializationSettingsAndroid);
    
    _notifications.initialize(
      initializationSettings,
      onDidReceiveNotificationResponse: _onNotificationTapped,
    );
    
    // Create persistent notification channel
    const AndroidNotificationChannel channel = AndroidNotificationChannel(
      _persistentChannelId,
      _persistentChannelName,
      description: _persistentChannelDescription,
      importance: Importance.high,
      playSound: false,
      enableVibration: false,
      showBadge: true,
    );
    
    _notifications
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(channel);
  }

  void _onNotificationTapped(NotificationResponse response) async {
    try {
      // When user taps fall detection notification, open SOS screen
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('pending_open_sos', true);
      if (Platform.isAndroid) {
        final intent = AndroidIntent(
          action: 'android.intent.action.MAIN',
          category: 'android.intent.category.LAUNCHER',
          package: 'com.aidx.health.app',
          componentName: 'com.aidx.health.app.MainActivity',
        );
        await intent.launch();
      }
    } catch (_) {
      // ignore
    }
  }

  void _initializeTts() {
    _flutterTts.setLanguage("en-US");
    _flutterTts.setSpeechRate(0.5);
    _flutterTts.setVolume(1.0);
    _flutterTts.setPitch(1.0);
  }

  Future<void> _initializePersistence() async {
    _prefs = await SharedPreferences.getInstance();
    await _loadMonitoringState();
  }

  Future<void> _loadMonitoringState() async {
    if (_prefs == null) return;
    
    final wasFallDetectionActive = _prefs!.getBool('fall_detection_active') ?? false;
    final wasSleepTrackingActive = _prefs!.getBool('sleep_tracking_active') ?? false;
    
    if (wasFallDetectionActive) {
      await startFallDetection();
    }
    if (wasSleepTrackingActive) {
      await startSleepTracking();
    }
  }

  Future<void> _saveMonitoringState(bool fallDetection, bool sleepTracking) async {
    if (_prefs == null) return;
    await _prefs!.setBool('fall_detection_active', fallDetection);
    await _prefs!.setBool('sleep_tracking_active', sleepTracking);
    debugPrint('💾 Saved monitoring state: Fall=$fallDetection, Sleep=$sleepTracking');
  }

  // Start fall detection only
  Future<void> startFallDetection() async {
    if (_isFallDetectionActive) return;
    
    debugPrint('🛡️ Starting fall detection monitoring...');
    _isFallDetectionActive = true;
    _isMonitoring = true;
    
    // Save monitoring state
    await _saveMonitoringState(true, _isSleepTrackingActive);
    
    // Start sensor monitoring for fall detection
    _accelerometerSubscription = accelerometerEvents.listen((AccelerometerEvent event) {
      _handleFallDetection(event);
    });
    
    _gyroscopeSubscription = gyroscopeEvents.listen((GyroscopeEvent event) {
      _handleRotationForFall(event);
    });
    
    debugPrint('✅ Fall detection monitoring started');
  }

  // Start sleep tracking only
  Future<void> startSleepTracking() async {
    if (_isSleepTrackingActive) return;
    
    debugPrint('🛏️ Starting sleep tracking monitoring...');
    _isSleepTrackingActive = true;
    _isMonitoring = true;
    _lastMovementTime = DateTime.now();
    
    // Save monitoring state
    await _saveMonitoringState(_isFallDetectionActive, true);
    
    // Start persistent notification
    await _showPersistentNotification();
    
    // Start periodic check for inactivity
    _checkTimer = Timer.periodic(const Duration(minutes: 1), (timer) {
      _checkInactivity();
    });
    
    debugPrint('✅ Sleep tracking monitoring started');
  }

  // Stop fall detection only
  Future<void> stopFallDetection() async {
    if (!_isFallDetectionActive) return;
    
    debugPrint('🛑 Stopping fall detection monitoring...');
    _isFallDetectionActive = false;
    
    // Save monitoring state
    await _saveMonitoringState(false, _isSleepTrackingActive);
    
    // Cancel fall detection subscriptions
    await _accelerometerSubscription?.cancel();
    await _gyroscopeSubscription?.cancel();
    
    _accelerometerSubscription = null;
    _gyroscopeSubscription = null;
    
    // If no other monitoring is active, stop general monitoring
    if (!_isSleepTrackingActive) {
      _isMonitoring = false;
    }
    
    debugPrint('✅ Fall detection monitoring stopped');
  }

  // Stop sleep tracking only
  Future<void> stopSleepTracking() async {
    if (!_isSleepTrackingActive) return;
    
    debugPrint('🛑 Stopping sleep tracking monitoring...');
    _isSleepTrackingActive = false;
    
    // Save monitoring state
    await _saveMonitoringState(_isFallDetectionActive, false);
    
    // Stop persistent notification
    await _hidePersistentNotification();
    
    // Cancel sleep tracking timer
    _checkTimer?.cancel();
    _checkTimer = null;
    
    // If no other monitoring is active, stop general monitoring
    if (!_isFallDetectionActive) {
      _isMonitoring = false;
    }
    
    debugPrint('✅ Sleep tracking monitoring stopped');
  }

  // Stop all monitoring
  Future<void> stopMonitoring() async {
    await stopFallDetection();
    await stopSleepTracking();
  }

  // Real-time fall detection
  void _handleFallDetection(AccelerometerEvent event) {
    final magnitude = sqrt(event.x * event.x + event.y * event.y + event.z * event.z);
    
    // Instant free-fall detection
    if (_isFallDetectionActive && magnitude < _freeFallThreshold) {
      debugPrint('🪂 Free-fall detected instantly: ${magnitude.toStringAsFixed(2)}');
      _triggerImmediateFallAlert();
      return;
    }

    // Add to recent accelerations for pattern detection
    _recentAccelerations.add(magnitude);
    if (_recentAccelerations.length > 10) {
      _recentAccelerations.removeAt(0);
    }
    
    // Detect sudden acceleration (potential fall)
    if (magnitude > _fallThreshold) {
      debugPrint('⚠️ High acceleration detected: ${magnitude.toStringAsFixed(2)} - Possible fall');
      
      // Check for fall pattern (sudden spike followed by stillness)
      _checkForFallPattern(magnitude);
    }
  }

  void _handleRotationForFall(GyroscopeEvent event) {
    final rotationMagnitude = sqrt(event.x * event.x + event.y * event.y + event.z * event.z);
    
    // Consider rotation as movement
    if (rotationMagnitude > 0.5) {
      _lastMovementTime = DateTime.now();
      debugPrint('🔄 Rotation detected: ${rotationMagnitude.toStringAsFixed(2)}');
    }
  }

  void _checkForFallPattern(double currentMagnitude) {
    if (_recentAccelerations.length < 5) return;
    
    // Calculate average acceleration before the spike
    final beforeSpike = _recentAccelerations.take(_recentAccelerations.length - 1).toList();
    final avgBefore = beforeSpike.reduce((a, b) => a + b) / beforeSpike.length;
    
    // Check if current magnitude is significantly higher than average
    if (currentMagnitude > avgBefore * 1.5 && currentMagnitude > _fallThreshold) {
      debugPrint('🚨 Fall pattern detected! Spike: ${currentMagnitude.toStringAsFixed(2)} vs Avg: ${avgBefore.toStringAsFixed(2)}');
      
      // Start fall confirmation timer
      Timer(Duration(seconds: _fallDetectionWindow), () async {
        await _confirmFall();
      });
    }
  }

  Future<void> _confirmFall() async {
    // Check if there's been minimal movement since the fall
    if (_recentAccelerations.length < 5) return;
    
    final recentMagnitudes = _recentAccelerations.sublist(_recentAccelerations.length - 5);
    final avgRecent = recentMagnitudes.reduce((a, b) => a + b) / recentMagnitudes.length;
    
    if (avgRecent < 1.0) { // Low movement indicates fall
      await _triggerImmediateFallAlert();
    }
  }

  Future<void> _triggerImmediateFallAlert() async {
    // Debounce to prevent multiple triggers in very short time windows
    if (_lastEmergencyTime != null &&
        DateTime.now().difference(_lastEmergencyTime!).inSeconds < 15) {
      debugPrint('⏱️ Emergency recently triggered; skipping duplicate');
      return;
    }
    _lastEmergencyTime = DateTime.now();

    debugPrint('🚨 FALL CONFIRMED! Triggering immediate emergency response...');
    
    // Create fall event
    final event = SleepFallDetectionModel(
      id: '',
      userId: _auth.currentUser?.uid ?? '',
      eventType: 'fall_detected',
      timestamp: DateTime.now(),
      location: 'unknown',
      alertMessage: 'Sudden fall detected - immediate response required',
      isAlertTriggered: true,
      metadata: {
        'severity': 'critical',
        'detection_method': 'accelerometer',
        'response_time': 'immediate',
        'acceleration_magnitude': _recentAccelerations.last,
      },
    );
    
    // Save to database
    await _saveEvent(event);
    
    // Show immediate alert notification
    await _showFallAlertNotification();
    
    // Voice alert
    await _flutterTts.speak(
      "Fall detected! Emergency services will be contacted immediately."
    );
    
    // Get current location
    Position? location;
    try {
      location = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 5),
      );
    } catch (e) {
      debugPrint('❌ Error getting location: $e');
    }
    
    // Open SOS screen and start countdown (like manual press)
    await _openSosScreenAndStartCountdown();
    
    // Start SOS countdown with alarm
    try {
      final sosService = SosService();
      await sosService.startSOSCountdown();
      debugPrint('🚨 SOS countdown started due to fall detection');
    } catch (e) {
      debugPrint('❌ Error starting SOS countdown: $e');
    }
  }

  Future<void> _openSosScreenAndStartCountdown() async {
    try {
      // Start countdown immediately so alarm plays even before UI render
      final sosService = SosService();
      await sosService.startSOSCountdown();

      // Mark pending route so cold start routes to SOS
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('pending_open_sos', true);

      if (Platform.isAndroid) {
        final intent = AndroidIntent(
          action: 'android.intent.action.MAIN',
          category: 'android.intent.category.LAUNCHER',
          package: 'com.aidx.health.app',
          componentName: 'com.aidx.health.app.MainActivity',
        );
        await intent.launch();
        debugPrint('✅ Launched app to foreground for SOS screen');
      }
    } catch (e) {
      debugPrint('❌ Error opening SOS screen: $e');
    }
  }

  void _checkInactivity() {
    if (!_isMonitoring || _lastMovementTime == null) return;
    
    final now = DateTime.now();
    final timeSinceLastMovement = now.difference(_lastMovementTime!);
    
    // Check for 12+ hours of inactivity (sleep/fall detection)
    if (timeSinceLastMovement.inHours >= 12) {
      _triggerSleepFallAlert();
    }
    
    // Update persistent notification with current time
    _updatePersistentNotification();
  }

  Future<void> _showPersistentNotification() async {
    if (_isNotificationActive) return;
    
    final AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      _persistentChannelId,
      _persistentChannelName,
      channelDescription: _persistentChannelDescription,
      importance: Importance.high,
      priority: Priority.high,
      ongoing: true, // Makes notification persistent
      autoCancel: false, // Prevents user from dismissing
      showWhen: true,
      when: DateTime.now().millisecondsSinceEpoch,
      usesChronometer: true, // Shows elapsed time
      chronometerCountDown: false,
      category: AndroidNotificationCategory.service,
      visibility: NotificationVisibility.public,
      playSound: false,
      enableVibration: false,
      icon: '@mipmap/ic_launcher',
      color: AppTheme.primaryColor,
      largeIcon: DrawableResourceAndroidBitmap('@mipmap/ic_launcher'),
      styleInformation: DefaultStyleInformation(true, true),
    );
    
    final NotificationDetails notificationDetails = NotificationDetails(
      android: androidDetails,
    );
    
    await _notifications.show(
      _persistentNotificationId,
      '🛏️ Sleep & Fall Monitoring',
      'Monitoring active • ${_getCurrentTime()}',
      notificationDetails,
    );
    
    _isNotificationActive = true;
    debugPrint('📱 Persistent notification started');
  }

  Future<void> _updatePersistentNotification() async {
    if (!_isNotificationActive) return;
    
    final AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      _persistentChannelId,
      _persistentChannelName,
      channelDescription: _persistentChannelDescription,
      importance: Importance.high,
      priority: Priority.high,
      ongoing: true,
      autoCancel: false,
      showWhen: true,
      when: DateTime.now().millisecondsSinceEpoch,
      usesChronometer: true,
      chronometerCountDown: false,
      category: AndroidNotificationCategory.service,
      visibility: NotificationVisibility.public,
      playSound: false,
      enableVibration: false,
      icon: '@mipmap/ic_launcher',
      color: AppTheme.primaryColor,
      largeIcon: DrawableResourceAndroidBitmap('@mipmap/ic_launcher'),
      styleInformation: DefaultStyleInformation(true, true),
    );
    
    final NotificationDetails notificationDetails = NotificationDetails(
      android: androidDetails,
    );
    
    await _notifications.show(
      _persistentNotificationId,
      '🛏️ Sleep & Fall Monitoring',
      'Monitoring active • ${_getCurrentTime()} • Last movement: ${_getLastMovementTime()}',
      notificationDetails,
    );
  }

  Future<void> _hidePersistentNotification() async {
    if (!_isNotificationActive) return;
    
    await _notifications.cancel(_persistentNotificationId);
    _isNotificationActive = false;
    debugPrint('📱 Persistent notification stopped');
  }

  String _getCurrentTime() {
    final now = DateTime.now();
    return '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';
  }

  String _getLastMovementTime() {
    if (_lastMovementTime == null) return 'Unknown';
    
    final now = DateTime.now();
    final difference = now.difference(_lastMovementTime!);
    
    if (difference.inMinutes < 1) {
      return 'Just now';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inHours < 24) {
      return '${difference.inHours}h ago';
    } else {
      return '${difference.inDays}d ago';
    }
  }

  void _triggerSleepFallAlert() async {
    debugPrint('🚨 Sleep/Fall alert triggered!');
    
    // Create alert event
    final event = SleepFallDetectionModel(
      id: '',
      userId: _auth.currentUser?.uid ?? '',
      eventType: 'sleep_fall_alert',
      timestamp: DateTime.now(),
      location: 'bed',
      alertMessage: 'No movement detected for 12+ hours',
      isAlertTriggered: true,
      metadata: {
        'severity': 'high',
        'duration_hours': 12,
        'detection_method': 'phone_sensors',
      },
    );
    
    // Save to database
    await _saveEvent(event);
    
    // Show alert notification
    await _showAlertNotification();
    
    // Voice alert
    await _flutterTts.speak(
      "Hello! Are you okay? No movement has been detected for over 12 hours. "
      "Please respond if you're safe, or call for help if needed."
    );
    
    // Trigger SOS emergency response
    try {
      final sosService = SosService();
      final location = await Geolocator.getCurrentPosition();
      
      await sosService.triggerSOS(
        reason: 'Sleep/Fall Detection: No movement for 12+ hours',
        location: location,
      );
      
      debugPrint('🚨 SOS triggered due to sleep/fall detection');
    } catch (e) {
      debugPrint('❌ Error triggering SOS: $e');
    }
  }

  Future<void> _showAlertNotification() async {
    const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      'sleep_fall_alert',
      'Sleep & Fall Alerts',
      channelDescription: 'Critical alerts for sleep and fall detection',
      importance: Importance.max,
      priority: Priority.max,
      playSound: true,
      enableVibration: true,
      icon: '@mipmap/ic_launcher',
      color: AppTheme.dangerColor,
      category: AndroidNotificationCategory.alarm,
      visibility: NotificationVisibility.public,
      fullScreenIntent: true,
    );
    
    const NotificationDetails notificationDetails = NotificationDetails(
      android: androidDetails,
    );
    
    await _notifications.show(
      1002, // Different ID for alert
      '🚨 Safety Check Required',
      'No movement detected for 12+ hours. Are you okay?',
      notificationDetails,
      payload: 'sleep_inactivity',
    );
  }

  Future<void> _showFallAlertNotification() async {
    const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      'fall_alert',
      'Fall Detection Alerts',
      channelDescription: 'Critical alerts for fall detection',
      importance: Importance.max,
      priority: Priority.max,
      playSound: true,
      enableVibration: true,
      icon: '@mipmap/ic_launcher',
      color: AppTheme.dangerColor,
      category: AndroidNotificationCategory.alarm,
      visibility: NotificationVisibility.public,
      fullScreenIntent: true,
    );
    
    const NotificationDetails notificationDetails = NotificationDetails(
      android: androidDetails,
    );
    
    await _notifications.show(
      1003, // Different ID for fall alert
      '🚨 FALL DETECTED!',
      'Sudden fall detected. Emergency services will be contacted in 30 seconds.',
      notificationDetails,
      payload: 'fall_detected',
    );
  }

  Future<void> _saveEvent(SleepFallDetectionModel event) async {
    try {
      final docRef = await _firestore
          .collection('sleep_fall_detection')
          .add(event.toFirestore());
      
      // Update the event with the document ID
      await docRef.update({'id': docRef.id});
      
      debugPrint('💾 Sleep/Fall event saved: ${event.id}');
    } catch (e) {
      debugPrint('❌ Error saving sleep/fall event: $e');
    }
  }

  Future<List<SleepFallDetectionModel>> getEvents() async {
    try {
      final userId = _auth.currentUser?.uid;
      if (userId == null) return [];
      
      final snapshot = await _firestore
          .collection('sleep_fall_detection')
          .where('userId', isEqualTo: userId)
          .orderBy('timestamp', descending: true)
          .limit(50)
          .get();
      
              return snapshot.docs
            .map((doc) => SleepFallDetectionModel.fromFirestore(doc))
            .toList();
    } catch (e) {
      debugPrint('❌ Error fetching sleep/fall events: $e');
      return [];
    }
  }

  Future<void> markEventResolved(String eventId) async {
    try {
      await _firestore
          .collection('sleep_fall_detection')
          .doc(eventId)
          .update({'isResolved': true});
      
      debugPrint('✅ Event marked as resolved: $eventId');
    } catch (e) {
      debugPrint('❌ Error marking event as resolved: $e');
    }
  }

  // Get current status for UI display
  Future<Map<String, dynamic>> getCurrentStatus() async {
    try {
      // Get current location
      String currentLocation = 'Unknown';
      try {
        final position = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high,
          timeLimit: const Duration(seconds: 5),
        );
        currentLocation = '${position.latitude.toStringAsFixed(4)}, ${position.longitude.toStringAsFixed(4)}';
      } catch (e) {
        debugPrint('Error getting location: $e');
      }

      return {
        'isFallDetectionActive': _isFallDetectionActive,
        'isSleepTrackingActive': _isSleepTrackingActive,
        'isMonitoring': _isMonitoring,
        'currentLocation': currentLocation,
        'potentialFallDetected': false, // This would be set based on recent events
        'lastMovementTime': _lastMovementTime?.toString(),
        'recentAccelerations': _recentAccelerations.length,
      };
    } catch (e) {
      debugPrint('Error getting current status: $e');
      return {
        'isFallDetectionActive': _isFallDetectionActive,
        'isSleepTrackingActive': _isSleepTrackingActive,
        'isMonitoring': _isMonitoring,
        'currentLocation': 'Unknown',
        'potentialFallDetected': false,
        'lastMovementTime': null,
        'recentAccelerations': 0,
      };
    }
  }

  bool get isMonitoring => _isMonitoring;
  bool get isNotificationActive => _isNotificationActive;
  DateTime? get lastMovementTime => _lastMovementTime;
} 