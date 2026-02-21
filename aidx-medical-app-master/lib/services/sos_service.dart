import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'notification_service.dart';
import 'package:just_audio/just_audio.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'background_service.dart';
import 'dart:async';
import 'telegram_service.dart';
import '../utils/constants.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:android_intent_plus/android_intent.dart';
import 'package:permission_handler/permission_handler.dart';

class SosService {
  final NotificationService _notificationService = NotificationService();
  final BackgroundService _backgroundService = BackgroundService();
  final AudioPlayer _audioPlayer = AudioPlayer();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  
  bool _isAlarmPlaying = false;
  Timer? _countdownTimer;
  int _countdownSeconds = 30;
  bool _sosActive = false;
  
  // Singleton pattern for global access
  static final SosService _instance = SosService._internal();
  factory SosService() => _instance;
  SosService._internal();

  /// Enable SOS with automatic fall detection and background monitoring
  Future<void> enableSOS() async {
    debugPrint('Enabling SOS with fall detection and background monitoring');
    
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('sos_enabled', true);
    
    // Initialize background service
    await _backgroundService.initialize();
    
    // Automatically enable fall detection when SOS is enabled
    
    // Start background service for continuous monitoring
    try {
      await _backgroundService.startBackgroundService();
    } catch (e) {
      debugPrint('Error starting background service: $e');
    }
    
    debugPrint('SOS, fall detection, and background monitoring enabled');
  }

  /// Disable SOS and fall detection
  Future<void> disableSOS() async {
    debugPrint('Disabling SOS and fall detection');
    
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('sos_enabled', false);
    
    // Automatically disable fall detection when SOS is disabled
    
    // Stop background service
    await _backgroundService.stopBackgroundService();
    
    debugPrint('SOS, fall detection, and background monitoring disabled');
  }

