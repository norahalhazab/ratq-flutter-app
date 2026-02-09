// homepage.dart
import 'dart:ui';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../utils/app_colors.dart';
import '../widgets/bottom_nav.dart';
import 'create_case_screen.dart';

class Homepage extends StatefulWidget {
  const Homepage({super.key});

  @override
  State<Homepage> createState() => _HomepageState();
}

class _HomepageState extends State<Homepage> {
  String? _selectedCaseId;

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      return Scaffold(
        backgroundColor: AppColors.backgroundColor,
        body: SafeArea(
          child: Center(
            child: Text(
              "You must be logged in.",
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

    final Query<Map<String, dynamic>> casesQuery = FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .collection('cases')
        .orderBy('lastUpdated', descending: true);

    return Scaffold(
      backgroundColor: AppColors.backgroundColor,
      bottomNavigationBar: AppBottomNav(
        currentIndex: 0,
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

                return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                  stream: casesQuery.snapshots(),
                  builder: (context, casesSnap) {
                    final docs = casesSnap.data?.docs ?? [];

                    // Ensure a selected case (if any exist)
                    if (docs.isNotEmpty) {
                      final ids = docs.map((d) => d.id).toList();
                      if (_selectedCaseId == null ||
                          !ids.contains(_selectedCaseId)) {
                        WidgetsBinding.instance.addPostFrameCallback((_) {
                          if (!mounted) return;
                          setState(() => _selectedCaseId = ids.first);
                        });
                      }
                    } else {
                      _selectedCaseId = null;
                    }

                    QueryDocumentSnapshot<Map<String, dynamic>>? selectedDoc;

                    if (docs.isNotEmpty && _selectedCaseId != null) {
                      final i = docs.indexWhere((d) => d.id == _selectedCaseId);
                      selectedDoc = (i >= 0) ? docs[i] : docs.first;
                    } else if (docs.isNotEmpty) {
                      selectedDoc = docs.first;
                    } else {
                      selectedDoc = null;
                    }

                    final selectedData = selectedDoc?.data();

                    final startValue = selectedData == null
                        ? null
                        : (selectedData['startDate'] ??
                        selectedData['createdAt'] ??
                        selectedData['surgeryDate']);

                    final daysSince = _daysSince(startValue);
                    final status =
                    ((selectedData?['status'] as String?) ?? 'active')
                        .toLowerCase();
                    final isClosed = status == 'closed';

                    final score = selectedData == null ? null : _infectionScore(selectedData);
                    final assessment = _assessmentFromScore(score);

                    return CustomScrollView(
                      slivers: [
                        SliverToBoxAdapter(
                          child: Padding(
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
                        ),

                        // Title
                        SliverToBoxAdapter(
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(18, 2, 18, 0),
                            child: Align(
                              alignment: Alignment.centerLeft,
                              child: Text(
                                "Dashboard",
                                style: GoogleFonts.dmSans(
                                  fontSize: 30,
                                  fontWeight: FontWeight.w900,
                                  color: AppColors.textPrimary,
                                  height: 1.0,
                                ),
                              ),
                            ),
                          ),
                        ),
                        SliverToBoxAdapter(
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(18, 6, 18, 10),
                            child: Align(
                              alignment: Alignment.centerLeft,
                              child: Text(
                                "Vitals, trends, and WHQ insights",
                                style: GoogleFonts.inter(
                                  fontSize: 13.2,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                            ),
                          ),
                        ),

                        // Case selector pill
                        SliverToBoxAdapter(
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
                            child: Row(
                              children: [
                                Expanded(
                                  child: _CasePickerPill(
                                    enabled: docs.isNotEmpty,
                                    title: docs.isEmpty
                                        ? "No cases yet"
                                        : _caseTitleForDoc(selectedDoc, docs),
                                    subtitle: docs.isEmpty
                                        ? "Create a case to start"
                                        : (isClosed ? "Closed" : "Active"),
                                    onTap: docs.isEmpty
                                        ? null
                                        : () => _openCasePicker(
                                      context: context,
                                      cases: docs,
                                      selectedId: _selectedCaseId,
                                      onSelect: (id) => setState(() {
                                        _selectedCaseId = id;
                                      }),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                _IconPillButton(
                                  icon: Icons.insights_rounded,
                                  onTap: () {},
                                ),
                              ],
                            ),
                          ),
                        ),

                        // Summary card (selected case)
                        SliverToBoxAdapter(
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(16, 6, 16, 12),
                            child: _CaseSummaryCard(
                              enabled: selectedDoc != null,
                              title: selectedDoc == null
                                  ? "Select a case"
                                  : _caseTitleForDoc(selectedDoc, docs),
                              dayLabel: selectedDoc == null
                                  ? "Day --"
                                  : "Day ${daysSince == null ? "--" : daysSince.toString()}",
                              isClosed: isClosed,
                              scoreText: score == null ? "--" : score.toString(),
                              assessment: assessment,
                              startDate: _formatDate(startValue),
                              lastUpdated: _formatDate(
                                selectedData?['lastUpdated'] ??
                                    selectedData?['createdAt'],
                              ),
                              whqCountBuilder: selectedDoc == null
                                  ? null
                                  : _WhqCountBuilder(
                                userId: user.uid,
                                caseId: selectedDoc.id,
                              ),
                            ),
                          ),
                        ),

                        // Vitals grid + charts
                        SliverPadding(
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 96),
                          sliver: SliverList(
                            delegate: SliverChildListDelegate(
                              [
                                Row(
                                  children: const [
                                    Expanded(
                                      child: _MetricGlassCard(
                                        label: "Heart\nRate",
                                        value: "---",
                                        unit: "bpm",
                                        badgeText: "Not synced",
                                        icon: Icons.favorite_border,
                                        tint: AppColors.errorColor,
                                      ),
                                    ),
                                    SizedBox(width: 12),
                                    Expanded(
                                      child: _MetricGlassCard(
                                        label: "Blood\nPressure",
                                        value: "--- / ---",
                                        unit: "mmHg",
                                        badgeText: "Not synced",
                                        icon: Icons.water_drop_outlined,
                                        tint: AppColors.secondaryColor,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                Row(
                                  children: const [
                                    Expanded(
                                      child: _MetricGlassCard(
                                        label: "Temperature",
                                        value: "---",
                                        unit: "°C",
                                        badgeText: "Not synced",
                                        icon: Icons.thermostat_outlined,
                                        tint: AppColors.warningColor,
                                      ),
                                    ),
                                    SizedBox(width: 12),
                                    Expanded(
                                      child: _MetricGlassCard(
                                        label: "Oxygen",
                                        value: "---",
                                        unit: "%",
                                        badgeText: "Not synced",
                                        icon: Icons.bloodtype_outlined,
                                        tint: AppColors.primaryColor,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),

                                _GlassSectionCard(
                                  title: "Trends (placeholder)",
                                  subtitle:
                                  "Charts will automatically display when smartwatch + WHQ data is connected.",
                                  child: Column(
                                    children: const [
                                      _MiniChartPlaceholder(
                                        title: "Infection score trend",
                                        hint: "Line chart • last 14 days",
                                      ),
                                      SizedBox(height: 12),
                                      _MiniChartPlaceholder(
                                        title: "Vitals trend",
                                        hint: "Heart rate / Temp • last 7 days",
                                      ),
                                    ],
                                  ),
                                ),

                                const SizedBox(height: 12),

                                _GlassSectionCard(
                                  title: "WHQ insights (data-ready)",
                                  subtitle:
                                  "We’ll compute simple analytics per case (no manual work).",
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      _InsightRow(
                                        icon: Icons.query_stats_rounded,
                                        title: "Completion consistency",
                                        value: "streak, missed days, weekly rate",
                                      ),
                                      const SizedBox(height: 10),
                                      _InsightRow(
                                        icon: Icons.rule_rounded,
                                        title: "Risk pattern",
                                        value:
                                        "compare WHQ answers vs score changes",
                                      ),
                                      const SizedBox(height: 10),
                                      _InsightRow(
                                        icon: Icons.auto_graph_rounded,
                                        title: "Forecast (later)",
                                        value:
                                        "basic trend-based early warning signal",
                                      ),
                                      const SizedBox(height: 14),
                                      _WhiteHintPill(
                                        text:
                                        "Tip: Once connected, this screen becomes your “doctor-like” dashboard for each wound.",
                                      ),
                                    ],
                                  ),
                                ),

                                const SizedBox(height: 10),
                              ],
                            ),
                          ),
                        ),
                      ],
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  void _openCasePicker({
    required BuildContext context,
    required List<QueryDocumentSnapshot<Map<String, dynamic>>> cases,
    required String? selectedId,
    required ValueChanged<String> onSelect,
  }) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withOpacity(0.15),
      builder: (_) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
          child: _FrostedSheet(
            child: Column(
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
                      "Choose case",
                      style: GoogleFonts.dmSans(
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const Spacer(),
                    _IconPillButton(
                      icon: Icons.close_rounded,
                      onTap: () => Navigator.pop(context),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Flexible(
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: cases.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (context, i) {
                      final d = cases[i];
                      final data = d.data();
                      final title = _caseTitleFromData(data, fallback: "Wound");
                      final status =
                      ((data['status'] as String?) ?? 'active').toLowerCase();
                      final isClosed = status == 'closed';
                      final isSelected = d.id == selectedId;

                      return InkWell(
                        onTap: () {
                          onSelect(d.id);
                          Navigator.pop(context);
                        },
                        borderRadius: BorderRadius.circular(18),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 160),
                          curve: Curves.easeOutCubic,
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(18),
                            color: Colors.white.withOpacity(0.92),
                            border: Border.all(
                              color: isSelected
                                  ? AppColors.primaryColor.withOpacity(0.30)
                                  : AppColors.dividerColor.withOpacity(0.9),
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.06),
                                blurRadius: 18,
                                offset: const Offset(0, 10),
                              ),
                            ],
                          ),
                          child: Row(
                            children: [
                              _CardIconBadge(
                                tint: isClosed
                                    ? AppColors.textMuted
                                    : AppColors.primaryColor,
                                icon: Icons.folder_outlined,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      title,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: GoogleFonts.dmSans(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w900,
                                        color: AppColors.textPrimary,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      "Start: ${_formatDate(data['startDate'] ?? data['createdAt'] ?? data['surgeryDate'])}",
                                      style: GoogleFonts.inter(
                                        fontSize: 12.2,
                                        fontWeight: FontWeight.w700,
                                        color: AppColors.textMuted,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 10),
                              _StatusChip(
                                text: isClosed ? "Closed" : "Active",
                                color: isClosed
                                    ? AppColors.textMuted
                                    : AppColors.successColor,
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 10),
              ],
            ),
          ),
        );
      },
    );
  }

  static String _caseTitleForDoc(
      QueryDocumentSnapshot<Map<String, dynamic>>? selected,
      List<QueryDocumentSnapshot<Map<String, dynamic>>> all,
      ) {
    if (selected == null) return "Select case";
    final data = selected.data();

    // Prefer stable numbering if available
    final caseNo = data['caseNo'];
    if (caseNo is int && caseNo > 0) return "Wound $caseNo";

    // Otherwise fallback to title or "Wound"
    final title = _caseTitleFromData(data, fallback: "Wound");
    return title;
  }

  static String _caseTitleFromData(
      Map<String, dynamic> data, {
        required String fallback,
      }) {
    final v = data['title'] ?? data['name'] ?? data['caseTitle'];
    final s = (v is String) ? v.trim() : '';
    if (s.isNotEmpty) return s;
    return fallback;
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

/* ===================== Top pills ===================== */

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

/* ===================== Case picker pill ===================== */

class _CasePickerPill extends StatelessWidget {
  const _CasePickerPill({
    required this.enabled,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final bool enabled;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: enabled ? 1 : 0.55,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: Container(
          height: 50,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(999),
            color: Colors.white.withOpacity(0.92),
            border: Border.all(color: AppColors.dividerColor.withOpacity(0.9)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.06),
                blurRadius: 16,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Row(
            children: [
              const Icon(Icons.folder_outlined, color: AppColors.primaryColor),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.dmSans(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w900,
                        color: AppColors.textPrimary,
                        height: 1.0,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.inter(
                        fontSize: 12.2,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              const Icon(Icons.keyboard_arrow_down_rounded,
                  color: AppColors.primaryColor),
            ],
          ),
        ),
      ),
    );
  }
}

/* ===================== Summary card ===================== */

class _CaseSummaryCard extends StatelessWidget {
  const _CaseSummaryCard({
    required this.enabled,
    required this.title,
    required this.dayLabel,
    required this.isClosed,
    required this.scoreText,
    required this.assessment,
    required this.startDate,
    required this.lastUpdated,
    required this.whqCountBuilder,
  });

  final bool enabled;
  final String title;
  final String dayLabel;
  final bool isClosed;
  final String scoreText;
  final String assessment;
  final String startDate;
  final String lastUpdated;

  final Widget? whqCountBuilder;

  @override
  Widget build(BuildContext context) {
    final statusColor = isClosed ? AppColors.textMuted : AppColors.successColor;

    return Opacity(
      opacity: enabled ? 1 : 0.65,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(26),
          color: Colors.white.withOpacity(0.92),
          border: Border.all(
            color: AppColors.primaryColor.withOpacity(0.10),
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
                    tint: AppColors.primaryColor,
                    icon: Icons.dashboard_outlined,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.dmSans(
                            fontSize: 18,
                            fontWeight: FontWeight.w900,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          dayLabel,
                          style: GoogleFonts.inter(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textMuted,
                          ),
                        ),
                      ],
                    ),
                  ),
                  _StatusChip(
                    text: isClosed ? "Closed" : "Active",
                    color: statusColor,
                  ),
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

              Row(
                children: [
                  Expanded(
                    child: _KpiTile(
                      title: "Infection score",
                      value: scoreText,
                      pill: assessment,
                      tint: AppColors.primaryColor,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _KpiTile(
                      title: "WHQ completed",
                      valueWidget: whqCountBuilder ??
                          Text(
                            "--",
                            style: GoogleFonts.dmSans(
                              fontSize: 22,
                              fontWeight: FontWeight.w900,
                              color: AppColors.textPrimary,
                            ),
                          ),
                      pill: "Per selected case",
                      tint: AppColors.secondaryColor,
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

class _KpiTile extends StatelessWidget {
  const _KpiTile({
    required this.title,
    this.value,
    this.valueWidget,
    required this.pill,
    required this.tint,
  });

  final String title;
  final String? value;
  final Widget? valueWidget;
  final String pill;
  final Color tint;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        color: AppColors.surfaceColor.withOpacity(0.95),
        border: Border.all(color: tint.withOpacity(0.12)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: GoogleFonts.inter(
              fontSize: 12.5,
              fontWeight: FontWeight.w900,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 10),
          valueWidget ??
              Text(
                value ?? "--",
                style: GoogleFonts.dmSans(
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                  color: AppColors.textPrimary,
                ),
              ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(999),
              color: tint.withOpacity(0.10),
              border: Border.all(color: tint.withOpacity(0.18)),
            ),
            child: Text(
              pill,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.inter(
                fontSize: 11.4,
                fontWeight: FontWeight.w900,
                color: tint,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/* ===================== WHQ count builder ===================== */

class _WhqCountBuilder extends StatelessWidget {
  const _WhqCountBuilder({
    required this.userId,
    required this.caseId,
  });

  final String userId;
  final String caseId;

  @override
  Widget build(BuildContext context) {
    final base = FirebaseFirestore.instance
        .collection('users')
        .doc(userId)
        .collection('cases')
        .doc(caseId);

    // We try common subcollection names. Missing collections return 0 docs (no crash).
    final q1 = base.collection('whq');
    final q2 = base.collection('whqResponses');
    final q3 = base.collection('whq_logs');

    return FutureBuilder<int>(
      future: () async {
        final a = await q1.get();
        if (a.size > 0) return a.size;
        final b = await q2.get();
        if (b.size > 0) return b.size;
        final c = await q3.get();
        return c.size;
      }(),
      builder: (context, snap) {
        final n = snap.data;
        return Text(
          n == null ? "--" : n.toString(),
          style: GoogleFonts.dmSans(
            fontSize: 22,
            fontWeight: FontWeight.w900,
            color: AppColors.textPrimary,
          ),
        );
      },
    );
  }
}

/* ===================== Vitals cards ===================== */

class _MetricGlassCard extends StatelessWidget {
  const _MetricGlassCard({
    required this.label,
    required this.value,
    required this.unit,
    required this.badgeText,
    required this.icon,
    required this.tint,
  });

  final String label;
  final String value;
  final String unit;
  final String badgeText;
  final IconData icon;
  final Color tint;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        color: Colors.white.withOpacity(0.92),
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
          Row(
            children: [
              _CardIconBadge(tint: tint, icon: icon),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  label,
                  style: GoogleFonts.dmSans(
                    fontSize: 14.5,
                    fontWeight: FontWeight.w900,
                    color: AppColors.textPrimary,
                    height: 1.05,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    value,
                    style: GoogleFonts.dmSans(
                      fontSize: 24,
                      fontWeight: FontWeight.w900,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 6),
              Padding(
                padding: const EdgeInsets.only(bottom: 3),
                child: Text(
                  unit,
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textMuted,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(999),
              color: AppColors.surfaceColor.withOpacity(0.95),
              border: Border.all(color: AppColors.dividerColor.withOpacity(0.9)),
            ),
            child: Text(
              badgeText,
              style: GoogleFonts.inter(
                fontSize: 11.8,
                fontWeight: FontWeight.w900,
                color: AppColors.textSecondary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/* ===================== Sections ===================== */

class _GlassSectionCard extends StatelessWidget {
  const _GlassSectionCard({
    required this.title,
    required this.subtitle,
    required this.child,
  });

  final String title;
  final String subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
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
            title,
            style: GoogleFonts.dmSans(
              fontSize: 18,
              fontWeight: FontWeight.w900,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: GoogleFonts.inter(
              fontSize: 12.8,
              fontWeight: FontWeight.w600,
              color: AppColors.textSecondary,
              height: 1.35,
            ),
          ),
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }
}

class _MiniChartPlaceholder extends StatelessWidget {
  const _MiniChartPlaceholder({
    required this.title,
    required this.hint,
  });

  final String title;
  final String hint;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        color: AppColors.surfaceColor.withOpacity(0.95),
        border: Border.all(color: AppColors.primaryColor.withOpacity(0.10)),
      ),
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.show_chart_rounded,
                  color: AppColors.primaryColor, size: 18),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.w900,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Container(
            height: 84,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              color: Colors.white.withOpacity(0.90),
              border: Border.all(color: AppColors.dividerColor.withOpacity(0.9)),
            ),
            child: CustomPaint(
              painter: _SparklinePainter(),
              child: const SizedBox.expand(),
            ),
          ),
          const SizedBox(height: 10),
          Text(
            hint,
            style: GoogleFonts.inter(
              fontSize: 12.2,
              fontWeight: FontWeight.w700,
              color: AppColors.textMuted,
            ),
          ),
        ],
      ),
    );
  }
}

class _SparklinePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppColors.primaryColor.withOpacity(0.35)
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final points = <Offset>[];
    final values = <double>[0.15, 0.35, 0.22, 0.55, 0.48, 0.72, 0.60, 0.85, 0.70];
    for (int i = 0; i < values.length; i++) {
      final x = (i / (values.length - 1)) * (size.width - 20) + 10;
      final y = (1 - values[i]) * (size.height - 20) + 10;
      points.add(Offset(x, y));
    }

    final path = Path()..moveTo(points.first.dx, points.first.dy);
    for (int i = 1; i < points.length; i++) {
      path.lineTo(points[i].dx, points[i].dy);
    }

    // Soft grid dots
    final dotPaint = Paint()..color = Colors.black.withOpacity(0.06);
    for (double x = 10; x < size.width; x += 22) {
      for (double y = 10; y < size.height; y += 22) {
        canvas.drawCircle(Offset(x, y), 1.4, dotPaint);
      }
    }

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _InsightRow extends StatelessWidget {
  const _InsightRow({
    required this.icon,
    required this.title,
    required this.value,
  });

  final IconData icon;
  final String title;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _CardIconBadge(tint: AppColors.secondaryColor, icon: icon),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: GoogleFonts.dmSans(
                  fontSize: 14.5,
                  fontWeight: FontWeight.w900,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: GoogleFonts.inter(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _WhiteHintPill extends StatelessWidget {
  const _WhiteHintPill({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        color: Colors.white.withOpacity(0.90),
        border: Border.all(color: AppColors.dividerColor.withOpacity(0.9)),
      ),
      child: Row(
        children: [
          const Icon(Icons.lightbulb_outline_rounded,
              size: 18, color: AppColors.primaryColor),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: GoogleFonts.inter(
                fontSize: 12.2,
                fontWeight: FontWeight.w800,
                color: AppColors.textSecondary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/* ===================== Shared chips/badges ===================== */

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

/* ===================== Frosted sheet ===================== */

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

/* ===================== Helpers (data) ===================== */

int? _daysSince(dynamic startDate) {
  final dt = _toDate(startDate);
  if (dt == null) return null;
  final diff = DateTime.now().difference(dt).inDays + 1;
  return diff < 1 ? 1 : diff;
}

int _infectionScore(Map<String, dynamic> data) {
  final raw = data['infectionScore'];
  if (raw is int) return raw;
  return int.tryParse('$raw') ?? 0;
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

String _assessmentFromScore(int? score) {
  if (score == null) return "No data yet";
  if (score <= 2) return "Low sign of infection • keep monitoring";
  if (score <= 5) return "Warning • watch symptoms";
  return "High risk • seek care";
}
