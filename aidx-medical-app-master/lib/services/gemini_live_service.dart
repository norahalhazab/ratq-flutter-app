import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter_sound/flutter_sound.dart';
import 'package:audio_session/audio_session.dart';
import 'package:flutter/foundation.dart';
import 'package:camera/camera.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:aidx/models/conversation_state.dart';
import '../utils/constants.dart';

class GeminiLiveService {
  static String get _apiKey => AppConstants.geminiApiKey;
  static const String _model = 'gemini-2.0-flash-exp';

  // Camera
  CameraController? _cameraController;
  List<CameraDescription>? _cameras;
  Timer? _videoStreamTimer;

  // Audio
  final FlutterSoundRecorder _recorder = FlutterSoundRecorder();
  final FlutterSoundPlayer _player = FlutterSoundPlayer();
  StreamSubscription? _recorderSubscription;
  bool _isRecording = false;
  bool _isPlaying = false;

  // WebSocket
  WebSocket? _ws;
  bool _isConnected = false;

  // Conversation State Management
  ConversationStateData _currentState = ConversationStateData(state: ConversationState.idle);
  final StreamController<ConversationStateData> _stateController = StreamController.broadcast();
  
  // Audio feedback
  final StreamController<double> _volumeController = StreamController.broadcast();
  
  // Response tracking
  bool _expectingResponse = false;
  Timer? _responseTimeout;

  // Getters
  CameraController? get cameraController => _cameraController;
  bool get isConnected => _isConnected;
  Stream<ConversationStateData> get stateStream => _stateController.stream;
  Stream<double> get volumeStream => _volumeController.stream;
  ConversationState get currentState => _currentState.state;

  Future<void> initialize() async {
    _cameras = await availableCameras();
    
    final session = await AudioSession.instance;
    await session.configure(AudioSessionConfiguration(
      avAudioSessionCategory: AVAudioSessionCategory.playAndRecord,
      avAudioSessionCategoryOptions: AVAudioSessionCategoryOptions.allowBluetooth | 
                                     AVAudioSessionCategoryOptions.defaultToSpeaker |
                                     AVAudioSessionCategoryOptions.allowAirPlay,
      avAudioSessionMode: AVAudioSessionMode.videoChat,
      avAudioSessionRouteSharingPolicy: AVAudioSessionRouteSharingPolicy.defaultPolicy,
      avAudioSessionSetActiveOptions: AVAudioSessionSetActiveOptions.none,
      androidAudioAttributes: const AndroidAudioAttributes(
        contentType: AndroidAudioContentType.speech,
        flags: AndroidAudioFlags.none,
        usage: AndroidAudioUsage.voiceCommunication,
      ),
      androidAudioFocusGainType: AndroidAudioFocusGainType.gain,
      androidWillPauseWhenDucked: true,
    ));

    await _recorder.openRecorder();
    await _player.openPlayer();
    await _recorder.setSubscriptionDuration(const Duration(milliseconds: 100));
  }

  Future<void> dispose() async {
    await disconnect();
    await _recorder.closeRecorder();
    await _player.closePlayer();
    await _stateController.close();
    await _volumeController.close();
    await _cameraController?.dispose();
  }

  void _updateState(ConversationState newState, {String? message}) {
    _currentState = ConversationStateData(
      state: newState,
      message: message,
    );
    _stateController.add(_currentState);
    debugPrint('State: ${newState.name}${message != null ? ' - $message' : ''}');
  }

  Future<void> startCamera() async {
    if (_cameras == null || _cameras!.isEmpty) return;

    final camera = _cameras!.firstWhere(
      (c) => c.lensDirection == CameraLensDirection.front,
      orElse: () => _cameras!.first,
    );

    _cameraController = CameraController(
      camera,
      ResolutionPreset.medium,
      enableAudio: false,
      imageFormatGroup: ImageFormatGroup.jpeg,
    );

    await _cameraController!.initialize();
    if (_cameraController!.value.isInitialized) {
      await _cameraController!.setFocusMode(FocusMode.auto);
      await _cameraController!.setExposureMode(ExposureMode.auto);
    }
  }

