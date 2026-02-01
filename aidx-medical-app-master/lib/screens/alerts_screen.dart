import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../widgets/bottom_nav.dart';

class AlertsScreen extends StatelessWidget {
  const AlertsScreen({super.key});

  static const bg = Colors.white;
  static const titleColor = Color(0xFF0F172A);
  static const muted = Color(0xFF94A3B8);
  static const bodyMuted = Color(0xFF64748B);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bg,

      body: SafeArea(
        child: Padding(
          // ✅ خلينا padding السفلي أكبر عشان ما يصير overlap مع البار
          padding: const EdgeInsets.fromLTRB(22, 18, 22, 110),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 8),

              Text(
                "Alert & Notifications",
                style: GoogleFonts.dmSans(
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
                  color: titleColor,
                ),
              ),
              const SizedBox(height: 6),

              Text(
                "Important updates about your wound healing",
                style: GoogleFonts.inter(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w500,
                  color: muted,
                ),
              ),

              const Spacer(),

              Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.notifications_none_rounded,
                      size: 34,
                      color: titleColor.withOpacity(0.85),
                    ),
                    const SizedBox(height: 18),
                    Text(
                      "No Notifications Yet",
                      style: GoogleFonts.inter(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w600,
                        color: titleColor,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      "You’ll be notified here once there’s\nsomething new.",
                      textAlign: TextAlign.center,
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        height: 1.4,
                        fontWeight: FontWeight.w400,
                        color: bodyMuted,
                      ),
                    ),
                  ],
                ),
              ),

              const Spacer(),
            ],
          ),
        ),
      ),

      // ✅ بدون Padding عشان ما يطلع Floating
      bottomNavigationBar: AppBottomNav(
        currentIndex: 3, // Alerts selected
        // لو تبين زر + يفتح CreateCase
        onNewTap: () {
          // اتركيه فاضي مؤقتًا أو افتحي create screen هنا
        },
      ),
    );
  }
}
