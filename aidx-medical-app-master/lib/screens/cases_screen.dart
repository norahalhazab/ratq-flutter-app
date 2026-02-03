// cases_screen.dart
import 'dart:ui';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../widgets/bottom_nav.dart';
import 'case_details_screen.dart';
import 'create_case_screen.dart';
import 'whq_screen.dart';

enum CaseChipFilter { all, active, closed, highRisk, lowRisk }
enum CaseSort { startMostRecent, startOldest }

class CasesScreen extends StatefulWidget {
  const CasesScreen({super.key});

  @override
  State<CasesScreen> createState() => _CasesScreenState();
}

class _CasesScreenState extends State<CasesScreen> {
  // Brand
  static const Color primary = Color(0xFF3B7691);
  static const Color secondary = Color(0xFF63A2BF);

  // Status
  static const Color activeGreen = Color(0xFF16A34A);
  static const Color closedRed = Color(0xFFDC2626);

  // Risk colors
  static const Color riskBlue = Color(0xFF3B7691);
  static const Color riskRed = Color(0xFFDC2626);

  CaseChipFilter _chip = CaseChipFilter.all;

  // Advanced filter state (bottom sheet)
  CaseSort _sort = CaseSort.startMostRecent;
  String _statusFilter = 'all'; // all / active / closed
  String _riskFilter = 'all'; // all / low / high

