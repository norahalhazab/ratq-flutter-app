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
import '../utils/app_colors.dart';

enum CaseChipFilter { all, active, closed }
enum CaseSort { startMostRecent, startOldest }

class CasesScreen extends StatefulWidget {
  const CasesScreen({super.key});

  @override
  State<CasesScreen> createState() => _CasesScreenState();
}

class _CasesScreenState extends State<CasesScreen> {
  CaseChipFilter _chip = CaseChipFilter.all;

  CaseSort _sort = CaseSort.startMostRecent;
  String _statusFilter = 'all'; // all / active / closed
  String _riskFilter = 'all'; // all / low / high

  void _openFilters() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withOpacity(0.15),
      builder: (_) {
        var tmpSort = _sort;
        var tmpStatus = _statusFilter;
        var tmpRisk = _riskFilter;

        return Padding(
          padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
          child: _FrostedSheet(
            child: StatefulBuilder(
              builder: (context, setSheet) {
                return Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 46,
                      height: 5,
                      margin: const EdgeInsets.only(top: 10, bottom: 14),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.12),
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
                            color: AppColors.textPrimary,
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
                              color: AppColors.primaryColor,
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
                            onTap: () => setSheet(() {
                              tmpSort = CaseSort.startMostRecent;
                            }),
                          ),
                          const SizedBox(height: 8),
                          _RadioRow(
                            label: "Oldest first",
                            selected: tmpSort == CaseSort.startOldest,
                            onTap: () => setSheet(() {
                              tmpSort = CaseSort.startOldest;
                            }),
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
                            text: "Low risk",
                            selected: tmpRisk == 'low',
                            onTap: () => setSheet(() => tmpRisk = 'low'),
                          ),
                          _MiniPill(
                            text: "High risk",
                            selected: tmpRisk == 'high',
                            onTap: () => setSheet(() => tmpRisk = 'high'),
                            selectedColor: AppColors.errorColor,
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 18),

                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton(
                        onPressed: () {
                          setState(() {
                            _sort = tmpSort;
                            _statusFilter = tmpStatus;
                            _riskFilter = tmpRisk;

                            if (_statusFilter == 'active') {
                              _chip = CaseChipFilter.active;
                            } else if (_statusFilter == 'closed') {
                              _chip = CaseChipFilter.closed;
                            } else {
                              _chip = CaseChipFilter.all;
                            }
                          });

                          Navigator.pop(context);
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primaryColor,
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
                );
              },
            ),
          ),
        );
      },
    );
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
              "You must be logged in to view cases.",
              style: GoogleFonts.dmSans(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
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
      backgroundColor: AppColors.backgroundColor,
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
          const _BlueGlassyBackground(),
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
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 10),
                      child: Row(
                        children: [
                          _AvatarButton(
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
                                    color: AppColors.textSecondary,
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
                                    color: AppColors.textPrimary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          _HeaderPill(
                            label: "New Wound",
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

                    Padding(
                      padding: const EdgeInsets.fromLTRB(18, 2, 18, 0),
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          "Wound cases",
                          style: GoogleFonts.dmSans(
                            fontSize: 30,
                            fontWeight: FontWeight.w900,
                            color: AppColors.textPrimary,
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
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ),
                    ),

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
                                  _SegmentPill(
                                    label: "All",
                                    selected: _chip == CaseChipFilter.all,
                                    onTap: () {
                                      setState(() {
                                        _chip = CaseChipFilter.all;
                                        _statusFilter = 'all';
                                      });
                                    },
                                  ),
                                  const SizedBox(width: 10),
                                  _SegmentPill(
                                    label: "Active",
                                    selected: _chip == CaseChipFilter.active,
                                    onTap: () {
                                      setState(() {
                                        _chip = CaseChipFilter.active;
                                        _statusFilter = 'active';
                                      });
                                    },
                                  ),
                                  const SizedBox(width: 10),
                                  _SegmentPill(
                                    label: "Closed",
                                    selected: _chip == CaseChipFilter.closed,
                                    onTap: () {
                                      setState(() {
                                        _chip = CaseChipFilter.closed;
                                        _statusFilter = 'closed';
                                      });
                                    },
                                  ),
                                  const SizedBox(width: 10),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          _IconPillButton(
                            icon: Icons.tune_rounded,
                            onTap: _openFilters,
                          ),
                        ],
                      ),
                    ),

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

                          final caseNumberById = _computeCaseNumbers(docs);

                          List<QueryDocumentSnapshot<Map<String, dynamic>>> list =
                          [...docs];

                          if (_statusFilter != 'all') {
                            final wantClosed = _statusFilter == 'closed';
                            list = list.where((d) {
                              final status =
                              ((d.data()['status'] as String?) ?? 'active')
                                  .toLowerCase();
                              final isClosed = status == 'closed';
                              return wantClosed ? isClosed : !isClosed;
                            }).toList();
                          }

                          if (_riskFilter != 'all') {
                            final wantHigh = _riskFilter == 'high';
                            list = list.where((d) {
                              final score = _infectionScore(d.data());
                              final risk = _riskBucket(score);
                              return wantHigh ? risk == 'high' : risk == 'low';
                            }).toList();
                          }

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

                              // ✅ NEW: pick the displayed name
                              final caseTitle = _caseDisplayName(data, caseNo);

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
                              final isHighRisk = _riskBucket(score) == 'high';

                              return Padding(
                                padding: const EdgeInsets.only(bottom: 14),
                                child: _WoundCleanCard(
                                  caseTitle: caseTitle,
                                  caseNo: caseNo,
                                  dayLabel: _computeDayLabel(
                                    data['startDate'] ??
                                        data['createdAt'] ??
                                        data['surgeryDate'],
                                  ),
                                  startDate: startDate,
                                  lastUpdated: lastUpdated,
                                  isClosed: isClosed,
                                  isHighRisk: isHighRisk,
                                  assessment: assessment,
                                  onStartDaily: isClosed
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

  static String _getUserName(Map<String, dynamic>? data,
      {required String fallback}) {
    if (data == null) return fallback;
    final v = data['name'] ?? data['username'] ?? data['displayName'];
    final s = (v is String) ? v.trim() : '';
    return s.isNotEmpty ? s : fallback;
  }
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

/* ===================== Header pills ===================== */

class _AvatarButton extends StatelessWidget {
  const _AvatarButton({required this.letter});
  final String letter;

  @override
  Widget build(BuildContext context) {
    return _WhitePill(
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
              color: AppColors.primaryColor,
            ),
          ),
        ),
      ),
    );
  }
}

