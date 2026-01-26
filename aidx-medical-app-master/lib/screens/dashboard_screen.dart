import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/auth_service.dart';
import '../services/news_service.dart';

import '../services/android_wearable_service.dart';
import '../services/notification_service.dart';
import '../models/news_model.dart';
import '../services/premium_service.dart';

import '../utils/constants.dart';
import '../utils/theme.dart';

import 'package:flutter_feather_icons/flutter_feather_icons.dart';
import 'dart:async';
import 'dart:math' as math;

import 'package:aidx/screens/news_detail_screen.dart';
import 'dart:ui';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'inbox_screen.dart';
import '../widgets/dashboard_animations.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen>
    with TickerProviderStateMixin {

  late AnimationController _ecgController;

  late Animation<double> _ecgAnimation;
  // Animated gradient background
  late AnimationController _bgController;
  late Animation<Alignment> _bgAlignment1;
  late Animation<Alignment> _bgAlignment2;
  
  // Pulse animation for vitals
  late AnimationController _pulseController;
  
  // News carousel
  int _currentNewsIndex = 0;
  Timer? _newsTimer;

  String _selectedMood = '';
  // Demo placeholders so the UI shows sample vitals even when no device is connected
  String _heartRate = '72'; // bpm
  String _spo2 = '98'; // %
  String _temperature = '--';

  bool _isWatchConnected = false;

  bool _isLoadingNews = false;
  List<NewsArticle> _newsPool = [];
  
  bool _canUseSymptomAnalysis = true;
  bool _canUseDrugInfo = true;


  final NewsService _newsService = NewsService();
  AndroidWearableService? _wearableService;
  final NotificationService _notificationService = NotificationService();
  
  @override
  void initState() {
    super.initState();
    _initializeAnimations();
    _loadUserMood();
    _loadHealthNews();
    _checkUsageLimits();
    _initializeWearableService();
    _startNewsCarousel();

  }

  Future<void> _checkUsageLimits() async {
    final canSymptoms = await PremiumService.canUseSymptomAnalysis();
    final canDrugs = await PremiumService.canUseDrugInfo();
    if (mounted) {
      setState(() {
        _canUseSymptomAnalysis = canSymptoms;
        _canUseDrugInfo = canDrugs;
      });
    }
  }

  void _initializeAnimations() {


    _ecgController = AnimationController(
      duration: const Duration(seconds: 3),
      vsync: this,
    );
    _ecgAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _ecgController, curve: Curves.linear),
    );
    _ecgController.repeat();

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
  
  void _startNewsCarousel() {
    _newsTimer = Timer.periodic(const Duration(seconds: 5), (timer) {
      if (_newsPool.isNotEmpty && mounted) {
        setState(() {
          _currentNewsIndex = (_currentNewsIndex + 1) % _newsPool.length;
        });
      }
    });
  }

  Future<void> _loadUserMood() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _selectedMood = prefs.getString('user_mood') ?? '';
    });
  }

  Future<void> _saveUserMood(String mood) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('user_mood', mood);
      
      setState(() {
        _selectedMood = mood;
      });
      
      debugPrint('✅ User mood saved: $mood');
      
      // Also save to Firebase if user is logged in
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser != null) {
        try {
          await FirebaseFirestore.instance
              .collection('users')
              .doc(currentUser.uid)
              .update({
            'mood': mood,
            'lastMoodUpdate': FieldValue.serverTimestamp(),
          });
          debugPrint('✅ User mood saved to Firebase');
        } catch (e) {
          debugPrint('⚠️ Error saving mood to Firebase: $e');
        }
      }
    } catch (e) {
      debugPrint('Error saving user mood: $e');
    }
  }

  Future<void> _loadHealthNews({bool force = false}) async {
    setState(() {
      _isLoadingNews = true;
    });

    try {
      if (force || _newsPool.isEmpty) {
        _newsPool = await _newsService.getHealthNews();
        
        // If API returned 0 articles, use fallback data
        if (_newsPool.isEmpty) {
          _newsPool = _getFallbackNews();
        }
      }
      
      if (_newsPool.isNotEmpty) {
        // Select a random article from the pool
        final randomIndex = math.Random().nextInt(_newsPool.length);
        final selectedNews = _newsPool[randomIndex];
        

        
        // Show notification for new health news (only when forced refresh)
        if (force) {
          _notificationService.showNewsNotification(
            title: 'New Health Update',
            body: selectedNews.title,
          );
        }
      }
    } catch (e) {
      // If API fails, use fallback data
      _newsPool = _getFallbackNews();
      if (_newsPool.isNotEmpty) {
        final randomIndex = math.Random().nextInt(_newsPool.length);

      }
    } finally {
      setState(() {
        _isLoadingNews = false;
      });
    }
  }
  
  List<NewsArticle> _getFallbackNews() {
    return [
      NewsArticle(
        title: "WHO warns about rising flu cases this season",
        description: "Health authorities recommend vaccination",
        url: "",
        imageUrl: "https://source.unsplash.com/96x96/?virus",
        source: "WHO",
        publishedAt: DateTime.now().toIso8601String(),
      ),
      NewsArticle(
        title: "New study links walking 30 mins/day to better heart health",
        description: "Research shows significant cardiovascular benefits",
        url: "",
        imageUrl: "https://source.unsplash.com/96x96/?heart",
        source: "Health Research",
        publishedAt: DateTime.now().toIso8601String(),
      ),
      NewsArticle(
        title: "Researchers develop painless glucose monitoring patch",
        description: "Breakthrough in diabetes management technology",
        url: "",
        imageUrl: "https://source.unsplash.com/96x96/?glucose",
        source: "Medical Innovation",
        publishedAt: DateTime.now().toIso8601String(),
      ),
      NewsArticle(
        title: "Meditation shown to reduce stress hormones by 25%",
        description: "Study confirms mental health benefits",
        url: "",
        imageUrl: "https://source.unsplash.com/96x96/?meditation",
        source: "Wellness Research",
        publishedAt: DateTime.now().toIso8601String(),
      ),
    ];
  }


  
  void _initializeWearableService() async {
    _wearableService = context.read<AndroidWearableService>();
    // Attempt auto-reconnect (service already tries on init, but do again on dashboard)
    // ignore: unawaited_futures
    _wearableService!.autoReconnect();

    // Listen to changes via ChangeNotifier
    _wearableService!.addListener(() {
      if (!mounted) return;
      setState(() {
        final svc = _wearableService!;
        _isWatchConnected = svc.isConnected;
        // Update vitals from wearable service
        if (svc.heartRate > 0) _heartRate = svc.heartRate.toString();
        if (svc.spo2 > 0) _spo2 = svc.spo2.toString();
        if (svc.temperature > 0) _temperature = svc.temperature.toString();

      });
    });
  }

  @override
  void dispose() {

    _ecgController.dispose();

    _bgController.dispose();
    _pulseController.dispose();
    _newsTimer?.cancel();
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
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildHeader(),
                  const SizedBox(height: 16),
                  // Vitals Section
                  StaggeredAnimation(
                    index: 0,
                    child: _buildCompactVitalsCard(),
                  ),
                  const SizedBox(height: 16),
                  // News & Mood Section
                  StaggeredAnimation(
                    index: 1,
                    child: SizedBox(
                      height: 75,
                      child: Row(
                        children: [
                          Expanded(
                            flex: 3,
                            child: _buildNewsCard(),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            flex: 2,
                            child: _buildMoodSelector(),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  // Quick Actions Title
                  Padding(
                    padding: const EdgeInsets.only(left: 6, bottom: 16),
                    child: Row(
                      children: [
                        Container(
                          width: 4,
                          height: 20,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                                AppTheme.accentColor,
                                AppTheme.primaryColor,
                              ],
                            ),
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                        const SizedBox(width: 10),
                        ShaderMask(
                          shaderCallback: (bounds) => LinearGradient(
                            colors: [
                              Colors.white,
                              Colors.white.withOpacity(0.8),
                            ],
                          ).createShader(bounds),
                          child: const Text(
                            'Quick Actions',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                              fontFamily: 'Montserrat',
                              letterSpacing: 0.3,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Quick Actions Section
                  StaggeredAnimation(
                    index: 2,
                    child: _buildQuickActionsSection(),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      height: 75,
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
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(3),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            AppTheme.accentColor.withOpacity(0.25),
                            AppTheme.accentColor.withOpacity(0.15),
                          ],
                        ),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        FeatherIcons.sun,
                        color: AppTheme.accentColor,
                        size: 8,
                      ),
                    ),
                    const SizedBox(width: 5),
                    Text(
                      _getGreeting().toUpperCase(),
                      style: TextStyle(
                        fontSize: 7,
                        color: AppTheme.accentColor.withOpacity(0.9),
                        fontFamily: 'Montserrat',
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 3),
                Consumer<AuthService>(
                  builder: (context, auth, _) {
                    final name = auth.currentUser?.displayName?.split(' ').first ?? 'User';
                    return Text(
                      name,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                        fontFamily: 'Montserrat',
                        letterSpacing: -0.5,
                        height: 1.1,
                      ),
                      overflow: TextOverflow.ellipsis,
                    );
                  },
                ),
              ],
            ),
          ),
          _buildHeaderStatusCard(
            icon: FeatherIcons.watch,
            isActive: _isWatchConnected,
            onTap: () => Navigator.pushNamed(context, AppConstants.routeWearable),
          ),
          const SizedBox(width: 8),
          _buildHeaderIconButton(
            icon: FeatherIcons.inbox,
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const InboxScreen()),
            ),
          ),
          const SizedBox(width: 8),
          _buildHeaderIconButton(
            icon: FeatherIcons.bell,
            onTap: () {},
          ),
          const SizedBox(width: 8),
          Consumer<AuthService>(
            builder: (context, auth, _) {
              final user = auth.currentUser;
              return GestureDetector(
                onTap: () => Navigator.pushNamed(context, AppConstants.routeProfile),
                child: Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: Colors.white.withOpacity(0.3),
                      width: 2,
                    ),
                    image: user?.photoURL != null
                        ? DecorationImage(
                            image: NetworkImage(user!.photoURL!),
                            fit: BoxFit.cover,
                          )
                        : null,
                    gradient: LinearGradient(
                      colors: [
                        AppTheme.primaryColor,
                        AppTheme.accentColor,
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: AppTheme.primaryColor.withOpacity(0.4),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: user?.photoURL == null
                      ? const Icon(FeatherIcons.user, color: Colors.white, size: 18)
                      : null,
                ),
              );
            },
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

  Widget _buildHeaderIconButton({
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 34,
        height: 34,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Colors.white.withOpacity(0.15),
              Colors.white.withOpacity(0.08),
            ],
          ),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: Colors.white.withOpacity(0.15),
            width: 1,
          ),
        ),
        child: Icon(icon, color: Colors.white.withOpacity(0.9), size: 16),
      ),
    );
  }

  Widget _buildCompactVitalsCard() {
    return GestureDetector(
      onTap: () => Navigator.pushNamed(context, AppConstants.routeVitals),
      child: Container(
        height: 75,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              const Color(0xFF2C2C3E).withOpacity(0.95),
              const Color(0xFF1a1a2e).withOpacity(0.85),
            ],
          ),
          border: Border.all(
            color: Colors.white.withOpacity(0.12),
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.3),
              blurRadius: 20,
              offset: const Offset(0, 8),
              spreadRadius: -2,
            ),
            BoxShadow(
              color: AppTheme.primaryColor.withOpacity(0.1),
              blurRadius: 15,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Stack(
          children: [
            Positioned(
              top: -30,
              right: -10,
              child: Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      Colors.white.withOpacity(0.04),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),
            Positioned(
              bottom: -25,
              left: -15,
              child: Container(
                width: 70,
                height: 70,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      Colors.white.withOpacity(0.03),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(18),
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.white.withOpacity(0.03),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _buildVitalItem(
                    icon: FeatherIcons.activity,
                    value: _heartRate,
                    unit: 'bpm',
                    color: const Color(0xFFE57373),
                    delay: 0,
                  ),
                  Container(
                    width: 1,
                    height: 30,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.white.withOpacity(0.0),
                          Colors.white.withOpacity(0.12),
                          Colors.white.withOpacity(0.0),
                        ],
                      ),
                    ),
                  ),
                  _buildVitalItem(
                    icon: FeatherIcons.droplet,
                    value: _spo2,
                    unit: '%',
                    color: const Color(0xFF64B5F6),
                    delay: 50,
                  ),
                  Container(
                    width: 1,
                    height: 30,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.white.withOpacity(0.0),
                          Colors.white.withOpacity(0.12),
                          Colors.white.withOpacity(0.0),
                        ],
                      ),
                    ),
                  ),
                  _buildVitalItem(
                    icon: FeatherIcons.thermometer,
                    value: _temperature,
                    unit: '°C',
                    color: const Color(0xFFFFB74D),
                    delay: 100,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildVitalItem({
    required IconData icon,
    required String value,
    required String unit,
    required Color color,
    required int delay,
  }) {
    final double targetValue = double.tryParse(value) ?? 0;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        AnimatedBuilder(
          animation: _pulseController,
          builder: (context, child) {
            return Transform.scale(
              scale: 1.0 + (_pulseController.value * 0.08),
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: color.withOpacity(0.35),
                    width: 1.5,
                  ),
                  gradient: RadialGradient(
                    colors: [
                      color.withOpacity(0.3),
                      color.withOpacity(0.1),
                    ],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: color.withOpacity(0.3 * _pulseController.value),
                      blurRadius: 12,
                      spreadRadius: 2,
                    ),
                  ],
                ),
                child: Icon(
                  icon,
                  color: Colors.white.withOpacity(0.95),
                  size: 16,
                ),
              ),
            );
          },
        ),
        const SizedBox(width: 8),
        TweenAnimationBuilder<double>(
          tween: Tween(begin: 0.0, end: targetValue),
          duration: const Duration(milliseconds: 1200),
          curve: Curves.easeOutCubic,
          builder: (context, val, child) {
            if (value == '--') {
              return const Text(
                '--',
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  fontFamily: 'Montserrat',
                ),
              );
            }

            return ShaderMask(
              shaderCallback: (rect) => LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Colors.white,
                  color.withOpacity(0.8),
                ],
              ).createShader(rect),
              blendMode: BlendMode.srcIn,
              child: Text(
                val.toInt().toString(),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  fontFamily: 'Montserrat',
                ),
              ),
            );
          },
        ),
        const SizedBox(width: 3),
        Text(
          unit,
          style: TextStyle(
            color: color.withOpacity(0.65),
            fontSize: 12,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.3,
          ),
        ),
      ],
    );
  }

  Widget _buildQuickActionsSection() {
    final actions = [
      {
        'title': 'AI Symptoms',
        'icon': FeatherIcons.activity,
        'color': _canUseSymptomAnalysis ? const Color(0xFFFF6B6B) : Colors.grey,
        'route': AppConstants.routeSymptomAI,
        'isLocked': !_canUseSymptomAnalysis,
      },
      {
        'title': 'AI Chat',
        'icon': FeatherIcons.messageCircle,
        'color': const Color(0xFF4ECDC4),
        'route': AppConstants.routeChat,
      },
      {
        'title': 'Medicines',
        'icon': FeatherIcons.package,
        'color': _canUseDrugInfo ? const Color(0xFF95E1D3) : Colors.grey,
        'route': AppConstants.routeDrug,
        'isLocked': !_canUseDrugInfo,
      },
      {
        'title': 'Hospitals',
        'icon': FeatherIcons.plusSquare,
        'color': const Color(0xFFFF6B6B),
        'route': AppConstants.routeHospital,
      },
      {
        'title': 'Doctors',
        'icon': FeatherIcons.userCheck,
        'color': const Color(0xFF4ECDC4),
        'route': AppConstants.routeDoctorSearch,
      },
      {
        'title': 'First Aid',
        'icon': FeatherIcons.heart,
        'color': const Color(0xFFFF6B6B),
        'route': AppConstants.routeFirstAid,
      },
      {
        'title': 'Blood',
        'icon': FeatherIcons.droplet,
        'color': const Color(0xFFE57373),
        'route': AppConstants.routeBloodDonation,
      },
      {
        'title': 'Reminders',
        'icon': FeatherIcons.bell,
        'color': const Color(0xFFFFB74D),
        'route': AppConstants.routeReminder,
      },
      {
        'title': 'Timeline',
        'icon': FeatherIcons.clock,
        'color': const Color(0xFF64B5F6),
        'route': AppConstants.routeTimeline,
      },
      {
        'title': 'Emergency',
        'icon': FeatherIcons.alertOctagon,
        'color': const Color(0xFFFF5252),
        'route': AppConstants.routeSos,
      },
      {
        'title': 'Health ID',
        'icon': FeatherIcons.creditCard,
        'color': const Color(0xFF4FC3F7),
        'route': AppConstants.routeHealthId,
      },
      {
        'title': 'Habits',
        'icon': FeatherIcons.checkCircle,
        'color': const Color(0xFF81C784),
        'route': AppConstants.routeHealthHabits,
      },
      {
        'title': 'Wearable',
        'icon': FeatherIcons.watch,
        'color': const Color(0xFF9575CD),
        'route': AppConstants.routeWearable,
      },
      {
        'title': 'Community',
        'icon': FeatherIcons.users,
        'color': const Color(0xFF4DB6AC),
        'route': AppConstants.routeCommunitySupport,
      },
      {
        'title': 'Cases',
        'icon': FeatherIcons.folder,
        'color': const Color(0xFF63A2BF), // match your light teal
        'route': AppConstants.routeCases,
      },

    ];

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(0, 0, 0, 24),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 14,
        mainAxisSpacing: 14,
        childAspectRatio: 1.0,
      ),
      itemCount: actions.length,
      itemBuilder: (context, index) {
        final action = actions[index];
        return _buildActionCard(
          title: action['title'] as String,
          icon: action['icon'] as IconData,
          color: action['color'] as Color,
          onTap: () {
            if (action['isLocked'] == true) {
              _showLimitReachedDialog(action['title'] as String);
            } else {
              Navigator.pushNamed(context, action['route'] as String);
            }
          },
          index: index,
          isLocked: action['isLocked'] as bool? ?? false,
        );
      },
    );
  }

  void _showLimitReachedDialog(String feature) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E2C),
        title: Text('$feature Limit Reached', style: const TextStyle(color: Colors.white)),
        content: const Text(
          'You have reached your daily limit for this feature. Upgrade to Premium for unlimited access.',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.pushNamed(context, AppConstants.routePremium);
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryColor),
            child: const Text('Upgrade', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  String _getGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good Morning';
    if (hour < 17) return 'Good Afternoon';
    return 'Good Evening';
  }

  Widget _buildCompactVital({
    required IconData icon,
    required String value,
    required String unit,
    required Color color,
    required int delay,
  }) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: Duration(milliseconds: 600 + delay),
      curve: Curves.easeOutCubic,
      builder: (context, animValue, child) {
        return Transform.translate(
          offset: Offset(0, 10 * (1 - animValue)),
          child: Opacity(
            opacity: animValue,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                AnimatedBuilder(
                  animation: _pulseController,
                  builder: (context, child) {
                    return Transform.scale(
                      scale: 1.0 + (_pulseController.value * 0.05),
                      child: Container(
                        padding: const EdgeInsets.all(5), // Minimal padding
                        decoration: BoxDecoration(
                          color: color.withOpacity(0.12),
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: color.withOpacity(0.15 * _pulseController.value),
                              blurRadius: 6,
                              spreadRadius: 0.5,
                            ),
                          ],
                        ),
                        child: Icon(icon, color: color, size: 14), // Tiny icon
                      ),
                    );
                  },
                ),
                const SizedBox(height: 4),
                TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0.0, end: double.tryParse(value) ?? 0),
                  duration: const Duration(milliseconds: 1000),
                  curve: Curves.easeOut,
                  builder: (context, val, child) {
                    return Text(
                      value == '--' ? '--' : val.toInt().toString(),
                      style: const TextStyle(
                        fontSize: 16, // Smaller font
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        height: 1.0,
                        fontFamily: 'Montserrat',
                      ),
                    );
                  },
                ),
                const SizedBox(height: 2),
                Text(
                  unit,
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.5),
                    fontSize: 8, // Tiny unit
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.2,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildActionCard({
    required String title,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
    required int index,
    bool isLocked = false,
  }) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: Duration(milliseconds: 350 + (index * 40)),
      curve: Curves.easeOutCubic,
      builder: (context, animValue, child) {
        return Transform.scale(
          scale: 0.88 + (0.12 * animValue),
          child: Opacity(
            opacity: animValue,
            child: GestureDetector(
              onTap: onTap,
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(24),
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Colors.white.withOpacity(0.1),
                      Colors.white.withOpacity(0.05),
                    ],
                  ),
                  border: Border.all(
                    color: Colors.white.withOpacity(0.15),
                    width: 1.5,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: color.withOpacity(0.15),
                      blurRadius: 12,
                      offset: const Offset(0, 6),
                      spreadRadius: -2,
                    ),
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 8,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(24),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Stack(
                          alignment: Alignment.center,
                          children: [
                            Container(
                              width: 54,
                              height: 54,
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                  colors: [
                                    color.withOpacity(0.85),
                                    color.withOpacity(0.65),
                                  ],
                                ),
                                borderRadius: BorderRadius.circular(18),
                                boxShadow: [
                                  BoxShadow(
                                    color: color.withOpacity(0.4),
                                    blurRadius: 12,
                                    spreadRadius: 0,
                                  ),
                                ],
                              ),
                              child: Icon(
                                icon,
                                size: 26,
                                color: Colors.white,
                              ),
                            ),
                            if (isLocked)
                              Container(
                                width: 54,
                                height: 54,
                                decoration: BoxDecoration(
                                  color: Colors.black.withOpacity(0.5),
                                  borderRadius: BorderRadius.circular(18),
                                ),
                                child: const Icon(
                                  FeatherIcons.lock,
                                  size: 20,
                                  color: Colors.white,
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          child: Text(
                            title,
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                              fontFamily: 'Montserrat',
                              letterSpacing: 0.3,
                              height: 1.2,
                            ),
                            textAlign: TextAlign.center,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }



  Widget _buildNewsCard() {
    if (_newsPool.isEmpty) return const SizedBox.shrink();
    
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 500),
      transitionBuilder: (Widget child, Animation<double> animation) {
        return FadeTransition(
          opacity: animation,
          child: SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(0.3, 0),
              end: Offset.zero,
            ).animate(animation),
            child: child,
          ),
        );
      },
      child: _buildNewsItem(_newsPool[_currentNewsIndex], _currentNewsIndex),
    );
  }
  
  Widget _buildNewsItem(NewsArticle article, int index) {
    return GestureDetector(
      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => NewsDetailScreen(article: article))),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(22),
          border: Border.all(
            color: Colors.white.withOpacity(0.12),
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.3),
              blurRadius: 20,
              offset: const Offset(0, 8),
              spreadRadius: -2,
            ),
            BoxShadow(
              color: AppTheme.accentColor.withOpacity(0.15),
              blurRadius: 15,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(22),
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (article.imageUrl != null)
                Image.network(
                  article.imageUrl!,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) => Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [AppTheme.primaryColor, AppTheme.accentColor],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                    ),
                  ),
                )
              else
                Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [AppTheme.primaryColor, AppTheme.accentColor],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                  ),
                ),
              Positioned.fill(
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.black.withOpacity(0.3),
                        Colors.black.withOpacity(0.8),
                      ],
                    ),
                  ),
                ),
              ),
              Positioned.fill(
                child: Container(
                  decoration: BoxDecoration(
                    gradient: RadialGradient(
                      center: const Alignment(-0.6, -0.8),
                      radius: 1.2,
                      colors: [
                        Colors.white.withOpacity(0.08),
                        Colors.transparent,
                      ],
                    ),
                  ),
                ),
              ),
              Positioned(
                top: -35,
                right: -15,
                child: Container(
                  width: 100,
                  height: 100,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        AppTheme.accentColor.withOpacity(0.08),
                        Colors.transparent,
                      ],
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                AppTheme.accentColor.withOpacity(0.8),
                                AppTheme.accentColor.withOpacity(0.6),
                              ],
                            ),
                            borderRadius: BorderRadius.circular(6),
                            boxShadow: [
                              BoxShadow(
                                color: AppTheme.accentColor.withOpacity(0.3),
                                blurRadius: 8,
                                spreadRadius: 1,
                              ),
                            ],
                          ),
                          child: const Text(
                            'NEWS',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 8,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.8,
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            article.source ?? 'HealthWire',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.7),
                              fontSize: 9,
                              letterSpacing: 0.5,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        const SizedBox(width: 4),
                        Container(
                          padding: const EdgeInsets.all(3),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.15),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            FeatherIcons.arrowUpRight,
                            color: Colors.white.withOpacity(0.8),
                            size: 10,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      article.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10.5,
                        fontWeight: FontWeight.w800,
                        height: 1.2,
                        letterSpacing: 0.2,
                        shadows: [
                          Shadow(
                            color: Colors.black38,
                            offset: Offset(0, 1),
                            blurRadius: 4,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMoodSelector() {
    final moods = ['😄', '🙂', '😐', '😔', '😢'];
    final colors = [
      const Color(0xFF66BB6A),
      const Color(0xFF64B5F6),
      const Color(0xFFFFB74D),
      const Color(0xFFFF8A65),
      const Color(0xFFE57373),
    ];
    
    int currentIndex = moods.indexOf(_selectedMood.isEmpty ? '🙂' : _selectedMood);
    if (currentIndex == -1) currentIndex = 1;
    final currentColor = colors[currentIndex];

    return GestureDetector(
      onTap: () {
        int nextIndex = (currentIndex + 1) % moods.length;
        _saveUserMood(moods[nextIndex]);
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeInOut,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(22),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              currentColor.withOpacity(0.25),
              currentColor.withOpacity(0.1),
            ],
          ),
          border: Border.all(
            color: currentColor.withOpacity(0.35),
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: currentColor.withOpacity(0.25),
              blurRadius: 20,
              offset: const Offset(0, 8),
              spreadRadius: -2,
            ),
            BoxShadow(
              color: Colors.black.withOpacity(0.2),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Stack(
          children: [
            Positioned(
              top: -25,
              right: -20,
              child: Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      Colors.white.withOpacity(0.06),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),
            Positioned(
              bottom: -30,
              left: -25,
              child: Container(
                width: 90,
                height: 90,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      currentColor.withOpacity(0.2),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),
            Center(
              child: Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withOpacity(0.08),
                  border: Border.all(
                    color: Colors.white.withOpacity(0.18),
                    width: 2,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: currentColor.withOpacity(0.3),
                      blurRadius: 15,
                      spreadRadius: 2,
                    ),
                  ],
                ),
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 400),
                  transitionBuilder: (Widget child, Animation<double> animation) {
                    return ScaleTransition(
                      scale: Tween<double>(begin: 0.8, end: 1.0).animate(
                        CurvedAnimation(
                          parent: animation,
                          curve: Curves.elasticOut,
                        ),
                      ),
                      child: RotationTransition(
                        turns: Tween<double>(begin: 0.85, end: 1.0).animate(animation),
                        child: child,
                      ),
                    );
                  },
                  child: Center(
                    child: Text(
                      moods[currentIndex],
                      key: ValueKey<String>(moods[currentIndex]),
                      style: const TextStyle(fontSize: 34),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
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
      onEnd: () {
        if (mounted) {
          setState(() {});
        }
      },
    );
  }
}

class ECGPainter extends CustomPainter {
  final double animationValue;

  ECGPainter(this.animationValue);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppTheme.accentColor.withOpacity(0.5)
      ..strokeWidth = 2.0
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final path = Path();
    final width = size.width;
    final height = size.height;
    final midY = height / 2;

    path.moveTo(0, midY);
    
    // Draw a more realistic ECG wave
    // P wave
    path.lineTo(width * 0.1, midY);
    path.quadraticBezierTo(width * 0.15, midY - height * 0.2, width * 0.2, midY);
    
    // QRS complex
    path.lineTo(width * 0.3, midY); // Q start
    path.lineTo(width * 0.35, midY + height * 0.2); // Q
    path.lineTo(width * 0.45, midY - height * 0.8); // R
    path.lineTo(width * 0.55, midY + height * 0.3); // S
    path.lineTo(width * 0.6, midY); // S end
    
    // T wave
    path.lineTo(width * 0.7, midY);
    path.quadraticBezierTo(width * 0.8, midY - height * 0.3, width * 0.9, midY);
    path.lineTo(width, midY);

    // Create a gradient shader for the path
    final shader = LinearGradient(
      colors: [
        Colors.transparent,
        AppTheme.accentColor,
        Colors.transparent,
      ],
      stops: [
        (animationValue - 0.2).clamp(0.0, 1.0),
        animationValue,
        (animationValue + 0.2).clamp(0.0, 1.0),
      ],
    ).createShader(Rect.fromLTWH(0, 0, width, height));

    paint.shader = shader;

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(ECGPainter oldDelegate) => true;
}