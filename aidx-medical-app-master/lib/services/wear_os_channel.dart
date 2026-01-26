import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';

class LiveVitalsData {
  final int? heartRate;
  final int? spo2;
  final int? bpSystolic;
  final int? bpDiastolic;

  const LiveVitalsData({this.heartRate, this.spo2, this.bpSystolic, this.bpDiastolic});
}

class WearOsChannel {
  static const MethodChannel _channel = MethodChannel('com.example.wearos/data');
  static final ValueNotifier<LiveVitalsData?> vitalsNotifier = ValueNotifier<LiveVitalsData?>(null);

  static void init() {
    _channel.setMethodCallHandler((call) async {
      if (call.method == 'liveVitals') {
        try {
          final String payload = call.arguments as String;
          final Map<String, dynamic> data = jsonDecode(payload) as Map<String, dynamic>;
          vitalsNotifier.value = LiveVitalsData(
            heartRate: _toIntOrNull(data['heartRate']),
            spo2: _toIntOrNull(data['spo2']),
            bpSystolic: _toIntOrNull(data['bpSystolic']),
            bpDiastolic: _toIntOrNull(data['bpDiastolic']),
          );
        } catch (_) {
          // ignore malformed payload
        }
      }
    });
  }

  static int? _toIntOrNull(dynamic v) {
    if (v == null) return null;
    if (v is int) return v;
    if (v is double) return v.round();
    try { return int.parse(v.toString()); } catch (_) { return null; }
  }
}