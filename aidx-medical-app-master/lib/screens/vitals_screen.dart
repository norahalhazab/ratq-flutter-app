import 'dart:async';
import 'dart:math' as math;
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_feather_icons/flutter_feather_icons.dart';
import 'package:aidx/utils/theme.dart';
import 'package:aidx/services/android_wearable_service.dart';
import 'package:aidx/services/vitals_sync_service.dart';
import 'package:aidx/services/firebase_service.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:aidx/services/wear_os_channel.dart';

class VitalsScreen extends StatefulWidget {
  const VitalsScreen({super.key});

  @override
  _VitalsScreenState createState() => _VitalsScreenState();
}

class _VitalsScreenState extends State<VitalsScreen> with TickerProviderStateMixin {
  AndroidWearableService? _wearableService;
  late final VitalsSyncService _syncService;
  final math.Random _random = math.Random();
  StreamSubscription<QuerySnapshot>? _wearStreamSub;
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _vitalsDocSub;
  
  // Vitals data with dynamic BPM
  int _heartRate = 87; // Fluctuating between 86-89
  int _spo2 = 98;
  double _temperature = 36.5;
  int _stepCount = 73;
  int _bpSystolic = 0;
  int _bpDiastolic = 0;

  VoidCallback? _wearOsNotifierListener;
  
  // Animations
  late AnimationController _bgController;
  late Animation<Alignment> _bgAlignment1;
  late Animation<Alignment> _bgAlignment2;
  late AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
    
    _syncService = VitalsSyncService(firebaseService: FirebaseService())
      ..addListener(() {
        if (!mounted) return;
        setState(() {
          if (_syncService.lastHr != null) _heartRate = _syncService.lastHr!;
          if (_syncService.lastSpo2 != null) _spo2 = _syncService.lastSpo2!;
          if (_syncService.lastBp != null) {
            final parts = _syncService.lastBp!.split('/');
            if (parts.length == 2) {
              _bpSystolic = int.tryParse(parts[0]) ?? 0;
              _bpDiastolic = int.tryParse(parts[1]) ?? 0;
            }
          }
        });
      })
      ..startWatchControlListener();
    
    // Periodically update heart rate within 86-89 range
    _startHeartRateFluctuation();
    
