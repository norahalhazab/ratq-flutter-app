import 'dart:async';
import 'dart:ui';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:flutter_background_service_android/flutter_background_service_android.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sensors_plus/sensors_plus.dart';
import 'package:geolocator/geolocator.dart';
import 'notification_service.dart';
import 'sos_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:android_intent_plus/android_intent.dart';

class BackgroundService {
  static const String _backgroundTask = 'backgroundTask';
  static const String _sosTask = 'sosTask';
  static const String _vitalsTask = 'vitalsTask';
  
  static BackgroundService? _instance;
  factory BackgroundService() {
    _instance ??= BackgroundService._internal();
    return _instance!;
  }
  BackgroundService._internal();

  late final NotificationService _notificationService;
  late final SosService _sosService;
  
  // Background service instance
  late FlutterBackgroundService _backgroundService;
  
  // Sensor monitoring
  StreamSubscription<AccelerometerEvent>? _accelerometerSubscription;
  StreamSubscription<GyroscopeEvent>? _gyroscopeSubscription;
  bool _isMonitoring = false;
  
  // Fall detection parameters
  static const double _fallThreshold = 15.0;
  static const double _impactThreshold = 20.0;
  static const double _rotationThreshold = 2.0;
  static const int _fallDetectionWindow = 1000;
  static const int _postFallDelay = 5000;
  static const double _freeFallThreshold = 0.5; // near-zero g for free-fall
  
  // Sensor data storage
  final List<SensorData> _accelerometerData = [];
  final List<GyroscopeData> _gyroscopeData = [];
  Timer? _fallDetectionTimer;
  Timer? _sosTriggerTimer;
  bool _isFallDetected = false;
  
  // Vitals monitoring
  Timer? _vitalsCheckTimer;
  static const int _vitalsCheckInterval = 30000; // 30 seconds
  
  /// Initialize background service
  Future<void> initialize() async {
    debugPrint('🔄 Initializing background service...');
    
    // Initialize dependent services
    _notificationService = NotificationService();
    _sosService = SosService();
    
    _backgroundService = FlutterBackgroundService();
    
    // Configure background service
    await _backgroundService.configure(
      androidConfiguration: AndroidConfiguration(
        onStart: onStart,
        autoStart: false,
        isForegroundMode: true,
        notificationChannelId: 'aidx_background_service',
        initialNotificationTitle: 'AidX Background Service',
        initialNotificationContent: 'Monitoring health and safety',
        foregroundServiceNotificationId: 888,
      ),
      iosConfiguration: IosConfiguration(
        autoStart: false,
        onForeground: onStart,
        onBackground: onIosBackground,
      ),
    );
    
    debugPrint('✅ Background service initialized');
  }

  /// Start background service
  Future<void> startBackgroundService() async {
    debugPrint('🔄 Starting background service...');
    
    // Check if SOS is enabled
    final prefs = await SharedPreferences.getInstance();
    final sosEnabled = prefs.getBool('sos_enabled') ?? false;
    
    if (sosEnabled) {
      await _backgroundService.startService();
      await _startSensorMonitoring();
      await _startVitalsMonitoring();
      
      debugPrint('✅ Background service started with SOS enabled');
    } else {
      debugPrint('⚠️ Background service not started - SOS disabled');
    }
  }

  /// Stop background service
  Future<void> stopBackgroundService() async {
    debugPrint('🔄 Stopping background service...');
    
    _backgroundService.invoke('stopService');
    await _stopSensorMonitoring();
    await _stopVitalsMonitoring();
    
    debugPrint('✅ Background service stopped');
  }

