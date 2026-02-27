// infection_assessment_screen.dart
import 'dart:async';
import 'dart:ui';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'cases_screen.dart';
import '../utils/app_colors.dart';

class InfectionAssessmentScreen extends StatefulWidget {
  const InfectionAssessmentScreen({
    super.key,
    required this.caseId,
    required this.whqResponseId,
    this.highThreshold = 4,
  });

  final String caseId;
  final String whqResponseId;
  final int highThreshold;

  @override
  State<InfectionAssessmentScreen> createState() =>
      _InfectionAssessmentScreenState();
}

class _InfectionAssessmentScreenState extends State<InfectionAssessmentScreen> {
  bool _writing = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    // Compute & write once when entering screen.
    WidgetsBinding.instance.addPostFrameCallback((_) => _computeAndSave());
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      return Scaffold(
        backgroundColor: AppColors.backgroundColor,
        body: SafeArea(
          child: Center(
            child: Text(
              "You must be logged in.",
              style: GoogleFonts.dmSans(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
          ),
        ),
      );
    }

    final base = FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .collection('cases')
        .doc(widget.caseId);

    final docRef =
    base.collection('whqResponses').doc(widget.whqResponseId).withConverter(
      fromFirestore: (s, _) => s.data() ?? <String, dynamic>{},
      toFirestore: (m, _) => m,
    );

    return Scaffold(
      backgroundColor: AppColors.backgroundColor,
      body: Stack(
        children: [
          const _BlueGlassyBackground(),
          SafeArea(
            child: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
              stream: docRef.snapshots(),
              builder: (context, snap) {
                if (snap.hasError) {
                  return _CenteredState(
                    title: "Couldn’t load assessment",
                    subtitle: "Please try again.",
                    icon: Icons.error_outline_rounded,
                  );
                }
                if (!snap.hasData) return const _LoadingState();

                final data = snap.data!.data();
                if (data == null || data.isEmpty) {
                  return _CenteredState(
                    title: "No assessment yet",
                    subtitle: "Complete today’s check to generate an assessment.",
                    icon: Icons.info_outline_rounded,
                  );
                }

                final int? finalScore = _asInt(data['finalScore']);
                final bool pending = finalScore == null || _writing;

                final bool isHigh = (!pending && finalScore! >= widget.highThreshold);

                final String title = "Infection Assessment";
                final String headline = pending
                    ? "Analyzing your data"
                    : (isHigh ? "High Signs of Infection" : "No Signs of Infection");
                final String description = pending
                    ? "We’re combining your questionnaire, photo, and vitals.\nThis may take a moment."
                    : (isHigh
                    ? "Several concerning signs detected.\nProfessional consultation recommended."
                    : "No concerning signs detected today.\nKeep monitoring to stay safe.");

                final Color badgeTint = pending
                    ? AppColors.warningColor
                    : (isHigh ? AppColors.errorColor : AppColors.successColor);

                final IconData badgeIcon = pending
                    ? Icons.hourglass_top_rounded
                    : (isHigh ? Icons.warning_amber_rounded : Icons.verified_rounded);

                final recs = pending
                    ? _pendingRecs()
                    : (isHigh ? _highRecs() : _lowRecs());

                return CustomScrollView(
                  slivers: [
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(12, 8, 12, 10),
                        child: Row(
                          children: [
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: GoogleFonts.dmSans(
                                  fontSize: 24,
                                  fontWeight: FontWeight.w900,
                                  color: AppColors.textPrimary,

                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            // tiny status chip
                            _IconPillButton(
                              icon: Icons.close,
                              onTap: () {
                                Navigator.pushAndRemoveUntil(
                                  context,
                                  MaterialPageRoute(builder: (_) => const CasesScreen()),
                                      (route) => false,
                                );
                              },
                            ),
                          ],
                        ),
                      ),
                    ),

                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(18, 6, 18, 10),
                        child: Text(
                          "",
                          style: GoogleFonts.inter(
                            fontSize: 13.0,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ),
                    ),

                    if (_error != null)
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                          child: _ErrorBanner(text: _error!),
                        ),
                      ),

                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(16, 6, 16, 12),
                        child: _AssessmentCard(
                          tint: badgeTint,
                          icon: badgeIcon,
                          headline: headline,
                          description: description,
                        ),
                      ),
                    ),

                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                        child: _NoticeCard(
                          text:
                          "Important Notice: This assessment is for monitoring purposes only and does not constitute medical diagnosis. Please consult your healthcare provider for proper medical advice.",
                        ),
                      ),
                    ),

                    const SliverToBoxAdapter(child: SizedBox(height: 22)),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _computeAndSave() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    if (_writing) return;
    setState(() {
      _writing = true;
      _error = null;
    });

    try {
      final base = FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('cases')
          .doc(widget.caseId);

      final respRef = base.collection('whqResponses').doc(widget.whqResponseId);
      final respSnap = await respRef.get();
      final data = respSnap.data() ?? <String, dynamic>{};

      // If already computed, do nothing.
      final existing = _asInt(data['finalScore']);
      if (existing != null) {
        if (mounted) setState(() => _writing = false);
        return;
      }

      // -------- 1) WHQ points --------
      final whqScore = _asInt(_deepGet(data, ['userResponse', 'questionnaireScore'])) ??
          _asInt(data['lastWhqScore']) ??
          0;


      // -------- 2) Image points (erythema/exudate) --------
      // Supports your screenshot: data['image']['erythema'] = 1, exudate = 1
      final erythema = _asInt(_deepGet(data, ['image', 'erythema'])) ?? 0;
      final exudate = _asInt(_deepGet(data, ['image', 'exudate'])) ?? 0;

      // If you store exudate as string category, map it here instead:
      // final exType = (_deepGet(data, ['image','exudateType']) ?? '').toString();
      final imagePoints = (erythema == 1 ? 1 : 0) + (exudate == 1 ? 1 : 0);

      // -------- 3) Vitals points --------
      // You can store vitals as flags (0/1) OR raw numbers.
      // This supports both patterns.

      final vitals = (_deepGet(data, ['vitals']) as Map?)?.cast<String, dynamic>();

      final vitalsPoints = _vitalsPointsFromAny(vitals);

      // -------- Final score --------
      final finalScore = whqScore + imagePoints + vitalsPoints;

      // Write to Firebase (same doc + case summary)
      final batch = FirebaseFirestore.instance.batch();

      batch.set(respRef, {
        'finalScore': finalScore,
        'updatedAt': FieldValue.serverTimestamp(),
        'assessment': {
          'computedAt': FieldValue.serverTimestamp(),
          'whqRaw': whqScore,
          'imagePoints': imagePoints,
          'vitalsPoints': vitalsPoints,
          'threshold': widget.highThreshold,
          'result': (finalScore >= widget.highThreshold) ? 'high' : 'low',
        },
      }, SetOptions(merge: true));

      batch.set(base, {
        'infectionScore': finalScore, // for your CasesScreen/Homepage
        'lastUpdated': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      await batch.commit();

      if (mounted) setState(() => _writing = false);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _writing = false;
        _error = "Couldn’t compute final score. (${e.toString()})";
      });
    }
  }