class _HeaderPill extends StatelessWidget {
  const _HeaderPill({
    required this.label,
    required this.icon,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return _WhitePillButton(
      onTap: onTap,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 18, color: AppColors.primaryColor),
          const SizedBox(width: 8),
          Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 13,
              fontWeight: FontWeight.w900,
              color: AppColors.primaryColor,
            ),
          ),
        ],
      ),
    );
  }
}

class _SegmentPill extends StatelessWidget {
  const _SegmentPill({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOutCubic,
        height: 44,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(999),
          gradient: selected ? AppColors.primaryGradient : null,
          color: selected ? null : Colors.white.withOpacity(0.92),
          border: Border.all(
            color: selected
                ? Colors.white.withOpacity(0.55)
                : AppColors.dividerColor.withOpacity(0.9),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(selected ? 0.10 : 0.06),
              blurRadius: 16,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Center(
          child: Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 13,
              fontWeight: FontWeight.w900,
              color: selected ? Colors.white : AppColors.textSecondary,
            ),
          ),
        ),
      ),
    );
  }
}

class _IconPillButton extends StatelessWidget {
  const _IconPillButton({required this.icon, required this.onTap});
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return _WhitePillButton(
      onTap: onTap,
      child: Icon(icon, color: AppColors.primaryColor),
    );
  }
}

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

/* ===================== Card ===================== */

