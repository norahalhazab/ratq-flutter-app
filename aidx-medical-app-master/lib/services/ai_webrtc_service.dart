import 'dart:async';

// WebRTC is disabled in this build. This file provides a lightweight
// stub implementation of `AiWebRtcService` so the app can compile
// without the `flutter_webrtc` plugin. Replace with the real
// implementation when you re-enable the dependency.

class AiWebRtcService {
  final StreamController<String> _analysisTextController = StreamController.broadcast();
  Stream<String> get analysisTextStream => _analysisTextController.stream;

  Future<void> initialize() async {}
  Future<void> dispose() async {
    try {
      await _analysisTextController.close();
    } catch (_) {}
  }

  Future<void> startLocalMedia({bool video = true, bool audio = true}) async {}
  Future<void> initializePeerConnection() async {}

  Future<Map<String, String>> createOffer() async {
    return {'type': 'offer', 'sdp': ''};
  }

  Future<void> setRemoteDescription(String sdp, String type) async {}
  void addIceCandidate(dynamic candidate) {}

  Future<void> switchCamera() async {}

  Future<void> connectToGemini({
    required String apiKey,
    String model = 'gemini-2.5-flash',
    String? instructions,
    String? userPrompt,
  }) async {
    // Not available in this build.
    _analysisTextController.add('WebRTC support disabled in this build');
    throw StateError('WebRTC not available in this build');
  }

  Future<void> sendTextPrompt(String text) async {}
}