  /// Background service start callback
  @pragma('vm:entry-point')
  static void onStart(ServiceInstance service) async {
    WidgetsFlutterBinding.ensureInitialized();
    
    debugPrint('🔄 Background service started');
    
    try {
      // Initialize services
      final notificationService = NotificationService();
      await notificationService.init();
      
      // Create sensor subscriptions directly without recursive initialization
      StreamSubscription<AccelerometerEvent>? accelerometerSubscription;
      StreamSubscription<GyroscopeEvent>? gyroscopeSubscription;
      
      // Start sensor monitoring
      try {
        accelerometerSubscription = accelerometerEvents.listen((AccelerometerEvent event) {
          // Process accelerometer data for fall detection
          final magnitude = sqrt(event.x * event.x + event.y * event.y + event.z * event.z);
          
          // Simple fall detection threshold
          if (magnitude > 15.0) {
            debugPrint('⚠️ Potential fall detected: $magnitude');
            notificationService.showNotification(
              title: 'Fall Alert',
              body: 'Unusual movement detected',
              payload: 'fall_detection',
            );
          }
        });
        
        debugPrint('✅ Sensor monitoring started in background service');
      } catch (e) {
        debugPrint('❌ Error starting sensor monitoring: $e');
      }
      
      // Keep service alive
      service.on('stopService').listen((event) {
        debugPrint('🔄 Stopping background service...');
        accelerometerSubscription?.cancel();
        gyroscopeSubscription?.cancel();
        service.stopSelf();
      });
      
      // Periodic health check
      Timer.periodic(const Duration(minutes: 5), (timer) async {
        try {
          // Check if SOS is still enabled
          final prefs = await SharedPreferences.getInstance();
          final sosEnabled = prefs.getBool('sos_enabled') ?? false;
          
          if (!sosEnabled) {
            debugPrint('🔄 SOS disabled, stopping background service');
            accelerometerSubscription?.cancel();
            gyroscopeSubscription?.cancel();
            service.stopSelf();
            timer.cancel();
            return;
          }
          
          // Update notification less frequently
          await notificationService.showNotification(
            title: 'AidX Active',
            body: 'Health monitoring active',
            payload: 'background_service',
          );
        } catch (e) {
          debugPrint('❌ Error in periodic health check: $e');
        }
      });
      
    } catch (e) {
      debugPrint('❌ Error in background service onStart: $e');
      service.stopSelf();
    }
  }

  /// iOS background callback
  @pragma('vm:entry-point')
  static Future<bool> onIosBackground(ServiceInstance service) async {
    WidgetsFlutterBinding.ensureInitialized();
    return true;
  }

  /// Start sensor monitoring for fall detection
  Future<void> _startSensorMonitoring() async {
    if (_isMonitoring) return;
    
    _isMonitoring = true;
    debugPrint('🔄 Starting sensor monitoring...');
    
    try {
      // Accelerometer monitoring
      _accelerometerSubscription = accelerometerEvents.listen((AccelerometerEvent event) {
        _processAccelerometerData(event);
      });
      
      // Gyroscope monitoring
      _gyroscopeSubscription = gyroscopeEvents.listen((GyroscopeEvent event) {
        _processGyroscopeData(event);
      });
      
      debugPrint('✅ Sensor monitoring started');
    } catch (e) {
      debugPrint('❌ Error starting sensor monitoring: $e');
    }
  }

  /// Stop sensor monitoring
  Future<void> _stopSensorMonitoring() async {
    if (!_isMonitoring) return;
    
    _isMonitoring = false;
    debugPrint('🔄 Stopping sensor monitoring...');
    
    _accelerometerSubscription?.cancel();
    _gyroscopeSubscription?.cancel();
    _fallDetectionTimer?.cancel();
    _sosTriggerTimer?.cancel();
    
    _accelerometerData.clear();
    _gyroscopeData.clear();
    _isFallDetected = false;
    
    debugPrint('✅ Sensor monitoring stopped');
  }

  /// Process accelerometer data for fall detection
  void _processAccelerometerData(AccelerometerEvent event) {
    final magnitude = sqrt(event.x * event.x + event.y * event.y + event.z * event.z);
    
    // Instant free-fall detection in background
    if (magnitude < _freeFallThreshold) {
      debugPrint('🪂 Background free-fall detected: ${magnitude.toStringAsFixed(2)}');
      _isFallDetected = true;
      _triggerSOS();
      return;
    }

    _accelerometerData.add(SensorData(
      timestamp: DateTime.now(),
      x: event.x,
      y: event.y,
      z: event.z,
      magnitude: magnitude,
    ));
    
    // Keep only recent data
    if (_accelerometerData.length > 50) {
      _accelerometerData.removeAt(0);
    }
    
    // Check for fall
    if (magnitude > _fallThreshold) {
      _detectFall();
    }
  }

  /// Process gyroscope data for fall detection
  void _processGyroscopeData(GyroscopeEvent event) {
    final magnitude = sqrt(event.x * event.x + event.y * event.y + event.z * event.z);
    
    _gyroscopeData.add(GyroscopeData(
      timestamp: DateTime.now(),
      x: event.x,
      y: event.y,
      z: event.z,
      magnitude: magnitude,
    ));
    
    // Keep only recent data
    if (_gyroscopeData.length > 50) {
      _gyroscopeData.removeAt(0);
    }
  }