class _WoundCleanCard extends StatelessWidget {
  const _WoundCleanCard({
    required this.caseTitle,
    required this.caseNo,
    required this.dayLabel,
    required this.startDate,
    required this.lastUpdated,
    required this.isClosed,
    required this.isHighRisk,
    required this.assessment,
    required this.onDetails,
    required this.onDashboard,
    this.onStartDaily,
  });

  final String caseTitle;
  final int caseNo;
  final String dayLabel;
  final String startDate;
  final String lastUpdated;

  final bool isClosed;
  final bool isHighRisk;
  final String assessment;

  final VoidCallback onDetails;
  final VoidCallback onDashboard;
  final VoidCallback? onStartDaily;

  @override
  Widget build(BuildContext context) {
    final statusColor = isClosed ? AppColors.errorColor : AppColors.successColor;
    final statusText = isClosed ? "Closed" : "Active";

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(26),
        color: Colors.white.withOpacity(0.92),
        border: Border.all(
          color: isHighRisk
              ? AppColors.errorColor.withOpacity(0.18)
              : AppColors.primaryColor.withOpacity(0.10),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 22,
            offset: const Offset(0, 14),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              children: [
                _CardIconBadge(
                  tint: isHighRisk ? AppColors.errorColor : AppColors.primaryColor,
                  icon: Icons.folder_outlined,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // ✅ name you chose
                      Text(
                        caseTitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.dmSans(
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      // ✅ keep number + day label as info (small)
                      Text(
                        "Wound $caseNo • $dayLabel",
                        style: GoogleFonts.inter(
                          fontSize: 12.2,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textMuted,
                        ),
                      ),
                    ],
                  ),
                ),
                _StatusChip(text: statusText, color: statusColor),
              ],
            ),

            const SizedBox(height: 12),
            Divider(height: 1, color: AppColors.dividerColor.withOpacity(0.9)),
            const SizedBox(height: 12),

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

            Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(22),
                color: AppColors.surfaceColor.withOpacity(0.95),
                border: Border.all(
                  color: isHighRisk
                      ? AppColors.errorColor.withOpacity(0.14)
                      : AppColors.primaryColor.withOpacity(0.10),
                ),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "Daily Check",
                          style: GoogleFonts.dmSans(
                            fontSize: 16,
                            fontWeight: FontWeight.w900,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          assessment,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.inter(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  _PrimaryCircleArrow(
                    onTap: onStartDaily,
                    disabled: onStartDaily == null,
                  ),
                ],
              ),
            ),

            const SizedBox(height: 12),

            Row(
              children: [
                Expanded(
                  child: _BlueActionButton(
                    label: "View Details",
                    icon: Icons.remove_red_eye_outlined,
                    gradient: AppColors.primaryGradient,
                    onTap: onDetails,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _BlueActionButton(
                    label: "View Dashboard",
                    icon: Icons.bar_chart_rounded,
                    gradient: const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        Color(0xFF63A2BF),
                        Color(0xFF3B7691),
                      ],
                    ),
                    onTap: onDashboard,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _CardIconBadge extends StatelessWidget {
  const _CardIconBadge({required this.tint, required this.icon});
  final Color tint;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            tint.withOpacity(0.18),
            tint.withOpacity(0.10),
            Colors.white.withOpacity(0.70),
          ],
        ),
        border: Border.all(color: AppColors.dividerColor.withOpacity(0.85)),
      ),
      child: Icon(icon, color: tint),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.text, required this.color});
  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        color: color.withOpacity(0.12),
        border: Border.all(color: color.withOpacity(0.26)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 7,
            height: 7,
            decoration: BoxDecoration(shape: BoxShape.circle, color: color),
          ),
          const SizedBox(width: 7),
          Text(
            text,
            style: GoogleFonts.inter(
              fontSize: 11.5,
              fontWeight: FontWeight.w900,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

class _PrimaryCircleArrow extends StatelessWidget {
  const _PrimaryCircleArrow({required this.onTap, required this.disabled});
  final VoidCallback? onTap;
  final bool disabled;

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: disabled ? 0.35 : 1,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: Container(
          width: 52,
          height: 52,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(999),
            gradient: AppColors.primaryGradient,
            boxShadow: [
              BoxShadow(
                color: AppColors.primaryColor.withOpacity(0.25),
                blurRadius: 18,
                offset: const Offset(0, 12),
                spreadRadius: -10,
              ),
            ],
          ),
          child: const Icon(
            Icons.arrow_forward_rounded,
            color: Colors.white,
            size: 24,
          ),
        ),
      ),
    );
  }
}