  // ---------------- Scoring rules (edit these) ----------------



  /// Accepts vitals map that may contain either:
  /// - flags: { fever:1, tachycardia:1, hypotension:0 }
  /// - numbers: { temperature: 38.2, heartRate: 110, systolic: 90 }
  int _vitalsPointsFromAny(Map<String, dynamic>? v) {
    if (v == null) return 0;

    final temp = _asDouble(v['temperature']);

    if (temp == null) return 0;

    // 🔥 Your rule
    if (temp >= 38.5) {
      return 1;
    }

    return 0;
  }

  static int? _tryParseBpSys(dynamic bp) {
    if (bp == null) return null;
    final s = bp.toString();
    final parts = s.split('/');
    if (parts.isEmpty) return null;
    return int.tryParse(parts.first.trim());
  }

  // ---------------- Utils ----------------

  static dynamic _deepGet(Map<String, dynamic> root, List<String> path) {
    dynamic cur = root;
    for (final k in path) {
      if (cur is Map<String, dynamic>) {
        cur = cur[k];
      } else if (cur is Map) {
        cur = cur[k];
      } else {
        return null;
      }
    }
    return cur;
  }

  static int? _asInt(dynamic v) {
    if (v == null) return null;
    if (v is int) return v;
    return int.tryParse(v.toString());
  }