  Future<void> connect() async {
    if (_isConnected) return;

    try {
      _updateState(ConversationState.connecting, message: 'Establishing connection...');
      
      final uri = Uri.parse(
        'wss://generativelanguage.googleapis.com/ws/google.ai.generativelanguage.v1alpha.GenerativeService.BidiGenerateContent?key=$_apiKey'
      );
      
      _ws = await WebSocket.connect(uri.toString());
      _isConnected = true;

      await _sendSetupMessage();

      _ws!.listen(
        _handleWebSocketMessage,
        onError: (error) {
           debugPrint('WebSocket stream error: $error');
           _handleWebSocketError(error);
        },
        onDone: () {
           debugPrint('WebSocket stream closed');
           _handleWebSocketDone();
        },
        cancelOnError: true,
      );

      // Wait a moment for setup to complete
      await Future.delayed(const Duration(milliseconds: 500));
      
    } catch (e) {
      _isConnected = false;
      String errorMessage = 'Connection failed: $e';
      if (e.toString().contains('403') || e.toString().contains('401')) {
         errorMessage = 'Authentication failed. Please check API key.';
      } else if (e.toString().contains('429')) {
         errorMessage = 'Connection limit exceeded. Please try again later.';
      }
      _updateState(ConversationState.error, message: errorMessage);
      rethrow;
    }
  }

  Future<void> _sendSetupMessage() async {
    if (_ws == null || !_isConnected) return;

    final setupMessage = {
      'setup': {
        'model': 'models/$_model',
        'generation_config': {
          'response_modalities': ['AUDIO'],
          'speech_config': {
            'voice_config': {'prebuilt_voice_config': {'voice_name': 'Puck'}}
          }
        },
        'system_instruction': {
          'parts': [{
            'text': 'You are Aidx, a helpful medical AI assistant. Keep responses concise and natural for voice conversation. Speak clearly and empathetically.'
          }]
        }
      }
    };

    _ws!.add(jsonEncode(setupMessage));
  }

  Future<void> _handleWebSocketMessage(dynamic data) async {
    try {
      final response = jsonDecode(data as String);

      if (response.containsKey('setupComplete')) {
        debugPrint('Setup complete');
        return;
      }

      if (response.containsKey('serverContent')) {
        final content = response['serverContent'];
        
        // Handle interruption
        if (content['interrupted'] == true) {
          debugPrint('AI interrupted');
          await _stopPlayback();
          await _startListening();
          return;
        }

        // Handle model turn (AI response)
        if (content['modelTurn'] != null) {
          final parts = content['modelTurn']['parts'] as List?;
          
          if (parts != null && parts.isNotEmpty) {
            // Transition to speaking if not already
            if (_currentState.state != ConversationState.speaking) {
              _updateState(ConversationState.speaking, message: 'AI responding...');
              await _startPlayback();
            }

            // Process audio chunks
            for (final part in parts) {
              if (part['inlineData'] != null) {
                final inlineData = part['inlineData'];
                if (inlineData['mimeType'] == 'audio/pcm;rate=24000') {
                  final base64Audio = inlineData['data'] as String;
                  final bytes = base64Decode(base64Audio);
                  
                  if (_isPlaying && _player.isPlaying) {
                    await _player.feedFromStream(bytes);
                  }
                }
              }
            }
          }

          // Check if turn is complete
          if (content['turnComplete'] == true) {
            debugPrint('Turn complete - returning to listening');
            _responseTimeout?.cancel();
            
            // Give a moment for audio to finish
            await Future.delayed(const Duration(milliseconds: 500));
            await _stopPlayback();
            await _startListening();
          }
        }
      }
    } catch (e) {
      debugPrint('Error parsing message: $e');
    }
  }

  void _handleWebSocketError(Object error) {
    debugPrint('WebSocket error: $error');
    _isConnected = false;
    _updateState(ConversationState.error, message: 'Connection error');
  }

  void _handleWebSocketDone() {
    debugPrint('WebSocket closed');
    _isConnected = false;
    if (_currentState.state != ConversationState.error) {
      _updateState(ConversationState.idle, message: 'Disconnected');
    }
  }

  Future<void> _startListening() async {
    if (!_isConnected) return;
    
    _updateState(ConversationState.listening, message: 'Listening...');
    _expectingResponse = false;
    
    if (!_isRecording) {
      await _startRecording();
    }
  }

