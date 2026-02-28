// alerts_screen.dart
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

class AlertsScreen extends StatefulWidget {
  const AlertsScreen({super.key});

  @override
  State<AlertsScreen> createState() => _AlertsScreenState();
}

class _AlertsScreenState extends State<AlertsScreen> {
  static const double _navBarHeight = 78;

  final _auth = FirebaseAuth.instance;
  final _firestore = FirebaseFirestore.instance;

  final Set<String> _dismissedKeys = {};

  bool _loadingPrefs = true;
  bool _loadingReminders = true;
  String? _error;

  StreamSubscription? _sub;
  List<_AlertItem> _items = [];

  static const _prefsKeyDismissed = 'alerts_dismissed_keys';
  static String _reminderPrefsKey(String caseId) => 'whq_reminder_case_$caseId';

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
    await _loadDismissedPrefs();
    _listenCasesAndBuildReminders();
  }

  Future<void> _loadDismissedPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    final dismissed = prefs.getStringList(_prefsKeyDismissed) ?? <String>[];

    if (!mounted) return;
    setState(() {
      _dismissedKeys
        ..clear()
        ..addAll(dismissed);
      _loadingPrefs = false;
    });
  }

  Future<void> _saveDismissedPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_prefsKeyDismissed, _dismissedKeys.toList());
  }

  Future<void> _dismiss(String key) async {
    _dismissedKeys.add(key);
    await _saveDismissedPrefs();
  }

  void _listenCasesAndBuildReminders() {
    _sub?.cancel();

    final user = _auth.currentUser;
    if (user == null) {
      setState(() {
        _error = null;
        _loadingReminders = false;
        _items = [];
      });
      return;
    }

    final casesRef = _firestore
        .collection('users')
        .doc(user.uid)
        .collection('cases')
        .orderBy('lastUpdated', descending: true);

    _sub = casesRef.snapshots().listen((snap) async {
      try {
        if (!mounted) return;
        setState(() {
          _error = null;
          _loadingReminders = true;
        });

        final prefs = await SharedPreferences.getInstance();
        final today = DateFormat('yyyy-MM-dd').format(DateTime.now());

        final built = <_AlertItem>[];

        for (final d in snap.docs) {
          final data = d.data();
          final caseId = d.id;
          final caseTitle = _readCaseTitle(data);

          final raw = prefs.getString(_reminderPrefsKey(caseId));
          if (raw == null || raw.trim().isEmpty) continue;

          Map<String, dynamic> map;
          try {
            map = jsonDecode(raw) as Map<String, dynamic>;
          } catch (_) {
            continue;
          }

          final enabled = (map['enabled'] as bool?) ?? false;
          if (!enabled) continue;

          final hour = (map['hour'] is int)
              ? map['hour'] as int
              : int.tryParse('${map['hour']}') ?? 20;
          final minute = (map['minute'] is int)
              ? map['minute'] as int
              : int.tryParse('${map['minute']}') ?? 0;

          final key = 'whqcase:$caseId:$today';
          if (_dismissedKeys.contains(key)) continue;

          built.add(
            _AlertItem(
              keyId: key,
              type: _AlertType.whq,
              title: "Daily WHQ Reminder",
              subtitle: "Case: $caseTitle",
              date: DateTime.now(),
              payload: caseId,
              caseTitle: caseTitle,
              hour: hour,
              minute: minute,
            ),
          );
        }

        // ✅ sort by hour/minute directly
        built.sort((a, b) => (a.hour * 60 + a.minute).compareTo(b.hour * 60 + b.minute));

        if (!mounted) return;
        setState(() {
          _items = built;
          _loadingReminders = false;
        });
      } catch (e) {
        if (!mounted) return;
        setState(() {
          _error = e.toString();
          _items = [];
          _loadingReminders = false;
        });
      }
    }, onError: (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _items = [];
        _loadingReminders = false;
      });
    });
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
                    "Notifications",
                    style: GoogleFonts.dmSans(
                      fontSize: 28,
                      fontWeight: FontWeight.w900,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    "Daily wound check reminder",
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 14),
                  Expanded(
                    child: (user == null)
                        ? _emptyState()
                        : (_error != null)
                        ? _errorState(_error!)
                        : (_loadingReminders
                        ? const Center(child: CircularProgressIndicator())
                        : (_items.isEmpty ? _emptyState() : _list())),
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
        final t = TimeOfDay(hour: item.hour, minute: item.minute);

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
          onDismissed: (_) async {
            if (!mounted) return;
            setState(() {
              _items.removeWhere((x) => x.keyId == item.keyId);
            });
            await _dismiss(item.keyId);
          },
          child: _NotificationCard(
            item: item,
            timeText: "Scheduled at ${t.format(context)}",
            onTap: () {
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
            size: 50,
            color: AppColors.textPrimary.withOpacity(0.85),
          ),
          const SizedBox(height: 16),
          Text(
            "No Notifications Yet",
            style: GoogleFonts.inter(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
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
          "Failed to load reminders.\n\n$msg",
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

  String _readCaseTitle(Map<String, dynamic> data) {
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
              colors: [Color(0xFFEAF5FB), Color(0xFFDCEEF7), Color(0xFFF7FBFF)],
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

enum _AlertType { whq }

class _AlertItem {
  final String keyId;
  final _AlertType type;
  final String title;
  final String subtitle;
  final DateTime date;
  final String payload;
  final String caseTitle;
  final int hour;
  final int minute;

  _AlertItem({
    required this.keyId,
    required this.type,
    required this.title,
    required this.subtitle,
    required this.date,
    required this.payload,
    required this.caseTitle,
    required this.hour,
    required this.minute,
  });
}

class _NotificationCard extends StatelessWidget {
  const _NotificationCard({
    required this.item,
    required this.timeText,
    required this.onTap,
  });

  final _AlertItem item;
  final String timeText;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final iconTint = AppColors.primaryColor;
    final icon = Icons.assignment_rounded;

    final chipColor = AppColors.primaryColor;
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
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(
                          item.title,
                          style: GoogleFonts.dmSans(
                            fontSize: 15.5,
                            fontWeight: FontWeight.w900,
                            color: AppColors.textPrimary,
                          ),
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
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(999),
                        color: chipColor.withOpacity(0.10),
                        border: Border.all(color: chipColor.withOpacity(0.22)),
                      ),
                      child: Text(
                        timeText,
                        style: GoogleFonts.inter(
                          fontSize: 11.6,
                          fontWeight: FontWeight.w900,
                          color: chipColor,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Icon(Icons.arrow_forward_rounded, size: 18, color: AppColors.primaryColor),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          'Go to case "${item.caseTitle}"',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.inter(
                            fontSize: 12.8,
                            fontWeight: FontWeight.w900,
                            color: AppColors.primaryColor,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
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