import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../widgets/bottom_nav.dart';
import 'create_case_screen.dart';
import 'case_details_screen.dart';
import 'whq_screen.dart';

class CasesScreen extends StatefulWidget {
  const CasesScreen({super.key});

  @override
  State<CasesScreen> createState() => _CasesScreenState();
}

enum _CaseFilter { all, active, closed }

class _CasesScreenState extends State<CasesScreen> {
  static const Color primary = Color(0xFF3B7691);
  static const Color secondary = Color(0xFF63A2BF);

  // Status colors
  static const Color activeGreen = Color(0xFF16A34A);
  static const Color closedRed = Color(0xFFDC2626);

  _CaseFilter _filter = _CaseFilter.all;

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      return Scaffold(
        backgroundColor: Colors.white,
        body: SafeArea(
          child: Center(
            child: Text(
              "You must be logged in to view cases.",
              style: GoogleFonts.dmSans(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: const Color(0xFF0F172A),
              ),
            ),
          ),
        ),
      );
    }

    final casesQuery = FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .collection('cases')
        .orderBy('lastUpdated', descending: true);

    final userDocStream =
    FirebaseFirestore.instance.collection('users').doc(user.uid).snapshots();

    return Scaffold(
      backgroundColor: Colors.white,
      bottomNavigationBar: AppBottomNav(
        currentIndex: 1,
        onNewTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const CreateCaseScreen()),
          );
        },
      ),
      body: Stack(
        children: [
          const _SoftGlassBackground(),

          SafeArea(
            child: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
              stream: userDocStream,
              builder: (context, userSnap) {
                final userName = _getUserNameFromDoc(
                  userSnap.data?.data(),
                  fallback: user.displayName ?? "User",
                );

                return Column(
                  children: [
                    // ======= Top Bar =======
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 10),
                      child: Row(
                        children: [
                          _AvatarChip(
                            letter: (userName.isNotEmpty
                                ? userName.characters.first
                                : "U")
                                .toUpperCase(),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Hello',
                                  style: GoogleFonts.inter(
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.w700,
                                    color: const Color(0xFF64748B),
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  userName,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: GoogleFonts.dmSans(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w800,
                                    color: const Color(0xFF0F172A),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          _GlassPillButton(
                            label: "New Case",
                            icon: Icons.add,
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                    builder: (_) => const CreateCaseScreen()),
                              );
                            },
                          ),
                        ],
                      ),
                    ),

                    // ======= Title + subtitle (NO CARD behind) =======
                    Padding(
                      padding: const EdgeInsets.fromLTRB(18, 2, 18, 0),
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          "Wound cases",
                          style: GoogleFonts.dmSans(
                            fontSize: 30,
                            fontWeight: FontWeight.w900,
                            color: const Color(0xFF0F172A),
                            height: 1.0,
                          ),
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(18, 6, 18, 10),
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          "Track your wound healing progress",
                          style: GoogleFonts.inter(
                            fontSize: 13.2,
                            fontWeight: FontWeight.w600,
                            color: const Color(0xFF64748B),
                          ),
                        ),
                      ),
                    ),

                    // ======= Filter Chips (NO CARD behind) =======
                    Padding(
                      padding: const EdgeInsets.fromLTRB(18, 0, 18, 10),
                      child: _FilterRow(
                        value: _filter,
                        onChanged: (v) => setState(() => _filter = v),
                      ),
                    ),

                    // ======= Cases =======
                    Expanded(
                      child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                        stream: casesQuery.snapshots(),
                        builder: (context, snapshot) {
                          if (snapshot.hasError) {
                            return _ErrorState(
                              message: "Error loading cases: ${snapshot.error}",
                            );
                          }
                          if (snapshot.connectionState ==
                              ConnectionState.waiting) {
                            return const Center(
                                child: CircularProgressIndicator());
                          }

                          final docs = snapshot.data?.docs ?? [];
                          if (docs.isEmpty) {
                            return _EmptyState(
                              onCreate: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                      builder: (_) => const CreateCaseScreen()),
                                );
                              },
                            );
                          }

                          // ===== Case numbering (oldest = Case 1) =====
                          final sortedByCreated = [...docs];
                          sortedByCreated.sort((a, b) {
                            final aDt = _bestCaseDate(a.data());
                            final bDt = _bestCaseDate(b.data());
                            return aDt.compareTo(bDt);
                          });

                          final Map<String, int> caseNumberById = {};
                          for (int i = 0; i < sortedByCreated.length; i++) {
                            caseNumberById[sortedByCreated[i].id] = i + 1;
                          }

                          // Filter
                          List<QueryDocumentSnapshot<Map<String, dynamic>>> list;
                          if (_filter == _CaseFilter.all) {
                            list = docs;
                          } else {
                            final wantClosed = _filter == _CaseFilter.closed;
                            list = docs.where((d) {
                              final status =
                              ((d.data()['status'] as String?) ?? 'active')
                                  .toLowerCase();
                              final isClosed = status == 'closed';
                              return wantClosed ? isClosed : !isClosed;
                            }).toList();
                          }

                          return ListView.builder(
                            padding: const EdgeInsets.fromLTRB(16, 6, 16, 96),
                            itemCount: list.length,
                            itemBuilder: (context, i) {
                              final doc = list[i];
                              final data = doc.data();
                              final caseId = doc.id;

                              final status =
                              ((data['status'] as String?) ?? 'active')
                                  .toLowerCase();
                              final isClosed = status == 'closed';

                              final caseNo = caseNumberById[caseId] ?? 0;

                              final startDate = _formatDate(
                                data['startDate'] ??
                                    data['surgeryDate'] ??
                                    data['createdAt'],
                              );
                              final lastUpdated = _formatDate(
                                data['lastUpdated'] ?? data['createdAt'],
                              );

                              final scoreRaw = data['infectionScore'];
                              final int? score = scoreRaw is int
                                  ? scoreRaw
                                  : int.tryParse('$scoreRaw');

                              final dayLabel = _computeDayLabel(
                                data['startDate'] ??
                                    data['createdAt'] ??
                                    data['surgeryDate'],
                              );

                              return Padding(
                                padding: const EdgeInsets.only(bottom: 14),
                                child: _CaseGlassCard(
                                  caseNo: caseNo,
                                  dayLabel: dayLabel,
                                  startDate: startDate,
                                  lastUpdated: lastUpdated,
                                  score: score ?? 0,
                                  isClosed: isClosed,
                                  onPlay: isClosed
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
                                  onDetails: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) => CaseDetailsScreen(
                                          caseId: caseId,
                                          caseNumber: caseNo,
                                        ),
                                      ),
                                    );
                                  },
                                  onDashboard: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) => CaseDetailsScreen(
                                          caseId: caseId,
                                          caseNumber: caseNo,
                                        ),
                                      ),
                                    );
                                  },
                                ),
                              );
                            },
                          );
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

  static String _getUserNameFromDoc(
      Map<String, dynamic>? data, {
        required String fallback,
      }) {
    if (data == null) return fallback;
    // Adjust these keys if your Firestore uses different field name
    final v = data['name'] ?? data['username'] ?? data['displayName'];
    final s = (v is String) ? v.trim() : '';
    return s.isNotEmpty ? s : fallback;
  }
}

