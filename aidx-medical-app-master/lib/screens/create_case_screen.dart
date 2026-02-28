// create_case_screen.dart
import 'dart:ui';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../utils/app_colors.dart';
import '../widgets/bottom_nav.dart';
import 'cases_screen.dart';
import 'whq_screen.dart';

class CreateCaseScreen extends StatefulWidget {
  const CreateCaseScreen({super.key});

  @override
  State<CreateCaseScreen> createState() => _CreateCaseScreenState();
}

class _CreateCaseScreenState extends State<CreateCaseScreen> {
  DateTime? _surgeryDate;
  bool _loading = false;

  final TextEditingController _caseNameCtrl = TextEditingController();

  @override
  void dispose() {
    _caseNameCtrl.dispose();
    super.dispose();
  }

  void _toast(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _goToCases() {
    Navigator.pushReplacement(context, _route(const CasesScreen()));
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();

    final picked = await showDatePicker(
      context: context,
      firstDate: DateTime(2000),
      lastDate: now,
      initialDate: _surgeryDate ?? now,
      builder: (context, child) {
        final base = Theme.of(context);
        return Theme(
          data: base.copyWith(
            colorScheme: base.colorScheme.copyWith(
              primary: AppColors.primaryColor,
              onPrimary: Colors.white,
              surface: Colors.white,
              onSurface: AppColors.textPrimary,
            ),
            textButtonTheme: TextButtonThemeData(
              style: TextButton.styleFrom(
                foregroundColor: AppColors.primaryColor,
                textStyle: GoogleFonts.inter(fontWeight: FontWeight.w800),
              ),
            ),
            dialogTheme: DialogThemeData(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(26),
              ),
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) setState(() => _surgeryDate = picked);
  }

  Future<int> _getNextCaseNumber(String uid) async {
    final snap = await FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('cases')
        .orderBy('caseNumber', descending: true)
        .limit(1)
        .get();

    if (snap.docs.isEmpty) return 1;

    final data = snap.docs.first.data();
    final raw = data['caseNumber'];

    if (raw is int) return raw + 1;
    final parsed = int.tryParse('$raw');
    return (parsed ?? 0) + 1;
  }

  Future<void> _createCase() async {
    final name = _caseNameCtrl.text.trim();

    if (_surgeryDate == null) {
      _toast("Please select the surgery date");
      return;
    }

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      _toast("You are not logged in");
      return;
    }

    setState(() => _loading = true);

    try {
      final nextNo = await _getNextCaseNumber(user.uid);
      final finalName = name.isNotEmpty ? name : "Wound $nextNo";

      final docRef = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('cases')
          .add({
        'caseNumber': nextNo,
        'caseNo': nextNo,
        'caseName': finalName,
        'title': finalName,
        'status': 'active',
        'infectionScore': 0,
        'surgeryDate': Timestamp.fromDate(_surgeryDate!),
        'startDate': Timestamp.fromDate(_surgeryDate!),
        'lastUpdated': FieldValue.serverTimestamp(),
        'createdAt': FieldValue.serverTimestamp(),
      });

      if (!mounted) return;
      _toast("Case created ✅");

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => WhqScreen(caseId: docRef.id)),
      );
    } catch (e) {
      _toast(e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final dd = _surgeryDate == null ? "DD" : _two(_surgeryDate!.day);
    final mm = _surgeryDate == null ? "MM" : _two(_surgeryDate!.month);
    final yyyy = _surgeryDate == null ? "YYYY" : _surgeryDate!.year.toString();

    return Scaffold(
      backgroundColor: AppColors.backgroundColor,
      bottomNavigationBar: AppBottomNav(
        currentIndex: 2,
        onNewTap: () {}, // already here
      ),
      body: Stack(
        children: [
          const _BlueGlassyBackground(),
          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 118),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ===== Top bar (matches CasesScreen style) =====
                  Row(
                    children: [
                      _IconPillButton(
                        icon: Icons.arrow_back_ios_new_rounded,
                        onTap: _goToCases,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Center(
                          child: Text(
                            "Create Wound",
                            style: GoogleFonts.dmSans(
                              fontSize: 28,
                              fontWeight: FontWeight.w900,
                              color: AppColors.textPrimary,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 44), // balance
                    ],
                  ),

                  const SizedBox(height: 14),

                  // ===== Wound name =====
                  Text(
                    "Wound name",
                    style: GoogleFonts.inter(
                      fontSize: 20, // Subheading
                      fontWeight: FontWeight.w900,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 10), // tighter spacing (fix your issue)
                  _BlueGlassTextField(
                    controller: _caseNameCtrl,
                    hintText: "e.g. Left knee",
                  ),

                  const SizedBox(height: 18),

                  // ===== Surgery date =====
                  Text(
                    "Surgery date",
                    style: GoogleFonts.inter(
                      fontSize: 20, // Subheading
                      fontWeight: FontWeight.w900,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 10),

                  Row(
                    children: [
                      Expanded(
                        child: _BlueGlassDateBox(
                          label: "Day",
                          value: dd,
                          onTap: _pickDate,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _BlueGlassDateBox(
                          label: "Month",
                          value: mm,
                          onTap: _pickDate,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _BlueGlassDateBox(
                          label: "Year",
                          value: yyyy,
                          onTap: _pickDate,
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 18),

                  const _FaqGlassCard(),

                  const SizedBox(height: 18),

                  // ===== Primary button (match other pages) =====
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: _loading
                        ? const _LoadingPrimaryButton()
                        : _PrimaryButton(
                      label: "Create Wound Case",
                      onTap: _createCase,
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

/* ---------------- helpers ---------------- */

String _two(int n) => n.toString().padLeft(2, '0');

PageRouteBuilder _route(Widget page) {
  return PageRouteBuilder(
    transitionDuration: const Duration(milliseconds: 180),
    pageBuilder: (_, __, ___) => page,
    transitionsBuilder: (_, a, __, child) {
      return FadeTransition(
        opacity: CurvedAnimation(parent: a, curve: Curves.easeOut),
        child: child,
      );
    },
  );
}

/* ===================== Background: same as CasesScreen ===================== */

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

/* ===================== Pills (match CasesScreen) ===================== */

class _IconPillButton extends StatelessWidget {
  const _IconPillButton({required this.icon, required this.onTap});
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(999),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(999),
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
            child: Icon(icon, color: AppColors.primaryColor, size: 18),
          ),
        ),
      ),
    );
  }
}

/* ===================== Inputs (blue-tinted like login) ===================== */

class _BlueGlassTextField extends StatelessWidget {
  const _BlueGlassTextField({
    required this.controller,
    required this.hintText,
  });

  final TextEditingController controller;
  final String hintText;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            color: Colors.white,
            border: Border.all(
              color: AppColors.primaryColor.withOpacity(0.15),
              width: 1.2,
            ),
            boxShadow: [
              BoxShadow(
                color: AppColors.primaryColor.withOpacity(0.08),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: TextField(
            controller: controller,
            textInputAction: TextInputAction.done,
            style: GoogleFonts.inter(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
            decoration: InputDecoration(
              border: InputBorder.none,
              hintText: hintText,
              hintStyle: GoogleFonts.inter(
                fontSize: 15,
                fontWeight: FontWeight.w500,
                color: AppColors.textMuted.withOpacity(0.6),
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 4,
                vertical: 14,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _BlueGlassDateBox extends StatelessWidget {
  const _BlueGlassDateBox({
    required this.label,
    required this.value,
    required this.onTap,
  });

  final String label;
  final String value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isPlaceholder = value == "DD" || value == "MM" || value == "YYYY";

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
          child: Container(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              color: Colors.white.withOpacity(0.92), // ✅ white box
              border: Border.all(color: AppColors.dividerColor.withOpacity(0.9)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.06),
                  blurRadius: 18,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: GoogleFonts.inter(
                    fontSize: 14, // Small info
                    fontWeight: FontWeight.w700,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Text(
                      value,
                      style: GoogleFonts.inter(
                        fontSize: 16, // Body
                        fontWeight: FontWeight.w900,
                        color: isPlaceholder ? AppColors.textMuted : AppColors.textPrimary,
                      ),
                    ),
                    const Spacer(),
                    Icon(
                      Icons.calendar_month_rounded,
                      size: 18,
                      color: AppColors.primaryColor.withOpacity(0.85),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/* ===================== Primary button (match other pages vibe) ===================== */

class _PrimaryButton extends StatelessWidget {
  const _PrimaryButton({required this.label, required this.onTap});
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: AppColors.primaryGradient,
          boxShadow: const [
            BoxShadow(
              color: Color(0x22000000),
              blurRadius: 18,
              offset: Offset(0, 10),
            ),
          ],
        ),
        child: Center(
          child: Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 16, // Body
              fontWeight: FontWeight.w900,
              color: Colors.white,
            ),
          ),
        ),
      ),
    );
  }
}

class _LoadingPrimaryButton extends StatelessWidget {
  const _LoadingPrimaryButton();

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            color: Colors.white.withOpacity(0.80),
            border: Border.all(color: AppColors.primaryColor.withOpacity(0.22)),
          ),
          child: const Center(
            child: SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          ),
        ),
      ),
    );
  }
}

/* ===================== FAQ card (same, but font sizing aligned) ===================== */

class _FaqGlassCard extends StatefulWidget {
  const _FaqGlassCard();

  @override
  State<_FaqGlassCard> createState() => _FaqGlassCardState();
}

class _FaqGlassCardState extends State<_FaqGlassCard> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    return _FrostedCard(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    "What happens next?",
                    style: GoogleFonts.inter(
                      fontSize: 16, // Body
                      fontWeight: FontWeight.w900,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
                TextButton(
                  onPressed: () => setState(() => _expanded = !_expanded),
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    minimumSize: Size.zero,
                    foregroundColor: AppColors.primaryColor,
                    textStyle: GoogleFonts.inter(
                      fontSize: 14, // Small info
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  child: Text(_expanded ? "View less" : "View more"),
                ),
                const SizedBox(width: 6),
                InkWell(
                  onTap: () => setState(() => _expanded = !_expanded),
                  borderRadius: BorderRadius.circular(999),
                  child: Container(
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.70),
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(color: AppColors.primaryColor.withOpacity(0.20)),
                    ),
                    child: Icon(
                      _expanded ? Icons.keyboard_arrow_up_rounded : Icons.keyboard_arrow_down_rounded,
                      color: AppColors.primaryColor,
                      size: 22,
                    ),
                  ),
                ),
              ],
            ),
            AnimatedCrossFade(
              firstChild: const SizedBox(height: 0),
              secondChild: Padding(
                padding: const EdgeInsets.only(top: 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: const [
                    _FaqLine(icon: Icons.quiz_outlined, text: "Complete the WHQ questionnaire"),
                    SizedBox(height: 10),
                    _FaqLine(icon: Icons.photo_camera_outlined, text: "Capture wound images"),
                    SizedBox(height: 10),
                    _FaqLine(icon: Icons.thermostat_outlined, text: "Record your temperature"),
                    SizedBox(height: 10),
                    _FaqLine(icon: Icons.monitor_heart_outlined, text: "Get infection risk score"),
                  ],
                ),
              ),
              crossFadeState: _expanded ? CrossFadeState.showSecond : CrossFadeState.showFirst,
              duration: const Duration(milliseconds: 220),
              sizeCurve: Curves.easeOutCubic,
            ),
          ],
        ),
      ),
    );
  }
}

class _FaqLine extends StatelessWidget {
  const _FaqLine({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            color: AppColors.primaryColor.withOpacity(0.08),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.primaryColor.withOpacity(0.12)),
          ),
          child: Icon(icon, color: AppColors.primaryColor.withOpacity(0.9), size: 18),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            text,
            style: GoogleFonts.inter(
              fontSize: 14, // Small info
              height: 1.35,
              fontWeight: FontWeight.w700,
              color: AppColors.textSecondary,
            ),
          ),
        ),
      ],
    );
  }
}

/* ===================== Frosted card helper ===================== */

class _FrostedCard extends StatelessWidget {
  const _FrostedCard({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(22),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(22),
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
          child: child,
        ),
      ),
    );
  }
}