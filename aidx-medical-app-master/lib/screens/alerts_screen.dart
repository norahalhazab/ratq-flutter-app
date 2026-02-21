import 'dart:async';
import 'dart:convert';
import 'dart:ui';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../utils/app_colors.dart';
import '../widgets/bottom_nav.dart';
import 'case_details_screen.dart';

// ---------------- prefs model (same as settings) ----------------

class CaseWhqReminder {
  final String id;
  final String caseId;
  final String caseTitle;
  final int hour;
  final int minute;
  final bool enabled;

  const CaseWhqReminder({
    required this.id,
    required this.caseId,
    required this.caseTitle,
    required this.hour,
    required this.minute,
    required this.enabled,
  });

  TimeOfDay get time => TimeOfDay(hour: hour, minute: minute);

  static CaseWhqReminder fromJson(Map<String, dynamic> j) {
    return CaseWhqReminder(
      id: (j['id'] ?? '').toString(),
      caseId: (j['caseId'] ?? '').toString(),
      caseTitle: (j['caseTitle'] ?? 'Case').toString(),
      hour: (j['hour'] is int) ? j['hour'] as int : int.tryParse('${j['hour']}') ?? 20,
      minute:
      (j['minute'] is int) ? j['minute'] as int : int.tryParse('${j['minute']}') ?? 0,
      enabled: (j['enabled'] as bool?) ?? true,
    );
  }
}

class AlertsScreen extends StatefulWidget {
  const AlertsScreen({super.key});

  @override
  State<AlertsScreen> createState() => _AlertsScreenState();
}

class _AlertsScreenState extends State<AlertsScreen> {
  static const double _navBarHeight = 78;

  final _auth = FirebaseAuth.instance;
  final _firestore = FirebaseFirestore.instance;

  // dismissed cards
  final Set<String> _dismissedKeys = {};

  bool _loadingPrefs = true;
  String? _error;

  StreamSubscription? _sub;
  List<_AlertItem> _items = [];

  // ✅ read reminders from prefs (per case)
  final List<CaseWhqReminder> _reminders = [];

  // prefs keys
  static const _prefsKeyDismissed = 'alerts_dismissed_keys';
  static const _prefsKeyReminders = 'case_whq_reminders_v1';