  /// Check if SOS is enabled
  Future<bool> isSOSEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool('sos_enabled') ?? false;
  }

  /// Trigger SOS emergency response
  Future<void> triggerSOS({
    required String reason,
    Position? location,
  }) async {
    debugPrint('SOS triggered: $reason');
    
    // Show emergency notification
    try {
      await _notificationService.showNotification(
        title: 'EMERGENCY: SOS Triggered',
        body: 'Emergency contacts are being notified. Reason: $reason',
        payload: 'sos_triggered',
      );
    } catch (e) {
      debugPrint('Error showing notification: $e');
    }
    
    // Build Telegram SOS message (ensure we have a best-effort location)
    try {
      final telegram = TelegramService();
      // Try to fetch location if not provided
      Position? effectiveLocation = location;
      try {
        effectiveLocation ??= await getCurrentLocation();
      } catch (_) {}

      final String locationText = effectiveLocation != null
          ? 'Location: ${effectiveLocation.latitude}, ${effectiveLocation.longitude}\nMap: https://maps.google.com/?q=${effectiveLocation.latitude},${effectiveLocation.longitude}'
          : 'Location: unavailable';
      final String message = '🚨 SOS Triggered\nReason: $reason\n$locationText\n\nSharing live location (15 min).';
      await telegram.sendMessage(message);
      for (final extraId in AppConstants.extraTelegramChatIds) {
        await telegram.sendMessage(message, chatId: extraId);
      }
      // Send live location when available
      if (effectiveLocation != null) {
        await telegram.sendLiveLocation(
          effectiveLocation.latitude,
          effectiveLocation.longitude,
          livePeriodSeconds: 900,
        );
        for (final extraId in AppConstants.extraTelegramChatIds) {
          await telegram.sendLiveLocation(
            effectiveLocation.latitude,
            effectiveLocation.longitude,
            livePeriodSeconds: 900,
            chatId: extraId,
          );
        }
      }
      debugPrint('✅ SOS message sent to Telegram');
    } catch (e) {
      debugPrint('❌ Error sending SOS to Telegram: $e');
    }

    // Immediate call to emergency number
    try {
      // Use user-configured emergency number if available
      String emergencyNumber = AppConstants.defaultEmergencyNumber;
      try {
        final prefs = await SharedPreferences.getInstance();
        final configured = prefs.getString('emergency_number');
        if (configured != null && configured.trim().isNotEmpty) {
          emergencyNumber = configured.trim();
        }
      } catch (_) {}
      final status = await Permission.phone.status;
      if (!status.isGranted) {
        final result = await Permission.phone.request();
        if (!result.isGranted) {
          final url = 'tel:$emergencyNumber';
          if (await canLaunchUrl(Uri.parse(url))) {
            await launchUrl(Uri.parse(url));
          }
        } else {
          final intent = AndroidIntent(
            action: 'android.intent.action.CALL',
            data: 'tel:$emergencyNumber',
          );
          await intent.launch();
        }
      } else {
        final intent = AndroidIntent(
          action: 'android.intent.action.CALL',
          data: 'tel:$emergencyNumber',
        );
        await intent.launch();
      }
      debugPrint('✅ Emergency call attempted');
    } catch (e) {
      debugPrint('❌ Error initiating emergency call: $e');
    }
    
    debugPrint('SOS emergency response completed');
  }

  /// Start SOS countdown with alarm
  Future<void> startSOSCountdown() async {
    debugPrint('🚨 Starting SOS countdown with alarm');
    
    if (_sosActive) {
      debugPrint('⚠️ SOS already active, not starting new countdown');
      return;
    }
    
    _sosActive = true;
    _countdownSeconds = 30;
    _isAlarmPlaying = false;

    // Cancel any existing timer
    _countdownTimer?.cancel();
    
    // Start countdown timer
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_countdownSeconds > 0) {
        _countdownSeconds--;
        debugPrint('🚨 SOS countdown: $_countdownSeconds seconds remaining');
      } else {
        timer.cancel();
        _countdownSeconds = 0;
        debugPrint('🚨 SOS countdown finished. Triggering emergency response.');
        // Attempt to get current location before triggering
        unawaited(() async {
          Position? latest;
          try {
            latest = await getCurrentLocation();
          } catch (_) {}
          await triggerSOS(reason: 'SOS countdown finished', location: latest);
        }());
      }
    });

    // Play alarm sound
    try {
      await _audioPlayer.setAsset('assets/sounds/notification_sound.mp3');
      await _audioPlayer.setLoopMode(LoopMode.one); // Loop continuously
      await _audioPlayer.setVolume(1.0); // Max volume
      await _audioPlayer.play();
      _isAlarmPlaying = true;
      debugPrint('🚨 SOS alarm started playing');
    } catch (e) {
      debugPrint('❌ Error playing SOS alarm: $e');
    }
  }

  /// Stop SOS countdown and alarm
  Future<void> stopSOSCountdown() async {
    debugPrint('🛑 Stopping SOS countdown and alarm');
    
    _countdownTimer?.cancel();
    _sosActive = false;
    _countdownSeconds = 30;
    
    if (_isAlarmPlaying) {
      try {
        await _audioPlayer.stop();
        _isAlarmPlaying = false;
        debugPrint('🛑 SOS alarm stopped');
      } catch (e) {
        debugPrint('❌ Error stopping SOS alarm: $e');
      }
    }
  }

  /// Get current countdown status
  bool get isSOSActive => _sosActive;
  int get countdownSeconds => _countdownSeconds;
  bool get isAlarmPlaying => _isAlarmPlaying;

  /// Get current location for emergency
  Future<Position?> getCurrentLocation() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        debugPrint('Location services are disabled');
        return null;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          debugPrint('Location permissions are denied');
          return null;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        debugPrint('Location permissions are permanently denied');
        return null;
      }

      return await Geolocator.getCurrentPosition();
    } catch (e) {
      debugPrint('Error getting location: $e');
      return null;
    }
  }
} 