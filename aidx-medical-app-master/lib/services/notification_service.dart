// notification_service.dart
import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:io' show Platform;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:android_intent_plus/android_intent.dart';

import 'package:aidx/screens/case_details_screen.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _flutterLocalNotificationsPlugin =
  FlutterLocalNotificationsPlugin();

  // ✅ MUST MATCH AndroidManifest default_notification_channel_id
  static const String _channelId = 'medigay_channel';
  static const String _channelName = 'Ratq Notifications';
  static const String _channelDescription = 'Notifications for Ratq app';

  bool _isInitialized = false;
  bool _tzReady = false;

  StreamSubscription<QuerySnapshot>? _chatSubscription;
  StreamSubscription<User?>? _authSubscription;
  StreamSubscription<RemoteMessage>? _fgMessageSub;

  GlobalKey<NavigatorState>? _navigatorKey;
  void setNavigatorKey(GlobalKey<NavigatorState> key) => _navigatorKey = key;

  Future<void> init() async {
    if (_isInitialized) return;

    // ✅ timezone init (REQUIRED for zonedSchedule)
    _initTimeZone();

    const AndroidInitializationSettings androidSettings =
    AndroidInitializationSettings('@mipmap/ic_launcher');

    const InitializationSettings initSettings = InitializationSettings(
      android: androidSettings,
    );

    final bool? initResult = await _flutterLocalNotificationsPlugin.initialize(
      initSettings,
      onDidReceiveNotificationResponse: _onNotificationTapped,
    );

    if (initResult == false) {
      throw Exception('FlutterLocalNotificationsPlugin initialization failed');
    }

    await _createNotificationChannel();
    _isInitialized = true;

    _startAuthListener();
    await _initFcm();
  }

  void _initTimeZone() {
    if (_tzReady) return;

    // ✅ initialize TZ database
    tzdata.initializeTimeZones();

    // ✅ Set local timezone.
    // If you want hard-coded Riyadh (fine): tz.setLocalLocation(tz.getLocation('Asia/Riyadh'));
    // Better: use local device timezone (tz.local works after init)
    try {
      tz.setLocalLocation(tz.getLocation('Asia/Riyadh'));
    } catch (_) {
      // fallback to whatever tz.local is
    }

    _tzReady = true;
  }

  Future<void> _initFcm() async {
    final messaging = FirebaseMessaging.instance;

    await messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
      provisional: false,
    );

    final token = await messaging.getToken();
    if (token != null) {
      await _saveFcmToken(token);
    }

    FirebaseMessaging.instance.onTokenRefresh.listen(_saveFcmToken);

    _fgMessageSub?.cancel();
    _fgMessageSub = FirebaseMessaging.onMessage.listen(_handleRemoteMessage);

    FirebaseMessaging.onMessageOpenedApp.listen(_handleRemoteMessage);

    final initialMsg = await FirebaseMessaging.instance.getInitialMessage();
    if (initialMsg != null) {
      _handleRemoteMessage(initialMsg);
    }
  }

  Future<void> _saveFcmToken(String token) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
      'fcm': {
        'token': token,
        'updatedAt': FieldValue.serverTimestamp(),
      }
    }, SetOptions(merge: true));
  }

  void _handleRemoteMessage(RemoteMessage message) async {
    final title = message.notification?.title ?? (message.data['title'] ?? 'Ratq');
    final body = message.notification?.body ?? (message.data['body'] ?? '');
    final payload = message.data['payload'] as String?;

    await showNotification(title: title, body: body, payload: payload);
  }

  Future<void> _createNotificationChannel() async {
    const AndroidNotificationChannel channel = AndroidNotificationChannel(
      _channelId,
      _channelName,
      description: _channelDescription,
      importance: Importance.high,
      playSound: true,
      enableVibration: true,
      showBadge: true,
    );

    await _flutterLocalNotificationsPlugin
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(channel);
  }

  void _onNotificationTapped(NotificationResponse response) async {
    final payload = (response.payload ?? '').trim();
    if (payload.isEmpty) return;

    if (payload.startsWith('whq_case:')) {
      final caseId = payload.replaceFirst('whq_case:', '').trim();
      if (caseId.isEmpty) return;

      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('pending_open_case', true);
      await prefs.setString('pending_open_caseId', caseId);

      final nav = _navigatorKey?.currentState;
      if (nav != null) {
        nav.push(
          MaterialPageRoute(
            builder: (_) => CaseDetailsScreen(caseId: caseId),
          ),
        );

        await prefs.setBool('pending_open_case', false);
        await prefs.remove('pending_open_caseId');
        return;
      }

      if (Platform.isAndroid) {
        final intent = AndroidIntent(
          action: 'android.intent.action.MAIN',
          category: 'android.intent.category.LAUNCHER',
          package: 'com.aidx.health.app',
          componentName: 'com.aidx.health.app.MainActivity',
        );
        await intent.launch();
      }
      return;
    }

    if (payload.contains('fall') || payload.contains('sos')) {
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
    }
  }

  NotificationDetails _notificationDetails({
    bool sounds = true,
    bool vibration = true,
  }) {
    final AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      _channelId,
      _channelName,
      channelDescription: _channelDescription,
      importance: Importance.high,
      priority: Priority.high,
      playSound: sounds,
      enableVibration: vibration,
      showWhen: true,
    );

    return NotificationDetails(android: androidDetails);
  }

  Future<bool> _ensurePermissions() async {
    final status = await Permission.notification.status;
    if (status.isGranted) return true;

    final result = await Permission.notification.request();
    if (!result.isGranted) return false;

    if (Platform.isAndroid) {
      final exactAlarm = await Permission.scheduleExactAlarm.status;
      if (!exactAlarm.isGranted) {
        await Permission.scheduleExactAlarm.request();
      }
    }
    return true;
  }

  Future<void> showNotification({
    required String title,
    required String body,
    String? payload,
  }) async {
    if (!_isInitialized) await init();

    final prefs = await SharedPreferences.getInstance();
    final allow = prefs.getBool('allow_notifications') ?? true;
    if (!allow) return;

    final ok = await _ensurePermissions();
    if (!ok) return;

    final sounds = prefs.getBool('notif_sounds') ?? true;
    final vibration = sounds; // simple link, change if you want

    await _createNotificationChannel();

    final int id = DateTime.now().millisecondsSinceEpoch.remainder(100000);
    await _flutterLocalNotificationsPlugin.show(
      id,
      title,
      body,
      _notificationDetails(sounds: sounds, vibration: vibration),
      payload: payload,
    );
  }

  // ✅ NEW: daily schedule helper used by CaseDetailsScreen
  Future<void> scheduleDailyAtTime({
    required int id,
    required String title,
    required String body,
    required DateTime scheduledTime,
    String? payload,
  }) async {
    await scheduleRecurringNotification(
      id: id,
      title: title,
      body: body,
      scheduledTime: scheduledTime,
      frequency: 'daily',
      payload: payload,
    );
  }

  Future<void> scheduleRecurringNotification({
    required int id, // ✅ stable id from caller
    required String title,
    required String body,
    required DateTime scheduledTime,
    required String frequency, // daily/weekly/monthly
    String? payload,
  }) async {
    if (!_isInitialized) await init();

    final prefs = await SharedPreferences.getInstance();
    final allow = prefs.getBool('allow_notifications') ?? true;
    if (!allow) return;

    final ok = await _ensurePermissions();
    if (!ok) return;

    final sounds = prefs.getBool('notif_sounds') ?? true;
    final vibration = sounds;

    await _createNotificationChannel();

    final tz.TZDateTime tzScheduledTime = tz.TZDateTime.from(scheduledTime, tz.local);

    await _flutterLocalNotificationsPlugin.zonedSchedule(
      id,
      title,
      body,
      tzScheduledTime,
      _notificationDetails(sounds: sounds, vibration: vibration),
      androidAllowWhileIdle: true,
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
      payload: payload,
      matchDateTimeComponents: _getDateTimeComponents(frequency),
    );
  }

  DateTimeComponents? _getDateTimeComponents(String frequency) {
    switch (frequency.toLowerCase()) {
      case 'daily':
        return DateTimeComponents.time;
      case 'weekly':
        return DateTimeComponents.dayOfWeekAndTime;
      case 'monthly':
        return DateTimeComponents.dayOfMonthAndTime;
      default:
        return null;
    }
  }

  void _startAuthListener() {
    _authSubscription?.cancel();
    _authSubscription = FirebaseAuth.instance.authStateChanges().listen((user) {
      _chatSubscription?.cancel();
      if (user != null) _startChatListenerForUser(user.uid);
    });
  }

  void _startChatListenerForUser(String userId) {
    _chatSubscription?.cancel();
    _chatSubscription = FirebaseFirestore.instance
        .collection('chats')
        .where('participants', arrayContains: userId)
        .snapshots()
        .listen((snapshot) async {
      for (final doc in snapshot.docChanges) {
        if (doc.type == DocumentChangeType.modified || doc.type == DocumentChangeType.added) {
          final data = doc.doc.data() as Map<String, dynamic>;
          final lastSenderId = data['lastSenderId'] as String?;
          final lastMessage = data['lastMessage'] as String? ?? '';
          final participants = List<String>.from(data['participants'] ?? []);
          final unreadBy = List<String>.from(data['unreadBy'] ?? []);

          if (lastSenderId != null &&
              lastSenderId != userId &&
              lastMessage.isNotEmpty &&
              unreadBy.contains(userId)) {
            final peerId = participants.firstWhere((id) => id != userId, orElse: () => '');
            String peerName = 'New message';
            if (peerId.isNotEmpty) {
              try {
                final userDoc = await FirebaseFirestore.instance.collection('users').doc(peerId).get();
                final profile = (userDoc.data() ?? {})['profile'] as Map<String, dynamic>?;
                if (profile != null && (profile['name'] as String?)?.isNotEmpty == true) {
                  peerName = profile['name'] as String;
                }
              } catch (_) {}
            }
            await showNotification(title: peerName, body: lastMessage, payload: 'chat');
          }
        }
      }
    });
  }
}