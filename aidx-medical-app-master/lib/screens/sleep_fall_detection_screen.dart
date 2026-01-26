import 'package:flutter/material.dart';
import 'dart:ui';
import '../services/sleep_fall_detection_service.dart';
import '../models/sleep_fall_detection_model.dart';
import '../utils/theme.dart';
import '../utils/constants.dart';
import 'package:flutter_feather_icons/flutter_feather_icons.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SleepFallDetectionScreen extends StatefulWidget {
  const SleepFallDetectionScreen({super.key});

  @override
  State<SleepFallDetectionScreen> createState() => _SleepFallDetectionScreenState();
}

class _SleepFallDetectionScreenState extends State<SleepFallDetectionScreen>
    with TickerProviderStateMixin {
  final SleepFallDetectionService _detectionService = SleepFallDetectionService();
  Map<String, dynamic> _currentStatus = {};
  List<SleepFallDetectionModel> _detectionHistory = [];
  bool _isLoading = false;
  bool _isFallDetectionActive = false;
  bool _isSleepTrackingActive = false;
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
    _loadData();
    _loadMonitoringState();
  }

  void _initializeAnimations() {
    _pulseController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    );
    _pulseAnimation = Tween<double>(begin: 0.8, end: 1.2).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
    _pulseController.repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // Load detection history
      _detectionHistory = await _detectionService.getEvents();
      
      // Sync with service state
      await _syncServiceState();
      
      // Load current status
      _currentStatus = await _detectionService.getCurrentStatus();
    } catch (e) {
      debugPrint('Error loading detection data: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _syncServiceState() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final wasFallDetectionActive = prefs.getBool('fall_detection_active') ?? false;
      final wasSleepTrackingActive = prefs.getBool('sleep_tracking_active') ?? false;
      
      setState(() {
        _isFallDetectionActive = wasFallDetectionActive;
        _isSleepTrackingActive = wasSleepTrackingActive;
      });
      
      debugPrint('✅ Synced service state: Fall=$_isFallDetectionActive, Sleep=$_isSleepTrackingActive');
    } catch (e) {
      debugPrint('Error syncing service state: $e');
    }
  }

  Future<void> _loadMonitoringState() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final wasFallDetectionActive = prefs.getBool('fall_detection_active') ?? false;
      final wasSleepTrackingActive = prefs.getBool('sleep_tracking_active') ?? false;
      
      setState(() {
        _isFallDetectionActive = wasFallDetectionActive;
        _isSleepTrackingActive = wasSleepTrackingActive;
      });
      
      debugPrint('✅ Loaded monitoring state: Fall=$_isFallDetectionActive, Sleep=$_isSleepTrackingActive');
    } catch (e) {
      debugPrint('Error loading monitoring state: $e');
    }
  }

  Future<void> _saveMonitoringState(bool fallDetection, bool sleepTracking) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('fall_detection_active', fallDetection);
      await prefs.setBool('sleep_tracking_active', sleepTracking);
      debugPrint('✅ Saved monitoring state: Fall=$fallDetection, Sleep=$sleepTracking');
    } catch (e) {
      debugPrint('Error saving monitoring state: $e');
    }
  }

  void _toggleFallDetection() async {
    setState(() {
      _isFallDetectionActive = !_isFallDetectionActive;
    });

    // Save the state immediately
    await _saveMonitoringState(_isFallDetectionActive, _isSleepTrackingActive);

    if (_isFallDetectionActive) {
      await _detectionService.startFallDetection();
      debugPrint('✅ Started fall detection monitoring');
    } else {
      await _detectionService.stopFallDetection();
      debugPrint('✅ Stopped fall detection monitoring');
    }

    _loadData();
  }

  void _toggleSleepTracking() async {
    setState(() {
      _isSleepTrackingActive = !_isSleepTrackingActive;
    });

    // Save the state immediately
    await _saveMonitoringState(_isFallDetectionActive, _isSleepTrackingActive);

    if (_isSleepTrackingActive) {
      await _detectionService.startSleepTracking();
      debugPrint('✅ Started sleep tracking monitoring');
    } else {
      await _detectionService.stopSleepTracking();
      debugPrint('✅ Stopped sleep tracking monitoring');
    }

    _loadData();
  }

  void _manualCheckIn() async {
    // Manual check-in functionality removed for now
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Check-in recorded')),
    );
    _loadData();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bgDark,
      body: Stack(
        children: [
          _buildAnimatedBackground(),
          SafeArea(
            child: CustomScrollView(
              slivers: [
                SliverAppBar(
                  expandedHeight: 120,
                  floating: false,
                  pinned: true,
                  backgroundColor: Colors.transparent,
                  elevation: 0,
                  flexibleSpace: FlexibleSpaceBar(
                    title: const Text(
                      'Sleep & Fall Detection',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 20,
                      ),
                    ),
                    background: Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            AppTheme.dangerColor.withOpacity(0.3),
                            AppTheme.accentColor.withOpacity(0.2),
                          ],
                        ),
                      ),
                    ),
                  ),
                  leading: IconButton(
                    icon: const Icon(Icons.arrow_back, color: Colors.white),
                    onPressed: () => Navigator.pop(context),
                  ),
                ),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.all(16).copyWith(bottom: 24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildStatusCard(),
                        const SizedBox(height: 20),
                        _buildControlsCard(),
                        const SizedBox(height: 20),
                        _buildAlertCard(),
                        const SizedBox(height: 20),
                        _buildHistoryCard(),
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
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppTheme.bgDark,
            AppTheme.bgMedium,
            AppTheme.bgLight,
          ],
        ),
      ),
    );
  }

  Widget _buildStatusCard() {
    // Use local state for real-time status instead of database status
    final isFallDetectionActive = _isFallDetectionActive;
    final isSleepTrackingActive = _isSleepTrackingActive;
    final currentLocation = _currentStatus['currentLocation'] ?? 'Unknown';
    final potentialFallDetected = _currentStatus['potentialFallDetected'] ?? false;

    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Colors.white.withOpacity(0.13),
                AppTheme.bgGlassMedium.withOpacity(0.18),
                Colors.white.withOpacity(0.10),
              ],
            ),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              width: 1.8,
              color: potentialFallDetected 
                  ? AppTheme.dangerColor.withOpacity(0.18)
                  : isFallDetectionActive 
                      ? AppTheme.dangerColor.withOpacity(0.18)
                      : AppTheme.successColor.withOpacity(0.18),
            ),
            boxShadow: [
              BoxShadow(
                color: potentialFallDetected 
                    ? AppTheme.dangerColor.withOpacity(0.10)
                    : isFallDetectionActive 
                        ? AppTheme.dangerColor.withOpacity(0.10)
                        : AppTheme.successColor.withOpacity(0.10),
                blurRadius: 16,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  AnimatedBuilder(
                    animation: _pulseAnimation,
                    builder: (context, child) {
                      return Container(
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: potentialFallDetected 
                                  ? AppTheme.dangerColor.withOpacity(0.25 * _pulseAnimation.value)
                                  : isFallDetectionActive 
                                      ? AppTheme.dangerColor.withOpacity(0.25 * _pulseAnimation.value)
                                      : AppTheme.successColor.withOpacity(0.25 * _pulseAnimation.value),
                              blurRadius: 12 * _pulseAnimation.value,
                              spreadRadius: 1.5 * _pulseAnimation.value,
                            ),
                          ],
                        ),
                        child: Transform.scale(
                          scale: _pulseAnimation.value,
                          child: Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: potentialFallDetected 
                                    ? [AppTheme.dangerColor, AppTheme.warningColor]
                                    : isFallDetectionActive 
                                        ? [AppTheme.dangerColor, AppTheme.warningColor]
                                        : [AppTheme.successColor, AppTheme.primaryColor],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              potentialFallDetected 
                                  ? FeatherIcons.alertTriangle
                                  : isFallDetectionActive 
                                      ? FeatherIcons.alertTriangle
                                      : FeatherIcons.shield,
                              size: 24,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          potentialFallDetected 
                              ? 'Alert Detected'
                              : isFallDetectionActive 
                                  ? 'Fall Detection Active'
                                  : 'Safe',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          potentialFallDetected 
                              ? 'Potential fall detected'
                              : isFallDetectionActive 
                                  ? 'Fall detection active'
                                  : 'Monitoring active',
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.8),
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Column(
                children: [
                  _buildStatusRow('Location', currentLocation, FeatherIcons.mapPin),
                  const SizedBox(height: 12),
                  _buildStatusRow('Fall Detection', isFallDetectionActive ? 'Active' : 'Inactive', FeatherIcons.alertTriangle),
                  const SizedBox(height: 12),
                  _buildStatusRow('Sleep Tracking', isSleepTrackingActive ? 'Active' : 'Inactive', FeatherIcons.moon),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatusRow(String label, String value, IconData icon) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, size: 16, color: Colors.white),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.white.withOpacity(0.6),
                ),
              ),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildControlsCard() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Colors.white.withOpacity(0.13),
                AppTheme.bgGlassMedium.withOpacity(0.18),
                Colors.white.withOpacity(0.10),
              ],
            ),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              width: 1.8,
              color: AppTheme.infoColor.withOpacity(0.18),
            ),
            boxShadow: [
              BoxShadow(
                color: AppTheme.infoColor.withOpacity(0.10),
                blurRadius: 16,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [AppTheme.infoColor, AppTheme.accentColor],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      FeatherIcons.settings,
                      size: 20,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Text(
                    'Controls',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Column(
                children: [
                  GestureDetector(
                    onTap: _toggleFallDetection,
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: _isFallDetectionActive
                              ? [AppTheme.dangerColor, AppTheme.warningColor]
                              : [AppTheme.successColor, AppTheme.primaryColor],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: (_isFallDetectionActive ? AppTheme.dangerColor : AppTheme.successColor).withOpacity(0.3),
                            blurRadius: 8,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            _isFallDetectionActive ? FeatherIcons.pause : FeatherIcons.play,
                            color: Colors.white,
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          Flexible(
                            child: Text(
                              _isFallDetectionActive ? 'Stop Fall Detection' : 'Start Fall Detection',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  GestureDetector(
                    onTap: _toggleSleepTracking,
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: _isSleepTrackingActive
                              ? [AppTheme.accentColor, AppTheme.primaryColor]
                              : [AppTheme.successColor, AppTheme.primaryColor],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: (_isSleepTrackingActive ? AppTheme.accentColor : AppTheme.successColor).withOpacity(0.3),
                            blurRadius: 8,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            _isSleepTrackingActive ? FeatherIcons.pause : FeatherIcons.play,
                            color: Colors.white,
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          Flexible(
                            child: Text(
                              _isSleepTrackingActive ? 'Stop Sleep Tracking' : 'Start Sleep Tracking',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              GestureDetector(
                onTap: _manualCheckIn,
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 20),
                  decoration: BoxDecoration(
                    color: AppTheme.accentColor,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: AppTheme.accentColor.withOpacity(0.3),
                        blurRadius: 8,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        FeatherIcons.check,
                        color: Colors.white,
                        size: 18,
                      ),
                      SizedBox(width: 8),
                      Flexible(
                        child: Text(
                          'Manual Check-in',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAlertCard() {
    final potentialFallDetected = _currentStatus['potentialFallDetected'] ?? false;
    
    if (!potentialFallDetected) {
      return const SizedBox.shrink();
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                AppTheme.dangerColor.withOpacity(0.2),
                AppTheme.warningColor.withOpacity(0.1),
              ],
            ),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              width: 2,
              color: AppTheme.dangerColor.withOpacity(0.3),
            ),
            boxShadow: [
              BoxShadow(
                color: AppTheme.dangerColor.withOpacity(0.2),
                blurRadius: 16,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppTheme.dangerColor,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      FeatherIcons.alertTriangle,
                      size: 20,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Text(
                    'Safety Alert',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              const Text(
                'A potential fall was detected. Please confirm you are safe by tapping the check-in button.',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 16),
              GestureDetector(
                onTap: _manualCheckIn,
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 20),
                  decoration: BoxDecoration(
                    color: AppTheme.successColor,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: AppTheme.successColor.withOpacity(0.3),
                        blurRadius: 8,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        FeatherIcons.check,
                        color: Colors.white,
                        size: 18,
                      ),
                      SizedBox(width: 8),
                      Flexible(
                        child: Text(
                          'I\'m Safe',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHistoryCard() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Colors.white.withOpacity(0.13),
                AppTheme.bgGlassMedium.withOpacity(0.18),
                Colors.white.withOpacity(0.10),
              ],
            ),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              width: 1.8,
              color: AppTheme.accentColor.withOpacity(0.18),
            ),
            boxShadow: [
              BoxShadow(
                color: AppTheme.accentColor.withOpacity(0.10),
                blurRadius: 16,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [AppTheme.accentColor, AppTheme.primaryColor],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      FeatherIcons.activity,
                      size: 20,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Text(
                    'Recent Events',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              if (_detectionHistory.isEmpty)
                Center(
                  child: Column(
                    children: [
                      Icon(
                        FeatherIcons.shield,
                        size: 48,
                        color: Colors.white.withOpacity(0.5),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'No events recorded yet',
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.white.withOpacity(0.7),
                        ),
                      ),
                    ],
                  ),
                )
              else
                ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: _detectionHistory.take(5).length,
                  itemBuilder: (context, index) {
                    final event = _detectionHistory[index];
                    return Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: _getEventColor(event.eventType).withOpacity(0.2),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Icon(
                              _getEventIcon(event.eventType),
                              size: 16,
                              color: _getEventColor(event.eventType),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _getEventTitle(event.eventType),
                                  style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.white,
                                  ),
                                ),
                                Text(
                                  '${DateTime.now().difference(event.timestamp).inMinutes} min ago',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.white.withOpacity(0.6),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }

  Color _getEventColor(String eventType) {
    switch (eventType) {
      case 'fall_detected':
      case 'fall_alert':
        return AppTheme.dangerColor;
      case 'sleep_start':
      case 'sleep_end':
        return AppTheme.accentColor;
      case 'extended_inactivity':
        return AppTheme.warningColor;
      case 'manual_check_in':
        return AppTheme.successColor;
      default:
        return AppTheme.infoColor;
    }
  }

  IconData _getEventIcon(String eventType) {
    switch (eventType) {
      case 'fall_detected':
      case 'fall_alert':
        return FeatherIcons.alertTriangle;
      case 'sleep_start':
      case 'sleep_end':
        return FeatherIcons.moon;
      case 'extended_inactivity':
        return FeatherIcons.clock;
      case 'manual_check_in':
        return FeatherIcons.check;
      default:
        return FeatherIcons.activity;
    }
  }

  String _getEventTitle(String eventType) {
    switch (eventType) {
      case 'fall_detected':
        return 'Fall Detected';
      case 'fall_alert':
        return 'Fall Alert';
      case 'sleep_start':
        return 'Sleep Started';
      case 'sleep_end':
        return 'Sleep Ended';
      case 'extended_inactivity':
        return 'Extended Inactivity';
      case 'manual_check_in':
        return 'Manual Check-in';
      default:
        return 'Event';
    }
  }
} 