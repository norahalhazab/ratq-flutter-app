import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'whq_screen.dart';

class CaseCreatedStartScreen extends StatefulWidget {
  const CaseCreatedStartScreen({
    super.key,
    required this.caseId,
  });

  final String caseId;

  @override
  State<CaseCreatedStartScreen> createState() => _CaseCreatedStartScreenState();
}

class _CaseCreatedStartScreenState extends State<CaseCreatedStartScreen> {
  bool _navigating = false;

  Future<void> _goToWHQ() async {
    if (_navigating) return;
    setState(() => _navigating = true);

    await Future.delayed(const Duration(milliseconds: 160));
    if (!mounted) return;

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => WhqScreen(caseId: widget.caseId),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          const _LiquidBlueBackground(),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(18, 14, 18, 18),
              child: Column(
                children: [
                  // Top bar
                  Row(
                    children: [
                      const SizedBox(width: 34),
                      Expanded(
                        child: Center(
                          child: Text(
                            "Ratq",
                            style: GoogleFonts.inter(
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                              color: Colors.white.withOpacity(0.95),
                              letterSpacing: 0.2,
                            ),
                          ),
                        ),
                      ),
                      SizedBox(
                        width: 34,
                        child: IconButton(
                          padding: EdgeInsets.zero,
                          onPressed: _navigating ? null : () => Navigator.pop(context),
                          icon: Icon(
                            Icons.close_rounded,
                            color: Colors.white.withOpacity(0.92),
                            size: 22,
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 14),

                  // Content
                  Expanded(
                    child: Stack(
                      children: [
                        Align(
                          alignment: Alignment.topCenter,
                          child: _GlassHeroPanel(
                            height: 300,
                            child: Padding(
                              padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: const [
                                      _GlassBadgeIcon(icon: Icons.health_and_safety_rounded),
                                      SizedBox(width: 10),
                                      Expanded(
                                        child: _HeroTitle(),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 10),
                                  Text(
                                    "You’re all set. Your daily check-in helps track healing and detect early infection signals.",
                                    style: GoogleFonts.inter(
                                      fontSize: 13.2,
                                      height: 1.5,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.white.withOpacity(0.78),
                                    ),
                                  ),
                                  const Spacer(),
                                  Row(
                                    children: [
                                      Icon(
                                        Icons.info_outline_rounded,
                                        color: Colors.white.withOpacity(0.72),
                                        size: 18,
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          "Tip: Try to check at the same time each day.",
                                          style: GoogleFonts.inter(
                                            fontSize: 11.6,
                                            height: 1.35,
                                            fontWeight: FontWeight.w600,
                                            color: Colors.white.withOpacity(0.66),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),

                        Align(
                          alignment: Alignment.bottomCenter,
                          child: _BottomGlass(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  "What you’ll do",
                                  style: GoogleFonts.dmSans(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w900,
                                    color: Colors.white.withOpacity(0.95),
                                  ),
                                ),
                                const SizedBox(height: 12),

                                const _GlassStepTile(
                                  icon: Icons.quiz_outlined,
                                  title: "WHQ Questionnaire",
                                  subtitle: "Answer quick healing questions",
                                ),
                                const SizedBox(height: 10),
                                const _GlassStepTile(
                                  icon: Icons.photo_camera_outlined,
                                  title: "Wound Photo",
                                  subtitle: "Capture the wound image",
                                ),
                                const SizedBox(height: 10),
                                const _GlassStepTile(
                                  icon: Icons.thermostat_outlined,
                                  title: "Temperature",
                                  subtitle: "Record your temperature",
                                ),
                                const SizedBox(height: 10),
                                const _GlassStepTile(
                                  icon: Icons.monitor_heart_outlined,
                                  title: "Infection Risk Score",
                                  subtitle: "Get your daily risk signal",
                                ),

                                const SizedBox(height: 16),

                                // Slider always at the bottom (same page)
                                _SlideToStart(
                                  text: "Slide to start daily check",
                                  loading: _navigating,
                                  onCompleted: _goToWHQ,
                                ),

                                const SizedBox(height: 8),
                                Text(
                                  "Start now — it takes less than a minute.",
                                  style: GoogleFonts.inter(
                                    fontSize: 11.8,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.white.withOpacity(0.62),
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
            ),
          ),
        ],
      ),
    );
  }
}

/* ---------------- Small pieces ---------------- */

class _HeroTitle extends StatelessWidget {
  const _HeroTitle();

  @override
  Widget build(BuildContext context) {
    return Text(
      "Starting your\nwound monitoring",
      style: GoogleFonts.dmSans(
        fontSize: 24,
        height: 1.05,
        fontWeight: FontWeight.w900,
        color: Colors.white.withOpacity(0.96),
      ),
    );
  }
}

/* ---------------- Step tile (NO arrow) ---------------- */

class _GlassStepTile extends StatelessWidget {
  const _GlassStepTile({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
        child: Container(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            color: const Color(0xFF63A2BF).withOpacity(0.16),
            border: Border.all(color: Colors.white.withOpacity(0.18)),
          ),
          child: Row(
            children: [
              _TinyGlassIcon(icon: icon),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: GoogleFonts.inter(
                        fontSize: 13.3,
                        fontWeight: FontWeight.w900,
                        color: Colors.white.withOpacity(0.95),
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      subtitle,
                      style: GoogleFonts.inter(
                        fontSize: 11.6,
                        height: 1.35,
                        fontWeight: FontWeight.w600,
                        color: Colors.white.withOpacity(0.75),
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
}

class _TinyGlassIcon extends StatelessWidget {
  const _TinyGlassIcon({required this.icon});
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.16),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.white.withOpacity(0.18)),
          ),
          child: Icon(icon, color: Colors.white.withOpacity(0.92), size: 20),
        ),
      ),
    );
  }
}

/* ---------------- Slide To Start ---------------- */

class _SlideToStart extends StatefulWidget {
  const _SlideToStart({
    required this.text,
    required this.onCompleted,
    this.loading = false,
  });

  final String text;
  final VoidCallback onCompleted;
  final bool loading;

  @override
  State<_SlideToStart> createState() => _SlideToStartState();
}

class _SlideToStartState extends State<_SlideToStart> {
  double _dx = 0.0;
  bool _done = false;

  void _complete() {
    if (_done || widget.loading) return;
    setState(() => _done = true);
    widget.onCompleted();
  }

  @override
  Widget build(BuildContext context) {
    const double h = 54;
    const double knob = 46;

    return LayoutBuilder(
      builder: (context, c) {
        final trackW = c.maxWidth;
        final maxDx = (trackW - knob - 6).clamp(0.0, double.infinity);

        return ClipRRect(
          borderRadius: BorderRadius.circular(999),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
            child: Container(
              width: double.infinity,
              height: h,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(999),
                color: Colors.black.withOpacity(0.22),
                border: Border.all(color: Colors.white.withOpacity(0.22)),
              ),
              child: Stack(
                children: [
                  Positioned.fill(
                    child: Center(
                      child: AnimatedOpacity(
                        duration: const Duration(milliseconds: 180),
                        opacity: (_done || widget.loading) ? 0.0 : 1.0,
                        child: Text(
                          widget.text,
                          style: GoogleFonts.inter(
                            fontSize: 12.8,
                            fontWeight: FontWeight.w800,
                            color: Colors.white.withOpacity(0.88),
                          ),
                        ),
                      ),
                    ),
                  ),

                  // subtle shine
                  Positioned.fill(
                    child: IgnorePointer(
                      child: Opacity(
                        opacity: 0.30,
                        child: Container(
                          decoration: const BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [Colors.white12, Colors.transparent, Colors.white10],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),

                  Positioned(
                    left: 3 + _dx,
                    top: (h - knob) / 2,
                    child: GestureDetector(
                      onHorizontalDragUpdate: widget.loading
                          ? null
                          : (d) {
                        if (_done) return;
                        setState(() {
                          _dx = (_dx + d.delta.dx).clamp(0.0, maxDx);
                        });
                      },
                      onHorizontalDragEnd: widget.loading
                          ? null
                          : (_) {
                        if (_done) return;
                        final reached = _dx >= maxDx * 0.90;
                        if (reached) {
                          setState(() => _dx = maxDx);
                          _complete();
                        } else {
                          setState(() => _dx = 0.0);
                        }
                      },
                      child: ClipOval(
                        child: BackdropFilter(
                          filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
                          child: Container(
                            width: knob,
                            height: knob,
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.92),
                              border: Border.all(color: Colors.white.withOpacity(0.95)),
                            ),
                            child: widget.loading
                                ? const Padding(
                              padding: EdgeInsets.all(12),
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                                : const Icon(
                              Icons.arrow_forward_rounded,
                              color: Color(0xFF0F172A),
                              size: 22,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

/* ---------------- Background / Glass ---------------- */

class _LiquidBlueBackground extends StatelessWidget {
  const _LiquidBlueBackground();

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Color(0xFF6FB8D7),
                Color(0xFF4A97B8),
                Color(0xFF2D6F8B),
                Color(0xFF20384A),
              ],
            ),
          ),
        ),
        const Positioned(top: -180, left: -120, child: _Blob(size: 460, color: Colors.white24)),
        const Positioned(top: 140, right: -160, child: _Blob(size: 520, color: Colors.white12)),
        const Positioned(bottom: -220, left: -140, child: _Blob(size: 560, color: Color(0xFF63A2BF))),
        BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 80, sigmaY: 80),
          child: Container(color: Colors.transparent),
        ),
        Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Colors.white.withOpacity(0.06),
                Colors.transparent,
                Colors.black.withOpacity(0.22),
              ],
            ),
          ),
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
      decoration: BoxDecoration(
        color: color.withOpacity(0.14),
        shape: BoxShape.circle,
      ),
    );
  }
}

class _GlassHeroPanel extends StatelessWidget {
  const _GlassHeroPanel({required this.height, required this.child});
  final double height;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(34),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
        child: Container(
          height: height,
          width: double.infinity,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(34),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Colors.white.withOpacity(0.18),
                Colors.white.withOpacity(0.10),
              ],
            ),
            border: Border.all(color: Colors.white.withOpacity(0.22)),
          ),
          child: child,
        ),
      ),
    );
  }
}

class _BottomGlass extends StatelessWidget {
  const _BottomGlass({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(30),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(30),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Colors.white.withOpacity(0.16),
                Colors.white.withOpacity(0.08),
              ],
            ),
            border: Border.all(color: Colors.white.withOpacity(0.20)),
          ),
          child: child,
        ),
      ),
    );
  }
}

class _GlassBadgeIcon extends StatelessWidget {
  const _GlassBadgeIcon({required this.icon});
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
        child: Container(
          width: 52,
          height: 52,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            color: Colors.white.withOpacity(0.16),
            border: Border.all(color: Colors.white.withOpacity(0.20)),
          ),
          child: Icon(icon, color: Colors.white.withOpacity(0.92), size: 24),
        ),
      ),
    );
  }
}