/* ===================== UI: Background ===================== */

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
          top: -160,
          left: -140,
          child: _Blob(
            size: 520,
            color: const Color(0xFF63A2BF).withOpacity(0.18),
          ),
        ),
        Positioned(
          top: 140,
          right: -180,
          child: _Blob(
            size: 560,
            color: Colors.white.withOpacity(0.45),
          ),
        ),
        Positioned(
          bottom: -220,
          left: -160,
          child: _Blob(
            size: 600,
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

/* ===================== UI: Top widgets ===================== */

class _AvatarChip extends StatelessWidget {
  const _AvatarChip({required this.letter});
  final String letter;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
        child: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.55),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: Colors.white.withOpacity(0.70)),
            boxShadow: const [
              BoxShadow(
                color: Color(0x14000000),
                blurRadius: 18,
                offset: Offset(0, 10),
              )
            ],
          ),
          alignment: Alignment.center,
          child: Text(
            letter,
            style: GoogleFonts.dmSans(
              fontSize: 18,
              fontWeight: FontWeight.w900,
              color: const Color(0xFF3B7691),
            ),
          ),
        ),
      ),
    );
  }
}

class _GlassPillButton extends StatelessWidget {
  const _GlassPillButton({
    required this.label,
    required this.icon,
    required this.onTap,
  });

