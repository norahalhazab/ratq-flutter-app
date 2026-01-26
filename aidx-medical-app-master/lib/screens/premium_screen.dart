import 'package:flutter/material.dart';
import 'package:flutter_feather_icons/flutter_feather_icons.dart';
import 'dart:ui';

class PremiumScreen extends StatefulWidget {
  const PremiumScreen({super.key});

  @override
  State<PremiumScreen> createState() => _PremiumScreenState();
}

class _PremiumScreenState extends State<PremiumScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // Background (simplified for now)
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color(0xFF0a0e27),
                  Color(0xFF16213e),
                  Color(0xFF0f3460),
                ],
              ),
            ),
          ),
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
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildPremiumFeatures(),
                        const SizedBox(height: 24),
                        // Subscription UI removed as Applink is removed
                        Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.05),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: Colors.white.withOpacity(0.1)),
                          ),
                          child: Center(
                            child: Text(
                              'Subscription service is currently unavailable.',
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.7),
                                fontSize: 14,
                              ),
                            ),
                          ),
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
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Colors.white.withOpacity(0.15),
                    Colors.white.withOpacity(0.08),
                  ],
                ),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: Colors.white.withOpacity(0.15),
                  width: 1,
                ),
              ),
              child: Icon(
                FeatherIcons.arrowLeft,
                color: Colors.white.withOpacity(0.9),
                size: 20,
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Premium Features',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                    fontFamily: 'Montserrat',
                    letterSpacing: -0.5,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPremiumFeatures() {
    final features = [
      {
        'icon': FeatherIcons.zap,
        'title': 'AI-Powered Analysis',
        'description': 'Advanced AI diagnostics with Gemini integration',
        'color': const Color(0xFF2196F3),
      },
      {
        'icon': FeatherIcons.activity,
        'title': 'Advanced Health Tracking',
        'description': 'Detailed vitals monitoring and trend analysis',
        'color': const Color(0xFF4CAF50),
      },
      {
        'icon': FeatherIcons.messageCircle,
        'title': 'Priority AI Chat Support',
        'description': '24/7 AI medical assistant with priority responses',
        'color': const Color(0xFF9C27B0),
      },
      {
        'icon': FeatherIcons.calendar,
        'title': 'Appointment Scheduling',
        'description': 'Book appointments with healthcare providers',
        'color': const Color(0xFFFF9800),
      },
      {
        'icon': FeatherIcons.fileText,
        'title': 'Medical Report Storage',
        'description': 'Secure cloud storage for all medical documents',
        'color': const Color(0xFFE91E63),
      },
      {
        'icon': FeatherIcons.bell,
        'title': 'Emergency Alerts',
        'description': 'Instant notifications for critical health events',
        'color': const Color(0xFFFF5252),
      },
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Unlock Premium Features',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            color: Colors.white.withOpacity(0.95),
            fontFamily: 'Montserrat',
          ),
        ),
        const SizedBox(height: 16),
        ...features.map((feature) => Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: _buildFeatureCard(feature),
        )),
      ],
    );
  }

  Widget _buildFeatureCard(Map<String, dynamic> feature) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.white.withOpacity(0.12),
            Colors.white.withOpacity(0.06),
          ],
        ),
        border: Border.all(
          color: Colors.white.withOpacity(0.18),
          width: 1.5,
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: feature['color'].withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    feature['icon'],
                    color: feature['color'],
                    size: 20,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        feature['title'],
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: Colors.white.withOpacity(0.9),
                          fontFamily: 'Montserrat',
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        feature['description'],
                        style: TextStyle(
                          fontSize: 12,
                          height: 1.4,
                          color: Colors.white.withOpacity(0.6),
                          fontFamily: 'Montserrat',
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  FeatherIcons.star,
                  color: const Color(0xFFFFD700).withOpacity(0.6),
                  size: 16,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
