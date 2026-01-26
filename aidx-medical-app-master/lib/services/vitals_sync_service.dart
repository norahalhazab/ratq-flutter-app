import 'dart:async';
import 'package:aidx/services/firebase_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
// BLE removed per requirement; syncing only via Firestore and manual entry

class VitalsSyncService extends ChangeNotifier {
  VitalsSyncService({FirebaseService? firebaseService})
      : _firebaseService = firebaseService ?? FirebaseService();

  final FirebaseService _firebaseService;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  String _status = '';
  bool _isSyncing = false;
  int? _lastHr;
  int? _lastSpo2;
  String? _lastBp; // "SYS/DIA"
  String _connectionStatus = 'Unknown';

  String get status => _status;
  bool get isSyncing => _isSyncing;
  int? get lastHr => _lastHr;
  int? get lastSpo2 => _lastSpo2;
  String? get lastBp => _lastBp;
  String get connectionStatus => _connectionStatus;

  void _setStatus(String s) {
    _status = s;
    notifyListeners();
  }

  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _controlSub;

  // Start listening to watch control doc to reflect connection status
  void startWatchControlListener() {
    final user = _auth.currentUser;
    _controlSub?.cancel();
    if (user == null) return;
    _controlSub = FirebaseFirestore.instance
        .collection('watch_control')
        .doc(user.uid)
        .snapshots()
        .listen((doc) {
      final data = doc.data();
      if (data == null) {
        _connectionStatus = 'Watch Disconnected';
        notifyListeners();
        return;
      }
      final bool watchOnline = (data['watch_online'] as bool?) ?? false;
      final ts = data['watch_ack_at'];
      if (watchOnline && ts is Timestamp) {
        final diff = DateTime.now().difference(ts.toDate()).inSeconds;
        _connectionStatus = diff < 30 ? 'Watch Connected' : 'Watch Disconnected (No recent ack)';
      } else {
        _connectionStatus = 'Watch Disconnected';
      }
      notifyListeners();
    });
  }

  // Trigger connection request for the watch to acknowledge
  Future<void> requestConnection() async {
    final user = _auth.currentUser;
    if (user == null) {
      _setStatus('Not signed in');
      return;
    }
    _connectionStatus = 'Connecting…';
    notifyListeners();
    try {
      await FirebaseFirestore.instance.collection('watch_control').doc(user.uid).set({
        'userId': user.uid,
        'phone_online': true,
        'connect_request_at': Timestamp.now(),
      }, SetOptions(merge: true));
      _setStatus('Connect request sent');
    } catch (e) {
      _setStatus('Connect request failed');
      _connectionStatus = 'Connection Error';
      notifyListeners();
    }
  }

  Future<void> syncFromFirestore() async {
    final user = _auth.currentUser;
    if (user == null) {
      _setStatus('Not signed in');
      return;
    }
    _isSyncing = true;
    _setStatus('Syncing…');
    try {
      final data = await _firebaseService.getLatestVitalsOnce(user.uid);
      if (data == null || (!data.containsKey('heart_rate') && !data.containsKey('spo2') && !data.containsKey('blood_pressure'))) {
        _setStatus('No data in cloud');
        _connectionStatus = 'Watch Disconnected';
      } else {
        _lastHr = (data['heart_rate'] as num?)?.toInt();
        _lastSpo2 = (data['spo2'] as num?)?.toInt();
        _lastBp = data['blood_pressure']?.toString();
        
        // Check if data is recent (within last 30 seconds for demo)
        final timestamp = data['timestamp'];
        if (timestamp != null) {
          final dataTime = (timestamp as Timestamp).toDate();
          final now = DateTime.now();
          final diff = now.difference(dataTime).inSeconds;
          
          if (diff < 30) {
            _connectionStatus = 'Watch Connected';
            _setStatus('Sync Successful');
          } else {
            _connectionStatus = 'Watch Disconnected (Old Data)';
            _setStatus('Sync Successful (Old Data)');
          }
        } else {
          _connectionStatus = 'Watch Disconnected';
          _setStatus('Sync Successful');
        }
      }
    } catch (e) {
      _setStatus('Sync Failed');
      _connectionStatus = 'Connection Error';
    } finally {
      _isSyncing = false;
      notifyListeners();
    }
  }

  Future<void> submitManual({required int? hr, required int? spo2, required int? sys, required int? dia}) async {
    final user = _auth.currentUser;
    if (user == null) {
      _setStatus('Not signed in');
      return;
    }
    final String? bp = (sys != null && dia != null) ? '$sys/$dia' : null;
    try {
      await _firebaseService.setLatestVitals(
        userId: user.uid,
        heartRate: hr,
        spo2: spo2,
        bloodPressure: bp,
        source: 'manual',
      );
      _lastHr = hr;
      _lastSpo2 = spo2;
      _lastBp = bp;
      _setStatus('Manual Save Successful');
    } catch (e) {
      _setStatus('Manual Save Failed');
    }
  }

  // BLE functionality removed per requirement.
}