  Future<void> _startRecording() async {
    if (_isRecording) return;

    var status = await Permission.microphone.request();
    if (status != PermissionStatus.granted) {
      _updateState(ConversationState.error, message: 'Microphone permission denied');
      return;
    }

    _isRecording = true;

    final stream = StreamController<Uint8List>();
    _recorderSubscription = stream.stream.listen((data) {
      if (!_isRecording || !_isConnected) return;
      
      // Calculate volume for visualizer
      double volume = 0;
      for (int i = 0; i < data.length; i += 2) {
        if (i + 1 < data.length) {
          int sample = (data[i + 1] << 8) | data[i];
          if (sample > 32767) sample -= 65536;
          volume += sample.abs();
        }
      }
      volume = (volume / (data.length / 2)) / 32768.0;
      _volumeController.add(volume.clamp(0.0, 1.0));

      _sendAudioChunk(data);
    });

    await _recorder.startRecorder(
      toStream: stream.sink,
      codec: Codec.pcm16,
      numChannels: 1,
      sampleRate: 16000,
    );
  }

  Future<void> _stopRecording() async {
    if (!_isRecording) return;
    
    _isRecording = false;
    await _recorder.stopRecorder();
    await _recorderSubscription?.cancel();
    _recorderSubscription = null;
    _volumeController.add(0.0);
  }

  Future<void> _startPlayback() async {
    if (_isPlaying) return;
    
    _isPlaying = true;
    await _player.startPlayerFromStream(
      codec: Codec.pcm16,
      numChannels: 1,
      sampleRate: 24000,
      bufferSize: 4096,
      interleaved: false,
    );
  }

  Future<void> _stopPlayback() async {
    if (!_isPlaying) return;
    
    _isPlaying = false;
    await _player.stopPlayer();
  }

  Future<void> _sendAudioChunk(Uint8List data) async {
    if (_ws == null || _ws!.closeCode != null) return;
    
    try {
      final base64Audio = base64Encode(data);
      final message = {
        'realtime_input': {
          'media_chunks': [{
            'inline_data': {
              'mime_type': 'audio/pcm',
              'data': base64Audio
            }
          }]
        }
      };
      _ws!.add(jsonEncode(message));
    } catch (e) {
      debugPrint('Send audio error: $e');
    }
  }

  Future<void> startVideoStream() async {
    if (!_isConnected || _cameraController == null) return;

    _videoStreamTimer = Timer.periodic(const Duration(milliseconds: 2000), (timer) async {
      if (!_isConnected) {
        timer.cancel();
        return;
      }
      await _sendVideoFrame();
    });
  }

  Future<void> _sendVideoFrame() async {
    if (_cameraController == null || !_cameraController!.value.isInitialized) return;

    try {
      final image = await _cameraController!.takePicture();
      final bytes = await image.readAsBytes();
      final base64Image = base64Encode(bytes);

      final message = {
        'realtime_input': {
          'media_chunks': [{
            'inline_data': {
              'mime_type': 'image/jpeg',
              'data': base64Image
            }
          }]
        }
      };
      _ws!.add(jsonEncode(message));
    } catch (e) {
      debugPrint('Video frame error: $e');
    }
  }

  Future<void> stopVideoStream() async {
    _videoStreamTimer?.cancel();
    _videoStreamTimer = null;
  }

  Future<void> disconnect() async {
    _responseTimeout?.cancel();
    await _stopRecording();
    await _stopPlayback();
    await stopVideoStream();
    
    _isConnected = false;
    await _ws?.close();
    _ws = null;
    
    _updateState(ConversationState.idle);
  }

  // Public API
  Future<void> startLocalMedia({bool video = true, bool audio = true}) async {
    if (video) await startCamera();
  }

  Future<void> connectToGeminiLive({bool enableVision = true, bool enableVoice = true}) async {
    await connect();
    
    if (enableVoice) {
      await _startListening();
    }
    
    if (enableVision) {
      await startVideoStream();
    }
  }

  Future<void> enableVoice(bool enable) async {
    if (enable) {
      await _startListening();
    } else {
      await _stopRecording();
    }
  }

  Future<void> enableVision(bool enable) async {
    if (enable) {
      await startVideoStream();
    } else {
      await stopVideoStream();
    }
  }

  // Compatibility methods for chat_screen
  Stream<String> get responseStream => const Stream.empty();
  
  Future<void> sendImageAndText({required String text}) async {
    // Not implemented in new architecture
    debugPrint('sendImageAndText called with: $text');
  }
  
  Future<void> toggleCamera() async {
    // Not implemented - camera is always front-facing now
    debugPrint('toggleCamera called');
  }
}