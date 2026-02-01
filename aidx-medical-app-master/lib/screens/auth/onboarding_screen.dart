import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'login_screen.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _controller = PageController();
  int _index = 0;

  final pages = const <_OnbModel>[
    _OnbModel(
      title: "What is Ratq?",
      subtitle:
      "Ratq is a post-surgery wound monitoring app that helps patients track healing and watch for possible infection signs.",
      imagePath: "assets/images/onb_1.png",
    ),
    _OnbModel(
      title: "Daily check in seconds",
      subtitle:
      "After creating an account, you will answer a quick questionnaire (WHQ) and take a photo of your wound to get an infection risk score.",
      imagePath: "assets/images/onb_2.png",
    ),
    _OnbModel(
      title: "Dashboard & doctor report",
      subtitle:
      "View your dashboard, trends, and a summary report you can share with your doctor for better follow-up.",
      imagePath: "assets/images/onb_3.png",
    ),
  ];

  Future<void> _finish() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('seen_onboarding', true);

    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const LoginScreen()),
    );
  }

  Future<void> _next() async {
    final isLast = _index == pages.length - 1;
    if (isLast) {
      await _finish();
    } else {
      await _controller.nextPage(
        duration: const Duration(milliseconds: 320),
        curve: Curves.easeOutCubic,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isLast = _index == pages.length - 1;

    return Scaffold(
      body: Stack(
        children: [
          const _LiquidGlassBackground(),

          SafeArea(
            child: Column(
              children: [
                // Top bar: Close (X)
                Padding(
                  padding: const EdgeInsets.only(left: 10, right: 10, top: 6),
                  child: Row(
                    children: [
                      _CircleIconButton(
                        icon: Icons.close_rounded,
                        onTap: _finish,
                      ),
                      const Spacer(),
                    ],
                  ),
                ),

                // Top Logos row (same vibe as your reference)
                Padding(
                  padding: const EdgeInsets.fromLTRB(18, 8, 18, 0),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // watermark big
                      Opacity(
                        opacity: 0.22,
                        child: Image.asset(
                          "assets/images/logo1.png",
                          height: 92,
                        ),
                      ),
                      const Spacer(),
                      Opacity(
                        opacity: 0.95,
                        child: Image.asset(
                          "assets/images/logo2.png",
                          height: 64,
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 8),

                // Center illustration (keeps same position/size)
                Expanded(
                  child: PageView.builder(
                    controller: _controller,
                    itemCount: pages.length,
                    onPageChanged: (i) => setState(() => _index = i),
                    itemBuilder: (context, i) {
                      return _CenterIllustration(imagePath: pages[i].imagePath);
                    },
                  ),
                ),

                // Bottom glass card
                Padding(
                  padding: const EdgeInsets.fromLTRB(18, 0, 18, 18),
                  child: _BottomGlassCard(
                    title: pages[_index].title,
                    subtitle: pages[_index].subtitle,
                    index: _index,
                    total: pages.length,
                    isLast: isLast,
                    onSkip: _finish,
                    onNext: _next,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/* ---------------- Models ---------------- */

class _OnbModel {
  final String title;
  final String subtitle;
  final String imagePath;

  const _OnbModel({
    required this.title,
    required this.subtitle,
    required this.imagePath,
  });
}

/* ---------------- Background (NO CHESS) ---------------- */

class _LiquidGlassBackground extends StatelessWidget {
  const _LiquidGlassBackground();

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // base gradient
        Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [
                Color(0xFF173343),
                Color(0xFF1F4257),
                Color(0xFF102634),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),

        // soft blobs (liquid)
        Positioned(
          top: -120,
          left: -90,
          child: _Blob(
            size: 320,
            color: const Color(0xFF63A2BF).withOpacity(0.35),
          ),
        ),
        Positioned(
          top: 120,
          right: -140,
          child: _Blob(
            size: 360,
            color: Colors.white.withOpacity(0.12),
          ),
        ),
        Positioned(
          bottom: -150,
          left: -80,
          child: _Blob(
            size: 380,
            color: const Color(0xFF3B7691).withOpacity(0.28),
          ),
        ),

        // blur the blobs so it looks like liquid glass
        BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 60, sigmaY: 60),
          child: Container(color: Colors.transparent),
        ),

        // subtle vignette (adds depth)
        Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                Colors.black.withOpacity(0.30),
                Colors.transparent,
                Colors.black.withOpacity(0.25),
              ],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
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
        color: color,
        shape: BoxShape.circle,
      ),
    );
  }
}

/* ---------------- UI Pieces ---------------- */

class _CircleIconButton extends StatelessWidget {
  const _CircleIconButton({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ClipOval(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
        child: InkWell(
          onTap: onTap,
          child: Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.14),
              border: Border.all(color: Colors.white.withOpacity(0.22)),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: Colors.white.withOpacity(0.92), size: 20),
          ),
        ),
      ),
    );
  }
}

class _CenterIllustration extends StatelessWidget {
  const _CenterIllustration({required this.imagePath});
  final String imagePath;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(18, 6, 18, 10),
        child: Image.asset(
          imagePath,
          height: 170,
          fit: BoxFit.contain,
          errorBuilder: (_, __, ___) => Icon(
            Icons.image_not_supported,
            color: Colors.white.withOpacity(0.7),
            size: 42,
          ),
        ),
      ),
    );
  }
}

class _BottomGlassCard extends StatelessWidget {
  const _BottomGlassCard({
    required this.title,
    required this.subtitle,
    required this.index,
    required this.total,
    required this.isLast,
    required this.onSkip,
    required this.onNext,
  });

  final String title;
  final String subtitle;
  final int index;
  final int total;
  final bool isLast;
  final VoidCallback onSkip;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(26),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(26),
            // glass fill (no pattern)
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Colors.white.withOpacity(0.22),
                Colors.white.withOpacity(0.14),
              ],
            ),
            border: Border.all(color: Colors.white.withOpacity(0.22)),
            boxShadow: const [
              BoxShadow(
                color: Color(0x22000000),
                blurRadius: 22,
                offset: Offset(0, 12),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w900,
                  color: Colors.white.withOpacity(0.98),
                  height: 1.08,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                subtitle,
                style: TextStyle(
                  fontSize: 12.8,
                  fontWeight: FontWeight.w600,
                  color: Colors.white.withOpacity(0.78),
                  height: 1.35,
                ),
              ),

              const SizedBox(height: 14),

              // dots
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(total, (i) {
                  final active = i == index;
                  return AnimatedContainer(
                    duration: const Duration(milliseconds: 250),
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    width: active ? 18 : 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: active
                          ? Colors.white.withOpacity(0.95)
                          : Colors.white.withOpacity(0.30),
                      borderRadius: BorderRadius.circular(99),
                    ),
                  );
                }),
              ),

              const SizedBox(height: 14),

              Row(
                children: [
                  if (!isLast)
                    _GlassTextBtn(text: "Skip", onTap: onSkip)
                  else
                    const SizedBox(width: 56),
                  const Spacer(),
                  _PillActionBtn(
                    text: isLast ? "Get started" : "Next",
                    onTap: onNext,
                    big: isLast,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _GlassTextBtn extends StatelessWidget {
  const _GlassTextBtn({required this.text, required this.onTap});
  final String text;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
        child: Text(
          text,
          style: TextStyle(
            color: Colors.white.withOpacity(0.85),
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}

class _PillActionBtn extends StatelessWidget {
  const _PillActionBtn({
    required this.text,
    required this.onTap,
    this.big = false,
  });

  final String text;
  final VoidCallback onTap;
  final bool big;

  @override
  Widget build(BuildContext context) {
    final h = big ? 52.0 : 46.0;
    final padX = big ? 26.0 : 20.0;

    return ClipRRect(
      borderRadius: BorderRadius.circular(999),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: InkWell(
          onTap: onTap,
          child: Container(
            height: h,
            padding: EdgeInsets.symmetric(horizontal: padX),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              // visible pill
              color: Colors.white.withOpacity(0.86),
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: Colors.white.withOpacity(0.95), width: 1),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x18000000),
                  blurRadius: 12,
                  offset: Offset(0, 8),
                ),
              ],
            ),
            child: Text(
              text,
              style: const TextStyle(
                color: Color(0xFF0E232E),
                fontWeight: FontWeight.w900,
                fontSize: 14.5,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
