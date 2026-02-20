import 'dart:async';
import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class SmartWatchSimulatorService {
  SmartWatchSimulatorService._();
  static final instance = SmartWatchSimulatorService._();

  final _random = Random();
  Timer? _timer;
  bool _connected = false;

  int heartRate = 75;
  double temperature = 36.5;
  String bloodPressure = '116/72';

  final StreamController<void> _streamController =
  StreamController<void>.broadcast();

  Stream<void> get vitalsStream => _streamController.stream;
  bool get isConnected => _connected;

  // ✅ simple throttle to avoid too many writes
  DateTime? _lastUploadAt;
  static const Duration _uploadEvery = Duration(seconds: 6);

  void connect() {
    if (_connected) return;

    _connected = true;

    _timer = Timer.periodic(const Duration(seconds: 2), (_) async {
      heartRate = 70 + _random.nextInt(15);
      temperature = 36 + _random.nextDouble();
      bloodPressure = '${110 + _random.nextInt(10)}/${70 + _random.nextInt(10)}';

      _streamController.add(null);

      // ✅ Save to Firebase (Firestore)
      await _maybeUploadVitals();
    });
  }

  void disconnect() {
    if (!_connected) return;

    _connected = false;

    _timer?.cancel();
    _timer = null;

    _lastUploadAt = null;
    _streamController.add(null);
  }

  Future<void> _maybeUploadVitals() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      final now = DateTime.now();
      if (_lastUploadAt != null &&
          now.difference(_lastUploadAt!) < _uploadEvery) {
        return;
      }
      _lastUploadAt = now;

      final parts = bloodPressure.split('/');
      final sys = (parts.length == 2) ? (int.tryParse(parts[0].trim()) ?? 0) : 0;
      final dia = (parts.length == 2) ? (int.tryParse(parts[1].trim()) ?? 0) : 0;

      final base = FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('vitals');

      final data = <String, dynamic>{
        'heartRate': heartRate,
        'temperature': double.parse(temperature.toStringAsFixed(1)),
        'bloodPressure': bloodPressure,
        'bpSys': sys,
        'bpDia': dia,
        'createdAt': FieldValue.serverTimestamp(),
        'device': 'simulator',
      };

      // 1) current snapshot
      await base.doc('current').set(data, SetOptions(merge: true));

      // 2) history log
      await base.doc('history').collection('items').add(data);
    } catch (_) {
      // keep silent to avoid crashing UI if firestore/auth not ready
    }
  }
}