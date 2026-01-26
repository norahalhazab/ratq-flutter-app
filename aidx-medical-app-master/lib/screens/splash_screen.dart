import 'dart:async';
import 'package:flutter/material.dart';
import 'package:aidx/utils/constants.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  static const Color bgColor = Color(0xFF63A2BF);

  @override
  void initState() {
    super.initState();

    // مدة السبلاتش
    Timer(const Duration(seconds: 2), () {
      if (!mounted) return;

      // يروح للّوجن (عندك route جاهز)
      Navigator.pushReplacementNamed(context, AppConstants.routeLogin);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bgColor,
      body: SafeArea(
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Image.asset(
                'assets/images/logo2.png',
                height: 120,
                fit: BoxFit.contain,
              ),
              const SizedBox(height: 18),
              const Text(
                'Ratq',
                style: TextStyle(
                  fontSize: 34,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Wound Monitoring App',
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.white70,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 28),
              const SizedBox(
                width: 26,
                height: 26,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  color: Colors.white,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