class _BlueActionButton extends StatelessWidget {
  const _BlueActionButton({
    required this.label,
    required this.icon,
    required this.gradient,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final Gradient gradient;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: Container(
        height: 46,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(999),
          gradient: gradient,
          boxShadow: const [
            BoxShadow(
              color: Color(0x22000000),
              blurRadius: 18,
              offset: Offset(0, 10),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 18, color: Colors.white),
            const SizedBox(width: 8),
            Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 12.8,
                fontWeight: FontWeight.w900,
                color: Colors.white,
              ),
            ),
          ],
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

/* ===================== Bottom sheet UI ===================== */

class _FrostedSheet extends StatelessWidget {
  const _FrostedSheet({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(26),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
        child: Container(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
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
            color: AppColors.textPrimary,
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
    final c = selected ? AppColors.primaryColor : AppColors.textMuted;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          color: AppColors.surfaceColor.withOpacity(0.95),
          border: Border.all(color: AppColors.dividerColor.withOpacity(0.9)),
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
                  decoration:
                  BoxDecoration(shape: BoxShape.circle, color: c),
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
                  color: AppColors.textPrimary,
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
    this.selectedColor = AppColors.primaryColor,
  });

  final String text;
  final bool selected;
  final VoidCallback onTap;
  final Color selectedColor;

  @override
  Widget build(BuildContext context) {
    final bg = selected ? selectedColor.withOpacity(0.12) : Colors.white;
    final br = selected
        ? selectedColor.withOpacity(0.30)
        : AppColors.dividerColor.withOpacity(0.9);
    final tc = selected ? selectedColor : AppColors.textSecondary;

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
        Container(
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
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "No cases yet",
                style: GoogleFonts.dmSans(
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                "Create your first case to start monitoring your wound.",
                style: GoogleFonts.inter(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textSecondary,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                height: 46,
                child: ElevatedButton.icon(
                  onPressed: onCreate,
                  icon: const Icon(Icons.add),
                  label: const Text("Create New Case"),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryColor,
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
            color: AppColors.errorColor,
            fontWeight: FontWeight.w900,
          ),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}

/* ===================== Helpers (data) ===================== */

String _caseDisplayName(Map<String, dynamic> data, int caseNo) {
  final rawName = (data['caseName'] ?? data['title'] ?? '').toString().trim();
  if (rawName.isNotEmpty) return rawName;
  return "Wound $caseNo";
}

Map<String, int> _computeCaseNumbers(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
    ) {
  // ✅ accept both keys: caseNumber OR caseNo
  bool hasStored = false;
  for (final d in docs) {
    final data = d.data();
    final v1 = data['caseNumber'];
    final v2 = data['caseNo'];
    final n1 = (v1 is int) ? v1 : int.tryParse('$v1');
    final n2 = (v2 is int) ? v2 : int.tryParse('$v2');
    final n = (n1 ?? n2) ?? 0;
    if (n > 0) {
      hasStored = true;
      break;
    }
  }

  if (hasStored) {
    final out = <String, int>{};
    for (final d in docs) {
      final data = d.data();
      final v1 = data['caseNumber'];
      final v2 = data['caseNo'];
      final n1 = (v1 is int) ? v1 : int.tryParse('$v1');
      final n2 = (v2 is int) ? v2 : int.tryParse('$v2');
      final n = (n1 ?? n2) ?? 0;
      if (n > 0) out[d.id] = n;
    }

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
  if (score <= 2) return "Low sign of infection • keep monitoring";
  if (score <= 5) return "Warning • watch symptoms";
  return "High risk • seek care";
}
