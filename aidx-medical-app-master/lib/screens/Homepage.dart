// homepage.dart
import 'dart:async';
import 'dart:math' as math;
import 'dart:ui';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../utils/app_colors.dart';
import '../widgets/bottom_nav.dart';
import 'create_case_screen.dart';
import '../services/smart_watch_simulator_service.dart';

class Homepage extends StatefulWidget {
  const Homepage({super.key});

  @override
  State<Homepage> createState() => _HomepageState();
}

class _HomepageState extends State<Homepage> {
  String? _selectedCaseId;

  // ✅ Watch simulator service
  final _watch = SmartWatchSimulatorService.instance;
  StreamSubscription<void>? _watchSub;

  // ✅ small history for charts (local/watch)
  final List<int> _hrHistory = [];
  final List<double> _tempHistory = [];
  final List<double> _bpSysHistory = [];
  final List<double> _bpDiaHistory = [];
  static const int _historyMax = 28;

  @override
  void initState() {
    super.initState();

    // Listen to watch vitals stream and record values for charts
    _watchSub = _watch.vitalsStream.listen((_) {
      _pushVitalsToHistory();
      if (mounted) setState(() {});
    });

    // seed
    _pushVitalsToHistory();
  }

  @override
  void dispose() {
    _watchSub?.cancel();
    super.dispose();
  }

