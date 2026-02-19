// case_details_screen.dart
import 'dart:ui';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../utils/app_colors.dart';
import '../widgets/bottom_nav.dart';
import 'whq_screen.dart';

class CaseDetailsScreen extends StatelessWidget {
  const CaseDetailsScreen({
    super.key,
    required this.caseId,
    this.caseNumber,
  });

  final String caseId;
  final int? caseNumber;

  Future<void> _editCaseName(
      BuildContext context,
      DocumentReference<Map<String, dynamic>> caseRef,
      String currentName,
      int fallbackNo,
      ) async {
    final ctrl = TextEditingController(text: currentName);

    final newName = await showDialog<String?>(
      context: context,
      barrierDismissible: true,
      builder: (ctx) {
        return Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Text(
                      "Edit case name",
                      style: GoogleFonts.dmSans(
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const Spacer(),
                    IconButton(
                      onPressed: () => Navigator.pop(ctx),
                      icon: const Icon(Icons.close_rounded),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: ctrl,
                  autofocus: true,
                  textInputAction: TextInputAction.done,
                  decoration: InputDecoration(
                    hintText: "Example: Left knee",
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  height: 46,
                  child: ElevatedButton(
                    onPressed: () {
                      final v = ctrl.text.trim();
                      Navigator.pop(ctx, v.isEmpty ? null : v);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primaryColor,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      elevation: 0,
                    ),
                    child: Text(
                      "Save",
                      style: GoogleFonts.inter(
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  "If left empty, it will fallback to Wound $fallbackNo.",
                  style: GoogleFonts.inter(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textMuted,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );

    ctrl.dispose();

    // user cancelled
    if (newName == null) return;

    await caseRef.update({
      'caseName': newName,
      'title': newName,
      'lastUpdated': FieldValue.serverTimestamp(),
    });
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
              "User not logged in",
              style: GoogleFonts.inter(
                fontSize: 13,
                fontWeight: FontWeight.w800,
                color: AppColors.textPrimary,
              ),
            ),
          ),
        ),
      );
    }

    final caseRef = FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .collection('cases')
        .doc(caseId);

    return Scaffold(
      backgroundColor: AppColors.backgroundColor,
      bottomNavigationBar: const AppBottomNav(currentIndex: 1),
      body: Stack(
        children: [
          const _BlueGlassyBackground(),
          SafeArea(
            child: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
              stream: caseRef.snapshots(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return const _ErrorState(message: "Something went wrong");
                }
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (!snapshot.hasData || !snapshot.data!.exists) {
                  return const _ErrorState(message: "Case not found");
                }

                final data = snapshot.data!.data() ?? {};
                final status =
                ((data['status'] as String?) ?? 'active').toLowerCase();
                final isClosed = status == 'closed';

                final int fallbackNo = caseNumber ??
                    _asInt(data['caseNumber']) ??
                    _asInt(data['caseNo']) ??
                    0;

                // ✅ display name priority: caseName -> title -> fallback Wound #
                final rawName =
                (data['caseName'] ?? data['title'] ?? '').toString().trim();
                final displayTitle = rawName.isNotEmpty
                    ? rawName
                    : (fallbackNo > 0 ? "Wound $fallbackNo" : "Wound case");

                final startValue =
                    data['createdAt'] ?? data['startDate'] ?? data['surgeryDate'];
                final startDateText = _formatDateTime(startValue);

                final lastValue = data['lastUpdated'] ?? data['createdAt'];
                final lastUpdatedText = _formatDateTime(lastValue);

                final scoreRaw = data['infectionScore'];
                final int? score =
                scoreRaw is int ? scoreRaw : int.tryParse('$scoreRaw');
                final scoreText = score?.toString() ?? '--';
                final assessment = _assessmentFromScore(score);

                final isHighRisk = (score ?? 0) >= 6;

                return Stack(
                  children: [
                    SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(16, 10, 16, 120),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              _WhitePillButton(
                                onTap: () => Navigator.pop(context),
                                child: const Icon(
                                  Icons.arrow_back_ios_new_rounded,
                                  size: 18,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  "Wound Case details",
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: GoogleFonts.dmSans(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w900,
                                    color: AppColors.textPrimary,
                                  ),
                                ),
                              ),
                              _StatusPill(
                                isClosed: isClosed,
                                isHighRisk: isHighRisk,
                              ),
                            ],
                          ),

                          const SizedBox(height: 14),

                          // ✅ Title + Edit button
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              _FolderBubble(
                                tint: isHighRisk
                                    ? AppColors.errorColor
                                    : AppColors.primaryColor,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  displayTitle,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: GoogleFonts.dmSans(
                                    fontSize: 28,
                                    fontWeight: FontWeight.w900,
                                    color: AppColors.textPrimary,
                                    height: 1.0,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 10),
                              _WhitePillButton(
                                onTap: () => _editCaseName(
                                  context,
                                  caseRef,
                                  displayTitle,
                                  (fallbackNo == 0 ? 1 : fallbackNo),
                                ),
                                child: const Icon(
                                  Icons.edit_outlined,
                                  size: 18,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                            ],
                          ),

                          const SizedBox(height: 8),

                          Text(
                            "Monitor signs of infections for this wound case.",
                            style: GoogleFonts.inter(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textSecondary,
                              height: 1.4,
                            ),
                          ),

                          const SizedBox(height: 16),

                          _GlassyCard(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Text(
                                      "Wound Case overview",
                                      style: GoogleFonts.dmSans(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w900,
                                        color: AppColors.textPrimary,
                                      ),
                                    ),
                                    const Spacer(),
                                    _MiniChip(
                                      text: isClosed ? "Closed" : "Active",
                                      color: isClosed
                                          ? AppColors.textMuted
                                          : AppColors.primaryColor,
                                      filled: true,
                                    ),
                                  ],
                                ),

                                const SizedBox(height: 12),
                                Divider(
                                  height: 1,
                                  color: AppColors.dividerColor.withOpacity(0.9),
                                ),
                                const SizedBox(height: 12),

                                Row(
                                  children: [
                                    Expanded(
                                      child: _InfoMini(
                                        icon: Icons.calendar_today_outlined,
                                        label: startDateText,
                                      ),
                                    ),
                                    const SizedBox(width: 14),
                                    Expanded(
                                      child: _InfoMini(
                                        icon: Icons.access_time,
                                        label: lastUpdatedText,
                                      ),
                                    ),
                                  ],
                                ),

                                const SizedBox(height: 14),

                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 14, vertical: 14),
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(22),
                                    color: AppColors.surfaceColor.withOpacity(0.92),
                                    border: Border.all(
                                      color: isHighRisk
                                          ? AppColors.errorColor.withOpacity(0.16)
                                          : AppColors.primaryColor.withOpacity(0.10),
                                    ),
                                  ),
                                  child: Row(
                                    children: [
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              "Infection score",
                                              style: GoogleFonts.inter(
                                                fontSize: 12.8,
                                                fontWeight: FontWeight.w800,
                                                color: AppColors.textSecondary,
                                              ),
                                            ),
                                            const SizedBox(height: 6),
                                            _MiniPillText(
                                              text: assessment,
                                              tint: isHighRisk
                                                  ? AppColors.errorColor
                                                  : AppColors.primaryColor,
                                            ),
                                          ],
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Container(
                                        width: 62,
                                        height: 62,
                                        decoration: BoxDecoration(
                                          borderRadius:
                                          BorderRadius.circular(22),
                                          gradient: isHighRisk
                                              ? AppColors.dangerGradient
                                              : AppColors.primaryGradient,
                                          boxShadow: [
                                            BoxShadow(
                                              color: (isHighRisk
                                                  ? AppColors.errorColor
                                                  : AppColors.primaryColor)
                                                  .withOpacity(0.22),
                                              blurRadius: 22,
                                              offset: const Offset(0, 14),
                                              spreadRadius: -10,
                                            ),
                                          ],
                                        ),
                                        child: Center(
                                          child: Text(
                                            scoreText,
                                            style: GoogleFonts.dmSans(
                                              fontSize: 22,
                                              fontWeight: FontWeight.w900,
                                              color: Colors.white,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),

                                const SizedBox(height: 14),

                                Row(
                                  children: [
                                    Expanded(
                                      child: _PrimaryActionButton(
                                        label: isClosed
                                            ? "Case is closed"
                                            : "Start daily check",
                                        icon: Icons.play_arrow_rounded,
                                        disabled: isClosed,
                                        onTap: isClosed
                                            ? null
                                            : () {
                                          Navigator.push(
                                            context,
                                            MaterialPageRoute(
                                              builder: (_) =>
                                                  WhqScreen(caseId: caseId),
                                            ),
                                          );
                                        },
                                      ),
                                    ),
                                  ],
                                ),

                                const SizedBox(height: 10),
                              ],
                            ),
                          ),

                          const SizedBox(height: 14),

                          _FrostedSection(
                            title: "Tips",
                            child: Text(
                              "If symptoms worsen (pain, redness, swelling, fever), seek medical advice.",
                              style: GoogleFonts.inter(
                                fontSize: 12.8,
                                fontWeight: FontWeight.w600,
                                color: AppColors.textSecondary,
                                height: 1.45,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    Align(
                      alignment: Alignment.bottomCenter,
                      child: _BottomDangerBar(
                        disabled: isClosed,
                        onClose: () async {
                          await caseRef.update({
                            'status': 'closed',
                            'lastUpdated': FieldValue.serverTimestamp(),
                          });
                        },
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

int? _asInt(dynamic v) {
  if (v == null) return null;
  if (v is int) return v;
  return int.tryParse('$v');
}

/* ===================== Background: blue glassy ===================== */

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

/* ===================== Reusable UI ===================== */

class _WhitePillButton extends StatelessWidget {
  const _WhitePillButton({required this.child, required this.onTap});
  final Widget child;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: _WhitePill(
        radius: 999,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        child: child,
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

class _GlassyCard extends StatelessWidget {
  const _GlassyCard({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(26),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
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
          child: child,
        ),
      ),
    );
  }
}

class _FrostedSection extends StatelessWidget {
  const _FrostedSection({required this.title, required this.child});
  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return _GlassyCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: GoogleFonts.dmSans(
              fontSize: 16,
              fontWeight: FontWeight.w900,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 10),
          child,
        ],
      ),
    );
  }
}

class _FolderBubble extends StatelessWidget {
  const _FolderBubble({required this.tint});
  final Color tint;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 46,
      height: 46,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            tint.withOpacity(0.20),
            tint.withOpacity(0.10),
            Colors.white.withOpacity(0.70),
          ],
        ),
        border: Border.all(color: AppColors.dividerColor.withOpacity(0.85)),
      ),
      child: Icon(Icons.folder_outlined, color: tint),
    );
  }
}

class _InfoMini extends StatelessWidget {
  const _InfoMini({required this.icon, required this.label});
  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 16, color: AppColors.textPrimary),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 12.5,
              fontWeight: FontWeight.w900,
              color: AppColors.textPrimary,
            ),
          ),
        ),
      ],
    );
  }
}

