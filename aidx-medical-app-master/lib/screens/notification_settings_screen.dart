import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/notification_service.dart';

// =====================
// Models (prefs)
// =====================

class CaseWhqReminder {
  final String id; // unique
  final String caseId;
  final String caseTitle; // cached for UI
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

  CaseWhqReminder copyWith({
    String? id,
    String? caseId,
    String? caseTitle,
    int? hour,
    int? minute,
    bool? enabled,
  }) {
    return CaseWhqReminder(
      id: id ?? this.id,
      caseId: caseId ?? this.caseId,
      caseTitle: caseTitle ?? this.caseTitle,
      hour: hour ?? this.hour,
      minute: minute ?? this.minute,
      enabled: enabled ?? this.enabled,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'caseId': caseId,
    'caseTitle': caseTitle,
    'hour': hour,
    'minute': minute,
    'enabled': enabled,
  };

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

// =====================
// Screen
// =====================

class NotificationSettingsScreen extends StatefulWidget {
  const NotificationSettingsScreen({super.key});

  @override
  State<NotificationSettingsScreen> createState() => _NotificationSettingsScreenState();
}

class _NotificationSettingsScreenState extends State<NotificationSettingsScreen> {
  // ===== Colors (from your theme) =====
  static const Color primaryColor = Color(0xFF3B7691);
  static const Color bgLight = Color(0xFFF6F8FB);
  static const Color textDark = Color(0xFF0F172A);
  static const Color textMuted = Color(0xFF475569);
  static const Color white = Colors.white;

  static const double _inset = 16;

  bool allowNotifications = true;
  bool sounds = true;
  bool badges = true;

  ShowPreviews showPreviews = ShowPreviews.always;
  NotificationGrouping grouping = NotificationGrouping.automatic;

  bool _loadingPrefs = true;

  // ✅ multiple reminders (per case)
  final List<CaseWhqReminder> _reminders = [];

  // UI selection
  String? _selectedCaseId;
  String _selectedCaseTitle = "Select a case";

  @override
  void initState() {
    super.initState();
    _loadPrefs();
  }

  // ----------------- Prefs -----------------

  static const _prefsKeyReminders = 'case_whq_reminders_v1';

  Future<void> _loadPrefs() async {
    final prefs = await SharedPreferences.getInstance();

    final allow = prefs.getBool('allow_notifications') ?? true;
    final snd = prefs.getBool('notif_sounds') ?? true;
    final bdg = prefs.getBool('notif_badges') ?? true;

    final raw = prefs.getString(_prefsKeyReminders);
    final parsed = <CaseWhqReminder>[];
    if (raw != null && raw.trim().isNotEmpty) {
      try {
        final list = jsonDecode(raw) as List<dynamic>;
        for (final e in list) {
          parsed.add(CaseWhqReminder.fromJson(Map<String, dynamic>.from(e as Map)));
        }
      } catch (_) {
        // ignore bad prefs
      }
    }

    if (!mounted) return;
    setState(() {
      allowNotifications = allow;
      sounds = snd;
      badges = bdg;
      _reminders
        ..clear()
        ..addAll(parsed);
      _loadingPrefs = false;
    });
  }

  Future<void> _savePrefs() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('allow_notifications', allowNotifications);
    await prefs.setBool('notif_sounds', sounds);
    await prefs.setBool('notif_badges', badges);

    final raw = jsonEncode(_reminders.map((e) => e.toJson()).toList());
    await prefs.setString(_prefsKeyReminders, raw);
  }

  void _saveAndClose() async {
    await _savePrefs();
    if (!mounted) return;
    Navigator.pop(context, true);
  }

  // ----------------- Scheduling -----------------

  DateTime _nextOccurrence(TimeOfDay t) {
    final now = DateTime.now();
    var scheduled = DateTime(now.year, now.month, now.day, t.hour, t.minute);
    if (scheduled.isBefore(now)) scheduled = scheduled.add(const Duration(days: 1));
    return scheduled;
  }

  Future<void> _scheduleReminder(CaseWhqReminder r) async {
    if (!allowNotifications) return;
    if (!r.enabled) return;

    final service = NotificationService();
    await service.init();

    final scheduled = _nextOccurrence(r.time);

    // payload format: whq_case:<caseId>:<reminderId>
    final payload = 'whq_case:${r.caseId}:${r.id}';

    await service.scheduleRecurringNotification(
      title: 'WHQ Reminder • ${r.caseTitle}',
      body: "Don't forget to complete your WHQ for ${r.caseTitle}.",
      scheduledTime: scheduled,
      frequency: 'daily',
      payload: payload,
    );
  }

  // NOTE: If your NotificationService has cancel methods, add them here.
  // Future<void> _cancelReminder(CaseWhqReminder r) async { ... }

  // ----------------- Actions -----------------

  Future<void> _pickAndAddReminder() async {
    if (_selectedCaseId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please select a case first.")),
      );
      return;
    }

    final picked = await showTimePicker(
      context: context,
      initialTime: const TimeOfDay(hour: 20, minute: 0),
    );
    if (picked == null) return;

    final id = DateTime.now().millisecondsSinceEpoch.toString();

    final reminder = CaseWhqReminder(
      id: id,
      caseId: _selectedCaseId!,
      caseTitle: _selectedCaseTitle,
      hour: picked.hour,
      minute: picked.minute,
      enabled: true,
    );

    setState(() => _reminders.insert(0, reminder));
    await _savePrefs();
    await _scheduleReminder(reminder);

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text("Reminder added for ${reminder.caseTitle} at ${picked.format(context)}")),
    );
  }

  Future<void> _toggleReminder(CaseWhqReminder r, bool v) async {
    final idx = _reminders.indexWhere((x) => x.id == r.id);
    if (idx < 0) return;

    setState(() => _reminders[idx] = _reminders[idx].copyWith(enabled: v));
    await _savePrefs();

    if (v) {
      await _scheduleReminder(_reminders[idx]);
    } else {
      // If you have a cancel method, call it here.
    }
  }

  Future<void> _editReminderTime(CaseWhqReminder r) async {
    final picked = await showTimePicker(context: context, initialTime: r.time);
    if (picked == null) return;

    final idx = _reminders.indexWhere((x) => x.id == r.id);
    if (idx < 0) return;

    final updated = r.copyWith(hour: picked.hour, minute: picked.minute);

    setState(() => _reminders[idx] = updated);
    await _savePrefs();

    if (updated.enabled) {
      await _scheduleReminder(updated);
    }

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text("Updated time to ${picked.format(context)}")),
    );
  }

  Future<void> _deleteReminder(CaseWhqReminder r) async {
    setState(() => _reminders.removeWhere((x) => x.id == r.id));
    await _savePrefs();
    // If you have a cancel method, call it here.
  }

  // ----------------- Firestore Cases -----------------

  Stream<QuerySnapshot<Map<String, dynamic>>> _casesStream() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return const Stream.empty();
    }
    return FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .collection('cases')
        .orderBy('lastUpdated', descending: true)
        .snapshots();
  }

  String _caseDisplayName(Map<String, dynamic> data) {
    final raw = (data['caseName'] ?? data['title'] ?? '').toString().trim();

    if (raw.isNotEmpty) return raw;

    final fallbackNo = _asInt(data['caseNumber']) ?? _asInt(data['caseNo']) ?? 0;
    if (fallbackNo > 0) return "Wound $fallbackNo";

    return "Wound case";
  }

  @override
  Widget build(BuildContext context) {
    if (_loadingPrefs) {
      return const Scaffold(
        backgroundColor: bgLight,
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      backgroundColor: bgLight,
      appBar: AppBar(
        backgroundColor: bgLight,
        elevation: 0,
        centerTitle: true,
        title: const Text("Notifications"),
        leadingWidth: 90,
        leading: TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text(
            "Cancel",
            style: TextStyle(color: primaryColor, fontWeight: FontWeight.w600),
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 18),
        children: [
          _card(
            child: _switchRow(
              title: "Allow Notifications",
              value: allowNotifications,
              onChanged: (v) async {
                setState(() => allowNotifications = v);
                await _savePrefs();
              },
            ),
          ),

          const SizedBox(height: 18),
          _sectionLabel("WHQ REMINDERS (PER CASE)"),

          _card(
            child: Column(
              children: [
                // ✅ pick case (dropdown from Firestore)
                StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                  stream: _casesStream(),
                  builder: (context, snap) {
                    final docs = snap.data?.docs ?? [];

                    // Keep selection valid
                    if (_selectedCaseId != null && docs.every((d) => d.id != _selectedCaseId)) {
                      _selectedCaseId = null;
                      _selectedCaseTitle = "Select a case";
                    }

                    return Padding(
                      padding: const EdgeInsets.fromLTRB(_inset, 14, _inset, 12),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: Colors.black.withOpacity(0.10)),
                          color: Colors.white,
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            value: _selectedCaseId,
                            isExpanded: true,
                            hint: Text(
                              _selectedCaseTitle,
                              style: TextStyle(
                                fontWeight: FontWeight.w700,
                                color: textDark.withOpacity(0.85),
                              ),
                            ),
                            items: docs.map((d) {
                              final title = _caseDisplayName(d.data());
                              return DropdownMenuItem<String>(
                                value: d.id,
                                child: Text(
                                  title,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(fontWeight: FontWeight.w700),
                                ),
                              );
                            }).toList(),
                            onChanged: allowNotifications
                                ? (v) {
                              if (v == null) return;
                              final doc = docs.firstWhere((x) => x.id == v);
                              final title = _caseDisplayName(doc.data());
                              setState(() {
                                _selectedCaseId = v;
                                _selectedCaseTitle = title;
                              });
                            }
                                : null,
                          ),
                        ),
                      ),
                    );
                  },
                ),

                _insetDivider(),

                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: _inset, vertical: 12),
                  child: SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton(
                      onPressed: allowNotifications ? _pickAndAddReminder : null,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: primaryColor,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                      child: const Text(
                        "Add Reminder Time for Selected Case",
                        style: TextStyle(fontWeight: FontWeight.w800),
                      ),
                    ),
                  ),
                ),

                if (_reminders.isNotEmpty) _insetDivider(),

                // ✅ list reminders
                if (_reminders.isEmpty)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(_inset, 12, _inset, 14),
                    child: Text(
                      "No reminders yet. Select a case and add a time.",
                      style: TextStyle(
                        color: textMuted.withOpacity(0.85),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  )
                else
                  ..._reminders.map((r) => _reminderRow(r)),
              ],
            ),
          ),

          const SizedBox(height: 18),
          _sectionLabel("ALERTS"),

          _card(
            child: Column(
              children: [
                _switchRow(
                  title: "Sounds",
                  value: sounds,
                  enabled: allowNotifications,
                  onChanged: (v) async {
                    setState(() => sounds = v);
                    await _savePrefs();
                  },
                ),
                _insetDivider(),
                _switchRow(
                  title: "Badges",
                  value: badges,
                  enabled: allowNotifications,
                  onChanged: (v) async {
                    setState(() => badges = v);
                    await _savePrefs();
                  },
                ),
              ],
            ),
          ),

          const SizedBox(height: 18),
          _sectionLabel("LOCK SCREEN APPEARANCE"),

          _card(
            child: Column(
              children: [
                _chevronRow(
                  title: "Show Previews",
                  valueText: _showPreviewsText(showPreviews),
                  enabled: allowNotifications,
                  onTap: () async {
                    if (!allowNotifications) return;
                    final result = await _pickShowPreviews();
                    if (result != null) setState(() => showPreviews = result);
                  },
                ),
                _insetDivider(),
                _chevronRow(
                  title: "Notification Grouping",
                  valueText: _groupingText(grouping),
                  enabled: allowNotifications,
                  onTap: () async {
                    if (!allowNotifications) return;
                    final result = await _pickGrouping();
                    if (result != null) setState(() => grouping = result);
                  },
                ),
              ],
            ),
          ),

          const SizedBox(height: 22),
          SizedBox(
            height: 54,
            child: ElevatedButton(
              onPressed: _saveAndClose,
              style: ElevatedButton.styleFrom(
                backgroundColor: primaryColor,
                foregroundColor: white,
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              child: const Text(
                "Save",
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ================= UI =================

  Widget _reminderRow(CaseWhqReminder r) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(_inset, 10, _inset, 10),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  r.caseTitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 14.5,
                    color: textDark,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  "Time: ${r.time.format(context)}",
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: textMuted.withOpacity(0.85),
                  ),
                ),
              ],
            ),
          ),

          IconButton(
            onPressed: allowNotifications ? () => _editReminderTime(r) : null,
            icon: Icon(Icons.schedule_rounded, color: textMuted.withOpacity(0.85)),
          ),

          Switch(
            value: r.enabled,
            onChanged: allowNotifications ? (v) => _toggleReminder(r, v) : null,
            thumbColor: WidgetStateProperty.all(Colors.white),
            trackColor: WidgetStateProperty.resolveWith((states) {
              if (states.contains(WidgetState.selected)) return primaryColor;
              return Colors.grey.shade300;
            }),
          ),

          IconButton(
            onPressed: () => _deleteReminder(r),
            icon: const Icon(Icons.delete_outline_rounded, color: Color(0xFFE53935)),
          ),
        ],
      ),
    );
  }

  Widget _card({required Widget child}) {
    return Container(
      decoration: BoxDecoration(
        color: white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0x1F0B0F14)),
        boxShadow: const [
          BoxShadow(color: Color(0x140B0F14), blurRadius: 18, offset: Offset(0, 10)),
        ],
      ),
      child: child,
    );
  }

  Widget _sectionLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(left: 6, bottom: 8),
      child: Text(
        text,
        style: TextStyle(
          fontWeight: FontWeight.w700,
          letterSpacing: 0.6,
          color: textMuted.withOpacity(0.8),
          fontSize: 12,
        ),
      ),
    );
  }

  Widget _insetDivider() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: _inset),
      child: Divider(
        height: 1,
        thickness: 0.6,
        color: Colors.black.withOpacity(0.10),
      ),
    );
  }

  Widget _switchRow({
    required String title,
    required bool value,
    required ValueChanged<bool> onChanged,
    bool enabled = true,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: _inset, vertical: 14),
      child: Row(
        children: [
          Expanded(
            child: Text(
              title,
              style: TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 16,
                color: enabled ? textDark : textMuted.withOpacity(0.6),
              ),
            ),
          ),
          Switch(
            value: value,
            onChanged: enabled ? onChanged : null,
            thumbColor: WidgetStateProperty.all(Colors.white),
            trackColor: WidgetStateProperty.resolveWith((states) {
              if (states.contains(WidgetState.selected)) return primaryColor;
              return Colors.grey.shade300;
            }),
          ),
        ],
      ),
    );
  }

  Widget _chevronRow({
    required String title,
    required String valueText,
    required VoidCallback onTap,
    bool enabled = true,
  }) {
    return InkWell(
      onTap: enabled ? onTap : null,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: _inset, vertical: 14),
        child: Row(
          children: [
            Expanded(
              child: Text(
                title,
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 16,
                  color: enabled ? textDark : textMuted.withOpacity(0.6),
                ),
              ),
            ),
            Text(
              valueText,
              style: TextStyle(
                fontWeight: FontWeight.w500,
                color: textMuted.withOpacity(enabled ? 1 : 0.6),
              ),
            ),
            const SizedBox(width: 6),
            Icon(Icons.chevron_right_rounded, color: textMuted.withOpacity(enabled ? 1 : 0.6)),
          ],
        ),
      ),
    );
  }

  // ================= Pickers =================

  Future<ShowPreviews?> _pickShowPreviews() async {
    return showModalBottomSheet<ShowPreviews>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => _pickerSheet(
        title: "Show Previews",
        options: const {
          "Always (Default)": ShowPreviews.always,
          "When Unlocked": ShowPreviews.whenUnlocked,
          "Never": ShowPreviews.never,
        },
      ),
    );
  }

  Future<NotificationGrouping?> _pickGrouping() async {
    return showModalBottomSheet<NotificationGrouping>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => _pickerSheet(
        title: "Notification Grouping",
        options: const {
          "Automatic": NotificationGrouping.automatic,
          "By App": NotificationGrouping.byApp,
          "Off": NotificationGrouping.off,
        },
      ),
    );
  }

  Widget _pickerSheet<T>({
    required String title,
    required Map<String, T> options,
  }) {
    return Container(
      decoration: const BoxDecoration(
        color: white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.10),
                borderRadius: BorderRadius.circular(100),
              ),
            ),
            const SizedBox(height: 12),
            Text(title, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
            const SizedBox(height: 10),
            ...options.entries.map(
                  (e) => ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(e.key, style: const TextStyle(fontWeight: FontWeight.w600)),
                onTap: () => Navigator.pop(context, e.value),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _showPreviewsText(ShowPreviews v) {
    switch (v) {
      case ShowPreviews.always:
        return "Always (Default)";
      case ShowPreviews.whenUnlocked:
        return "When Unlocked";
      case ShowPreviews.never:
        return "Never";
    }
  }

  String _groupingText(NotificationGrouping v) {
    switch (v) {
      case NotificationGrouping.automatic:
        return "Automatic";
      case NotificationGrouping.byApp:
        return "By App";
      case NotificationGrouping.off:
        return "Off";
    }
  }
}

enum ShowPreviews { always, whenUnlocked, never }
enum NotificationGrouping { automatic, byApp, off }

int? _asInt(dynamic v) {
  if (v == null) return null;
  if (v is int) return v;
  if (v is num) return v.toInt();
  return int.tryParse('$v');
}