  /// Detect fall based on sensor data
  void _detectFall() {
    if (_isFallDetected) return;
    
    // Check if we have enough data
    if (_accelerometerData.length < 10 || _gyroscopeData.length < 10) return;
    
    // Get recent data
    final recentAccel = _accelerometerData.sublist(_accelerometerData.length - 10);
    final recentGyro = _gyroscopeData.sublist(_gyroscopeData.length - 10);
    
    // Check for impact pattern
    bool hasImpact = recentAccel.any((data) => data.magnitude > _impactThreshold);
    bool hasRotation = recentGyro.any((data) => data.magnitude > _rotationThreshold);
    
    if (hasImpact && hasRotation) {
      _isFallDetected = true;
      debugPrint('🔄 Fall detected!');
      
      // Show warning notification
      _notificationService.showNotification(
        title: 'Fall Detected',
        body: 'SOS will be triggered in 5 seconds if no response',
        payload: 'fall_detected',
      );
      
      // Start SOS trigger timer
      _sosTriggerTimer = Timer(Duration(milliseconds: _postFallDelay), () {
        _triggerSOS();
      });
      
      // Start fall detection window timer
      _fallDetectionTimer = Timer(Duration(milliseconds: _fallDetectionWindow), () {
        _isFallDetected = false;
      });
    }
  }

  /// Trigger SOS emergency response
  Future<void> _triggerSOS() async {
    if (!_isFallDetected) return;
    
    debugPrint('🆘 Triggering SOS due to fall detection');
    
    try {
      // Start countdown immediately (like manual press)
      await _sosService.startSOSCountdown();

      // Mark pending navigation and bring app to foreground
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('pending_open_sos', true);
      final intent = AndroidIntent(
        action: 'android.intent.action.MAIN',
        category: 'android.intent.category.LAUNCHER',
        package: 'com.aidx.health.app',
        componentName: 'com.aidx.health.app.MainActivity',
      );
      await intent.launch();

      // Get current location
      Position? location;
      try {
        location = await Geolocator.getCurrentPosition();
      } catch (e) {
        debugPrint('❌ Error getting location: $e');
      }
      
      // Show emergency notification
      await _notificationService.showNotification(
        title: 'EMERGENCY: SOS Triggered',
        body: 'Fall detected! Emergency contacts are being notified.',
        payload: 'sos_triggered',
      );
      
      // Trigger SOS service
      await _sosService.triggerSOS(
        reason: 'Fall Detection',
        location: location,
      );
      
      // Reset fall detection
      _isFallDetected = false;
      
    } catch (e) {
      debugPrint('❌ Error triggering SOS: $e');
    }
  }

  /// Start vitals monitoring
  Future<void> _startVitalsMonitoring() async {
    debugPrint('🔄 Starting vitals monitoring...');
    
    _vitalsCheckTimer = Timer.periodic(Duration(milliseconds: _vitalsCheckInterval), (timer) async {
      await _checkVitals();
    });
    
    debugPrint('✅ Vitals monitoring started');
  }

  /// Stop vitals monitoring
  Future<void> _stopVitalsMonitoring() async {
    debugPrint('🔄 Stopping vitals monitoring...');
    
    _vitalsCheckTimer?.cancel();
    
    debugPrint('✅ Vitals monitoring stopped');
  }

  /// Check vitals and trigger SOS if abnormal
  Future<void> _checkVitals() async {
    try {
      // Get latest vitals from shared preferences or sensors
      final prefs = await SharedPreferences.getInstance();
      final lastHeartRate = prefs.getInt('last_heart_rate') ?? 0;
      final lastSpO2 = prefs.getInt('last_spo2') ?? 0;
      
      // Check for abnormal vitals
      bool isAbnormal = false;
      String reason = '';
      
      if (lastHeartRate > 0) {
        if (lastHeartRate > 120 || lastHeartRate < 40) {
          isAbnormal = true;
          reason = 'Abnormal Heart Rate: $lastHeartRate bpm';
        }
      }
      
      if (lastSpO2 > 0) {
        if (lastSpO2 < 90) {
          isAbnormal = true;
          reason = 'Low SpO2: $lastSpO2%';
        }
      }
      
      if (isAbnormal) {
        debugPrint('⚠️ Abnormal vitals detected: $reason');
        
        // Show warning notification
        await _notificationService.showNotification(
          title: 'Abnormal Vitals Detected',
          body: reason,
          payload: 'abnormal_vitals',
        );
        
        // Trigger SOS after delay
        Timer(const Duration(seconds: 30), () async {
          await _sosService.triggerSOS(reason: reason);
        });
      }
      
    } catch (e) {
      debugPrint('❌ Error checking vitals: $e');
    }
  }
}

/// Sensor data model
class SensorData {
  final DateTime timestamp;
  final double x;
  final double y;
  final double z;
  final double magnitude;
  
  SensorData({
    required this.timestamp,
    required this.x,
    required this.y,
    required this.z,
    required this.magnitude,
  });
}

/// Gyroscope data model
class GyroscopeData {
  final DateTime timestamp;
  final double x;
  final double y;
  final double z;
  final double magnitude;
  
  GyroscopeData({
    required this.timestamp,
    required this.x,
    required this.y,
    required this.z,
    required this.magnitude,
  });
} 