class _MiniPillText extends StatelessWidget {
  const _MiniPillText({required this.text, required this.tint});
  final String text;
  final Color tint;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        color: tint.withOpacity(0.10),
        border: Border.all(color: tint.withOpacity(0.22)),
      ),
      child: Text(
        text,
        style: GoogleFonts.inter(
          fontSize: 11.8,
          fontWeight: FontWeight.w800,
          color: tint,
        ),
      ),
    );
  }
}

class _MiniChip extends StatelessWidget {
  const _MiniChip({
    required this.text,
    required this.color,
    this.filled = false,
  });

  final String text;
  final Color color;
  final bool filled;

  @override
  Widget build(BuildContext context) {
    final bg = filled ? color.withOpacity(0.12) : Colors.transparent;
    final br = color.withOpacity(0.26);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        color: bg,
        border: Border.all(color: br),
      ),
      child: Text(
        text,
        style: GoogleFonts.inter(
          fontSize: 11.5,
          fontWeight: FontWeight.w900,
          color: color,
        ),
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.isClosed, required this.isHighRisk});
  final bool isClosed;
  final bool isHighRisk;

  @override
  Widget build(BuildContext context) {
    if (isClosed) {
      return _WhitePill(
        radius: 999,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 7,
              height: 7,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.textMuted,
              ),
            ),
            const SizedBox(width: 7),
            Text(
              "Closed",
              style: GoogleFonts.inter(
                fontSize: 11.8,
                fontWeight: FontWeight.w900,
                color: AppColors.textMuted,
              ),
            ),
          ],
        ),
      );
    }

    final tint = isHighRisk ? AppColors.errorColor : AppColors.primaryColor;

    return _WhitePill(
      radius: 999,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 7,
            height: 7,
            decoration: BoxDecoration(shape: BoxShape.circle, color: tint),
          ),
          const SizedBox(width: 7),
          Text(
            isHighRisk ? "High risk" : "Active",
            style: GoogleFonts.inter(
              fontSize: 11.8,
              fontWeight: FontWeight.w900,
              color: tint,
            ),
          ),
        ],
      ),
    );
  }
}

