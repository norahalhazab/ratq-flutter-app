import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:flutter_feather_icons/flutter_feather_icons.dart';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui';
import 'dart:math' as math;
import '../utils/theme.dart';
import '../services/gemini_service.dart';
import '../widgets/glass_container.dart';

class FirstAidScreen extends StatefulWidget {
  const FirstAidScreen({super.key});

  @override
  State<FirstAidScreen> createState() => _FirstAidScreenState();
}

class _FirstAidScreenState extends State<FirstAidScreen> with TickerProviderStateMixin {
  CameraController? _cameraController;
  List<CameraDescription>? _cameras;
  bool _isCameraInitialized = false;
  bool _isAnalyzing = false;
  Map<String, dynamic>? _analysisResult;
  final TextEditingController _situationController = TextEditingController();
  final GeminiService _geminiService = GeminiService();
  File? _capturedImage;

  // Animations
  late AnimationController _scanController;
  late AnimationController _bgController;

  @override
  void initState() {
    super.initState();
    _initializeCamera();
    _scanController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);

    _bgController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 10),
    )..repeat();
  }

  Future<void> _initializeCamera() async {
    try {
      _cameras = await availableCameras();
      if (_cameras != null && _cameras!.isNotEmpty) {
        _cameraController = CameraController(
          _cameras![0],
          ResolutionPreset.high,
          enableAudio: false,
          imageFormatGroup: ImageFormatGroup.jpeg,
        );
        await _cameraController!.initialize();
        if (mounted) {
          setState(() {
            _isCameraInitialized = true;
          });
        }
      }
    } catch (e) {
      debugPrint('Error initializing camera: $e');
    }
  }

  Future<void> _capturePhoto() async {
    if (_cameraController == null || !_cameraController!.value.isInitialized) {
      return;
    }

    try {
      final image = await _cameraController!.takePicture();
      setState(() {
        _capturedImage = File(image.path);
      });
    } catch (e) {
      debugPrint('Error capturing photo: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to capture photo: ${e.toString()}'),
            backgroundColor: AppTheme.dangerColor,
          ),
        );
      }
    }
  }

  Future<void> _analyzeWithGemini() async {
    if (_situationController.text.trim().isEmpty && _capturedImage == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please describe the situation or take a photo'),
          backgroundColor: AppTheme.warningColor,
        ),
      );
      return;
    }

    setState(() {
      _isAnalyzing = true;
      _analysisResult = null;
    });

    try {
      Uint8List? imageBytes;
      if (_capturedImage != null) {
        imageBytes = await _capturedImage!.readAsBytes();
      }

      final response = await _geminiService.getEmergencyFirstAid(
        situation: _situationController.text.trim(),
        imageBytes: imageBytes,
      );

      final result = _geminiService.parseFirstAidResponse(response);

      if (mounted) {
        setState(() {
          _analysisResult = result;
          _isAnalyzing = false;
        });
      }
    } catch (e) {
      debugPrint('Error analyzing with Gemini: $e');
      if (mounted) {
        setState(() {
          _analysisResult = _createErrorResponse(e.toString());
          _isAnalyzing = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Analysis failed: ${e.toString()}'),
            backgroundColor: AppTheme.dangerColor,
          ),
        );
      }
    }
  }

  Map<String, dynamic> _createErrorResponse(String error) {
    return {
      'severity': 'unknown',
      'condition': 'Unable to analyze',
      'immediateActions': [
        'Call emergency services: 911 or local emergency number',
        'Keep the person calm and comfortable',
        'Monitor breathing and consciousness',
      ],
      'warnings': [
        'Analysis failed',
        'Please seek immediate professional medical help',
      ],
      'whenToSeekHelp': 'Seek immediate medical attention',
      'additionalTips': [
        'Do not attempt complex procedures without training',
      ],
    };
  }

  @override
  void dispose() {
    _cameraController?.dispose();
    _situationController.dispose();
    _capturedImage?.delete().catchError((_) {});
    _scanController.dispose();
    _bgController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bgDark,
      body: Stack(
        children: [
          _buildAnimatedBackground(),
          SafeArea(
            child: Column(
              children: [
                _buildHeader(),
                Expanded(
                  child: SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildCameraSection(),
                        const SizedBox(height: 24),
                        _buildSituationInput(),
                        const SizedBox(height: 24),
                        _buildAnalyzeButton(),
                        if (_analysisResult != null) ...[
                          const SizedBox(height: 32),
                          _buildResultCard(),
                        ],
                        const SizedBox(height: 60),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAnimatedBackground() {
    return AnimatedBuilder(
      animation: _bgController,
      builder: (context, child) {
        return Stack(
          children: [
            Container(color: AppTheme.bgDark),
            Positioned(
              top: -100 + (math.sin(_bgController.value * 2 * math.pi) * 50),
              right: -50 + (math.cos(_bgController.value * 2 * math.pi) * 30),
              child: _buildBlob(300, AppTheme.primaryColor.withOpacity(0.15)),
            ),
            Positioned(
              bottom: 100 + (math.cos(_bgController.value * 2 * math.pi) * 60),
              left: -80 + (math.sin(_bgController.value * 2 * math.pi) * 40),
              child: _buildBlob(250, AppTheme.accentColor.withOpacity(0.1)),
            ),
            Positioned.fill(
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 80, sigmaY: 80),
                child: Container(color: Colors.transparent),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildBlob(double size, Color color) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color,
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.05),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.white.withOpacity(0.1)),
              ),
              child: const Icon(FeatherIcons.chevronLeft, color: Colors.white, size: 24),
            ),
          ),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'AI First Aid',
                  style: TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                    fontFamily: 'Montserrat',
                    letterSpacing: -0.5,
                  ),
                ),
                Text(
                  'Intelligent Emergency Guide',
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.white.withOpacity(0.5),
                    fontFamily: 'Montserrat',
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          _buildSOSBadge(),
        ],
      ),
    );
  }

  Widget _buildSOSBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [AppTheme.dangerColor.withOpacity(0.3), AppTheme.dangerColor.withOpacity(0.1)],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.dangerColor.withOpacity(0.4)),
        boxShadow: [
          BoxShadow(
            color: AppTheme.dangerColor.withOpacity(0.2),
            blurRadius: 10,
            spreadRadius: -2,
          ),
        ],
      ),
      child: Row(
        children: [
          const Icon(FeatherIcons.alertCircle, color: AppTheme.dangerColor, size: 18),
          const SizedBox(width: 8),
          const Text(
            'SOS',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              color: Colors.white,
              fontFamily: 'Montserrat',
              letterSpacing: 1,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCameraSection() {
    return Container(
      height: 380,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(32),
        border: Border.all(color: Colors.white.withOpacity(0.15), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.4),
            blurRadius: 30,
            offset: const Offset(0, 15),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(32),
        child: Stack(
          children: [
            if (_capturedImage != null)
              Positioned.fill(child: Image.file(_capturedImage!, fit: BoxFit.cover))
            else if (_isCameraInitialized && _cameraController != null)
              Positioned.fill(child: CameraPreview(_cameraController!))
            else
              _buildCameraPlaceholder(),
            
            if (_isCameraInitialized && _capturedImage == null) _buildScanningLine(),
            
            _buildCameraOverlay(),
            _buildCameraControls(),
          ],
        ),
      ),
    );
  }

  Widget _buildCameraPlaceholder() {
    return Container(
      color: Colors.black45,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.05),
                shape: BoxShape.circle,
              ),
              child: Icon(FeatherIcons.camera, size: 48, color: Colors.white.withOpacity(0.3)),
            ),
            const SizedBox(height: 16),
            Text(
              'Initializing Camera...',
              style: TextStyle(
                color: Colors.white.withOpacity(0.5),
                fontFamily: 'Montserrat',
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildScanningLine() {
    return AnimatedBuilder(
      animation: _scanController,
      builder: (context, child) {
        return Positioned(
          top: _scanController.value * 380,
          left: 0,
          right: 0,
          child: Container(
            height: 2,
            decoration: BoxDecoration(
              boxShadow: [
                BoxShadow(
                  color: AppTheme.accentColor.withOpacity(0.8),
                  blurRadius: 15,
                  spreadRadius: 2,
                ),
              ],
              gradient: LinearGradient(
                colors: [
                  Colors.transparent,
                  AppTheme.accentColor.withOpacity(0.5),
                  AppTheme.accentColor,
                  AppTheme.accentColor.withOpacity(0.5),
                  Colors.transparent,
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildCameraOverlay() {
    return Positioned(
      top: 20,
      left: 20,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.6),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white.withOpacity(0.1)),
        ),
        child: Row(
          children: [
            _buildStatusDot(),
            const SizedBox(width: 10),
            Text(
              _capturedImage != null ? 'CAPTURED' : 'LIVE SCAN',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 11,
                fontWeight: FontWeight.w800,
                fontFamily: 'Montserrat',
                letterSpacing: 1,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusDot() {
    return Container(
      width: 8,
      height: 8,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: _capturedImage != null ? AppTheme.successColor : AppTheme.dangerColor,
        boxShadow: [
          BoxShadow(
            color: (_capturedImage != null ? AppTheme.successColor : AppTheme.dangerColor).withOpacity(0.6),
            blurRadius: 8,
            spreadRadius: 2,
          ),
        ],
      ),
    );
  }

  Widget _buildCameraControls() {
    return Positioned(
      bottom: 25,
      left: 0,
      right: 0,
      child: Center(
        child: _capturedImage != null ? _buildRetakeButton() : _buildCaptureButton(),
      ),
    );
  }

  Widget _buildRetakeButton() {
    return GestureDetector(
      onTap: () {
        setState(() {
          _capturedImage?.delete().catchError((_) {});
          _capturedImage = null;
          _analysisResult = null;
        });
      },
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.15),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.white.withOpacity(0.2)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: const [
                Icon(FeatherIcons.refreshCw, color: Colors.white, size: 20),
                SizedBox(width: 10),
                Text(
                  'Retake Photo',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontFamily: 'Montserrat',
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCaptureButton() {
    return GestureDetector(
      onTap: _isCameraInitialized ? _capturePhoto : null,
      child: Container(
        width: 80,
        height: 80,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white.withOpacity(0.3), width: 4),
        ),
        child: Container(
          margin: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [AppTheme.dangerColor, const Color(0xFFE91E63)],
            ),
            boxShadow: [
              BoxShadow(
                color: AppTheme.dangerColor.withOpacity(0.5),
                blurRadius: 20,
                spreadRadius: 2,
              ),
            ],
          ),
          child: const Icon(FeatherIcons.camera, color: Colors.white, size: 32),
        ),
      ),
    );
  }

  Widget _buildSituationInput() {
    return GlassContainer(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppTheme.accentColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(FeatherIcons.edit3, color: AppTheme.accentColor, size: 18),
              ),
              const SizedBox(width: 12),
              const Text(
                'Describe the Situation',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                  fontFamily: 'Montserrat',
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _situationController,
            maxLines: 4,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 15,
              fontFamily: 'Montserrat',
              height: 1.4,
            ),
            decoration: InputDecoration(
              hintText: 'What happened? Any visible injuries or symptoms?',
              hintStyle: TextStyle(color: Colors.white.withOpacity(0.3), fontSize: 14),
              filled: true,
              fillColor: Colors.black.withOpacity(0.2),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(18),
                borderSide: BorderSide.none,
              ),
              contentPadding: const EdgeInsets.all(18),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(18),
                borderSide: BorderSide(color: AppTheme.accentColor.withOpacity(0.3)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAnalyzeButton() {
    return GestureDetector(
      onTap: _isAnalyzing ? null : _analyzeWithGemini,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 20),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: _isAnalyzing
                ? [Colors.grey.withOpacity(0.3), Colors.grey.withOpacity(0.2)]
                : [AppTheme.primaryColor, AppTheme.accentColor],
          ),
          borderRadius: BorderRadius.circular(22),
          boxShadow: _isAnalyzing
              ? []
              : [
                  BoxShadow(
                    color: AppTheme.primaryColor.withOpacity(0.4),
                    blurRadius: 25,
                    offset: const Offset(0, 10),
                  ),
                ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (_isAnalyzing)
              const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(strokeWidth: 3, color: Colors.white),
              )
            else
              const Icon(FeatherIcons.zap, color: Colors.white, size: 22),
            const SizedBox(width: 12),
            Text(
              _isAnalyzing ? 'ANALYZING...' : 'ANALYZE SITUATION',
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w900,
                color: Colors.white,
                fontFamily: 'Montserrat',
                letterSpacing: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildResultCard() {
    if (_analysisResult == null) return const SizedBox.shrink();

    final severity = _analysisResult!['severity'] ?? 'unknown';
    final condition = _analysisResult!['condition'] ?? 'Unknown';
    final immediateActions = _analysisResult!['immediateActions'] as List? ?? [];
    final warnings = _analysisResult!['warnings'] as List? ?? [];
    final whenToSeekHelp = _analysisResult!['whenToSeekHelp'] ?? '';
    final additionalTips = _analysisResult!['additionalTips'] as List? ?? [];

    Color severityColor;
    IconData severityIcon;
    switch (severity.toLowerCase()) {
      case 'critical':
      case 'severe':
        severityColor = AppTheme.dangerColor;
        severityIcon = FeatherIcons.alertTriangle;
        break;
      case 'moderate':
        severityColor = AppTheme.warningColor;
        severityIcon = FeatherIcons.alertCircle;
        break;
      case 'minor':
      case 'mild':
        severityColor = AppTheme.successColor;
        severityIcon = FeatherIcons.info;
        break;
      default:
        severityColor = AppTheme.accentColor;
        severityIcon = FeatherIcons.helpCircle;
    }

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(32),
        boxShadow: [
          BoxShadow(
            color: severityColor.withOpacity(0.15),
            blurRadius: 40,
            spreadRadius: -10,
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(32),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.05),
              borderRadius: BorderRadius.circular(32),
              border: Border.all(color: severityColor.withOpacity(0.3), width: 1.5),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildResultHeader(severity, condition, severityColor, severityIcon),
                const SizedBox(height: 32),
                _buildSection("IMMEDIATE ACTIONS", immediateActions, FeatherIcons.zap, Colors.white),
                const SizedBox(height: 24),
                if (warnings.isNotEmpty)
                  _buildSection("WARNINGS", warnings, FeatherIcons.alertOctagon, AppTheme.warningColor),
                const SizedBox(height: 24),
                if (whenToSeekHelp.isNotEmpty) _buildHelpSection(whenToSeekHelp),
                if (additionalTips.isNotEmpty) ...[
                  const SizedBox(height: 24),
                  _buildSection("ADDITIONAL TIPS", additionalTips, FeatherIcons.star, AppTheme.accentColor),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildResultHeader(String severity, String condition, Color color, IconData icon) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: color.withOpacity(0.2),
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: color.withOpacity(0.2),
                blurRadius: 15,
                spreadRadius: 2,
              ),
            ],
          ),
          child: Icon(icon, color: color, size: 28),
        ),
        const SizedBox(width: 20),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                severity.toUpperCase(),
                style: TextStyle(
                  color: color,
                  fontSize: 12,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 2,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                condition,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                  fontFamily: 'Montserrat',
                  letterSpacing: -0.5,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildHelpSection(String content) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.dangerColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppTheme.dangerColor.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(FeatherIcons.phoneCall, color: AppTheme.dangerColor, size: 18),
              const SizedBox(width: 10),
              const Text(
                "WHEN TO SEEK HELP",
                style: TextStyle(
                  color: AppTheme.dangerColor,
                  fontSize: 12,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.5,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            content,
            style: TextStyle(
              color: Colors.white.withOpacity(0.9),
              fontSize: 14,
              height: 1.6,
              fontFamily: 'Montserrat',
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSection(String title, List<dynamic> items, IconData icon, Color color) {
    if (items.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, color: color.withOpacity(0.8), size: 18),
            const SizedBox(width: 10),
            Text(
              title,
              style: TextStyle(
                color: color.withOpacity(0.8),
                fontSize: 12,
                fontWeight: FontWeight.w900,
                letterSpacing: 1.5,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        ...items.map((item) => Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                margin: const EdgeInsets.only(top: 6),
                width: 6,
                height: 6,
                decoration: BoxDecoration(
                  color: color.withOpacity(0.6),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: color.withOpacity(0.3),
                      blurRadius: 4,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Text(
                  item.toString(),
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.9),
                    fontSize: 15,
                    height: 1.6,
                    fontFamily: 'Montserrat',
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        )),
      ],
    );
  }
}
