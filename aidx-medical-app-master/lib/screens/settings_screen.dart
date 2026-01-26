import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_fonts/google_fonts.dart';

import '../widgets/bottom_nav.dart';
import 'profile_screen.dart';
import 'wearable_screen.dart'; // change to your smartwatch screen file
import 'auth/login_screen.dart';


class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  static const bg = Color(0xFFFFFFFF);
  static const primary = Color(0xFF3B7691);
  static const cardBg = Color(0xFFF8FAFC);
  static const border = Color(0xFFC8D3DF);

  Future<void> _logout(BuildContext context) async {
    await FirebaseAuth.instance.signOut();

    if (!context.mounted) return;

    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const LoginScreen()),
          (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bg,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(18, 18, 18, 90),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "Settings",
                style: GoogleFonts.dmSans(
                  fontSize: 26,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF0F172A),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                "Manage your account and preferences",
                style: GoogleFonts.inter(
                  fontSize: 13.5,
                  color: const Color(0xFF475569),
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 18),

              _SectionCard(
                title: "Account Settings",
                children: [
                  _SettingsTile(
                    icon: Icons.person_outline,
                    title: "User Profile",
                    subtitle: "Manage your personal information",
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const ProfileScreen()),
                      );
                    },
                  ),
                  const SizedBox(height: 12),
                  _SettingsTile(
                    icon: Icons.watch_outlined,
                    title: "Smartwatch Pairing",
                    subtitle: "Connect or manage your smartwatch",
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const WearableScreen()),
                      );
                    },
                  ),
                ],
              ),

              const SizedBox(height: 16),

              _SectionCard(
                title: "App Information",
                children: [
                  _InfoRow(label: "Version", value: "1.0.0"),
                  const SizedBox(height: 10),
                  _InfoRow(label: "Language", value: "English"),
                ],
              ),

              const SizedBox(height: 18),

              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton.icon(
                  onPressed: () => _logout(context),
                  icon: const Icon(Icons.logout, color: Colors.white),
                  label: Text(
                    "Logout",
                    style: GoogleFonts.inter(
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFB31217),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 0,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      bottomNavigationBar: const Padding(
        padding: EdgeInsets.all(10),
        child: AppBottomNav(currentIndex: 3),
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({
    required this.title,
    required this.children,
  });

  final String title;
  final List<Widget> children;

  static const cardBg = Color(0xFFF8FAFC);
  static const border = Color(0xFFC8D3DF);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: border.withOpacity(0.6)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: GoogleFonts.dmSans(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: const Color(0xFF0F172A),
            ),
          ),
          const SizedBox(height: 12),
          ...children,
        ],
      ),
    );
  }
}

class _SettingsTile extends StatelessWidget {
  const _SettingsTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  static const primary = Color(0xFF3B7691);
  static const border = Color(0xFFC8D3DF);

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: border.withOpacity(0.6)),
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: primary.withOpacity(0.10),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: primary),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: GoogleFonts.dmSans(
                      fontSize: 14.5,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF0F172A),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: GoogleFonts.inter(
                      fontSize: 12.5,
                      color: const Color(0xFF3B7691),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: Color(0xFF94A3B8)),
          ],
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 13,
              color: const Color(0xFF475569),
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        Text(
          value,
          style: GoogleFonts.inter(
            fontSize: 13,
            color: const Color(0xFF0F172A),
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}