  static double? _asDouble(dynamic v) {
    if (v == null) return null;
    if (v is double) return v;
    if (v is int) return v.toDouble();
    return double.tryParse(v.toString());
  }

  static List<String> _highRecs() => const [
    "Contact your healthcare provider soon",
    "Monitor your wound daily",
    "Watch for pain, swelling, or discharge",
    "Avoid home remedies without medical advice",
  ];

  static List<String> _lowRecs() => const [
    "Continue daily monitoring",
    "Follow your post-operative care instructions",
    "If symptoms appear (pain, swelling, fever), contact your doctor",
  ];

  static List<String> _pendingRecs() => const [
    "Stay on this screen for a moment",
    "If you feel unwell or symptoms worsen, contact your doctor",
  ];
}

/* ===================== UI widgets (same style) ===================== */

class _BlueGlassyBackground extends StatelessWidget {
  const _BlueGlassyBackground();

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Color(0xFFEAF5FB),
                Color(0xFFDCEEF7),
                Color(0xFFF7FBFF),
              ],
            ),
          ),
        ),
        Positioned(
          top: -170,
          left: -150,
          child: _Blob(
            size: 520,
            color: AppColors.secondaryColor.withOpacity(0.22),
          ),
        ),
        Positioned(
          top: 120,
          right: -180,
          child: _Blob(
            size: 560,
            color: AppColors.primaryColor.withOpacity(0.10),
          ),
        ),
        Positioned(
          bottom: -220,
          left: -160,
          child: _Blob(size: 600, color: Colors.white.withOpacity(0.60)),
        ),
        BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 70, sigmaY: 70),
          child: Container(color: Colors.transparent),
        ),
      ],
    );
  }
}

class _Blob extends StatelessWidget {
  const _Blob({required this.size, required this.color});
  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
    );
  }
}

class _IconPillButton extends StatelessWidget {
  const _IconPillButton({required this.icon, required this.onTap});
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: _WhitePill(
        radius: 999,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        child: Icon(icon, color: AppColors.primaryColor),
      ),
    );
  }
}

class _WhitePill extends StatelessWidget {
  const _WhitePill({
    required this.child,
    this.radius = 24,
    this.padding = const EdgeInsets.all(14),
  });

  final Widget child;
  final double radius;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          padding: padding,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(radius),
            color: Colors.white.withOpacity(0.90),
            border: Border.all(color: AppColors.dividerColor.withOpacity(0.9)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.06),
                blurRadius: 18,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: child,
        ),
      ),
    );
  }
}