  void _openFilters() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withOpacity(0.12),
      builder: (_) {
        // local temp values so user can cancel/close
        var tmpSort = _sort;
        var tmpStatus = _statusFilter;
        var tmpRisk = _riskFilter;

        return StatefulBuilder(
          builder: (context, setSheet) {
            return Padding(
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
              child: _GlassSheet(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Handle
                    Container(
                      width: 46,
                      height: 5,
                      margin: const EdgeInsets.only(top: 10, bottom: 14),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.10),
                        borderRadius: BorderRadius.circular(999),
                      ),
                    ),

                    Row(
                      children: [
                        Text(
                          "Filters",
                          style: GoogleFonts.dmSans(
                            fontSize: 18,
                            fontWeight: FontWeight.w900,
                            color: const Color(0xFF0F172A),
                          ),
                        ),
                        const Spacer(),
                        TextButton(
                          onPressed: () {
                            setSheet(() {
                              tmpSort = CaseSort.startMostRecent;
                              tmpStatus = 'all';
                              tmpRisk = 'all';
                            });
                          },
                          child: Text(
                            "Reset",
                            style: GoogleFonts.inter(
                              fontWeight: FontWeight.w900,
                              color: primary,
                            ),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 10),

                    _SheetSection(
                      title: "Sort by start date",
                      child: Column(
                        children: [
                          _RadioRow(
                            label: "Most recent first",
                            selected: tmpSort == CaseSort.startMostRecent,
                            onTap: () => setSheet(
                                  () => tmpSort = CaseSort.startMostRecent,
                            ),
                          ),
                          const SizedBox(height: 8),
                          _RadioRow(
                            label: "Oldest first",
                            selected: tmpSort == CaseSort.startOldest,
                            onTap: () => setSheet(
                                  () => tmpSort = CaseSort.startOldest,
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 14),

                    _SheetSection(
                      title: "Status",
                      child: Wrap(
                        spacing: 10,
                        runSpacing: 10,
                        children: [
                          _MiniPill(
                            text: "All",
                            selected: tmpStatus == 'all',
                            onTap: () => setSheet(() => tmpStatus = 'all'),
                          ),
                          _MiniPill(
                            text: "Active",
                            selected: tmpStatus == 'active',
                            onTap: () => setSheet(() => tmpStatus = 'active'),
                          ),
                          _MiniPill(
                            text: "Closed",
                            selected: tmpStatus == 'closed',
                            onTap: () => setSheet(() => tmpStatus = 'closed'),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 14),

                    _SheetSection(
                      title: "Infection risk",
                      child: Wrap(
                        spacing: 10,
                        runSpacing: 10,
                        children: [
                          _MiniPill(
                            text: "All",
                            selected: tmpRisk == 'all',
                            onTap: () => setSheet(() => tmpRisk = 'all'),
                          ),
                          _MiniPill(
                            text: "Low",
                            selected: tmpRisk == 'low',
                            onTap: () => setSheet(() => tmpRisk = 'low'),
                          ),
                          _MiniPill(
                            text: "High",
                            selected: tmpRisk == 'high',
                            onTap: () => setSheet(() => tmpRisk = 'high'),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 18),

                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: ElevatedButton(
                        onPressed: () {
                          setState(() {
                            _sort = tmpSort;
                            _statusFilter = tmpStatus;
                            _riskFilter = tmpRisk;

                            // keep chip in sync (nice UX)
                            if (_statusFilter == 'active' && _riskFilter == 'all') {
                              _chip = CaseChipFilter.active;
                            } else if (_statusFilter == 'closed' && _riskFilter == 'all') {
                              _chip = CaseChipFilter.closed;
                            } else if (_riskFilter == 'high' && _statusFilter == 'all') {
                              _chip = CaseChipFilter.highRisk;
                            } else if (_riskFilter == 'low' && _statusFilter == 'all') {
                              _chip = CaseChipFilter.lowRisk;
                            } else if (_statusFilter == 'all' && _riskFilter == 'all') {
                              _chip = CaseChipFilter.all;
                            } else {
                              // mixed filters -> keep current chip (or set to all)
                              _chip = CaseChipFilter.all;
                            }
                          });

                          Navigator.pop(context);
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: primary,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        child: Text(
                          "Done",
                          style: GoogleFonts.inter(
                            fontWeight: FontWeight.w900,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 14),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

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
                fontWeight: FontWeight.w700,
                color: const Color(0xFF0F172A),
              ),
            ),
          ),
        ),
      );
    }

    final userDocStream =
    FirebaseFirestore.instance.collection('users').doc(user.uid).snapshots();

    final casesQuery = FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .collection('cases')
        .orderBy('lastUpdated', descending: true);

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
                final userName = _getUserName(
                  userSnap.data?.data(),
                  fallback: user.displayName ?? "User",
                );

                return Column(
                  children: [
                    // ======= Top Row =======
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
                                  "Hello",
                                  style: GoogleFonts.inter(
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.w800,
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
                                    fontWeight: FontWeight.w900,
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
                                  builder: (_) => const CreateCaseScreen(),
                                ),
                              );
                            },
                          ),
                        ],
                      ),
                    ),

                    // ======= Title (NO background card) =======
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

                    // ======= Horizontal filter row + filter button =======
                    Padding(
                      padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
                      child: Row(
                        children: [
                          Expanded(
                            child: SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              padding: const EdgeInsets.only(left: 6),
                              child: Row(
                                children: [
                                  _ChipPill(
                                    label: "All",
                                    selected: _chip == CaseChipFilter.all,
                                    onTap: () {
                                      setState(() {
                                        _chip = CaseChipFilter.all;
                                        _statusFilter = 'all';
                                        _riskFilter = 'all';
                                      });
                                    },
                                  ),
                                  const SizedBox(width: 10),
                                  _ChipPill(
                                    label: "Active",
                                    selected: _chip == CaseChipFilter.active,
                                    onTap: () {
                                      setState(() {
                                        _chip = CaseChipFilter.active;
                                        _statusFilter = 'active';
                                        _riskFilter = 'all';
                                      });
                                    },
                                  ),
                                  const SizedBox(width: 10),
                                  _ChipPill(
                                    label: "Closed",
                                    selected: _chip == CaseChipFilter.closed,
                                    onTap: () {
                                      setState(() {
                                        _chip = CaseChipFilter.closed;
                                        _statusFilter = 'closed';
                                        _riskFilter = 'all';
                                      });
                                    },
                                  ),
                                  const SizedBox(width: 10),
                                  _ChipPill(
                                    label: "High risk",
                                    selected: _chip == CaseChipFilter.highRisk,
                                    selectedColor: riskRed,
                                    onTap: () {
                                      setState(() {
                                        _chip = CaseChipFilter.highRisk;
                                        _statusFilter = 'all';
                                        _riskFilter = 'high';
                                      });
                                    },
                                  ),
                                  const SizedBox(width: 10),
                                  _ChipPill(
                                    label: "Low risk",
                                    selected: _chip == CaseChipFilter.lowRisk,
                                    selectedColor: riskBlue,
                                    onTap: () {
                                      setState(() {
                                        _chip = CaseChipFilter.lowRisk;
                                        _statusFilter = 'all';
                                        _riskFilter = 'low';
                                      });
                                    },
                                  ),
                                  const SizedBox(width: 10),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          _GlassIconButton(
                            icon: Icons.tune_rounded, // filter slider icon
                            onTap: _openFilters,
                          ),
                        ],
                      ),
                    ),

                    // ======= Cases list =======
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
                              child: CircularProgressIndicator(),
                            );
                          }

                          final docs = snapshot.data?.docs ?? [];
                          if (docs.isEmpty) {
                            return _EmptyState(
                              onCreate: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => const CreateCaseScreen(),
                                  ),
                                );
                              },
                            );
                          }

                          // ---- Case numbers:
                          // Prefer stored 'caseNo' if exists, else compute oldest=1
                          final caseNumberById = _computeCaseNumbers(docs);

                          // ---- Apply advanced filters + chip filters
                          List<QueryDocumentSnapshot<Map<String, dynamic>>> list =
                          [...docs];

                          // status filter
                          final sFilter = _statusFilter;
                          if (sFilter != 'all') {
                            final wantClosed = sFilter == 'closed';
                            list = list.where((d) {
                              final status = ((d.data()['status'] as String?) ??
                                  'active')
                                  .toLowerCase();
                              final isClosed = status == 'closed';
                              return wantClosed ? isClosed : !isClosed;
                            }).toList();
                          }

                          // risk filter
                          final rFilter = _riskFilter;
                          if (rFilter != 'all') {
                            final wantHigh = rFilter == 'high';
                            list = list.where((d) {
                              final score = _infectionScore(d.data());
                              final risk = _riskBucket(score);
                              return wantHigh ? risk == 'high' : risk == 'low';
                            }).toList();
                          }

                          // sort
                          list.sort((a, b) {
                            final aDt = _bestStartDate(a.data());
                            final bDt = _bestStartDate(b.data());
                            if (_sort == CaseSort.startMostRecent) {
                              return bDt.compareTo(aDt);
                            } else {
                              return aDt.compareTo(bDt);
                            }
                          });

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

                              final score = _infectionScore(data);
                              final assessment = _assessmentFromScore(score);
                              final riskBucket = _riskBucket(score); // low/high

                              return Padding(
                                padding: const EdgeInsets.only(bottom: 14),
                                child: _CaseGlassCardV2(
                                  caseNo: caseNo,
                                  dayLabel: _computeDayLabel(
                                    data['startDate'] ??
                                        data['createdAt'] ??
                                        data['surgeryDate'],
                                  ),
                                  startDate: startDate,
                                  lastUpdated: lastUpdated,
                                  score: score,
                                  assessment: assessment,
                                  isClosed: isClosed,
                                  isHighRisk: riskBucket == 'high',
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

  static String _getUserName(
      Map<String, dynamic>? data, {
        required String fallback,
      }) {
    if (data == null) return fallback;
    final v = data['name'] ?? data['username'] ?? data['displayName'];
    final s = (v is String) ? v.trim() : '';
    return s.isNotEmpty ? s : fallback;
  }
}

/* ===================== Background ===================== */

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

/* ===================== Top widgets ===================== */

class _AvatarChip extends StatelessWidget {
  const _AvatarChip({required this.letter});
  final String letter;

  @override
  Widget build(BuildContext context) {
    return _Glass(
      radius: 18,
      padding: EdgeInsets.zero,
      child: SizedBox(
        width: 44,
        height: 44,
        child: Center(
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
      child: _Glass(
        radius: 999,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 18, color: const Color(0xFF3B7691)),
            const SizedBox(width: 8),
            Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 13,
                fontWeight: FontWeight.w900,
                color: const Color(0xFF3B7691),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _GlassIconButton extends StatelessWidget {
  const _GlassIconButton({
    required this.icon,
    required this.onTap,
  });

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: _Glass(
        radius: 18,
        padding: EdgeInsets.zero,
        child: const SizedBox(
          width: 44,
          height: 44,
          child: Center(
            child: Icon(Icons.filter_alt_outlined, color: Color(0xFF3B7691)),
          ),
        ),
      ),
    );
  }
}

/* ===================== Filter chips ===================== */

class _ChipPill extends StatelessWidget {
  const _ChipPill({
    required this.label,
    required this.selected,
    required this.onTap,
    this.selectedColor = const Color(0xFF3B7691),
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final Color selectedColor;

  @override
  Widget build(BuildContext context) {
    final bg = selected
        ? selectedColor.withOpacity(0.14)
        : Colors.white.withOpacity(0.50);

    final br = selected
        ? selectedColor.withOpacity(0.25)
        : Colors.white.withOpacity(0.70);

    final textColor = selected ? selectedColor : const Color(0xFF64748B);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(999),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
          child: Container(
            height: 44,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              color: bg,
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: br),
            ),
            child: Center(
              child: Text(
                label,
                style: GoogleFonts.inter(
                  fontSize: 13,
                  fontWeight: FontWeight.w900,
                  color: textColor,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/* ===================== Card (glass) ===================== */

class _CaseGlassCardV2 extends StatelessWidget {
  const _CaseGlassCardV2({
    required this.caseNo,
    required this.dayLabel,
    required this.startDate,
    required this.lastUpdated,
    required this.score,
    required this.assessment,
    required this.isClosed,
    required this.isHighRisk,
    required this.onDetails,
    required this.onDashboard,
    this.onPlay,
  });

  final int caseNo;
  final String dayLabel;
  final String startDate;
  final String lastUpdated;

  final int score;
  final String assessment;

  final bool isClosed;
  final bool isHighRisk;

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

    final riskColor = isHighRisk ? closedRed : primary;
    final riskText = isHighRisk ? "High risk" : "No signs of infection";

    // uniform glass base + small tint if high risk
    final tint = isHighRisk ? closedRed : secondary;

    return _Glass(
      radius: 26,
      tint: tint.withOpacity(0.08),
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // Header row
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  color: Colors.white.withOpacity(0.55),
                  border: Border.all(color: Colors.white.withOpacity(0.70)),
                ),
                child: Icon(
                  Icons.folder_outlined,
                  color: isHighRisk ? closedRed : primary,
                ),
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
              _StatusPill(text: statusText, color: statusColor),
            ],
          ),

          const SizedBox(height: 12),
          Container(height: 1, color: Colors.black.withOpacity(0.06)),
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
                    color: tint.withOpacity(0.10),
                    border: Border.all(color: tint.withOpacity(0.20)),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 34,
                        height: 34,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                          color: Colors.white.withOpacity(0.65),
                          border:
                          Border.all(color: Colors.white.withOpacity(0.70)),
                        ),
                        child: Icon(
                          Icons.monitor_heart_outlined,
                          color: isHighRisk ? closedRed : primary,
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
                                fontWeight: FontWeight.w900,
                                color: const Color(0xFF64748B),
                              ),
                            ),
                            const SizedBox(height: 2),
                            Row(
                              children: [
                                Text(
                                  "$score",
                                  style: GoogleFonts.dmSans(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w900,
                                    color: const Color(0xFF0F172A),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Flexible(
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 10, vertical: 5),
                                    decoration: BoxDecoration(
                                      color: riskColor.withOpacity(0.10),
                                      borderRadius: BorderRadius.circular(999),
                                      border: Border.all(
                                          color: riskColor.withOpacity(0.20)),
                                    ),
                                    child: Text(
                                      riskText,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: GoogleFonts.inter(
                                        fontSize: 11.2,
                                        fontWeight: FontWeight.w900,
                                        color: riskColor,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 2),
                            Text(
                              assessment,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.inter(
                                fontSize: 11.2,
                                fontWeight: FontWeight.w700,
                                color: const Color(0xFF64748B),
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

              // Play button
              InkWell(
                onTap: onPlay,
                borderRadius: BorderRadius.circular(18),
                child: Opacity(
                  opacity: onPlay == null ? 0.35 : 1,
                  child: Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(18),
                      color: primary.withOpacity(0.85),
                      boxShadow: [
                        BoxShadow(
                          color: primary.withOpacity(0.25),
                          blurRadius: 18,
                          offset: const Offset(0, 10),
                          spreadRadius: -8,
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.play_arrow_rounded,
                      color: Colors.white,
                      size: 30,
                    ),
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
              fontWeight: FontWeight.w900,
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

/* ===================== Glass primitives ===================== */

class _Glass extends StatelessWidget {
  const _Glass({
    required this.child,
    this.radius = 24,
    this.padding = const EdgeInsets.all(14),
    this.tint,
  });

  final Widget child;
  final double radius;
  final EdgeInsets padding;
  final Color? tint;

  @override
  Widget build(BuildContext context) {
    final border = Colors.white.withOpacity(0.70);
    final bg = Colors.white.withOpacity(0.68);

    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
        child: Container(
          padding: padding,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(radius),
            border: Border.all(color: border),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                bg,
                bg.withOpacity(0.52),
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
          child: Stack(
            children: [
              if (tint != null)
                Positioned.fill(
                  child: DecoratedBox(
                    decoration: BoxDecoration(color: tint),
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

class _GlassSheet extends StatelessWidget {
  const _GlassSheet({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(26),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 22, sigmaY: 22),
        child: Container(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(26),
            color: Colors.white.withOpacity(0.70),
            border: Border.all(color: Colors.white.withOpacity(0.75)),
          ),
          child: child,
        ),
      ),
    );
  }
}

class _SheetSection extends StatelessWidget {
  const _SheetSection({required this.title, required this.child});
  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: GoogleFonts.inter(
            fontSize: 12.8,
            fontWeight: FontWeight.w900,
            color: const Color(0xFF0F172A),
          ),
        ),
        const SizedBox(height: 10),
        child,
      ],
    );
  }
}

class _RadioRow extends StatelessWidget {
  const _RadioRow({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = selected ? const Color(0xFF3B7691) : const Color(0xFF94A3B8);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          color: Colors.white.withOpacity(0.45),
          border: Border.all(color: Colors.white.withOpacity(0.70)),
        ),
        child: Row(
          children: [
            Container(
              width: 18,
              height: 18,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: c, width: 2),
              ),
              child: selected
                  ? Center(
                child: Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: c,
                  ),
                ),
              )
                  : null,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                label,
                style: GoogleFonts.inter(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: const Color(0xFF0F172A),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MiniPill extends StatelessWidget {
  const _MiniPill({
    required this.text,
    required this.selected,
    required this.onTap,
  });

  final String text;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final bg = selected
        ? const Color(0xFF3B7691).withOpacity(0.12)
        : Colors.white.withOpacity(0.45);

    final br = selected
        ? const Color(0xFF63A2BF).withOpacity(0.35)
        : Colors.white.withOpacity(0.70);

    final tc = selected ? const Color(0xFF3B7691) : const Color(0xFF64748B);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(999),
          color: bg,
          border: Border.all(color: br),
        ),
        child: Text(
          text,
          style: GoogleFonts.inter(
            fontSize: 12.8,
            fontWeight: FontWeight.w900,
            color: tc,
          ),
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
        _Glass(
          radius: 26,
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
                    elevation: 0,
                  ),
                ),
              ),
            ],
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
            fontWeight: FontWeight.w900,
          ),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}

/* ===================== Helpers (data) ===================== */

Map<String, int> _computeCaseNumbers(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
    ) {
  // If any doc has caseNo, use it (stable numbering)
  final hasStored = docs.any((d) {
    final v = d.data()['caseNo'];
    return v is int && v > 0;
  });

  if (hasStored) {
    final out = <String, int>{};
    for (final d in docs) {
      final v = d.data()['caseNo'];
      if (v is int && v > 0) out[d.id] = v;
    }
    // fallback: compute for missing
    if (out.length != docs.length) {
      final computed = _computeCaseNumbersFallback(docs);
      for (final d in docs) {
        out[d.id] ??= computed[d.id] ?? 0;
      }
    }
    return out;
  }

  return _computeCaseNumbersFallback(docs);
}

Map<String, int> _computeCaseNumbersFallback(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
    ) {
  final sorted = [...docs];
  sorted.sort((a, b) {
    final aDt = _bestStartDate(a.data());
    final bDt = _bestStartDate(b.data());
    return aDt.compareTo(bDt); // oldest -> newest
  });

  final out = <String, int>{};
  for (int i = 0; i < sorted.length; i++) {
    out[sorted[i].id] = i + 1;
  }
  return out;
}

DateTime _bestStartDate(Map<String, dynamic> data) {
  final dt = _toDate(data['startDate']) ??
      _toDate(data['surgeryDate']) ??
      _toDate(data['createdAt']);
  return dt ?? DateTime.fromMillisecondsSinceEpoch(0);
}

int _infectionScore(Map<String, dynamic> data) {
  final raw = data['infectionScore'];
  if (raw is int) return raw;
  return int.tryParse('$raw') ?? 0;
}

String _riskBucket(int score) {
  // adjust thresholds if you want
  if (score >= 6) return 'high';
  return 'low';
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

String _assessmentFromScore(int? score) {
  if (score == null) return "No data yet";
  if (score <= 2) return "No Signs of Infection";
  if (score <= 5) return "Mild Warning";
  return "High Risk — Seek Care";
}
