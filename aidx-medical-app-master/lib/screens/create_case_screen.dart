import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_fonts/google_fonts.dart';

import '../widgets/bottom_nav.dart';
import 'case_created_start_screen.dart';

class CreateCaseScreen extends StatefulWidget {
  const CreateCaseScreen({super.key});

  @override
  State<CreateCaseScreen> createState() => _CreateCaseScreenState();
}

class _CreateCaseScreenState extends State<CreateCaseScreen> {
  DateTime? _surgeryDate;
  bool _loading = false;

  // Brand
  static const Color primary = Color(0xFF3B7691);
  static const Color glassBlue = Color(0xFF63A2BF);
  static const Color titleColor = Color(0xFF0F172A);
  static const Color bodyMuted = Color(0xFF64748B);

  void _toast(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        behavior: SnackBarBehavior.floating,
      ),
    );
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
              primary: primary,
              onPrimary: Colors.white,
              surface: Colors.white,
              onSurface: titleColor,
            ),
            textButtonTheme: TextButtonThemeData(
              style: TextButton.styleFrom(
                foregroundColor: primary,
                textStyle: GoogleFonts.inter(fontWeight: FontWeight.w700),
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

  // ✅ NEW: Get next case number = max(caseNumber) + 1
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
      // ✅ compute next number
      final nextNo = await _getNextCaseNumber(user.uid);

      // ✅ create case with caseNumber saved
      final docRef = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('cases')
          .add({
        'caseNumber': nextNo, // ✅ IMPORTANT
        'title': 'Case $nextNo', // ✅ optional but recommended
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
        MaterialPageRoute(
          builder: (_) => CaseCreatedStartScreen(caseId: docRef.id),
        ),
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
      backgroundColor: Colors.white,
      bottomNavigationBar: AppBottomNav(
        currentIndex: 2,
        onNewTap: () {}, // you're already here
      ),
      body: Stack(
        children: [
          const _SoftGlassBackground(),
          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(18, 10, 18, 118),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    height: 44,
                    child: Center(
                      child: Text(
                        "Create Case",
                        style: GoogleFonts.inter(
                          fontSize: 15.5,
                          fontWeight: FontWeight.w700,
                          color: titleColor.withOpacity(0.85),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),

                  _GlassCard(
                    radius: 24,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "Create New Case",
                            style: GoogleFonts.dmSans(
                              fontSize: 26,
                              fontWeight: FontWeight.w800,
                              color: titleColor,
                              height: 1.1,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            "Start monitoring a new wound with daily check-ins and progress tracking.",
                            style: GoogleFonts.inter(
                              fontSize: 13.5,
                              height: 1.5,
                              fontWeight: FontWeight.w500,
                              color: bodyMuted,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),

                  Padding(
                    padding: const EdgeInsets.only(left: 6, bottom: 8),
                    child: Text(
                      "Surgery date",
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: titleColor.withOpacity(0.85),
                      ),
                    ),
                  ),

                  Padding(
                    padding: const EdgeInsets.only(left: 6, bottom: 12),
                    child: Text(
                      "Select the date when the surgery was performed.",
                      style: GoogleFonts.inter(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w500,
                        color: bodyMuted,
                      ),
                    ),
                  ),

                  Row(
                    children: [
                      Expanded(
                        child: _GlassDateBox(
                          label: "Day",
                          value: dd,
                          onTap: _pickDate,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _GlassDateBox(
                          label: "Month",
                          value: mm,
                          onTap: _pickDate,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _GlassDateBox(
                          label: "Year",
                          value: yyyy,
                          onTap: _pickDate,
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 18),

                  // ✅ FAQ
                  const _FaqGlassCard(),

                  const SizedBox(height: 18),

                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: _loading
                        ? const _LoadingGlassButton()
                        : ElevatedButton(
                      onPressed: _createCase,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white.withOpacity(0.80),
                        elevation: 0,
                        shape: const StadiumBorder(),
                        side: BorderSide(
                          color: primary.withOpacity(0.55),
                          width: 1.4,
                        ),
                      ),
                      child: Text(
                        "Create Case",
                        style: GoogleFonts.inter(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          color: primary,
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
    );
  }
}

/* ---------------- helpers ---------------- */

String _two(int n) => n.toString().padLeft(2, '0');

/* ---------------- background ---------------- */

class _SoftGlassBackground extends StatelessWidget {
  const _SoftGlassBackground();

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
                Color(0xFFF7FBFF),
                Color(0xFFEEF7FF),
                Color(0xFFF8FAFC),
              ],
            ),
          ),
        ),
        Positioned(
          top: -140,
          left: -120,
          child: _Blob(
            size: 420,
            color: const Color(0xFF63A2BF).withOpacity(0.18),
          ),
        ),
        Positioned(
          top: 120,
          right: -150,
          child: _Blob(
            size: 520,
            color: Colors.white.withOpacity(0.40),
          ),
        ),
        Positioned(
          bottom: -200,
          left: -140,
          child: _Blob(
            size: 560,
            color: const Color(0xFF3B7691).withOpacity(0.10),
          ),
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

/* ---------------- glass components ---------------- */

class _GlassCard extends StatelessWidget {
  const _GlassCard({
    required this.child,
    this.radius = 20,
    this.tint,
    this.tintOpacity = 0.0,
  });

  final Widget child;
  final double radius;
  final Color? tint;
  final double tintOpacity;

  @override
  Widget build(BuildContext context) {
    final border = Colors.white.withOpacity(0.70);
    final bg = Colors.white.withOpacity(0.72);

    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(radius),
            border: Border.all(color: border, width: 1),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                bg,
                bg.withOpacity(0.58),
                bg.withOpacity(0.70),
              ],
            ),
            boxShadow: const [
              BoxShadow(
                color: Color(0x14000000),
                blurRadius: 18,
                offset: Offset(0, 10),
              ),
            ],
          ),
          child: Stack(
            children: [
              if (tint != null && tintOpacity > 0)
                Positioned.fill(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: tint!.withOpacity(tintOpacity),
                    ),
                  ),
                ),
              child,
            ],
          ),
        ),
      ),
    );
  }
}

class _GlassDateBox extends StatelessWidget {
  const _GlassDateBox({
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
          filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
          child: Container(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: Colors.white.withOpacity(0.70)),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Colors.white.withOpacity(0.75),
                  Colors.white.withOpacity(0.55),
                ],
              ),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x12000000),
                  blurRadius: 12,
                  offset: Offset(0, 8),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: GoogleFonts.inter(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF64748B),
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Text(
                      value,
                      style: GoogleFonts.inter(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: isPlaceholder
                            ? const Color(0xFF94A3B8)
                            : const Color(0xFF0F172A),
                      ),
                    ),
                    const Spacer(),
                    Icon(
                      Icons.calendar_month_rounded,
                      size: 18,
                      color: const Color(0xFF3B7691).withOpacity(0.75),
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

class _LoadingGlassButton extends StatelessWidget {
  const _LoadingGlassButton();

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(999),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.70),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
              color: const Color(0xFF3B7691).withOpacity(0.35),
              width: 1.2,
            ),
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

/* ---------------- FAQ "What happens next?" ---------------- */

class _FaqGlassCard extends StatefulWidget {
  const _FaqGlassCard();

  @override
  State<_FaqGlassCard> createState() => _FaqGlassCardState();
}

class _FaqGlassCardState extends State<_FaqGlassCard> {
  bool _expanded = false;

  static const Color primary = Color(0xFF3B7691);
  static const Color titleColor = Color(0xFF0F172A);

  @override
  Widget build(BuildContext context) {
    return _GlassCard(
      radius: 22,
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
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: titleColor,
                    ),
                  ),
                ),
                TextButton(
                  onPressed: () => setState(() => _expanded = !_expanded),
                  style: TextButton.styleFrom(
                    padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    minimumSize: Size.zero,
                    foregroundColor: primary,
                    textStyle: GoogleFonts.inter(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w800,
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
                      border: Border.all(color: primary.withOpacity(0.20)),
                    ),
                    child: Icon(
                      _expanded
                          ? Icons.keyboard_arrow_up_rounded
                          : Icons.keyboard_arrow_down_rounded,
                      color: primary,
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
                    _FaqLine(
                      icon: Icons.quiz_outlined,
                      text: "Complete the WHQ questionnaire",
                    ),
                    SizedBox(height: 8),
                    _FaqLine(
                      icon: Icons.photo_camera_outlined,
                      text: "Capture wound images",
                    ),
                    SizedBox(height: 8),
                    _FaqLine(
                      icon: Icons.thermostat_outlined,
                      text: "Record your temperature",
                    ),
                    SizedBox(height: 8),
                    _FaqLine(
                      icon: Icons.monitor_heart_outlined,
                      text: "Get infection risk score",
                    ),
                  ],
                ),
              ),
              crossFadeState:
              _expanded ? CrossFadeState.showSecond : CrossFadeState.showFirst,
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
  const _FaqLine({
    required this.icon,
    required this.text,
  });

  final IconData icon;
  final String text;

  static const Color primary = Color(0xFF3B7691);
  static const Color bodyMuted = Color(0xFF64748B);

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            color: primary.withOpacity(0.08),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: primary.withOpacity(0.12)),
          ),
          child: Icon(icon, color: primary.withOpacity(0.9), size: 18),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            text,
            style: GoogleFonts.inter(
              fontSize: 12.8,
              height: 1.4,
              fontWeight: FontWeight.w600,
              color: bodyMuted,
            ),
          ),
        ),
      ],
    );
  }
}