class _PrimaryActionButton extends StatelessWidget {
  const _PrimaryActionButton({
    required this.label,
    required this.icon,
    required this.disabled,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool disabled;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: disabled ? 0.45 : 1,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: Container(
          height: 48,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(999),
            gradient: AppColors.primaryGradient,
            boxShadow: [
              BoxShadow(
                color: AppColors.primaryColor.withOpacity(0.22),
                blurRadius: 18,
                offset: const Offset(0, 12),
                spreadRadius: -10,
              ),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 20, color: Colors.white),
              const SizedBox(width: 10),
              Text(
                label,
                style: GoogleFonts.inter(
                  fontSize: 13.2,
                  fontWeight: FontWeight.w900,
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

/* ===================== Bottom red bar ===================== */

class _BottomDangerBar extends StatelessWidget {
  const _BottomDangerBar({
    required this.disabled,
    required this.onClose,
  });

  final bool disabled;
  final Future<void> Function() onClose;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 14),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(26),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.78),
                borderRadius: BorderRadius.circular(26),
                border: Border.all(color: AppColors.dividerColor.withOpacity(0.9)),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x22000000),
                    blurRadius: 22,
                    offset: Offset(0, 12),
                  ),
                ],
              ),
              child: Opacity(
                opacity: disabled ? 0.45 : 1,
                child: InkWell(
                  onTap: disabled ? null : () async => onClose(),
                  borderRadius: BorderRadius.circular(20),
                  child: Container(
                    height: 48,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(20),
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          AppColors.errorColor.withOpacity(0.95),
                          const Color(0xFF7A0000).withOpacity(0.95),
                        ],
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.errorColor.withOpacity(0.22),
                          blurRadius: 22,
                          offset: const Offset(0, 14),
                          spreadRadius: -12,
                        ),
                      ],
                    ),
                    child: Center(
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.delete_outline,
                              color: Colors.white, size: 20),
                          const SizedBox(width: 10),
                          Text(
                            disabled ? "Case already closed" : "Close wound case",
                            style: GoogleFonts.inter(
                              fontSize: 13.2,
                              fontWeight: FontWeight.w900,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/* ===================== Error ===================== */

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.message});
  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Text(
          message,
          style: GoogleFonts.inter(
            fontSize: 13,
            color: AppColors.errorColor,
            fontWeight: FontWeight.w900,
          ),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}

/* ===================== Helpers ===================== */

String _formatDateTime(dynamic value) {
  if (value == null) return "--";
  try {
    DateTime dt;

    if (value is Timestamp) {
      dt = value.toDate();
    } else if (value is DateTime) {
      dt = value;
    } else if (value is String) {
      dt = DateTime.tryParse(value) ?? DateTime.now();
    } else {
      return "--";
    }

    final yyyy = dt.year.toString();
    final mm = dt.month.toString().padLeft(2, '0');
    final dd = dt.day.toString().padLeft(2, '0');
    final hh = dt.hour.toString().padLeft(2, '0');
    final min = dt.minute.toString().padLeft(2, '0');

    return "$yyyy-$mm-$dd  $hh:$min";
  } catch (_) {
    return "--";
  }
}

String _assessmentFromScore(int? score) {
  if (score == null) return "No data yet";
  if (score <= 2) return "Stable • keep monitoring";
  if (score <= 5) return "Warning • watch symptoms";
  return "High risk • seek care";
}
