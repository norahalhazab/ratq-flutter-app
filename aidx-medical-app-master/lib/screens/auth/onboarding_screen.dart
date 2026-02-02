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

  static const int _total = 3;

  final List<_OnbModel> pages = const [
    _OnbModel(
      title: "Welcome to Ratq",
      subtitle:
      "Track your wound healing and get early infection risk signals with quick daily check-ins.",
      buttonText: "Next",
    ),
    _OnbModel(
      title: "Daily check in seconds",
      subtitle:
      "Answer the WHQ questionnaire and capture a wound photo to get an infection risk score.",
      buttonText: "Next",
    ),
    _OnbModel(
      title: "Let’s Get Started!",
      subtitle: "Sign in or create an account to begin.",
      buttonText: "Get Started",
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
    final isLast = _index == _total - 1;
    if (isLast) {
      await _finish();
    } else {
      await _controller.nextPage(
        duration: const Duration(milliseconds: 340),
        curve: Curves.easeOutCubic,
      );
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isLast = _index == _total - 1;

    return Scaffold(
      body: Stack(
        children: [
          const _LightLiquidGlassBackground(),

          SafeArea(
            child: Stack(
              children: [
                // ✅ top progress lines (FULL WIDTH like Arc)
                Positioned(
                  left: 18,
                  right: 18,
                  top: 15,
                  child: _TopProgressFullWidth(index: _index, total: _total),
                ),

                // ✅ Skip bigger (top-right)
                Positioned(
                  right: 16,
                  top: 10,
                  child: TextButton(
                    onPressed: _finish,
                    style: TextButton.styleFrom(
                      foregroundColor: Colors.white.withOpacity(0.96),
                      textStyle: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    ),
                    child: const Text("Skip"),
                  ),
                ),

// ✅ PageView (show image on page 1 & 2)
                PageView.builder(
                  controller: _controller,
                  itemCount: pages.length,
                  onPageChanged: (i) => setState(() => _index = i),
                  itemBuilder: (context, i) {
                    return Stack(
                      children: [
                        // PAGE 1 (index 0)
                        if (i == 0)
                          Align(
                            alignment: Alignment.topCenter,
                            child: Padding(
                              padding: const EdgeInsets.only(top: 22),
                              child: Image.asset(
                                "assets/images/onb11.png",
                                height: 460,
                                fit: BoxFit.contain,
                              ),
                            ),
                          ),

                        // PAGE 2 (index 1)
                        if (i == 1)
                          Align(
                            alignment: Alignment.topCenter,
                            child: Padding(
                              padding: const EdgeInsets.only(top: 22),
                              child: Image.asset(
                                "assets/images/onb22.png",
                                height: 480,
                                fit: BoxFit.contain,
                              ),
                            ),
                          ),
                        if (i == 2)
                          Align(
                            alignment: Alignment.topCenter,
                            child: Padding(
                              padding: const EdgeInsets.only(top: 22),
                              child: Image.asset(
                                "assets/images/logo2.png",
                                height: 420,
                                fit: BoxFit.contain,
                              ),
                            ),
                          ),
                      ],
                    );
                  },
                ),

                // ✅ Title + subtitle positions like Arc (lower-left)
                Positioned(
                  left: 24,
                  right: 24,
                  bottom: isLast ? 150 : 130, // give more air on last page
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        pages[_index].title,
                        style: const TextStyle(
                          fontSize: 48,
                          fontWeight: FontWeight.w900,
                          height: 1.02,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 14),
                      Text(
                        pages[_index].subtitle,
                        style: TextStyle(
                          fontSize: 20,
                          height: 1.55,
                          fontWeight: FontWeight.w400,
                          color: Colors.white.withOpacity(0.82),
                        ),
                      ),
                    ],
                  ),
                ),

                // ✅ Button placement:
                // - Next: bottom-right small outline pill
                // - Get Started: BIG centered button (like Arc)
                Positioned(
                  left: 22,
                  right: 22,
                  bottom: 78,
                  child: isLast
                      ? _BigCenterButton(
                    text: pages[_index].buttonText,
                    onTap: _next,
                  )
                      : Align(
                    alignment: Alignment.centerRight,
                    child: _OutlinePillButton(
                      text: pages[_index].buttonText,
                      onTap: _next,
                    ),
                  ),
                ),

                // ✅ Bottom "Already have an account? Sign in"
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 28,
                  child: Center(
                    child: _BottomSignIn(
                      onSignIn: _finish,
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
}

/* ---------------- model ---------------- */

class _OnbModel {
  final String title;
  final String subtitle;
  final String buttonText;

  const _OnbModel({
    required this.title,
    required this.subtitle,
    required this.buttonText,
  });
}

/* ---------------- background (LIGHT white-blue liquid glass) ---------------- */

class _LightLiquidGlassBackground extends StatelessWidget {
  const _LightLiquidGlassBackground();

  // base palette (light, not dark)
  static const Color a = Color(0xFFAED7EA);
  static const Color b = Color(0xFF86C2DA);
  static const Color c = Color(0xFF63A2BF); // your main

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // bright gradient base
        Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [a, b, c],
            ),
          ),
        ),

        // soft blobs (white glass)
        Positioned(
          top: -140,
          left: -140,
          child: _Blob(size: 420, color: Colors.white.withOpacity(0.24)),
        ),
        Positioned(
          top: 120,
          right: -180,
          child: _Blob(size: 520, color: Colors.white.withOpacity(0.16)),
        ),
        Positioned(
          bottom: -220,
          left: -160,
          child: _Blob(size: 560, color: Colors.white.withOpacity(0.18)),
        ),
        Positioned(
          bottom: 40,
          right: -120,
          child: _Blob(size: 360, color: Colors.white.withOpacity(0.10)),
        ),

        // blur to make it liquid/glass
        BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 80, sigmaY: 80),
          child: Container(color: Colors.transparent),
        ),

        // gentle vignette + gloss
        Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Colors.white.withOpacity(0.06),
                Colors.transparent,
                Colors.black.withOpacity(0.08),
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
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
    );
  }
}

/* ---------------- top progress lines (FULL WIDTH) ---------------- */

class _TopProgressFullWidth extends StatelessWidget {
  const _TopProgressFullWidth({required this.index, required this.total});
  final int index;
  final int total;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: List.generate(total, (i) {
        final active = i == index;
        return Expanded(
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 280),
            curve: Curves.easeOutCubic,
            margin: EdgeInsets.only(right: i == total - 1 ? 0 : 10),
            height: 4,
            decoration: BoxDecoration(
              color: active
                  ? Colors.white.withOpacity(0.95)
                  : Colors.white.withOpacity(0.40),
              borderRadius: BorderRadius.circular(999),
            ),
          ),
        );
      }),
    );
  }
}