class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        color: AppColors.errorColor.withOpacity(0.10),
        border: Border.all(color: AppColors.errorColor.withOpacity(0.22)),
      ),
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          const Icon(Icons.error_outline_rounded,
              color: AppColors.errorColor),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: GoogleFonts.inter(
                fontSize: 12.2,
                fontWeight: FontWeight.w800,
                color: AppColors.errorColor,
                height: 1.35,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AssessmentCard extends StatelessWidget {
  const _AssessmentCard({
    required this.tint,
    required this.icon,
    required this.headline,
    required this.description,
  });

  final Color tint;
  final IconData icon;
  final String headline;
  final String description;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(26),
        color: Colors.white.withOpacity(0.92),
        border: Border.all(color: AppColors.dividerColor.withOpacity(0.9)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x22000000),
            blurRadius: 22,
            offset: Offset(0, 12),
          ),
        ],
      ),
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 18),
      child: Column(
        children: [
          _IconBadge(tint: tint, icon: icon),
          const SizedBox(height: 14),
          Text(
            headline,
            textAlign: TextAlign.center,
            style: GoogleFonts.dmSans(
              fontSize: 22,
              fontWeight: FontWeight.w900,
              color: AppColors.textPrimary,
              height: 1.05,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            description,
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: AppColors.textSecondary,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }
}

class _IconBadge extends StatelessWidget {
  const _IconBadge({required this.tint, required this.icon});
  final Color tint;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 86,
      height: 86,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            tint.withOpacity(0.30),
            tint.withOpacity(0.16),
            Colors.white.withOpacity(0.85),
          ],
        ),
        border: Border.all(color: AppColors.dividerColor.withOpacity(0.9)),
      ),
      child: Icon(icon, size: 40, color: tint),
    );
  }
}

class _GlassSectionCard extends StatelessWidget {
  const _GlassSectionCard({
    required this.title,
    required this.subtitle,
    required this.child,
  });

  final String title;
  final String subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(26),
        color: Colors.white.withOpacity(0.92),
        border: Border.all(color: AppColors.dividerColor.withOpacity(0.9)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x22000000),
            blurRadius: 22,
            offset: Offset(0, 12),
          ),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: GoogleFonts.dmSans(
              fontSize: 18,
              fontWeight: FontWeight.w900,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: GoogleFonts.inter(
              fontSize: 12.8,
              fontWeight: FontWeight.w600,
              color: AppColors.textSecondary,
              height: 1.35,
            ),
          ),
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }
}

class _RecommendationRow extends StatelessWidget {
  const _RecommendationRow({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        color: AppColors.surfaceColor.withOpacity(0.95),
        border: Border.all(color: AppColors.dividerColor.withOpacity(0.9)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      child: Row(
        children: [
          Container(
            width: 26,
            height: 26,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.primaryColor.withOpacity(0.12),
              border:
              Border.all(color: AppColors.primaryColor.withOpacity(0.20)),
            ),
            child: const Icon(
              Icons.check_rounded,
              size: 18,
              color: AppColors.primaryColor,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: GoogleFonts.inter(
                fontSize: 12.8,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
                height: 1.35,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _NoticeCard extends StatelessWidget {
  const _NoticeCard({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        color: const Color(0xFFFFF5E6).withOpacity(0.92),
        border: Border.all(color: const Color(0xFFE9D6B5)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x11000000),
            blurRadius: 18,
            offset: Offset(0, 10),
          ),
        ],
      ),
      padding: const EdgeInsets.all(14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.info_outline_rounded, color: Color(0xFFB26A00)),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: GoogleFonts.inter(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: const Color(0xFF6B4B1E),
                height: 1.35,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _LoadingState extends StatelessWidget {
  const _LoadingState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: _WhitePill(
        radius: 18,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2.4),
            ),
            const SizedBox(width: 12),
            Text(
              "Loading…",
              style: GoogleFonts.inter(
                fontSize: 13,
                fontWeight: FontWeight.w800,
                color: AppColors.textPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CenteredState extends StatelessWidget {
  const _CenteredState({
    required this.title,
    required this.subtitle,
    required this.icon,
  });

  final String title;
  final String subtitle;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: _WhitePill(
          radius: 22,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: AppColors.primaryColor, size: 30),
              const SizedBox(height: 10),
              Text(
                title,
                textAlign: TextAlign.center,
                style: GoogleFonts.dmSans(
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                subtitle,
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(
                  fontSize: 12.8,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textSecondary,
                  height: 1.35,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}