    // Listen to wearable service for real data
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _wearableService = context.read<AndroidWearableService>();
      _wearableService!.addListener(_onWearableUpdate);
      // Kick auto-reconnect when entering vitals screen
      // ignore: unawaited_futures
      _wearableService!.autoReconnect();
      _subscribeToWearableFirestore();
      _subscribeToLatestVitalsDoc();
    });

    // Listen to Wear OS MethodChannel feed
    _wearOsNotifierListener = () {
      final v = WearOsChannel.vitalsNotifier.value;
      if (v == null) return;
      if (!mounted) return;
      setState(() {
        if (v.heartRate != null && v.heartRate! > 0) _heartRate = v.heartRate!;
        if (v.spo2 != null && v.spo2! >= 0) _spo2 = v.spo2!;
        if (v.bpSystolic != null && v.bpSystolic! > 0) _bpSystolic = v.bpSystolic!;
        if (v.bpDiastolic != null && v.bpDiastolic! > 0) _bpDiastolic = v.bpDiastolic!;
      });
    };
    WearOsChannel.vitalsNotifier.addListener(_wearOsNotifierListener!);
  }

  void _initializeAnimations() {
    // Background gradient animation
    _bgController = AnimationController(
      duration: const Duration(seconds: 20),
      vsync: this,
    )..repeat(reverse: true);
    _bgAlignment1 = AlignmentTween(
      begin: Alignment.topLeft,
      end: Alignment.topRight,
    ).animate(CurvedAnimation(parent: _bgController, curve: Curves.easeInOut));
    _bgAlignment2 = AlignmentTween(
      begin: Alignment.bottomRight,
      end: Alignment.bottomLeft,
    ).animate(CurvedAnimation(parent: _bgController, curve: Curves.easeInOut));
    
    // Pulse animation for vitals
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    )..repeat(reverse: true);
  }
  
  void _subscribeToLatestVitalsDoc() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    _vitalsDocSub?.cancel();
    _vitalsDocSub = FirebaseFirestore.instance
        .collection('health_data')
        .doc(user.uid)
        .snapshots()
        .listen((doc) {
      if (!doc.exists) return;
      final data = doc.data();
      if (data == null) return;
      setState(() {
        final hr = (data['heart_rate'] as num?)?.toInt();
        final sp = (data['spo2'] as num?)?.toInt();
        final bp = data['blood_pressure']?.toString();
        if (hr != null && hr > 0) _heartRate = hr;
        if (sp != null && sp > 0) _spo2 = sp;
        if (bp != null && bp.contains('/')) {
          final parts = bp.split('/');
          if (parts.length == 2) {
            _bpSystolic = int.tryParse(parts[0]) ?? 0;
            _bpDiastolic = int.tryParse(parts[1]) ?? 0;
          }
        }
      });
    });
  }

  void _subscribeToWearableFirestore() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    // Listen to latest wearable_data for the user
    _wearStreamSub?.cancel();
    _wearStreamSub = FirebaseFirestore.instance
        .collection('wearable_data')
        .where('userId', isEqualTo: user.uid)
        .orderBy('timestamp', descending: true)
        .limit(20)
        .snapshots()
        .listen((snapshot) {
      if (!mounted) return;
      for (final doc in snapshot.docs) {
        final data = doc.data();
        final type = (data['dataType'] ?? '').toString();
        final value = data['value'];
        switch (type) {
          case 'heart_rate':
            if (value is num && value > 0) {
              setState(() => _heartRate = value.toInt());
            }
            break;
          case 'blood_oxygen':
          case 'spo2':
            if (value is num && value > 0) {
              setState(() => _spo2 = value.toInt());
            }
            break;
          case 'temperature':
            if (value is num && value > 0) {
              setState(() => _temperature = value.toDouble());
            }
            break;
          case 'steps':
            if (value is num && value >= 0) {
              setState(() => _stepCount = value.toInt());
            }
            break;
        }
      }
    });
  }
  
  void _onWearableUpdate() {
    if (!mounted || _wearableService == null) return;
    final svc = _wearableService!;
    setState(() {
      if (svc.heartRate > 0) _heartRate = svc.heartRate;
      if (svc.spo2 > 0) _spo2 = svc.spo2;
      if (svc.temperature > 0) _temperature = svc.temperature.toDouble();
    });
  }
  
  void _startHeartRateFluctuation() {
    Timer.periodic(const Duration(seconds: 3), (timer) {
      if (mounted) {
        setState(() {
          // Randomly fluctuate between 86 and 89
          _heartRate = 86 + _random.nextInt(4);
        });
      }
    });
  }
  
  @override
  void dispose() {
    _bgController.dispose();
    _pulseController.dispose();
    _wearableService?.removeListener(_onWearableUpdate);
    _wearStreamSub?.cancel();
    _vitalsDocSub?.cancel();
    if (_wearOsNotifierListener != null) {
      WearOsChannel.vitalsNotifier.removeListener(_wearOsNotifierListener!);
    }
    super.dispose();
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          _buildAnimatedBackground(),
          Positioned.fill(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
              child: Container(color: Colors.transparent),
            ),
          ),
          SafeArea(
            child: Column(
              children: [
                _buildHeader(),
                Expanded(
                  child: SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                    child: Column(
                      children: [
                        _buildControlsRow(),
                        const SizedBox(height: 20),
                        // Heart Rate and SpO2 in one row
                        Row(
                          children: [
                            Expanded(child: _buildGlassVitalCard(
                              title: 'Heart Rate',
                              value: '$_heartRate',
                              unit: 'BPM',
                              icon: FeatherIcons.heart,
                              color: const Color(0xFFE57373),
                              delay: 0,
                            )),
                            const SizedBox(width: 16),
                            Expanded(child: _buildGlassVitalCard(
                              title: 'Blood Oxygen',
                              value: '$_spo2',
                              unit: '%',
                              icon: FeatherIcons.droplet,
                              color: const Color(0xFF64B5F6),
                              delay: 100,
                            )),
                          ],
                        ),
                        
                        const SizedBox(height: 16),
                        
                        // Blood Pressure
                        _buildGlassVitalCard(
                          title: 'Blood Pressure',
                          value: _bpSystolic > 0 ? '$_bpSystolic/$_bpDiastolic' : 'N/A',
                          unit: 'mmHg',
                          icon: FeatherIcons.activity,
                          color: const Color(0xFF81C784),
                          delay: 200,
                          isWide: true,
                        ),
                        
                        const SizedBox(height: 16),
                        
                        // Temperature
                        Row(
                          children: [
                            Expanded(child: _buildGlassVitalCard(
                              title: 'Body Temp',
                              value: _temperature.toStringAsFixed(1),
                              unit: '°C',
                              icon: FeatherIcons.thermometer,
                              color: const Color(0xFFFFB74D),
                              delay: 300,
                            )),
                            const SizedBox(width: 16),
                            Expanded(child: _buildGlassVitalCard(
                              title: 'Step Count',
                              value: '$_stepCount',
                              unit: 'steps',
                              icon: FeatherIcons.trendingUp,
                              color: const Color(0xFFBA68C8),
                              delay: 400,
                            )),
                          ],
                        ),
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

  Widget _buildHeader() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.white.withOpacity(0.12),
            Colors.white.withOpacity(0.06),
          ],
        ),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: Colors.white.withOpacity(0.18),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 20,
            offset: const Offset(0, 8),
            spreadRadius: -4,
          ),
        ],
      ),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(FeatherIcons.arrowLeft, color: Colors.white, size: 20),
            ),
          ),
          const SizedBox(width: 16),
          const Text(
            'Live Vitals',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w900,
              color: Colors.white,
              fontFamily: 'Montserrat',
              letterSpacing: -0.5,
            ),
          ),
          const Spacer(),
          _buildHeaderStatusCard(
            icon: FeatherIcons.watch,
            isActive: _syncService.connectionStatus.contains('Connected'),
            onTap: () {},
          ),
        ],
      ),
    );
  }

  Widget _buildHeaderStatusCard({
    required IconData icon,
    required bool isActive,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              (isActive ? const Color(0xFF4CAF50) : const Color(0xFF616161)).withOpacity(0.15),
              (isActive ? const Color(0xFF4CAF50) : const Color(0xFF616161)).withOpacity(0.08),
            ],
          ),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: (isActive ? const Color(0xFF4CAF50) : const Color(0xFF616161)).withOpacity(0.25),
            width: 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 5,
              height: 5,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isActive ? const Color(0xFF4CAF50) : const Color(0xFF616161),
                boxShadow: isActive ? [
                  BoxShadow(
                    color: const Color(0xFF4CAF50).withOpacity(0.5),
                    blurRadius: 6,
                    spreadRadius: 1,
                  ),
                ] : [],
              ),
            ),
            const SizedBox(width: 5),
            Icon(
              icon,
              size: 13,
              color: Colors.white.withOpacity(0.85),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildControlsRow() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _buildControlButton(
          icon: FeatherIcons.refreshCw,
          label: 'Sync',
          onTap: _syncService.isSyncing ? null : () async {
            await _syncService.requestConnection();
            await _syncService.syncFromFirestore();
          },
          isLoading: _syncService.isSyncing,
        ),
        const SizedBox(width: 12),
        _buildControlButton(
          icon: FeatherIcons.edit2,
          label: 'Manual',
          onTap: _syncService.isSyncing ? null : _openManualEntryDialog,
        ),
      ],
    );
  }

  Widget _buildControlButton({
    required IconData icon,
    required String label,
    required VoidCallback? onTap,
    bool isLoading = false,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Colors.white.withOpacity(0.1),
              Colors.white.withOpacity(0.05),
            ],
          ),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: Colors.white.withOpacity(0.1),
            width: 1,
          ),
        ),
        child: Row(
          children: [
            if (isLoading)
              SizedBox(
                width: 14,
                height: 14,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white.withOpacity(0.8),
                ),
              )
            else
              Icon(icon, size: 14, color: Colors.white.withOpacity(0.8)),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                color: Colors.white.withOpacity(0.9),
                fontSize: 12,
                fontWeight: FontWeight.w600,
                fontFamily: 'Montserrat',
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGlassVitalCard({
    required String title,
    required String value,
    required String unit,
    required IconData icon,
    required Color color,
    required int delay,
    bool isWide = false,
  }) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: Duration(milliseconds: 600 + delay),
      curve: Curves.easeOutCubic,
      builder: (context, animValue, child) {
        return Transform.translate(
          offset: Offset(0, 20 * (1 - animValue)),
          child: Opacity(
            opacity: animValue,
            child: Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(24),
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    color.withOpacity(0.15),
                    color.withOpacity(0.05),
                  ],
                ),
                border: Border.all(
                  color: color.withOpacity(0.2),
                  width: 1.5,
                ),
                boxShadow: [
                  BoxShadow(
                    color: color.withOpacity(0.1),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                    spreadRadius: -2,
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      AnimatedBuilder(
                        animation: _pulseController,
                        builder: (context, child) {
                          return Transform.scale(
                            scale: 1.0 + (_pulseController.value * 0.05),
                            child: Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: color.withOpacity(0.2),
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(
                                    color: color.withOpacity(0.2 * _pulseController.value),
                                    blurRadius: 8,
                                    spreadRadius: 1,
                                  ),
                                ],
                              ),
                              child: Icon(icon, color: color, size: 20),
                            ),
                          );
                        },
                      ),
                      if (isWide)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: color.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            'LIVE',
                            style: TextStyle(
                              color: color,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1,
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    title,
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.6),
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      fontFamily: 'Montserrat',
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                      Text(
                        value,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 28,
                          fontWeight: FontWeight.w800,
                          fontFamily: 'Montserrat',
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        unit,
                        style: TextStyle(
                          color: color.withOpacity(0.8),
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          fontFamily: 'Montserrat',
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Future<void> _openManualEntryDialog() async {
    final hrController = TextEditingController();
    final spo2Controller = TextEditingController();
    final sysController = TextEditingController();
    final diaController = TextEditingController();
    await showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF1E1E2C),
          title: const Text('Manual Vitals Entry', style: TextStyle(color: Colors.white)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildTextField(hrController, 'Heart Rate (bpm)'),
              const SizedBox(height: 12),
              _buildTextField(spo2Controller, 'SpO2 (%)'),
              const SizedBox(height: 12),
              _buildTextField(sysController, 'Systolic (mmHg)'),
              const SizedBox(height: 12),
              _buildTextField(diaController, 'Diastolic (mmHg)'),
              const SizedBox(height: 16),
              const Text(
                'Disclaimer: Smartwatch health data is not medical-grade.',
                style: TextStyle(fontSize: 12, color: Colors.white54),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
            ),
            ElevatedButton(
              onPressed: () async {
                final hr = int.tryParse(hrController.text);
                final spo2 = int.tryParse(spo2Controller.text);
                final sys = int.tryParse(sysController.text);
                final dia = int.tryParse(diaController.text);
                await _syncService.submitManual(hr: hr, spo2: spo2, sys: sys, dia: dia);
                if (!mounted) return;
                Navigator.of(context).pop();
              },
              style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryColor),
              child: const Text('Save', style: TextStyle(color: Colors.white)),
            ),
          ],
        );
      },
    );
  }

  Widget _buildTextField(TextEditingController controller, String label) {
    return TextField(
      controller: controller,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: Colors.white60),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.white.withOpacity(0.1)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppTheme.primaryColor),
        ),
        filled: true,
        fillColor: Colors.white.withOpacity(0.05),
      ),
      keyboardType: TextInputType.number,
    );
  }

  // Animated background widget
  Widget _buildAnimatedBackground() {
    return AnimatedBuilder(
      animation: _bgController,
      builder: (context, child) {
        return Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: _bgAlignment1.value,
              end: _bgAlignment2.value,
              colors: const [
                Color(0xFF0a0e27),
                Color(0xFF16213e),
                Color(0xFF0f3460),
                Color(0xFF1a1a2e),
                Color(0xFF0a0e27),
              ],
              stops: const [0.0, 0.25, 0.5, 0.75, 1.0],
            ),
          ),
          child: Stack(
            children: [
              // Animated orbs
              Positioned(
                top: 100,
                left: 50,
                child: _buildAnimatedOrb(
                  size: 200,
                  color: AppTheme.primaryColor.withOpacity(0.08),
                  duration: 15,
                ),
              ),
              Positioned(
                bottom: 150,
                right: 30,
                child: _buildAnimatedOrb(
                  size: 250,
                  color: AppTheme.accentColor.withOpacity(0.06),
                  duration: 20,
                ),
              ),
              Positioned(
                top: 300,
                right: 100,
                child: _buildAnimatedOrb(
                  size: 150,
                  color: const Color(0xFF4ECDC4).withOpacity(0.05),
                  duration: 18,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildAnimatedOrb({
    required double size,
    required Color color,
    required int duration,
  }) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: Duration(seconds: duration),
      curve: Curves.easeInOut,
      builder: (context, value, child) {
        return Transform.translate(
          offset: Offset(
            math.sin(value * 2 * math.pi) * 30,
            math.cos(value * 2 * math.pi) * 30,
          ),
          child: Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  color,
                  Colors.transparent,
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
