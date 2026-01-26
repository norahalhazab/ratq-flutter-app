import 'package:flutter/material.dart';
import 'package:aidx/services/gemini_service.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:flutter_tts/flutter_tts.dart';

class VoiceChatScreen extends StatefulWidget {
  final String chatType; // 'emergency', 'consultation', 'general'

  const VoiceChatScreen({
    super.key,
    this.chatType = 'general',
  });

  @override
  State<VoiceChatScreen> createState() => _VoiceChatScreenState();
}

class _VoiceChatScreenState extends State<VoiceChatScreen> {
  final GeminiService _geminiService = GeminiService();
  final stt.SpeechToText _speechToText = stt.SpeechToText();
  final FlutterTts _flutterTts = FlutterTts();
  final TextEditingController _textController = TextEditingController();
  
  final List<Map<String, String>> _messages = [];
  bool _isListening = false;
  bool _isProcessing = false;
  String _recognizedText = '';
  final List<Map<String, String>> _conversationHistory = [];

  @override
  void initState() {
    super.initState();
    _initializeSpeech();
    _initializeTts();
  }

  void _initializeTts() async {
    await _flutterTts.setLanguage("en-US");
    await _flutterTts.setPitch(1.0);
    await _flutterTts.setSpeechRate(0.5);
    await _flutterTts.setVolume(1.0);
    
    // iOS specific configuration for better audio handling
    await _flutterTts.setIosAudioCategory(IosTextToSpeechAudioCategory.playback,
        [
          IosTextToSpeechAudioCategoryOptions.allowBluetooth,
          IosTextToSpeechAudioCategoryOptions.allowBluetoothA2DP,
          IosTextToSpeechAudioCategoryOptions.mixWithOthers,
          IosTextToSpeechAudioCategoryOptions.defaultToSpeaker
        ],
        IosTextToSpeechAudioMode.voicePrompt
    );
  }

  void _initializeSpeech() async {
    await _speechToText.initialize(
      onError: (error) {
        debugPrint('Speech Error: $error');
        _showError('Speech recognition error: $error');
      },
      onStatus: (status) {
        debugPrint('Speech Status: $status');
      },
    );
  }

  void _startListening() async {
    if (!_isListening && _speechToText.isAvailable) {
      await _flutterTts.stop(); // Stop speaking when listening starts
      setState(() => _isListening = true);
      _speechToText.listen(
        onResult: (result) {
          setState(() {
            _recognizedText = result.recognizedWords;
            if (result.finalResult) {
              _textController.text = _recognizedText;
              _isListening = false;
            }
          });
        },
      );
    }
  }

  void _stopListening() async {
    if (_isListening) {
      await _speechToText.stop();
      setState(() => _isListening = false);
    }
  }

  void _sendMessage() async {
    final message = _textController.text.trim();
    if (message.isEmpty) return;

    setState(() {
      _messages.add({'role': 'user', 'content': message});
      _conversationHistory.add({'role': 'user', 'content': message});
      _isProcessing = true;
      _textController.clear();
    });

    try {
      // Build conversation context
      final context = _conversationHistory
          .map((m) => '${m['role']}: ${m['content']}')
          .join('\n');
      
      final response = await _geminiService.sendMessage(
        message,
        conversationContext: context,
      );

      setState(() {
        _messages.add({'role': 'assistant', 'content': response});
        _conversationHistory.add({'role': 'assistant', 'content': response});
      });
      
      await _flutterTts.speak(response);
    } catch (e) {
      _showError('Error: $e');
    } finally {
      setState(() => _isProcessing = false);
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  @override
  void dispose() {
    _textController.dispose();
    _speechToText.stop();
    _flutterTts.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('${widget.chatType[0].toUpperCase()}${widget.chatType.substring(1)} Chat'),
        backgroundColor: Colors.blue.shade700,
      ),
      body: Column(
        children: [
          // Chat messages
          Expanded(
            child: _messages.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.chat_bubble_outline,
                          size: 64,
                          color: Colors.grey.shade400,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Start a conversation',
                          style: TextStyle(
                            fontSize: 18,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    itemCount: _messages.length,
                    itemBuilder: (context, index) {
                      final msg = _messages[index];
                      final isUser = msg['role'] == 'user';
                      return Align(
                        alignment:
                            isUser ? Alignment.centerRight : Alignment.centerLeft,
                        child: Container(
                          margin: const EdgeInsets.all(8),
                          padding: const EdgeInsets.all(12),
                          constraints: BoxConstraints(
                            maxWidth: MediaQuery.of(context).size.width * 0.8,
                          ),
                          decoration: BoxDecoration(
                            color: isUser
                                ? Colors.blue.shade600
                                : Colors.grey.shade300,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            msg['content'] ?? '',
                            style: TextStyle(
                              color: isUser ? Colors.white : Colors.black87,
                            ),
                          ),
                        ),
                      );
                    },
                  ),
          ),

          // Input area
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.grey.withOpacity(0.1),
                  blurRadius: 8,
                )
              ],
            ),
            child: Column(
              children: [
                if (_recognizedText.isNotEmpty)
                  Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.blue.shade50,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      'Recognized: $_recognizedText',
                      style: const TextStyle(fontSize: 14),
                    ),
                  ),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _textController,
                        decoration: InputDecoration(
                          hintText: 'Type or speak...',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          suffixIcon: _isListening
                              ? const Icon(Icons.mic, color: Colors.red)
                              : null,
                        ),
                        enabled: !_isProcessing,
                      ),
                    ),
                    const SizedBox(width: 8),
                    GestureDetector(
                      onLongPress: _startListening,
                      onLongPressUp: _stopListening,
                      child: Container(
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: _isListening ? Colors.red : Colors.blue,
                        ),
                        padding: const EdgeInsets.all(12),
                        child: Icon(
                          _isListening ? Icons.mic : Icons.mic_none,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton.icon(
                      onPressed: _isProcessing ? null : _sendMessage,
                      icon: _isProcessing
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor:
                                    AlwaysStoppedAnimation<Color>(Colors.white),
                              ),
                            )
                          : const Icon(Icons.send),
                      label: const Text('Send'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