  final String label;
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
          filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.55),
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: Colors.white.withOpacity(0.70)),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x14000000),
                  blurRadius: 18,
                  offset: Offset(0, 10),
                )
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 18, color: const Color(0xFF3B7691)),
                const SizedBox(width: 8),
                Text(
                  label,
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: const Color(0xFF3B7691),
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

/* ===================== UI: Filter row ===================== */

class _FilterRow extends StatelessWidget {
  const _FilterRow({required this.value, required this.onChanged});
  final _CaseFilter value;
  final ValueChanged<_CaseFilter> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _FilterChip(
            label: "All",
            selected: value == _CaseFilter.all,
            onTap: () => onChanged(_CaseFilter.all),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _FilterChip(
            label: "Active",
            selected: value == _CaseFilter.active,
            onTap: () => onChanged(_CaseFilter.active),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _FilterChip(
            label: "Closed",
            selected: value == _CaseFilter.closed,
            onTap: () => onChanged(_CaseFilter.closed),
          ),
        ),
      ],
    );
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  static const Color primary = Color(0xFF3B7691);
  static const Color secondary = Color(0xFF63A2BF);

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(999),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
          child: Container(
            height: 44,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(999),
              color: selected
                  ? primary.withOpacity(0.12)
                  : Colors.white.withOpacity(0.45),
              border: Border.all(
                color: selected
                    ? secondary.withOpacity(0.35)
                    : Colors.white.withOpacity(0.65),
              ),
            ),
            child: Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 13,
                fontWeight: FontWeight.w800,
                color: selected ? primary : const Color(0xFF64748B),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/* ===================== UI: Case glass card ===================== */

class _CaseGlassCard extends StatelessWidget {
  const _CaseGlassCard({
    required this.caseNo,
    required this.dayLabel,
    required this.startDate,
    required this.lastUpdated,
    required this.score,
    required this.isClosed,
    required this.onDetails,
    required this.onDashboard,
    this.onPlay,
  });

  final int caseNo;
  final String dayLabel;
  final String startDate;
  final String lastUpdated;
  final int score;
  final bool isClosed;

  final VoidCallback onDetails;
  final VoidCallback onDashboard;
  final VoidCallback? onPlay;

  static const Color primary = Color(0xFF3B7691);
  static const Color secondary = Color(0xFF63A2BF);

  static const Color activeGreen = Color(0xFF16A34A);
  static const Color closedRed = Color(0xFFDC2626);

  @override
  Widget build(BuildContext context) {
    final statusColor = isClosed ? closedRed : activeGreen;
    final statusText = isClosed ? "Closed" : "Active";

    final iconBg = isClosed
        ? closedRed.withOpacity(0.10)
        : secondary.withOpacity(0.14);

    final iconColor = isClosed ? closedRed : primary;

    final playBg = isClosed
        ? Colors.black.withOpacity(0.06)
        : primary.withOpacity(0.85);

    return ClipRRect(
      borderRadius: BorderRadius.circular(26),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(26),
            border: Border.all(color: Colors.white.withOpacity(0.70)),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Colors.white.withOpacity(0.68),
                Colors.white.withOpacity(0.52),
                const Color(0xFFEEF7FF).withOpacity(0.35),
              ],
            ),
            boxShadow: const [
              BoxShadow(
                color: Color(0x14000000),
                blurRadius: 22,
                offset: Offset(0, 12),
              ),
            ],
          ),
          child: Column(
            children: [
              // Header row
              Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: iconBg,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: (isClosed ? closedRed : secondary)
                            .withOpacity(0.20),
                      ),
                    ),
                    child: Icon(Icons.folder_outlined, color: iconColor),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "Case $caseNo",
                          style: GoogleFonts.dmSans(
                            fontSize: 18,
                            fontWeight: FontWeight.w900,
                            color: const Color(0xFF0F172A),
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          dayLabel,
                          style: GoogleFonts.inter(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w700,
                            color: const Color(0xFF64748B),
                          ),
                        ),
                      ],
                    ),
                  ),
                  _StatusPill(
                    text: statusText,
                    color: statusColor,
                  ),
                ],
              ),

              const SizedBox(height: 12),
              Container(
                height: 1,
                color: Colors.black.withOpacity(0.06),
              ),
              const SizedBox(height: 12),

              // Dates
              Row(
                children: [
                  Expanded(
                    child: _InfoMini(
                      icon: Icons.calendar_today_outlined,
                      label: startDate,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: _InfoMini(
                      icon: Icons.access_time,
                      label: lastUpdated,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 12),

              // Score + Play
              Row(
                children: [
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(18),
                        color: (isClosed ? closedRed : secondary)
                            .withOpacity(0.10),
                        border: Border.all(
                          color: (isClosed ? closedRed : secondary)
                              .withOpacity(0.20),
                        ),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 34,
                            height: 34,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(12),
                              color: Colors.white.withOpacity(0.65),
                              border: Border.all(
                                  color: Colors.white.withOpacity(0.70)),
                            ),
                            child: Icon(
                              Icons.monitor_heart_outlined,
                              color: isClosed ? closedRed : primary,
                              size: 18,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  "Infection Score",
                                  style: GoogleFonts.inter(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w800,
                                    color: const Color(0xFF64748B),
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  "$score",
                                  style: GoogleFonts.dmSans(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w900,
                                    color: const Color(0xFF0F172A),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  InkWell(
                    onTap: onPlay, // null => disabled automatically by InkWell? we handle below
                    borderRadius: BorderRadius.circular(18),
                    child: Opacity(
                      opacity: onPlay == null ? 0.35 : 1,
                      child: Container(
                        width: 56,
                        height: 56,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(18),
                          color: playBg,
                          boxShadow: [
                            BoxShadow(
                              color: primary.withOpacity(0.25),
                              blurRadius: 18,
                              offset: const Offset(0, 10),
                              spreadRadius: -8,
                            ),
                          ],
                        ),
                        child: const Icon(Icons.play_arrow_rounded,
                            color: Colors.white, size: 30),
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 12),

              // Actions
              Row(
                children: [
                  Expanded(
                    child: _ActionPill(
                      label: "View Details",
                      icon: Icons.remove_red_eye_outlined,
                      color: isClosed ? closedRed : primary,
                      onTap: onDetails,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _ActionPill(
                      label: "View Dashboard",
                      icon: Icons.bar_chart_rounded,
                      color: isClosed ? closedRed : primary,
                      onTap: onDashboard,
                    ),
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

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.text, required this.color});
  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        color: color.withOpacity(0.12),
        border: Border.all(color: color.withOpacity(0.25)),
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

class _InfoMini extends StatelessWidget {
  const _InfoMini({required this.icon, required this.label});
  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 16, color: const Color(0xFF0F172A)),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 12.5,
              fontWeight: FontWeight.w800,
              color: const Color(0xFF0F172A),
            ),
          ),
        ),
      ],
    );
  }
}

class _ActionPill extends StatelessWidget {
  const _ActionPill({
    required this.label,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: Container(
        height: 40,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(999),
          color: color.withOpacity(0.08),
          border: Border.all(color: color.withOpacity(0.25)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 16, color: color),
            const SizedBox(width: 8),
            Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 12.6,
                fontWeight: FontWeight.w900,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/* ===================== Empty / Error ===================== */

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.onCreate});
  final VoidCallback onCreate;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(18, 10, 18, 96),
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(26),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
            child: Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(26),
                color: Colors.white.withOpacity(0.60),
                border: Border.all(color: Colors.white.withOpacity(0.70)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "No cases yet",
                    style: GoogleFonts.dmSans(
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                      color: const Color(0xFF0F172A),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    "Create your first case to start monitoring healing progress.",
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFF64748B),
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 14),
                  SizedBox(
                    width: double.infinity,
                    height: 44,
                    child: ElevatedButton.icon(
                      onPressed: onCreate,
                      icon: const Icon(Icons.add),
                      label: const Text("Create New Case"),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF3B7691),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        )
      ],
    );
  }
}

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
            color: const Color(0xFFDC2626),
            fontWeight: FontWeight.w800,
          ),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}

/* ===================== Helpers ===================== */

DateTime _bestCaseDate(Map<String, dynamic> data) {
  final dt = _toDate(data['createdAt']) ??
      _toDate(data['startDate']) ??
      _toDate(data['surgeryDate']);
  return dt ?? DateTime.fromMillisecondsSinceEpoch(0);
}

DateTime? _toDate(dynamic value) {
  if (value == null) return null;
  try {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    if (value is String) return DateTime.tryParse(value);
  } catch (_) {}
  return null;
}

String _formatDate(dynamic value) {
  if (value == null) return "--";
  final dt = _toDate(value);
  if (dt == null) return "--";
  final y = dt.year.toString().padLeft(4, '0');
  final m = dt.month.toString().padLeft(2, '0');
  final d = dt.day.toString().padLeft(2, '0');
  return "$y-$m-$d";
}

String _computeDayLabel(dynamic startDate) {
  final dt = _toDate(startDate);
  if (dt == null) return "Day --";
  final diff = DateTime.now().difference(dt).inDays + 1;
  return "Day $diff";
}