/* ---------------- buttons ---------------- */

class _OutlinePillButton extends StatelessWidget {
  const _OutlinePillButton({
    required this.text,
    required this.onTap,
  });

  final String text;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: Container(
        height: 48,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: Colors.white.withOpacity(0.88), width: 1.4),
          color: Colors.white.withOpacity(0.08),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              text,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
                fontSize: 14.5,
              ),
            ),
            const SizedBox(width: 10),
            const Icon(Icons.chevron_right_rounded, color: Colors.white, size: 20),
          ],
        ),
      ),
    );
  }
}

class _BigCenterButton extends StatelessWidget {
  const _BigCenterButton({
    required this.text,
    required this.onTap,
  });

  final String text;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: Container(
        height: 54,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: Colors.white.withOpacity(0.85), width: 1.6),
          color: Colors.white.withOpacity(0.10),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              text,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w800,
                fontSize: 15,
              ),
            ),
            const SizedBox(width: 10),
            const Icon(Icons.chevron_right_rounded, color: Colors.white, size: 22),
          ],
        ),
      ),
    );
  }
}

/* ---------------- bottom sign in ---------------- */

class _BottomSignIn extends StatelessWidget {
  const _BottomSignIn({required this.onSignIn});
  final VoidCallback onSignIn;

  static const Color accent = Color(0xFF0F5F7A); // readable on light-blue bg

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 18),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            "Already have an account? ",
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w500,
              color: Colors.white.withOpacity(0.88),
            ),
          ),
          GestureDetector(
            onTap: onSignIn,
            child: const Text(
              "Sign in",
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: accent,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
