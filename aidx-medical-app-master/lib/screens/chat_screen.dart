import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:aidx/services/gemini_service.dart';
import 'package:aidx/services/health_id_service.dart';
import 'package:aidx/models/health_id_model.dart';
import 'package:aidx/utils/app_colors.dart';
import 'package:aidx/utils/theme.dart';
import 'package:aidx/services/timeline_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:async';
import 'dart:ui';

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> with TickerProviderStateMixin {
  final GeminiService _geminiService = GeminiService();
  final HealthIdService _healthIdService = HealthIdService();
  final TimelineService _timelineService = TimelineService();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FlutterTts _flutterTts = FlutterTts();
  final stt.SpeechToText _speech = stt.SpeechToText();
  final ScrollController _scrollController = ScrollController();
  final TextEditingController _textController = TextEditingController();

  List<Map<String, String>> _messages = [];
  bool _isListening = false;
  bool _isSpeaking = false;
  bool _isLoading = false;
  bool _speechEnabled = false;
  bool _handsFreeMode = true; // Hands-free mode enabled by default
  String _conversationContext = "";
  String _currentTranscript = "";
  HealthIdModel? _healthId;
  String _healthContext = "";
  String _timelineContext = "";

  late AnimationController _pulseController;
  late AnimationController _waveController;
  late AnimationController _orbController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _setupAnimations();
    _loadHealthId();
    _initTts();
    _initSpeech();
    
    _loadHealthId();
    _loadTimelineContext();
    _loadChatHistory();
    _initTts();
    _initSpeech();
  }

  Future<void> _loadTimelineContext() async {
    _timelineContext = await _timelineService.getTimelineSummary();
  }

  Future<void> _loadChatHistory() async {
    final user = _auth.currentUser;
    if (user == null) return;

    try {
      final snapshot = await _firestore
          .collection('chat_history')
          .where('userId', isEqualTo: user.uid)
          .orderBy('timestamp', descending: false)
          .limit(100)
          .get();

      if (snapshot.docs.isNotEmpty) {
        setState(() {
          _messages = snapshot.docs.map((doc) {
            return {
              "text": doc['text'] as String,
              "role": doc['role'] as String,
            };
          }).toList();
          
          // Rebuild context from history
          _conversationContext = _messages.map((m) => "${m['role']}: ${m['text']}").join("\n");
        });
        _scrollToBottom();
      } else {
        // Initial greeting if no history
        _addMessage("Hello! I'm Aidx, your medical assistant. I'm listening - how can I help you today?", "ai");
        _speak("Hello! I'm Aidx, your medical assistant. How can I help you today?");
      }
    } catch (e) {
      debugPrint('Error loading chat history: $e');
      // Show initial greeting on error
      _addMessage("Hello! I'm Aidx, your medical assistant. I'm listening - how can I help you today?", "ai");
      _speak("Hello! I'm Aidx, your medical assistant. How can I help you today?");
    }
  }

  Future<void> _loadHealthId() async {
    try {
      final healthId = await _healthIdService.getHealthId();
      if (healthId != null && mounted) {
        setState(() {
          _healthId = healthId;
          _healthContext = _buildHealthContext(healthId);
        });
      }
    } catch (e) {
      debugPrint('Error loading health ID: $e');
    }
  }

  String _buildHealthContext(HealthIdModel healthId) {
    final buffer = StringBuffer();
    buffer.writeln('\n--- PATIENT PROFILE (Digital Health ID) ---');
    buffer.writeln('Name: ${healthId.name}');
    if (healthId.age != null) buffer.writeln('Age: ${healthId.age}');
    if (healthId.bloodGroup != null) buffer.writeln('Blood Group: ${healthId.bloodGroup}');
    
    if (healthId.allergies.isNotEmpty) {
      buffer.writeln('Allergies: ${healthId.allergies.join(", ")}');
    }
    
    if (healthId.activeMedications.isNotEmpty) {
      buffer.writeln('Current Medications: ${healthId.activeMedications.join(", ")}');
    }
    
    if (healthId.medicalConditions != null && healthId.medicalConditions!.isNotEmpty) {
      buffer.writeln('Medical Conditions: ${healthId.medicalConditions}');
    }
    
    if (healthId.notes != null && healthId.notes!.isNotEmpty) {
      buffer.writeln('Additional Notes: ${healthId.notes}');
    }
    
    buffer.writeln('--- END PATIENT PROFILE ---\n');
    return buffer.toString();
  }

  void _setupAnimations() {
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);

    _waveController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat();

    _orbController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat();

    _pulseAnimation = Tween<double>(begin: 0.95, end: 1.05).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  Future<void> _initTts() async {
    await _flutterTts.setLanguage("en-US");
    await _flutterTts.setPitch(1.0);
    await _flutterTts.setSpeechRate(0.5);
    await _flutterTts.awaitSpeakCompletion(true);
    
    _flutterTts.setStartHandler(() {
      if (mounted) setState(() => _isSpeaking = true);
    });

    _flutterTts.setCompletionHandler(() {
      if (mounted) {
        setState(() => _isSpeaking = false);
        // Auto-restart listening in hands-free mode
        if (_handsFreeMode && !_isListening) {
          Future.delayed(const Duration(milliseconds: 500), () {
            if (mounted && _handsFreeMode) _listen();
          });
        }
      }
    });

    _flutterTts.setErrorHandler((msg) {
      if (mounted) setState(() => _isSpeaking = false);
    });
  }

  Future<void> _initSpeech() async {
    _speechEnabled = await _speech.initialize(
      onError: (val) {
        if (mounted) setState(() => _isListening = false);
      },
      onStatus: (val) {
        if (val == 'notListening' && mounted) {
          setState(() => _isListening = false);
          // Auto-restart in hands-free mode if not speaking or loading
          if (_handsFreeMode && !_isSpeaking && !_isLoading) {
            Future.delayed(const Duration(milliseconds: 800), () {
              if (mounted && _handsFreeMode && !_isSpeaking && !_isLoading) {
                _listen();
              }
            });
          }
        }
      },
    );
    
    // Start listening immediately in hands-free mode
    if (_speechEnabled && _handsFreeMode) {
      Future.delayed(const Duration(seconds: 1), () {
        if (mounted && _handsFreeMode) _listen();
      });
    }
    
    setState(() {});
  }

  Future<void> _speak(String text) async {
    if (text.isNotEmpty) {
      await _flutterTts.speak(text);
    }
  }

  Future<void> _stopSpeaking() async {
    await _flutterTts.stop();
    if (mounted) setState(() => _isSpeaking = false);
  }

  void _listen() async {
    if (!_speechEnabled || _isSpeaking || _isLoading) return;

    if (_isListening) {
      await _speech.stop();
      if (mounted) setState(() => _isListening = false);
    } else {
      if (mounted) setState(() => _currentTranscript = "");
      
      try {
        await _speech.listen(
          onResult: (val) {
            if (mounted) {
              setState(() {
                _currentTranscript = val.recognizedWords;
                _textController.text = val.recognizedWords;
              });
              
              if (val.finalResult && val.recognizedWords.trim().isNotEmpty) {
                _sendMessage();
              }
            }
          },
          listenFor: const Duration(seconds: 60),
          pauseFor: const Duration(seconds: 5),
          partialResults: true,
          cancelOnError: false,
          listenMode: stt.ListenMode.dictation,
        );
        
        if (mounted) setState(() => _isListening = true);
      } catch (e) {
        debugPrint("Error starting speech listener: $e");
        if (mounted) setState(() => _isListening = false);
      }
    }
  }

  void _addMessage(String text, String role) {
    if (mounted) {
      setState(() {
        _messages.add({"text": text, "role": role});
      });
      _scrollToBottom();
      
      // Update context
      _conversationContext += "$role: $text\n";
      if (_conversationContext.length > 30000) {
        _conversationContext = _conversationContext.substring(_conversationContext.length - 30000);
      }

      // Persist to Firestore
      final user = _auth.currentUser;
      if (user != null) {
        _firestore.collection('chat_history').add({
          'userId': user.uid,
          'text': text,
          'role': role,
          'timestamp': FieldValue.serverTimestamp(),
        });
      }
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _processTtsQueue(Stream<String> stream) async {
    String buffer = "";
    await for (final chunk in stream) {
      buffer += chunk;
      while (true) {
        final match = RegExp(r'[.?!]').firstMatch(buffer);
        if (match == null) break;
        final end = match.end;
        final sentence = buffer.substring(0, end);
        buffer = buffer.substring(end);
        if (sentence.trim().isNotEmpty) {
          await _speak(sentence.trim());
        }
      }
    }
    if (buffer.trim().isNotEmpty) {
      await _speak(buffer.trim());
    }
  }

  Future<void> _sendMessage() async {
    final text = _textController.text.trim();
    if (text.isEmpty) return;

    _textController.clear();
    if (mounted) setState(() => _currentTranscript = "");
    _addMessage(text, "user");
    
    if (mounted) setState(() => _isLoading = true);
    await _flutterTts.stop();

    try {
      final enrichedContext = _healthContext.isNotEmpty 
          ? '$_healthContext\n$_timelineContext\n$_conversationContext'
          : '$_timelineContext\n$_conversationContext';
      
      _addMessage("", "ai");
      int messageIndex = _messages.length - 1;
      String fullResponse = "";
      
      final StreamController<String> ttsController = StreamController();
      final ttsFuture = _processTtsQueue(ttsController.stream);

      await for (final chunk in _geminiService.streamMessage(text, conversationContext: enrichedContext)) {
        fullResponse += chunk;
        ttsController.add(chunk);
        
        if (mounted) {
          setState(() {
            _messages[messageIndex]["text"] = fullResponse;
          });
          _scrollToBottom();
        }
      }
      
      ttsController.close();
      await ttsFuture;

      _conversationContext += "ai: $fullResponse\n";
    } catch (e) {
      _addMessage("Sorry, I encountered an error. Please try again.", "ai");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _toggleHandsFreeMode() {
    setState(() {
      _handsFreeMode = !_handsFreeMode;
      if (_handsFreeMode && !_isListening && !_isSpeaking && !_isLoading) {
        Future.delayed(const Duration(milliseconds: 300), () {
          if (mounted && _handsFreeMode) _listen();
        });
      } else if (!_handsFreeMode && _isListening) {
        _speech.stop();
      }
    });
  }

  @override
  void dispose() {
    _flutterTts.stop();
    _speech.stop();
    _pulseController.dispose();
    _waveController.dispose();
    _orbController.dispose();
    _textController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bgDark,
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 100,
            floating: true,
            pinned: true,
            backgroundColor: AppTheme.bgDark,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back, color: Colors.white),
              onPressed: () => Navigator.pop(context),
            ),
            actions: [
              IconButton(
                icon: Icon(_handsFreeMode ? Icons.mic : Icons.mic_off, color: Colors.white),
                onPressed: _toggleHandsFreeMode,
              ),
            ],
            flexibleSpace: FlexibleSpaceBar(
              title: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('AI Health Chat', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  if (_isListening || _isSpeaking)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                      decoration: BoxDecoration(
                        color: _isListening ? AppColors.successColor.withOpacity(0.2) : AppColors.accentColor.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: _isListening ? AppColors.successColor : AppColors.accentColor,
                          width: 1,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(
                              color: _isListening ? AppColors.successColor : AppColors.accentColor,
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: (_isListening ? AppColors.successColor : AppColors.accentColor).withOpacity(0.5),
                                  blurRadius: 8,
                                  spreadRadius: 2,
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            _isListening ? 'Listening...' : 'Speaking...',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
              centerTitle: true,
              background: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [AppTheme.primaryColor.withOpacity(0.2), AppTheme.bgDark],
                  ),
                ),
              ),
            ),
          ),
          SliverFillRemaining(
            child: Column(
              children: [
                Expanded(
                  child: Stack(
                    children: [
                      _buildMessagesList(),
                      if (_messages.isEmpty) _buildCenterOrb(),
                    ],
                  ),
                ),
                if (_isLoading) _buildLoadingIndicator(),
                _buildInputArea(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white.withOpacity(0.1)),
              ),
              child: const Icon(Icons.arrow_back_ios_new_rounded,
                  size: 18, color: Colors.white),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Aidx Assistant',
                  style: GoogleFonts.outfit(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    letterSpacing: -0.5,
                  ),
                ),
                Row(
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: _isListening ? AppColors.successColor : AppColors.accentColor,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: (_isListening ? AppColors.successColor : AppColors.accentColor).withOpacity(0.5),
                            blurRadius: 8,
                            spreadRadius: 2,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      _isListening ? 'Listening...' : _isSpeaking ? 'Speaking...' : 'Ready',
                      style: GoogleFonts.outfit(
                        color: Colors.white.withOpacity(0.7),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          GestureDetector(
            onTap: _toggleHandsFreeMode,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: _handsFreeMode 
                    ? AppColors.primaryColor.withOpacity(0.2)
                    : Colors.white.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: _handsFreeMode 
                      ? AppColors.primaryColor
                      : Colors.white.withOpacity(0.1),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    _handsFreeMode ? Icons.hearing : Icons.hearing_disabled,
                    color: _handsFreeMode ? AppColors.primaryColor : Colors.white.withOpacity(0.5),
                    size: 16,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'Hands-Free',
                    style: GoogleFonts.outfit(
                      color: _handsFreeMode ? AppColors.primaryColor : Colors.white.withOpacity(0.5),
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCenterOrb() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Stack(
            alignment: Alignment.center,
            children: [
              // Outer pulsing rings
              ...List.generate(3, (index) {
                return AnimatedBuilder(
                  animation: _pulseController,
                  builder: (context, child) {
                    return Transform.scale(
                      scale: 1.0 + (_pulseController.value * 0.3 * (index + 1)),
                      child: Container(
                        width: 150 + (index * 30.0),
                        height: 150 + (index * 30.0),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: AppColors.primaryColor.withOpacity(
                              (1.0 - _pulseController.value) * 0.3 / (index + 1),
                            ),
                            width: 2,
                          ),
                        ),
                      ),
                    );
                  },
                );
              }),
              // Center orb
              AnimatedBuilder(
                animation: _pulseAnimation,
                builder: (context, child) {
                  return Transform.scale(
                    scale: _pulseAnimation.value,
                    child: Container(
                      width: 120,
                      height: 120,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            AppColors.primaryColor,
                            AppColors.accentColor,
                          ],
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.primaryColor.withOpacity(0.5),
                            blurRadius: 30,
                            spreadRadius: 5,
                          ),
                        ],
                      ),
                      child: BackdropFilter(
                        filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
                        child: Icon(
                          _isListening ? Icons.mic : Icons.graphic_eq,
                          color: Colors.white,
                          size: 50,
                        ),
                      ),
                    ),
                  );
                },
              ),
            ],
          ),
          const SizedBox(height: 30),
          Text(
            _isListening ? 'Listening...' : 'Say something',
            style: GoogleFonts.outfit(
              color: Colors.white.withOpacity(0.9),
              fontSize: 20,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          if (_currentTranscript.isNotEmpty)
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 40),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.1),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.white.withOpacity(0.2)),
              ),
              child: Text(
                _currentTranscript,
                textAlign: TextAlign.center,
                style: GoogleFonts.outfit(
                  color: Colors.white.withOpacity(0.8),
                  fontSize: 14,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildMessagesList() {
    if (_messages.isEmpty) return const SizedBox();
    
    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.all(20),
      itemCount: _messages.length,
      itemBuilder: (context, index) {
        final msg = _messages[index];
        final isUser = msg['role'] == 'user';
        return _buildMessageBubble(msg['text']!, isUser, index);
      },
    );
  }

  Widget _buildMessageBubble(String text, bool isUser, int index) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeOut,
      builder: (context, value, child) {
        return Transform.translate(
          offset: Offset(0, 20 * (1 - value)),
          child: Opacity(
            opacity: value,
            child: child,
          ),
        );
      },
      child: Align(
        alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: 6),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
          constraints: BoxConstraints(
            maxWidth: MediaQuery.of(context).size.width * 0.75,
          ),
          decoration: BoxDecoration(
            gradient: isUser
                ? LinearGradient(
                    colors: [AppColors.primaryColor, AppColors.accentColor],
                  )
                : null,
            color: isUser ? null : Colors.white.withOpacity(0.1),
            borderRadius: BorderRadius.only(
              topLeft: const Radius.circular(20),
              topRight: const Radius.circular(20),
              bottomLeft: Radius.circular(isUser ? 20 : 6),
              bottomRight: Radius.circular(isUser ? 6 : 20),
            ),
            border: Border.all(
              color: isUser ? Colors.transparent : Colors.white.withOpacity(0.1),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Text(
            text,
            style: GoogleFonts.outfit(
              color: Colors.white,
              fontSize: 15,
              height: 1.4,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLoadingIndicator() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              valueColor: AlwaysStoppedAnimation<Color>(AppColors.accentColor),
            ),
          ),
          const SizedBox(width: 12),
          Text(
            'Thinking...',
            style: GoogleFonts.outfit(
              color: Colors.white.withOpacity(0.7),
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInputArea() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.2),
        border: Border(
          top: BorderSide(color: Colors.white.withOpacity(0.1)),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.1),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: Colors.white.withOpacity(0.1)),
              ),
              child: TextField(
                controller: _textController,
                style: GoogleFonts.outfit(color: Colors.white),
                decoration: InputDecoration(
                  hintText: _handsFreeMode ? 'Speak or type...' : 'Type a message...',
                  hintStyle: GoogleFonts.outfit(
                    color: Colors.white.withOpacity(0.4),
                  ),
                  border: InputBorder.none,
                ),
                onSubmitted: (_) => _sendMessage(),
              ),
            ),
          ),
          const SizedBox(width: 12),
          if (!_handsFreeMode)
            GestureDetector(
              onTap: _listen,
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: _isListening
                      ? AppColors.errorColor
                      : Colors.white.withOpacity(0.1),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: _isListening
                        ? AppColors.errorColor
                        : Colors.white.withOpacity(0.2),
                  ),
                  boxShadow: _isListening
                      ? [
                          BoxShadow(
                            color: AppColors.errorColor.withOpacity(0.4),
                            blurRadius: 12,
                            spreadRadius: 2,
                          ),
                        ]
                      : [],
                ),
                child: Icon(
                  _isListening ? Icons.mic : Icons.mic_none,
                  color: Colors.white,
                  size: 24,
                ),
              ),
            ),
          if (_textController.text.isNotEmpty || !_handsFreeMode)
            const SizedBox(width: 8),
          if (_textController.text.isNotEmpty)
            GestureDetector(
              onTap: _sendMessage,
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [AppColors.primaryColor, AppColors.accentColor],
                  ),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primaryColor.withOpacity(0.4),
                      blurRadius: 12,
                      spreadRadius: 2,
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.send_rounded,
                  color: Colors.white,
                  size: 24,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
