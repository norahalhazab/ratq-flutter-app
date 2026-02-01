import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'login_screen.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  static const bgTop = Color(0xFF63A2BF);
  static const bgBottom = Color(0xFFD8E7EF);

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _controller = PageController();
  int _index = 0;

  Future<void> _finish() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('seen_onboarding', true);

    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const LoginScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    // ✅ عدلي أسماء صورك هنا إذا مختلفة
    const pages = <_OnbModel>[
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

    final isLast = _index == pages.length - 1;

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [OnboardingScreen.bgTop, OnboardingScreen.bgBottom],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              const SizedBox(height: 18),

              // ✅ Logo switches between logo1/logo2 nicely
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 300),
                child: Image.asset(
                  _index == 0 ? 'assets/images/logo1.png' : 'assets/images/logo2.png',
                  key: ValueKey(_index == 0 ? 'logo1' : 'logo2'),
                  height: 92,
                ),
              ),

              const SizedBox(height: 10),
              const Text(
                "Ratq",
                style: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                "Wound Monitoring App",
                style: TextStyle(
                  fontSize: 14.5,
                  fontWeight: FontWeight.w600,
                  color: Colors.white70,
                ),
              ),

              const SizedBox(height: 18),

              Expanded(
                child: PageView.builder(
                  controller: _controller,
                  itemCount: pages.length,
                  onPageChanged: (i) => setState(() => _index = i),
                  itemBuilder: (context, i) => _OnbPage(model: pages[i]),
                ),
              ),

              const SizedBox(height: 12),

              // Dots
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(pages.length, (i) {
                  final active = i == _index;
                  return AnimatedContainer(
                    duration: const Duration(milliseconds: 250),
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    width: active ? 18 : 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: active ? Colors.white : Colors.white54,
                      borderRadius: BorderRadius.circular(99),
                    ),
                  );
                }),
              ),

              const SizedBox(height: 14),

              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 22),
                child: Row(
                  children: [
                    if (!isLast)
                      TextButton(
                        onPressed: _finish,
                        child: const Text(
                          "Skip",
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      )
                    else
                      const SizedBox(width: 60),

                    const Spacer(),

                    _GlassButton(
                      text: isLast ? "Get started" : "Next",
                      onTap: () async {
                        if (isLast) {
                          await _finish();
                        } else {
                          await _controller.nextPage(
                            duration: const Duration(milliseconds: 300),
                            curve: Curves.easeOut,
                          );
                        }
                      },
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

/* ---------------- Page UI ---------------- */

class _OnbPage extends StatelessWidget {
  const _OnbPage({required this.model});
  final _OnbModel model;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 10),
      child: Center(
        child: _GlassCard(
          child: Padding(
            padding: const EdgeInsets.all(22),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // ✅ Your transparent PNG goes here
                ClipRRect(
                  borderRadius: BorderRadius.circular(18),
                  child: Image.asset(
                    model.imagePath,
                    height: 130,
                    fit: BoxFit.contain,
                    errorBuilder: (_, __, ___) => Container(
                      height: 130,
                      alignment: Alignment.center,
                      child: const Icon(Icons.image_not_supported, color: Colors.white),
                    ),
                  ),
                ),

                const SizedBox(height: 18),

                Text(
                  model.title,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                    height: 1.1,
                  ),
                ),

                const SizedBox(height: 10),

                Text(
                  model.subtitle,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 13.8,
                    color: Colors.white70,
                    height: 1.35,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _GlassCard extends StatelessWidget {
  const _GlassCard({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(28),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.16),
            borderRadius: BorderRadius.circular(28),
            border: Border.all(color: Colors.white.withOpacity(0.25)),
          ),
          child: child,
        ),
      ),
    );
  }
}

class _GlassButton extends StatelessWidget {
  const _GlassButton({required this.text, required this.onTap});
  final String text;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(999),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: InkWell(
          onTap: onTap,
          child: Container(
            height: 48,
            padding: const EdgeInsets.symmetric(horizontal: 18),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.22),
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: Colors.white.withOpacity(0.35)),
            ),
            child: Text(
              text,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w800,
                fontSize: 14.5,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