  void _pushVitalsToHistory() {
    _hrHistory.add(_watch.heartRate);
    if (_hrHistory.length > _historyMax) _hrHistory.removeAt(0);

    _tempHistory.add(_watch.temperature);
    if (_tempHistory.length > _historyMax) _tempHistory.removeAt(0);

    final parts = _watch.bloodPressure.split('/');
    double sys = 0, dia = 0;
    if (parts.length == 2) {
      sys = double.tryParse(parts[0].trim()) ?? 0;
      dia = double.tryParse(parts[1].trim()) ?? 0;
    }
    _bpSysHistory.add(sys);
    _bpDiaHistory.add(dia);
    if (_bpSysHistory.length > _historyMax) _bpSysHistory.removeAt(0);
    if (_bpDiaHistory.length > _historyMax) _bpDiaHistory.removeAt(0);
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

                    // Ensure a selected case
                    if (docs.isNotEmpty) {
                      final ids = docs.map((d) => d.id).toList();
                      if (_selectedCaseId == null || !ids.contains(_selectedCaseId)) {
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
                    final status = ((selectedData?['status'] as String?) ?? 'active').toLowerCase();
                    final isClosed = status == 'closed';

                    // Infection assessment
                    final score = selectedData == null ? null : _infectionScore(selectedData);
                    final isHigh = _isHighInfection(score);
                    final assessment = _assessmentLabelSimple(score);

                    // ✅ Force colors: green if no sign, red if high sign
                    final infectionTint = selectedDoc == null
                        ? AppColors.primaryColor
                        : (isHigh ? AppColors.errorColor : AppColors.successColor);

                    // ✅ Watch values
                    final isConnected = _watch.isConnected;
                    final hrText = isConnected ? "${_watch.heartRate}" : "---";
                    final tempText = isConnected ? _watch.temperature.toStringAsFixed(1) : "---";
                    final bpText = isConnected ? _watch.bloodPressure : "--- / ---";

                    return CustomScrollView(
                      slivers: [
                        SliverToBoxAdapter(
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(16, 12, 16, 10),
                            child: Row(
                              children: [
                                _AvatarButton(
                                  letter: (userName.isNotEmpty ? userName.characters.first : "U")
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
                                    subtitle: docs.isEmpty ? "Create a case to start" : (isClosed ? "Closed" : "Active"),
                                    onTap: docs.isEmpty
                                        ? null
                                        : () => _openCasePicker(
                                      context: context,
                                      cases: docs,
                                      selectedId: _selectedCaseId,
                                      onSelect: (id) => setState(() => _selectedCaseId = id),
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
                              title: selectedDoc == null ? "Select a case" : _caseTitleForDoc(selectedDoc, docs),
                              dayLabel: selectedDoc == null
                                  ? "Day --"
                                  : _funDayLabel(daysSince),
                              isClosed: isClosed,
                              isHigh: isHigh,
                              scoreText: score == null ? "--" : score.toString(),
                              assessment: assessment,
                              startDate: _formatDate(startValue),
                              lastUpdated: _formatDate(
                                selectedData?['lastUpdated'] ?? selectedData?['createdAt'],
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

                        // Vitals grid
                        SliverPadding(
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 96),
                          sliver: SliverList(
                            delegate: SliverChildListDelegate(
                              [
                                Row(
                                  children: [
                                    Expanded(
                                      child: _MetricGlassCard(
                                        label: "Heart\nRate",
                                        value: hrText,
                                        unit: "bpm",
                                        badgeText: isConnected ? "Connected" : "Not synced",
                                        icon: Icons.favorite_border,
                                        tint: AppColors.errorColor,
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: _MetricGlassCard(
                                        label: "Blood\nPressure",
                                        value: bpText,
                                        unit: "mmHg",
                                        badgeText: isConnected ? "Connected" : "Not synced",
                                        icon: Icons.water_drop_outlined,
                                        tint: AppColors.secondaryColor,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                Row(
                                  children: [
                                    Expanded(
                                      child: _MetricGlassCard(
                                        label: "Temperature",
                                        value: tempText,
                                        unit: "°C",
                                        badgeText: isConnected ? "Connected" : "Not synced",
                                        icon: Icons.thermostat_outlined,
                                        tint: AppColors.warningColor,
                                      ),
                                    ),
                                    const SizedBox(width: 12),

                                    // ✅ Infection assessment
                                    Expanded(
                                      child: _MetricGlassCard(
                                        label: "Infection\nAssessment",
                                        value: assessment,
                                        unit: "",
                                        badgeText: selectedDoc == null
                                            ? "No case"
                                            : (isHigh ? "High" : "Normal"),
                                        icon: Icons.health_and_safety_outlined,
                                        tint: infectionTint, // ✅ green/red
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),

                                // ✅ Better colorful charts (numbers + legends)
                                _GlassSectionCard(
                                  title: "Your health overview",
                                  subtitle: isConnected
                                      ? "Charts update automatically when your watch is connected."
                                      : "Connect your watch to see live charts. (Firebase charts still work below)",
                                  child: Column(
                                    children: [
                                      _DashboardLineChartCard(
                                        title: "Heart rate",
                                        subtitle: "Last $_historyMax points",
                                        unitRight: "bpm",
                                        valuesA: _hrHistory.map((e) => e.toDouble()).toList(),
                                        valuesB: const [],
                                        colorA: AppColors.errorColor,
                                        colorB: AppColors.secondaryColor,
                                        labelA: "HR",
                                        labelB: "",
                                        emptyHint: "No heart-rate data yet",
                                      ),
                                      const SizedBox(height: 12),
                                      _DashboardLineChartCard(
                                        title: "Temperature",
                                        subtitle: "Last $_historyMax points",
                                        unitRight: "°C",
                                        valuesA: _tempHistory,
                                        valuesB: const [],
                                        colorA: AppColors.warningColor,
                                        colorB: AppColors.secondaryColor,
                                        labelA: "Temp",
                                        labelB: "",
                                        emptyHint: "No temperature data yet",
                                      ),
                                      const SizedBox(height: 12),
                                      _DashboardLineChartCard(
                                        title: "Blood pressure",
                                        subtitle: "SYS / DIA • Last $_historyMax points",
                                        unitRight: "mmHg",
                                        valuesA: _bpSysHistory,
                                        valuesB: _bpDiaHistory,
                                        colorA: AppColors.primaryColor,
                                        colorB: AppColors.secondaryColor,
                                        labelA: "SYS",
                                        labelB: "DIA",
                                        emptyHint: "No BP data yet",
                                      ),
                                    ],
                                  ),
                                ),

                                const SizedBox(height: 12),

                                // ✅ Data science insights from Firebase vitals flags
                                if (selectedDoc != null)
                                  _VitalsInsightsFromFirebaseCard(
                                    userId: user.uid,
                                    caseId: selectedDoc!.id,
                                  )
                                else
                                  _GlassSectionCard(
                                    title: "Vitals insights",
                                    subtitle: "Select a case to see Firebase-based insights.",
                                    child: const SizedBox(height: 8),
                                  ),

                                const SizedBox(height: 12),

                                // ✅ Existing quick insights (WHQ-based)
                                if (selectedDoc != null)
                                  _PatientInsightsCard(
                                    userId: user.uid,
                                    caseId: selectedDoc!.id,
                                    daysSince: daysSince,
                                  )
                                else
                                  _GlassSectionCard(
                                    title: "Quick insights",
                                    subtitle: "Select a case to see your summary.",
                                    child: const SizedBox(height: 8),
                                  ),

                                const SizedBox(height: 12),

                                // ✅ Infection counts chart at the end (No sign vs High sign)
                                if (selectedDoc != null)
                                  _InfectionHistorySummaryCard(
                                    userId: user.uid,
                                    caseId: selectedDoc!.id,
                                  )
                                else
                                  const SizedBox.shrink(),

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
                      final title = _caseTitleFromData(data, fallback: "Untitled wound");
                      final status = ((data['status'] as String?) ?? 'active').toLowerCase();
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
                                tint: isClosed ? AppColors.textMuted : AppColors.primaryColor,
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
                                color: isClosed ? AppColors.textMuted : AppColors.successColor,
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
    return _caseTitleFromData(data, fallback: "Untitled wound");
  }

  static String _caseTitleFromData(
      Map<String, dynamic> data, {
        required String fallback,
      }) {
    final v = data['title'] ?? data['name'] ?? data['caseTitle'] ?? data['caseName'];
    final s = (v is String) ? v.trim() : '';
    if (s.isNotEmpty) return s;
    return fallback;
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
              const Icon(Icons.keyboard_arrow_down_rounded, color: AppColors.primaryColor),
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
    required this.isHigh,
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

  final bool isHigh;
  final String scoreText;
  final String assessment;

  final String startDate;
  final String lastUpdated;

  final Widget? whqCountBuilder;

  @override
  Widget build(BuildContext context) {
    final statusColor = isClosed ? AppColors.textMuted : AppColors.successColor;
    final assessTint = isHigh ? AppColors.errorColor : AppColors.successColor;

    return Opacity(
      opacity: enabled ? 1 : 0.65,
      child: Container(
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
                            fontWeight: FontWeight.w800,
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
                  Expanded(child: _InfoMini(icon: Icons.calendar_today_outlined, label: startDate)),
                  const SizedBox(width: 14),
                  Expanded(child: _InfoMini(icon: Icons.access_time, label: lastUpdated)),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _KpiTile(
                      title: "Infection assessment",
                      value: assessment,
                      pill: isHigh ? "Action needed" : "Looks ok",
                      tint: assessTint,
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
                  fontSize: 18,
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
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
              ),
              if (unit.trim().isNotEmpty) ...[
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
            ],
          ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(999),
              color: tint.withOpacity(0.08),
              border: Border.all(color: tint.withOpacity(0.18)),
            ),
            child: Text(
              badgeText,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
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

/* ===================== DASHBOARD STYLE CHART CARD (colorful + numbers) ===================== */

class _DashboardLineChartCard extends StatelessWidget {
  const _DashboardLineChartCard({
    required this.title,
    required this.subtitle,
    required this.valuesA,
    required this.valuesB,
    required this.colorA,
    required this.colorB,
    required this.labelA,
    required this.labelB,
    required this.emptyHint,
    required this.unitRight,
  });

  final String title;
  final String subtitle;
  final List<double> valuesA;
  final List<double> valuesB;
  final Color colorA;
  final Color colorB;
  final String labelA;
  final String labelB;
  final String emptyHint;
  final String unitRight;

  bool _hasData(List<double> v) => v.where((x) => x != 0).isNotEmpty && v.length >= 3;

  @override
  Widget build(BuildContext context) {
    final aOk = _hasData(valuesA);
    final bOk = valuesB.isNotEmpty ? _hasData(valuesB) : false;
    final hasData = aOk || bOk;

    final all = <double>[
      ...valuesA.where((e) => e != 0),
      ...valuesB.where((e) => e != 0),
    ];
    final minV = all.isEmpty ? 0.0 : all.reduce(math.min);
    final maxV = all.isEmpty ? 1.0 : all.reduce(math.max);

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
              const Icon(Icons.show_chart_rounded, color: AppColors.primaryColor, size: 18),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: GoogleFonts.inter(
                    fontSize: 13.2,
                    fontWeight: FontWeight.w900,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
              Text(
                unitRight,
                style: GoogleFonts.inter(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w900,
                  color: AppColors.textMuted,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: GoogleFonts.inter(
              fontSize: 12.2,
              fontWeight: FontWeight.w700,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 10),
          Container(
            height: 120,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              color: Colors.white.withOpacity(0.90),
              border: Border.all(color: AppColors.dividerColor.withOpacity(0.9)),
            ),
            child: hasData
                ? Stack(
              children: [
                Positioned.fill(
                  child: CustomPaint(
                    painter: _DashboardLinePainter(
                      a: valuesA,
                      b: valuesB,
                      colorA: colorA,
                      colorB: colorB,
                    ),
                  ),
                ),
                Positioned(
                  left: 10,
                  top: 8,
                  child: Text(
                    "max: ${maxV.toStringAsFixed(1)}",
                    style: GoogleFonts.inter(
                      fontSize: 11.0,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textMuted,
                    ),
                  ),
                ),
                Positioned(
                  left: 10,
                  bottom: 8,
                  child: Text(
                    "min: ${minV.toStringAsFixed(1)}",
                    style: GoogleFonts.inter(
                      fontSize: 11.0,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textMuted,
                    ),
                  ),
                ),
              ],
            )
                : Center(
              child: Text(
                emptyHint,
                style: GoogleFonts.inter(
                  fontSize: 12.2,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textMuted,
                ),
              ),
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              _LegendDot(color: colorA, text: labelA.isEmpty ? "A" : labelA),
              if (valuesB.isNotEmpty) ...[
                const SizedBox(width: 10),
                _LegendDot(color: colorB, text: labelB.isEmpty ? "B" : labelB),
              ],
              const Spacer(),
              Text(
                "trend",
                style: GoogleFonts.inter(
                  fontSize: 11.2,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textMuted,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _LegendDot extends StatelessWidget {
  const _LegendDot({required this.color, required this.text});
  final Color color;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 9,
          height: 9,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text(
          text,
          style: GoogleFonts.inter(
            fontSize: 11.4,
            fontWeight: FontWeight.w900,
            color: AppColors.textSecondary,
          ),
        ),
      ],
    );
  }
}

class _DashboardLinePainter extends CustomPainter {
  _DashboardLinePainter({
    required this.a,
    required this.b,
    required this.colorA,
    required this.colorB,
  });

  final List<double> a;
  final List<double> b;
  final Color colorA;
  final Color colorB;

  @override
  void paint(Canvas canvas, Size size) {
    // dotted background grid
    final dotPaint = Paint()..color = Colors.black.withOpacity(0.045);
    for (double x = 10; x < size.width; x += 22) {
      for (double y = 10; y < size.height; y += 22) {
        canvas.drawCircle(Offset(x, y), 1.35, dotPaint);
      }
    }

    if (a.length < 2) return;

    final all = <double>[
      ...a.where((e) => e != 0),
      ...b.where((e) => e != 0),
    ];
    if (all.isEmpty) return;

    final minV = all.reduce(math.min);
    final maxV = all.reduce(math.max);
    final range = (maxV - minV).abs() < 1e-6 ? 1.0 : (maxV - minV);

    Offset mapPoint(int i, List<double> values) {
      final x = (i / (values.length - 1)) * (size.width - 20) + 10;
      final norm = (values[i] - minV) / range;
      final y = (1 - norm) * (size.height - 24) + 12;
      return Offset(x, y);
    }

    void drawSeries(List<double> values, Color c) {
      if (values.length < 2) return;
      final pts = <Offset>[];
      for (int i = 0; i < values.length; i++) {
        pts.add(mapPoint(i, values));
      }

      // fill under curve (soft)
      final fill = Paint()
        ..color = c.withOpacity(0.10)
        ..style = PaintingStyle.fill;

      final fillPath = Path()
        ..moveTo(pts.first.dx, size.height - 12)
        ..lineTo(pts.first.dx, pts.first.dy);
      for (int i = 1; i < pts.length; i++) {
        fillPath.lineTo(pts[i].dx, pts[i].dy);
      }
      fillPath.lineTo(pts.last.dx, size.height - 12);
      fillPath.close();

      canvas.drawPath(fillPath, fill);

      final stroke = Paint()
        ..color = c.withOpacity(0.95)
        ..strokeWidth = 3.0
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round;

      final path = Path()..moveTo(pts.first.dx, pts.first.dy);
      for (int i = 1; i < pts.length; i++) {
        path.lineTo(pts[i].dx, pts[i].dy);
      }
      canvas.drawPath(path, stroke);

      // last-point marker
      canvas.drawCircle(pts.last, 4.2, Paint()..color = c.withOpacity(0.95));
      canvas.drawCircle(pts.last, 8.0, Paint()..color = c.withOpacity(0.12));
    }

    drawSeries(a, colorA);
    if (b.isNotEmpty) drawSeries(b, colorB);
  }

  @override
  bool shouldRepaint(covariant _DashboardLinePainter oldDelegate) {
    return oldDelegate.a != a || oldDelegate.b != b;
  }
}

/* ===================== Data-science insights from Firebase vitals flags ===================== */

class _VitalsInsightsFromFirebaseCard extends StatelessWidget {
  const _VitalsInsightsFromFirebaseCard({
    required this.userId,
    required this.caseId,
  });

  final String userId;
  final String caseId;

  bool _truthy(dynamic v) {
    if (v is bool) return v;
    if (v is num) return v != 0;
    final s = (v ?? '').toString().trim().toLowerCase();
    return s == 'true' || s == 'yes' || s == '1';
  }

  int _asInt(dynamic v) => (v is int) ? v : int.tryParse('$v') ?? 0;

  @override
  Widget build(BuildContext context) {
    final base = FirebaseFirestore.instance
        .collection('users')
        .doc(userId)
        .collection('cases')
        .doc(caseId);

    return FutureBuilder<Map<String, dynamic>>(
      future: () async {
        // We will try multiple collections (because schema might differ)
        final candidates = <CollectionReference<Map<String, dynamic>>>[
          base.collection('vitals'),
          base.collection('vitalsLogs'),
          base.collection('watchVitals'),
          base.collection('smartwatchVitals'),
        ];
        QuerySnapshot<Map<String, dynamic>>? snap;

        for (final col in candidates) {
          try {
            snap = await col.orderBy('createdAt', descending: true).limit(30).get();
            break;
          } catch (_) {
            // try next
          }
        }

        if (snap == null) {
          // couldn’t read any collection
          return {
            'total': 0,
            'highTempCount': 0,
            'highHrCount': 0,
            'highBpCount': 0,
            'last3N': 0,
            'last3HighTemp': 0,
          };
        }

        final docs = snap.docs.map((d) => d.data()).toList();

        // flags: 0 ok, 1 high (as you said)
        int highTempCount = 0;
        int highHrCount = 0;
        int highBpCount = 0;

        // last 3 summary
        int last3HighTemp = 0;
        int last3N = math.min(3, docs.length);

        for (int i = 0; i < docs.length; i++) {
          final d = docs[i];

          // try common names
          final tempFlag = d['tempFlag'] ?? d['temperatureFlag'] ?? d['highTempFlag'] ?? d['feverFlag'] ?? d['fever'];
          final hrFlag = d['hrFlag'] ?? d['heartRateFlag'] ?? d['highHrFlag'];
          final bpFlag = d['bpFlag'] ?? d['bloodPressureFlag'] ?? d['highBpFlag'];

          if (_truthy(tempFlag) || _asInt(tempFlag) == 1) highTempCount++;
          if (_truthy(hrFlag) || _asInt(hrFlag) == 1) highHrCount++;
          if (_truthy(bpFlag) || _asInt(bpFlag) == 1) highBpCount++;

          if (i < 3) {
            if (_truthy(tempFlag) || _asInt(tempFlag) == 1) last3HighTemp++;
          }
        }

        return {
          'total': docs.length,
          'highTempCount': highTempCount,
          'highHrCount': highHrCount,
          'highBpCount': highBpCount,
          'last3N': last3N,
          'last3HighTemp': last3HighTemp,
        };
      }(),
      builder: (context, snap) {
        final data = snap.data;

        final total = data?['total'] as int? ?? 0;
        final highTempCount = data?['highTempCount'] as int? ?? 0;
        final highHrCount = data?['highHrCount'] as int? ?? 0;
        final highBpCount = data?['highBpCount'] as int? ?? 0;

        final last3N = data?['last3N'] as int? ?? 0;
        final last3HighTemp = data?['last3HighTemp'] as int? ?? 0;

        final subtitle = total == 0
            ? "No vitals logs found yet in Firebase."
            : "Based on last $total vitals logs in Firebase.";

        return _GlassSectionCard(
          title: "Vitals insights (Firebase)",
          subtitle: subtitle,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _InsightRow(
                icon: Icons.local_fire_department_outlined,
                title: "High fever flag",
                value: total == 0 ? "--" : "$highTempCount / $total readings",
              ),
              const SizedBox(height: 10),
              _InsightRow(
                icon: Icons.favorite_outline,
                title: "High heart-rate flag",
                value: total == 0 ? "--" : "$highHrCount / $total readings",
              ),
              const SizedBox(height: 10),
              _InsightRow(
                icon: Icons.water_drop_outlined,
                title: "High blood-pressure flag",
                value: total == 0 ? "--" : "$highBpCount / $total readings",
              ),
              const SizedBox(height: 14),
              Text(
                last3N == 0
                    ? "Tip: once vitals are stored, you’ll see “2/3 had high fever” here."
                    : "Recent summary: $last3HighTemp / $last3N had high fever",
                style: GoogleFonts.inter(
                  fontSize: 12.8,
                  fontWeight: FontWeight.w900,
                  color: (last3N > 0 && last3HighTemp >= 2)
                      ? AppColors.errorColor
                      : AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 10),
              _MiniBar(
                value: highTempCount,
                max: math.max(1, total),
                label: total == 0 ? "--" : "${((highTempCount / total) * 100).round()}% high temp",
              ),
            ],
          ),
        );
      },
    );
  }
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

/* ===================== Existing WHQ insights card ===================== */

class _PatientInsightsCard extends StatelessWidget {
  const _PatientInsightsCard({
    required this.userId,
    required this.caseId,
    required this.daysSince,
  });

  final String userId;
  final String caseId;
  final int? daysSince;

  bool _truthy(dynamic v) {
    if (v is bool) return v;
    if (v is num) return v != 0;
    final s = (v ?? '').toString().trim().toLowerCase();
    return s == 'true' || s == 'yes' || s == '1';
  }

  int _asInt(dynamic v) => (v is int) ? v : int.tryParse('$v') ?? 0;

  @override
  Widget build(BuildContext context) {
    final base = FirebaseFirestore.instance
        .collection('users')
        .doc(userId)
        .collection('cases')
        .doc(caseId);

    return FutureBuilder<Map<String, dynamic>>(
      future: () async {
        // last 3 WHQ
        QuerySnapshot<Map<String, dynamic>> whqSnap;
        try {
          whqSnap = await base.collection('whq').orderBy('createdAt', descending: true).limit(3).get();
        } catch (_) {
          whqSnap = await base.collection('whqResponses').orderBy('createdAt', descending: true).limit(3).get();
        }

        final whqDocs = whqSnap.docs.map((d) => d.data()).toList();

        int rednessCount = 0;
        int dischargeCount = 0;
        int feverCount = 0;

        for (final w in whqDocs) {
          if (_truthy(w['redness'] ?? w['hasRedness'] ?? w['erythema'])) rednessCount++;
          if (_truthy(w['discharge'] ?? w['hasDischarge'] ?? w['exudate'])) dischargeCount++;
          if (_truthy(w['fever'] ?? w['hasFever'])) feverCount++;
        }

        // high infection days from infectionScores history
        int highDays = 0;
        try {
          final scoreSnap = await base.collection('infectionScores').orderBy('date', descending: true).limit(30).get();
          for (final d in scoreSnap.docs) {
            final s = _asInt(d.data()['score'] ?? d.data()['infectionScore']);
            if (s >= 4) highDays++;
          }
        } catch (_) {
          final caseDoc = await base.get();
          final s = _asInt(caseDoc.data()?['infectionScore']);
          highDays = (s >= 4) ? 1 : 0;
        }

        return {
          'whqCount': whqDocs.length,
          'rednessCount': rednessCount,
          'dischargeCount': dischargeCount,
          'feverCount': feverCount,
          'highDays': highDays,
        };
      }(),
      builder: (context, snap) {
        final data = snap.data;
        final whqCount = data?['whqCount'] as int? ?? 0;

        final redness = data?['rednessCount'] as int? ?? 0;
        final discharge = data?['dischargeCount'] as int? ?? 0;
        final fever = data?['feverCount'] as int? ?? 0;

        final highDays = data?['highDays'] as int? ?? 0;

        return _GlassSectionCard(
          title: "Quick insights",
          subtitle: "Simple summary based on your recent answers.",
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _InsightRow(
                icon: Icons.calendar_month_rounded,
                title: "Days since start",
                value: daysSince == null ? "--" : "$daysSince days",
              ),
              const SizedBox(height: 10),
              _InsightRow(
                icon: Icons.fact_check_outlined,
                title: "Last 3 WHQ checks",
                value: whqCount == 0
                    ? "No WHQ submitted yet"
                    : "Redness: $redness/$whqCount • Discharge: $discharge/$whqCount • Fever: $fever/$whqCount",
              ),
              const SizedBox(height: 14),
              Text(
                "High sign of infection (score ≥ 4) — last 30 entries",
                style: GoogleFonts.inter(
                  fontSize: 12.6,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 10),
              _MiniBar(value: highDays, max: 30, label: "$highDays days"),
            ],
          ),
        );
      },
    );
  }
}

class _MiniBar extends StatelessWidget {
  const _MiniBar({required this.value, required this.max, required this.label});
  final int value;
  final int max;
  final String label;

  @override
  Widget build(BuildContext context) {
    final v = value.clamp(0, max);
    final pct = max == 0 ? 0.0 : (v / max);

    return Container(
      height: 44,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: Colors.white.withOpacity(0.90),
        border: Border.all(color: AppColors.dividerColor.withOpacity(0.9)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Row(
        children: [
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(999),
              child: LinearProgressIndicator(
                value: pct,
                minHeight: 10,
                backgroundColor: Colors.black.withOpacity(0.06),
                color: pct >= (4 / 30) ? AppColors.errorColor : AppColors.successColor,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 12.5,
              fontWeight: FontWeight.w900,
              color: AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}

/* ===================== Infection summary chart (No sign vs High sign) ===================== */

class _InfectionHistorySummaryCard extends StatelessWidget {
  const _InfectionHistorySummaryCard({
    required this.userId,
    required this.caseId,
  });

  final String userId;
  final String caseId;

  int _asInt(dynamic v) => (v is int) ? v : int.tryParse('$v') ?? 0;

  @override
  Widget build(BuildContext context) {
    final base = FirebaseFirestore.instance
        .collection('users')
        .doc(userId)
        .collection('cases')
        .doc(caseId);

    return FutureBuilder<Map<String, dynamic>>(
      future: () async {
        // prefer infectionScores history
        int high = 0;
        int normal = 0;
        final scores = <int>[];

        try {
          final snap = await base.collection('infectionScores').orderBy('date', descending: true).limit(30).get();
          for (final d in snap.docs) {
            final s = _asInt(d.data()['score'] ?? d.data()['infectionScore']);
            scores.add(s);
            if (s >= 4) {
              high++;
            } else {
              normal++;
            }
          }
        } catch (_) {
          // fallback: use current infectionScore only
          final doc = await base.get();
          final s = _asInt(doc.data()?['infectionScore']);
          scores.add(s);
          if (s >= 4) {
            high = 1;
          } else {
            normal = 1;
          }
        }

        return {
          'high': high,
          'normal': normal,
          'scores': scores.reversed.toList(), // oldest -> newest
        };
      }(),
      builder: (context, snap) {
        final data = snap.data;
        final high = data?['high'] as int? ?? 0;
        final normal = data?['normal'] as int? ?? 0;
        final scores = (data?['scores'] as List<dynamic>?)?.map((e) => (e as int)).toList() ?? <int>[];

        final total = high + normal;
        final subtitle = total == 0 ? "No infection history found yet." : "Last $total entries";

        return _GlassSectionCard(
          title: "Infection trend summary",
          subtitle: subtitle,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                height: 120,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(18),
                  color: Colors.white.withOpacity(0.90),
                  border: Border.all(color: AppColors.dividerColor.withOpacity(0.9)),
                ),
                child: CustomPaint(
                  painter: _NoHighBarPainter(
                    normal: normal,
                    high: high,
                    colorNormal: AppColors.successColor,
                    colorHigh: AppColors.errorColor,
                  ),
                  child: const SizedBox.expand(),
                ),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  _LegendDot(color: AppColors.successColor, text: "No sign"),
                  const SizedBox(width: 12),
                  _LegendDot(color: AppColors.errorColor, text: "High sign"),
                  const Spacer(),
                  Text(
                    total == 0 ? "--" : "${((high / total) * 100).round()}% high",
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight: FontWeight.w900,
                      color: (total > 0 && (high / total) >= 0.4)
                          ? AppColors.errorColor
                          : AppColors.textMuted,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              if (scores.length >= 3)
                _DashboardLineChartCard(
                  title: "Infection score over time",
                  subtitle: "Older → Newer",
                  unitRight: "score",
                  valuesA: scores.map((e) => e.toDouble()).toList(),
                  valuesB: const [],
                  colorA: AppColors.primaryColor,
                  colorB: AppColors.secondaryColor,
                  labelA: "Score",
                  labelB: "",
                  emptyHint: "No score data",
                )
              else
                Text(
                  "Add more entries to see score trend line.",
                  style: GoogleFonts.inter(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textMuted,
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

class _NoHighBarPainter extends CustomPainter {
  _NoHighBarPainter({
    required this.normal,
    required this.high,
    required this.colorNormal,
    required this.colorHigh,
  });

  final int normal;
  final int high;
  final Color colorNormal;
  final Color colorHigh;

  @override
  void paint(Canvas canvas, Size size) {
    final total = math.max(1, normal + high);

    // grid
    final grid = Paint()..color = Colors.black.withOpacity(0.05);
    for (double y = 14; y < size.height; y += 22) {
      canvas.drawLine(Offset(12, y), Offset(size.width - 12, y), grid);
    }

    final barW = (size.width - 36) / 2;
    final maxH = size.height - 26;

    final normalH = (normal / total) * maxH;
    final highH = (high / total) * maxH;

    final r = Radius.circular(16);

    Rect rectNormal = Rect.fromLTWH(12, size.height - 12 - normalH, barW, normalH);
    Rect rectHigh = Rect.fromLTWH(24 + barW, size.height - 12 - highH, barW, highH);

    final paintN = Paint()..color = colorNormal.withOpacity(0.95);
    final paintH = Paint()..color = colorHigh.withOpacity(0.95);

    canvas.drawRRect(RRect.fromRectAndRadius(rectNormal, r), paintN);
    canvas.drawRRect(RRect.fromRectAndRadius(rectHigh, r), paintH);

    // labels
    final tp = (String s) => TextPainter(
      text: TextSpan(
        text: s,
        style: GoogleFonts.inter(
          fontSize: 12,
          fontWeight: FontWeight.w900,
          color: AppColors.textPrimary,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();

    final t1 = tp("No sign\n$normal");
    t1.paint(canvas, Offset(12 + 8, size.height - 12 - normalH + 10));

    final t2 = tp("High sign\n$high");
    t2.paint(canvas, Offset(24 + barW + 8, size.height - 12 - highH + 10));
  }

  @override
  bool shouldRepaint(covariant _NoHighBarPainter oldDelegate) {
    return oldDelegate.normal != normal || oldDelegate.high != high;
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
  final raw = data['infectionScore'] ?? data['score'];
  if (raw is int) return raw;
  return int.tryParse('$raw') ?? 0;
}

bool _isHighInfection(int? score) => (score ?? 0) >= 4;

String _assessmentLabelSimple(int? score) {
  if (score == null) return "No data yet";
  return _isHighInfection(score) ? "High sign of infection" : "No sign of infection";
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

String _funDayLabel(int? daysSince) {
  if (daysSince == null) return "Day --";
  if (daysSince <= 3) return "Day $daysSince • 🌱";
  if (daysSince <= 7) return "Day $daysSince • ✨";
  if (daysSince <= 14) return "Day $daysSince • 💪";
  if (daysSince <= 30) return "Day $daysSince • 🌟";
  return "Day $daysSince • 🏁";
}