  @override
  void initState() {
    super.initState();
    _init();
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  Future<void> _init() async {
    await _loadPrefs();
    _listen();
  }

  Future<void> _loadPrefs() async {
    final prefs = await SharedPreferences.getInstance();

    final dismissed = prefs.getStringList(_prefsKeyDismissed) ?? <String>[];

    // load reminders list
    final raw = prefs.getString(_prefsKeyReminders);
    final parsed = <CaseWhqReminder>[];
    if (raw != null && raw.trim().isNotEmpty) {
      try {
        final list = jsonDecode(raw) as List<dynamic>;
        for (final e in list) {
          parsed.add(CaseWhqReminder.fromJson(Map<String, dynamic>.from(e as Map)));
        }
      } catch (_) {}
    }

    if (!mounted) return;
    setState(() {
      _dismissedKeys
        ..clear()
        ..addAll(dismissed);
      _reminders
        ..clear()
        ..addAll(parsed.where((r) => r.enabled));
      _loadingPrefs = false;
    });
  }

  Future<void> _savePrefs() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_prefsKeyDismissed, _dismissedKeys.toList());
  }

  Future<void> _dismiss(String key) async {
    setState(() => _dismissedKeys.add(key));
    await _savePrefs();
  }

  void _listen() {
    _sub?.cancel();

    final user = _auth.currentUser;
    if (user == null) {
      setState(() {
        _error = null;
        _items = _buildWithWhqRows([]);
      });
      return;
    }

    // Stream cases ordered by lastUpdated
    final casesRef = _firestore
        .collection('users')
        .doc(user.uid)
        .collection('cases')
        .orderBy('lastUpdated', descending: true);

    _sub = casesRef.snapshots().listen((snap) {
      final infectionAlerts = <_AlertItem>[];

      for (final d in snap.docs) {
        final data = d.data();

        final caseTitle = _readCaseTitle(data);

        // score priority: finalScore else infectionScore
        final finalScore = _readInt(data['finalScore']);
        final infectionScore = _readInt(data['infectionScore']);
        final score = (finalScore != null && finalScore > 0) ? finalScore : (infectionScore ?? 0);

        // threshold
        if (score < 4) continue;

        final dt = _readDate(data['lastUpdated']) ??
            _readDate(data['createdAt']) ??
            _readDate(data['startDate']) ??
            DateTime.now();

        final key = 'infection:${d.id}';
        if (_dismissedKeys.contains(key)) continue;

        final infectionText = (score >= 6) ? "High sign of infection" : "Warning sign of infection";

        infectionAlerts.add(
          _AlertItem(
            keyId: key,
            type: _AlertType.infection,
            title: "Infection Risk Detected",
            subtitle: "Case: $caseTitle • Please seek medical advice promptly.",
            actionText: "Go to $caseTitle",
            date: dt,
            payload: d.id, // caseId
            caseTitle: caseTitle,
            score: score,
            severityText: infectionText,
          ),
        );
      }

      // newest first
      infectionAlerts.sort((a, b) => b.date.compareTo(a.date));

      if (!mounted) return;
      setState(() {
        _error = null;
        _items = _buildWithWhqRows(infectionAlerts);
      });
    }, onError: (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _items = _buildWithWhqRows([]);
      });
    });
  }

  // ✅ Insert WHQ reminder cards (per case, from prefs).
  // Each reminder appears daily; swipe dismiss hides it for today only.
  List<_AlertItem> _buildWithWhqRows(List<_AlertItem> infection) {
    final list = <_AlertItem>[...infection];

    final today = DateFormat('yyyy-MM-dd').format(DateTime.now());

    // Put all enabled reminders at top, sorted by time
    final remindersSorted = [..._reminders]
      ..sort((a, b) => (a.hour * 60 + a.minute).compareTo(b.hour * 60 + b.minute));

    for (final r in remindersSorted.reversed) {
      final key = 'whqcase:${r.id}:$today';
      if (_dismissedKeys.contains(key)) continue;

      // Insert at top (reverse loop keeps sorted order)
      list.insert(
        0,
        _AlertItem(
          keyId: key,
          type: _AlertType.whq,
          title: "Daily WHQ Reminder",
          subtitle: "Case: ${r.caseTitle}",
          actionText: "Open ${r.caseTitle}",
          date: DateTime.now(),
          payload: r.caseId, // ✅ caseId (so tap opens case details)
          caseTitle: r.caseTitle,
          score: 0,
          severityText: "Scheduled at ${r.time.format(context)}",
        ),
      );
    }

    return list;
  }

  @override
  Widget build(BuildContext context) {
    final user = _auth.currentUser;

    return Scaffold(
      backgroundColor: AppColors.backgroundColor,
      bottomNavigationBar: AppBottomNav(
        currentIndex: 3,
        onNewTap: () {},
      ),
      body: Stack(
        children: [
          const _BlueGlassyBackground(),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 12 + _navBarHeight),
              child: _loadingPrefs
                  ? const Center(child: CircularProgressIndicator())
                  : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 8),
                  Text(
                    "Alert & Notifications",
                    style: GoogleFonts.dmSans(
                      fontSize: 24,
                      fontWeight: FontWeight.w900,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    "Important updates about your wound healing",
                    style: GoogleFonts.inter(
                      fontSize: 13.2,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 14),

                  Expanded(
                    child: (user == null)
                        ? _emptyState()
                        : (_error != null)
                        ? _errorState(_error!)
                        : (_items.isEmpty ? _emptyState() : _list()),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _list() {
    return ListView.separated(
      itemCount: _items.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (context, i) {
        final item = _items[i];

        return Dismissible(
          key: ValueKey(item.keyId),
          direction: DismissDirection.endToStart,
          background: Container(
            alignment: Alignment.centerRight,
            padding: const EdgeInsets.only(right: 18),
            decoration: BoxDecoration(
              color: const Color(0xFFE53935),
              borderRadius: BorderRadius.circular(18),
            ),
            child: const Icon(Icons.delete, color: Colors.white),
          ),
          onDismissed: (_) => _dismiss(item.keyId),
          child: _NotificationCard(
            item: item,
            onTap: () {
              // ✅ Both WHQ + Infection open Case Details
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => CaseDetailsScreen(caseId: item.payload),
                ),
              );
            },
          ),
        );
      },
    );
  }

  Widget _emptyState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.notifications_none_rounded,
            size: 36,
            color: AppColors.textPrimary.withOpacity(0.85),
          ),
          const SizedBox(height: 16),
          Text(
            "No Notifications Yet",
            style: GoogleFonts.inter(
              fontSize: 14.5,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            "You’ll be notified here once there’s\nsomething new.",
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
              fontSize: 13,
              height: 1.4,
              fontWeight: FontWeight.w600,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _errorState(String msg) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10),
        child: Text(
          "Failed to load alerts.\n\n$msg",
          textAlign: TextAlign.center,
          style: GoogleFonts.inter(
            fontSize: 12.8,
            height: 1.35,
            color: AppColors.textSecondary,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }

  // ---------------- Helpers ----------------

  String _readCaseTitle(Map<String, dynamic> data) {
    // same priority idea as your CaseDetailsScreen
    final raw = (data['caseName'] ?? data['title'] ?? '').toString().trim();
    if (raw.isNotEmpty) return raw;

    final fallbackNo = _readInt(data['caseNumber']) ?? _readInt(data['caseNo']) ?? 0;
    if (fallbackNo > 0) return "Wound $fallbackNo";

    return 'Wound case';
  }

  int? _readInt(dynamic v) {
    if (v == null) return null;
    if (v is int) return v;
    if (v is num) return v.toInt();
    return int.tryParse(v.toString());
  }

  DateTime? _readDate(dynamic v) {
    if (v == null) return null;
    if (v is Timestamp) return v.toDate();
    if (v is DateTime) return v;
    if (v is String) return DateTime.tryParse(v);
    return null;
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
          child: _Blob(size: 520, color: AppColors.secondaryColor.withOpacity(0.22)),
        ),
        Positioned(
          top: 120,
          right: -180,
          child: _Blob(size: 560, color: AppColors.primaryColor.withOpacity(0.10)),
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

/* ===================== Card UI ===================== */

enum _AlertType { infection, whq }

class _AlertItem {
  final String keyId;
  final _AlertType type;
  final String title;
  final String subtitle;
  final String actionText;
  final DateTime date;
  final String payload; // ✅ ALWAYS caseId now
  final String caseTitle;
  final int score;
  final String severityText;

  _AlertItem({
    required this.keyId,
    required this.type,
    required this.title,
    required this.subtitle,
    required this.actionText,
    required this.date,
    required this.payload,
    required this.caseTitle,
    required this.score,
    required this.severityText,
  });
}

class _NotificationCard extends StatelessWidget {
  const _NotificationCard({required this.item, required this.onTap});

  final _AlertItem item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isInfection = item.type == _AlertType.infection;

    final iconTint = isInfection ? AppColors.errorColor : AppColors.primaryColor;
    final icon = isInfection ? Icons.warning_rounded : Icons.assignment_rounded;

    final Color chipColor = !isInfection
        ? AppColors.primaryColor
        : (item.score >= 6 ? AppColors.errorColor : AppColors.warningColor);

    final dateText = DateFormat('yyyy-MM-dd').format(item.date);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(22),
      child: Container(
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
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _IconBadge(tint: iconTint, icon: icon),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.title,
                    style: GoogleFonts.dmSans(
                      fontSize: 15.5,
                      fontWeight: FontWeight.w900,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    item.subtitle,
                    style: GoogleFonts.inter(
                      fontSize: 12.6,
                      height: 1.35,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          item.actionText,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.inter(
                            fontSize: 12.6,
                            fontWeight: FontWeight.w800,
                            color: AppColors.primaryColor,
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(999),
                          color: chipColor.withOpacity(0.10),
                          border: Border.all(color: chipColor.withOpacity(0.22)),
                        ),
                        child: Text(
                          item.severityText,
                          style: GoogleFonts.inter(
                            fontSize: 11.6,
                            fontWeight: FontWeight.w900,
                            color: chipColor,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Text(
              dateText,
              style: GoogleFonts.inter(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: AppColors.textMuted,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _IconBadge extends StatelessWidget {
  const _IconBadge({required this.tint, required this.icon});
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