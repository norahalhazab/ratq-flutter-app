// homepage.dart
import 'dart:math' as math;
import 'dart:ui';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'profile_screen.dart';
import '../utils/app_colors.dart';
import '../widgets/bottom_nav.dart';

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

    final userDocStream = FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .collection('profile')
        .doc('personal')
        .snapshots();

    final Query<Map<String, dynamic>> casesQuery = FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .collection('cases')
        .orderBy('lastUpdated', descending: true);

    return Scaffold(
      backgroundColor: AppColors.backgroundColor,
      bottomNavigationBar: AppBottomNav(
        currentIndex: 0,
        onNewTap: () {}, // keep if your bottom nav requires it
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

                final profileData = userSnap.data?.data();
                final profilePhoto =
                profileData?['photo']?.toString().trim();

                return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                  stream: casesQuery.snapshots(),
                  builder: (context, casesSnap) {
                    final docs = casesSnap.data?.docs ?? [];

                    // Ensure selected case
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
                    final status =
                    ((selectedData?['status'] as String?) ?? 'active')
                        .toLowerCase();
                    final isClosed = status == 'closed';

                    final startValue = selectedData == null
                        ? null
                        : (selectedData['startDate'] ??
                        selectedData['createdAt'] ??
                        selectedData['surgeryDate']);

                    final daysSince = _daysSince(startValue);
                    final caseTitle = selectedDoc == null
                        ? "Select case"
                        : _caseTitleFromData(selectedData!,
                        fallback: "Untitled wound");

                    final avatarLetter = (userName.isNotEmpty
                        ? userName.trim().substring(0, 1)
                        : "U")
                        .toUpperCase();

                    return CustomScrollView(
                      slivers: [
                        // Header
                        SliverToBoxAdapter(
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                            child: Row(
                              children: [
                                GestureDetector(
                                  onTap: () async {
                                    await Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) => const PersonalInformationScreen(),
                                      ),
                                    );
                                    setState(() {}); // refresh after returning
                                  },
                                  child: _AvatarButton(
                                    letter: avatarLetter,
                                    imageUrl: profilePhoto,
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                    CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        "Hello, welcome back",
                                        style: GoogleFonts.inter(
                                          fontSize: 16,
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
                              ],
                            ),
                          ),
                        ),

                        SliverToBoxAdapter(
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(18, 2, 18, 10),
                            child: Align(
                              alignment: Alignment.centerLeft,
                              child: Text(
                                "Dashboard",
                                style: GoogleFonts.dmSans(
                                  fontSize: 28,
                                  fontWeight: FontWeight.w900,
                                  color: AppColors.textPrimary,
                                  height: 1.0,
                                ),
                              ),
                            ),
                          ),
                        ),

                        // Case selector
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
                                        : caseTitle,
                                    subtitle: docs.isEmpty
                                        ? "Create a case to start"
                                        : (isClosed ? "Closed" : "Active"),
                                    onTap: docs.isEmpty
                                        ? null
                                        : () => _openCasePicker(
                                      context: context,
                                      cases: docs,
                                      selectedId: _selectedCaseId,
                                      onSelect: (id) => setState(
                                              () => _selectedCaseId = id),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),

                        // Body
                        SliverToBoxAdapter(
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(16, 6, 16, 14),
                            child: selectedDoc == null
                                ? _GlassSectionCard(
                              title: "Your Wounds",

                              child: const SizedBox(height: 10),
                            )
                                : FutureBuilder<_DashboardData>(
                              future: _loadDashboardData(
                                userId: user.uid,
                                caseId: selectedDoc!.id,
                              ),
                              builder: (context, snap) {
                                final data = snap.data;

                                final whqCount = data?.whqCount ?? 0;

                                final latest = data?.latestVitals;
                                final hrText = latest?.heartRate == null
                                    ? "---"
                                    : "${latest!.heartRate}";
                                final tempText =
                                latest?.temperature == null
                                    ? "---"
                                    : latest!.temperature!
                                    .toStringAsFixed(1);

                                final bpText = (latest?.bpSys != null &&
                                    latest?.bpDia != null)
                                    ? "${latest!.bpSys!.round()}/${latest.bpDia!.round()}"
                                    : (latest?.bloodPressureText
                                    ?.isNotEmpty ==
                                    true
                                    ? latest!.bloodPressureText!
                                    : "---/---");

                                final infectionLabel =
                                    data?.latestAssessmentLabel ??
                                        "No data yet";
                                final isHigh = infectionLabel
                                    .toLowerCase()
                                    .contains('high');
                                final infectionTint = isHigh
                                    ? AppColors.errorColor
                                    : AppColors.successColor;

                                return Column(
                                  children: [
                                    _TopSummaryCard(
                                      title: caseTitle,
                                      isClosed: isClosed,
                                      daysSince: daysSince,
                                      whqCount: whqCount,
                                      infectionLabel: infectionLabel,
                                      infectionTint: infectionTint,
                                      startDateText:
                                      _formatDate(startValue),
                                    ),
                                    const SizedBox(height: 12),

                                    _GlassSectionCard(
                                      title: "Latest vitals",
                                      child: Column(
                                        children: [
                                          _MetricGlassCard(
                                            label: "Heart Rate",
                                            value: hrText,
                                            unit: "bpm",
                                            badgeText: "", // or keep if you didn't remove badge UI
                                            icon: Icons.favorite_border,
                                            tint: AppColors.errorColor,
                                          ),
                                          const SizedBox(height: 12),

                                          _MetricGlassCard(
                                            label: "Blood Pressure",
                                            value: bpText,
                                            unit: "mmHg",
                                            badgeText: "",
                                            icon: Icons.water_drop_outlined,
                                            tint: AppColors.secondaryColor,
                                          ),
                                          const SizedBox(height: 12),

                                          _MetricGlassCard(
                                            label: "Temperature",
                                            value: tempText,
                                            unit: "°C",
                                            badgeText: "",
                                            icon: Icons.thermostat_outlined,
                                            tint: AppColors.warningColor,
                                          ),
                                        ],
                                      ),
                                    ),

                                    const SizedBox(height: 12),

                                    _GlassSectionCard(
                                      title: "Infection summary",
                                      child: (data == null ||
                                          data.totalAssessments == 0)
                                          ? const SizedBox(height: 8)
                                          : _InfectionDonutCard(
                                        high: data.highCount,
                                        low: data.lowCount,
                                      ),
                                    ),

                                    const SizedBox(height: 12),

                                  ],
                                );
                              },
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

  // ---------------- Case picker ----------------

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
                      final title =
                      _caseTitleFromData(data, fallback: "Untitled wound");
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

  // ---------------- Data loaders ----------------

  Future<_DashboardData> _loadDashboardData({
    required String userId,
    required String caseId,
  }) async {
    final base = FirebaseFirestore.instance
        .collection('users')
        .doc(userId)
        .collection('cases')
        .doc(caseId);

    final candidates = <CollectionReference<Map<String, dynamic>>>[
      base.collection('whqResponses'),
      base.collection('whq'),
      base.collection('whq_logs'),
    ];

    QuerySnapshot<Map<String, dynamic>>? whqSnap;

    for (final col in candidates) {
      try {
        whqSnap = await col.orderBy('createdAt', descending: true).limit(60).get();
        break;
      } catch (_) {
        try {
          whqSnap = await col.orderBy('date', descending: true).limit(60).get();
          break;
        } catch (_) {}
      }
    }

    final docs = whqSnap?.docs ?? [];
    final whqCount = await _countWhq(base);

    _VitalsPoint? latestVitals;
    String latestAssessment = "No data yet";

    int highCount = 0;
    int lowCount = 0;

    int highTempCount = 0;
    int totalTempChecks = 0;

    final List<String> lastResults = [];
    final List<DateTime> checkDates = [];

    for (int i = 0; i < docs.length; i++) {
      final d = docs[i].data();

      final vitals = _asMap(d['vitals']);
      final createdAt = _toDate(d['createdAt'] ?? d['date'] ?? d['timestamp']);

      final heartRate = _asInt(vitals?['heartRate'] ?? vitals?['hr']);
      final temperature = _asDouble(vitals?['temperature'] ?? vitals?['temp']);
      final bpText = (vitals?['bloodPressure'] ?? vitals?['bp']).toString();

      final bpSys = _asDouble(vitals?['bpSys'] ?? vitals?['systolic']);
      final bpDia = _asDouble(vitals?['bpDia'] ?? vitals?['diastolic']);

      if (createdAt != null) checkDates.add(createdAt);

      // High temperature analysis (>= 37.8)
      if (temperature != null && temperature > 0) {
        totalTempChecks++;
        if (temperature >= 37.8) highTempCount++;
      }

      // Parse "120/80" fallback
      double? parsedSys;
      double? parsedDia;
      if (bpText.contains('/')) {
        final parts = bpText.split('/');
        if (parts.length >= 2) {
          parsedSys = double.tryParse(parts[0].trim());
          parsedDia = double.tryParse(parts[1].trim());
        }
      }

      final sVal = (bpSys != null && bpSys > 0)
          ? bpSys
          : (parsedSys != null && parsedSys > 0 ? parsedSys : null);
      final dVal = (bpDia != null && bpDia > 0)
          ? bpDia
          : (parsedDia != null && parsedDia > 0 ? parsedDia : null);

      final assessment = _asMap(d['assessment']) ?? _asMap(d['assessmentResult']);
      final resultRaw =
      (assessment?['result'] ?? d['result'] ?? d['assessmentResult'])
          .toString()
          .trim();
      final result = resultRaw.toLowerCase();

      if (result == 'high') highCount++;
      if (result == 'low') lowCount++;

      if (result == 'high' || result == 'low') {
        lastResults.add(result); // newest -> older
      }

      if (i == 0) {
        latestVitals = _VitalsPoint(
          createdAt: createdAt,
          heartRate: heartRate,
          temperature: temperature,
          bpSys: sVal,
          bpDia: dVal,
          bloodPressureText: bpText.trim(),
        );

        if (result == 'high') latestAssessment = "High sign of infection";
        else if (result == 'low') latestAssessment = "No sign of infection";
        else latestAssessment = "No data yet";
      }
    }

    // Streak calculation (consecutive daily checks) + ignore same-day duplicates
    int streak = 0;
    checkDates.sort((a, b) => b.compareTo(a)); // newest first
    DateTime? prevDay;

    for (final dt in checkDates) {
      final day = DateTime(dt.year, dt.month, dt.day);

      if (prevDay == null) {
        streak = 1;
        prevDay = day;
        continue;
      }

      final diff = prevDay!.difference(day).inDays;

      if (diff == 0) {
        // duplicate same day -> ignore
        continue;
      } else if (diff == 1) {
        streak++;
        prevDay = day;
      } else {
        break;
      }
    }

    final totalAssess = highCount + lowCount;

    return _DashboardData(
      whqCount: whqCount,
      latestVitals: latestVitals,
      latestAssessmentLabel: latestAssessment,
      highCount: highCount,
      lowCount: lowCount,
      totalAssessments: totalAssess,
      highTempCount: highTempCount,
      totalTempChecks: totalTempChecks,
      checkStreak: streak,
      lastResults: lastResults.take(3).toList(),
    );
  }

  Future<int> _countWhq(DocumentReference<Map<String, dynamic>> base) async {
    final q1 = base.collection('whq');
    final q2 = base.collection('whqResponses');
    final q3 = base.collection('whq_logs');

    try {
      final a = await q2.get();
      if (a.size > 0) return a.size;
    } catch (_) {}
    try {
      final a = await q1.get();
      if (a.size > 0) return a.size;
    } catch (_) {}
    try {
      final a = await q3.get();
      return a.size;
    } catch (_) {}

    return 0;
  }
}

/* ===================== DATA MODELS ===================== */

class _DashboardData {
  final int whqCount;

  final _VitalsPoint? latestVitals;
  final String latestAssessmentLabel;

  final int highCount;
  final int lowCount;
  final int totalAssessments;

  final int highTempCount;
  final int totalTempChecks;
  final int checkStreak;
  final List<String> lastResults;

  _DashboardData({
    required this.whqCount,
    required this.latestVitals,
    required this.latestAssessmentLabel,
    required this.highCount,
    required this.lowCount,
    required this.totalAssessments,
    required this.highTempCount,
    required this.totalTempChecks,
    required this.checkStreak,
    required this.lastResults,
  });
}

class _VitalsPoint {
  final DateTime? createdAt;
  final int? heartRate;
  final double? temperature;
  final double? bpSys;
  final double? bpDia;
  final String? bloodPressureText;

  _VitalsPoint({
    required this.createdAt,
    required this.heartRate,
    required this.temperature,
    required this.bpSys,
    required this.bpDia,
    required this.bloodPressureText,
  });
}

/* ===================== TOP SUMMARY ===================== */

class _TopSummaryCard extends StatelessWidget {
  const _TopSummaryCard({
    required this.title,
    required this.isClosed,
    required this.daysSince,
    required this.whqCount,
    required this.infectionLabel,
    required this.infectionTint,
    required this.startDateText,
  });

  final String title;
  final bool isClosed;
  final int? daysSince;
  final int whqCount;

  final String infectionLabel;
  final Color infectionTint;

  final String startDateText;

  @override
  Widget build(BuildContext context) {
    final statusColor = isClosed ? AppColors.textMuted : AppColors.successColor;

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(26),
        color: Colors.white.withOpacity(0.92),
        border: Border.all(color: AppColors.primaryColor.withOpacity(0.10)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 22,
            offset: const Offset(0, 14),
          ),
        ],
      ),
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
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                  ],
                ),
              ),
              _StatusChip(text: isClosed ? "Closed" : "Active", color: statusColor),
            ],
          ),
          const SizedBox(height: 12),
          Divider(height: 1, color: AppColors.dividerColor.withOpacity(0.9)),
          const SizedBox(height: 12),

          Row(
            children: [
              Expanded(
                child: _BigNumberTile(
                  title: "Days since started",
                  value: daysSince == null ? "--" : "$daysSince",
                  suffix: "days",
                  tint: AppColors.primaryColor,
                  onTap: daysSince == null
                      ? null
                      : () => _showDaysInfo(context, daysSince!, startDateText),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _BigNumberTile(
                  title: "WHQ answered",
                  value: "$whqCount",
                  suffix: "checks",
                  tint: AppColors.secondaryColor,
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),

          _AssessmentRow(label: infectionLabel, tint: infectionTint),
        ],
      ),
    );
  }

  void _showDaysInfo(BuildContext context, int days, String startDate) {
    showDialog(
      context: context,
      builder: (_) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "Days since started",
                style: GoogleFonts.dmSans(
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                "Start date: $startDate\n\nYou are on day $days.",
                style: GoogleFonts.inter(
                  fontSize: 13,
                  height: 1.35,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 14),
              Align(
                alignment: Alignment.centerRight,
                child: _WhitePillButton(
                  onTap: () => Navigator.pop(context),
                  child: Text(
                    "OK",
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      fontWeight: FontWeight.w900,
                      color: AppColors.primaryColor,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BigNumberTile extends StatelessWidget {
  const _BigNumberTile({
    required this.title,
    required this.value,
    required this.suffix,
    required this.tint,
    this.onTap,
  });

  final String title;
  final String value;
  final String suffix;
  final Color tint;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(22),
      child: Container(
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
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.inter(
                fontSize: 14,
                fontWeight: FontWeight.w900,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 10),
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  value,
                  style: GoogleFonts.dmSans(
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(width: 6),
                Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Text(
                    suffix,
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      fontWeight: FontWeight.w900,
                      color: AppColors.textMuted,
                    ),
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

class _AssessmentRow extends StatelessWidget {
  const _AssessmentRow({
    required this.label,
    required this.tint,
  });

  final String label;
  final Color tint;

  @override
  Widget build(BuildContext context) {
    final pillText = label.toLowerCase().contains('high') ? "High sign" : "No sign";

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        color: tint.withOpacity(0.08),
        border: Border.all(color: tint.withOpacity(0.18)),
      ),
      child: Row(
        children: [
          _CardIconBadge(tint: tint, icon: Icons.health_and_safety_outlined),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              label,
              style: GoogleFonts.dmSans(
                fontSize: 15.2,
                fontWeight: FontWeight.w900,
                color: AppColors.textPrimary,
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(999),
              color: tint.withOpacity(0.14),
              border: Border.all(color: tint.withOpacity(0.22)),
            ),
            child: Text(
              pillText,
              style: GoogleFonts.inter(
                fontSize: 14,
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

/* ===================== Infection donut card ===================== */

class _InfectionDonutCard extends StatelessWidget {
  const _InfectionDonutCard({
    required this.high,
    required this.low,
  });

  final int high;
  final int low;

  @override
  Widget build(BuildContext context) {
    final total = math.max(1, high + low);
    final highPct = high / total;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        color: AppColors.surfaceColor.withOpacity(0.95),
        border: Border.all(color: AppColors.primaryColor.withOpacity(0.10)),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 120,
            height: 120,
            child: CustomPaint(
              painter: _DonutPainter(
                highPct: highPct,
                colorHigh: AppColors.errorColor,
                colorLow: AppColors.successColor,
              ),
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      "${(highPct * 100).round()}%",
                      style: GoogleFonts.dmSans(
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      "High",
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        fontWeight: FontWeight.w900,
                        color: AppColors.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Counts",
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w900,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 10),
                _LegendLine(color: AppColors.errorColor, title: "High", value: "$high"),
                const SizedBox(height: 8),
                _LegendLine(color: AppColors.successColor, title: "Low", value: "$low"),
                const SizedBox(height: 14),
                Text(
                  "Tip: if you see more High, consider contacting your doctor.",
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    height: 1.35,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textMuted,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _LegendLine extends StatelessWidget {
  const _LegendLine({
    required this.color,
    required this.title,
    required this.value,
  });

  final Color color;
  final String title;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            title,
            style: GoogleFonts.inter(
              fontSize: 14,
              fontWeight: FontWeight.w900,
              color: AppColors.textSecondary,
            ),
          ),
        ),
        Text(
          value,
          style: GoogleFonts.dmSans(
            fontSize: 14.5,
            fontWeight: FontWeight.w900,
            color: AppColors.textPrimary,
          ),
        ),
      ],
    );
  }
}

class _DonutPainter extends CustomPainter {
  _DonutPainter({
    required this.highPct,
    required this.colorHigh,
    required this.colorLow,
  });

  final double highPct;
  final Color colorHigh;
  final Color colorLow;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final r = math.min(size.width, size.height) / 2;

    final bg = Paint()
      ..color = Colors.black.withOpacity(0.06)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 14
      ..strokeCap = StrokeCap.round;

    final lowPaint = Paint()
      ..color = colorLow.withOpacity(0.85)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 14
      ..strokeCap = StrokeCap.round;

    final highPaint = Paint()
      ..color = colorHigh.withOpacity(0.92)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 14
      ..strokeCap = StrokeCap.round;

    canvas.drawCircle(center, r - 10, bg);

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: r - 10),
      -math.pi / 2,
      2 * math.pi,
      false,
      lowPaint,
    );

    final sweep = (2 * math.pi) * highPct.clamp(0.0, 1.0);
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: r - 10),
      -math.pi / 2,
      sweep,
      false,
      highPaint,
    );
  }

  @override
  bool shouldRepaint(covariant _DonutPainter oldDelegate) {
    return oldDelegate.highPct != highPct;
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
          child:
          _Blob(size: 520, color: AppColors.secondaryColor.withOpacity(0.22)),
        ),
        Positioned(
          top: 120,
          right: -180,
          child:
          _Blob(size: 560, color: AppColors.primaryColor.withOpacity(0.10)),
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

/* ===================== UI bits ===================== */

class _AvatarButton extends StatelessWidget {
  const _AvatarButton({
    required this.letter,
    this.imageUrl,
  });

  final String letter;
  final String? imageUrl;

  @override
  Widget build(BuildContext context) {
    return _WhitePill(
      radius: 18,
      padding: EdgeInsets.zero,
      child: SizedBox(
        width: 44,
        height: 44,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(18),
          child: imageUrl != null && imageUrl!.isNotEmpty
              ? Image.network(
            imageUrl!,
            fit: BoxFit.cover,
          )
              : Center(
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
                        fontSize: 16,
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
                        fontSize: 14,
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

class _GlassSectionCard extends StatelessWidget {
  const _GlassSectionCard({
    required this.title,
    required this.child,
  });

  final String title;
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
              fontSize: 20,
              fontWeight: FontWeight.w900,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 4),
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }
}

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
              const SizedBox(width: 12),

              // Left: label
              Expanded(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.dmSans(
                    fontSize: 16, // you’ll change sizes later
                    fontWeight: FontWeight.w900,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),

              const SizedBox(width: 12),

              // Right: value + unit
              Row(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    value,
                    style: GoogleFonts.dmSans(
                      fontSize: 16, // you’ll change sizes later
                      fontWeight: FontWeight.w900,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  if (unit.trim().isNotEmpty) ...[
                    const SizedBox(width: 6),
                    Padding(
                      padding: const EdgeInsets.only(bottom: 2),
                      child: Text(
                        unit,
                        style: GoogleFonts.inter(
                          fontSize: 14, // you’ll change sizes later
                          fontWeight: FontWeight.w800,
                          color: AppColors.textMuted,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),


        ],
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
              fontSize: 14,
              fontWeight: FontWeight.w900,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

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

/* ===================== Helpers ===================== */

int? _daysSince(dynamic startDate) {
  final dt = _toDate(startDate);
  if (dt == null) return null;
  final diff = DateTime.now().difference(dt).inDays + 1;
  return diff < 1 ? 1 : diff;
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

DateTime? _toDate(dynamic value) {
  if (value == null) return null;
  try {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    if (value is String) return DateTime.tryParse(value);
  } catch (_) {}
  return null;
}

Map<String, dynamic>? _asMap(dynamic v) {
  if (v == null) return null;
  if (v is Map<String, dynamic>) return v;
  if (v is Map) return Map<String, dynamic>.from(v);
  return null;
}

int? _asInt(dynamic v) {
  if (v == null) return null;
  if (v is int) return v;
  if (v is num) return v.toInt();
  return int.tryParse(v.toString());
}

double? _asDouble(dynamic v) {
  if (v == null) return null;
  if (v is double) return v;
  if (v is int) return v.toDouble();
  if (v is num) return v.toDouble();
  return double.tryParse(v.toString());
}

String _timeAgoShort(DateTime? dt) {
  if (dt == null) return "—";
  final diff = DateTime.now().difference(dt);
  if (diff.inMinutes < 1) return "Just now";
  if (diff.inMinutes < 60) return "${diff.inMinutes}m ago";
  if (diff.inHours < 24) return "${diff.inHours}h ago";
  return "${diff.inDays}d ago";
}

String _caseTitleFromData(
    Map<String, dynamic> data, {
      required String fallback,
    }) {
  final v = data['title'] ?? data['name'] ?? data['caseTitle'] ?? data['caseName'];
  final s = (v is String) ? v.trim() : '';
  if (s.isNotEmpty) return s;
  return fallback;
}

String _getUserName(
    Map<String, dynamic>? data, {
      required String fallback,
    }) {
  if (data == null) return fallback;
  final v = data['name'] ?? data['username'] ?? data['displayName'];
  final s = (v is String) ? v.trim() : '';
  return s.isNotEmpty ? s : fallback;
}