// case_details_screen.dart
import 'dart:convert';
import 'dart:ui';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../utils/app_colors.dart';
import '../widgets/bottom_nav.dart';
import '../services/notification_service.dart';
import '../services/pdf_service.dart';

class CaseDetailsScreen extends StatefulWidget {
  const CaseDetailsScreen({
    super.key,
    required this.caseId,
    this.caseNumber,
  });

  final String caseId;
  final int? caseNumber;

  @override
  State<CaseDetailsScreen> createState() => _CaseDetailsScreenState();
}

class _CaseDetailsScreenState extends State<CaseDetailsScreen> {
  // Key used to force-refresh the FutureBuilder when a reminder is saved
  Key _builderKey = UniqueKey();

  static String _reminderPrefsKey(String caseId) => 'whq_reminder_case_$caseId';
  static String _payloadForCase(String caseId) => 'whq_case:$caseId';

  // =========================
  // ✅ Reminder Logic
  // =========================

  Future<_CaseReminder?> _loadReminder(String caseId) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_reminderPrefsKey(caseId));
    if (raw == null || raw.trim().isEmpty) return null;
    try {
      final map = jsonDecode(raw) as Map<String, dynamic>;
      return _CaseReminder.fromJson(map);
    } catch (_) {
      return null;
    }
  }

  Future<void> _saveReminder(String caseId, _CaseReminder r) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_reminderPrefsKey(caseId), jsonEncode(r.toJson()));
  }

  DateTime _nextOccurrence(TimeOfDay t) {
    final now = DateTime.now();
    var scheduled = DateTime(now.year, now.month, now.day, t.hour, t.minute);
    if (scheduled.isBefore(now)) {
      scheduled = scheduled.add(const Duration(days: 1));
    }
    return scheduled;
  }

  Future<void> _scheduleReminder({
    required String caseId,
    required String caseTitle,
    required TimeOfDay time,
  }) async {
    final service = NotificationService();
    await service.init();

    final scheduled = _nextOccurrence(time);
    final payload = _payloadForCase(caseId);

    await service.scheduleRecurringNotification(
      title: 'WHQ Reminder • $caseTitle',
      body: "Don't forget to complete your WHQ for $caseTitle.",
      scheduledTime: scheduled,
      frequency: 'daily',
      payload: payload,
    );
  }

  Future<void> _openReminderSheet({
    required BuildContext context,
    required String caseId,
    required String caseTitle,
  }) async {
    final existing = await _loadReminder(caseId);

    var hour = existing?.hour ?? 20;
    var minute = existing?.minute ?? 0;

    if (!context.mounted) return;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
          child: _FrostedSheet(
            child: StatefulBuilder(
              builder: (sheetCtx, setSheet) {
                final t = TimeOfDay(hour: hour, minute: minute);
                final timeText = t.format(sheetCtx);

                return Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 46, height: 5,
                      margin: const EdgeInsets.only(top: 10, bottom: 20),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(999),
                      ),
                    ),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        "Daily Reminder Time",
                        style: GoogleFonts.dmSans(
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    InkWell(
                      onTap: () async {
                        final picked = await showTimePicker(
                          context: sheetCtx,
                          initialTime: TimeOfDay(hour: hour, minute: minute),
                        );
                        if (picked == null) return;
                        setSheet(() { hour = picked.hour; minute = picked.minute; });
                      },
                      borderRadius: BorderRadius.circular(18),
                      child: Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(18),
                          color: Colors.white.withOpacity(0.92),
                          border: Border.all(color: AppColors.dividerColor.withOpacity(0.9)),
                        ),
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
                        child: Row(
                          children: [
                            Icon(Icons.schedule_rounded, color: AppColors.primaryColor),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                "Reminder time",
                                style: GoogleFonts.inter(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w800,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                            ),
                            Text(
                              timeText,
                              style: GoogleFonts.inter(
                                fontSize: 14,
                                fontWeight: FontWeight.w900,
                                color: AppColors.textSecondary,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Icon(Icons.chevron_right_rounded, color: AppColors.textMuted.withOpacity(0.9)),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton(
                        onPressed: () async {
                          final r = _CaseReminder(enabled: true, hour: hour, minute: minute);
                          await _saveReminder(widget.caseId, r);
                          await _scheduleReminder(caseId: caseId, caseTitle: caseTitle, time: t);

                          if (sheetCtx.mounted) Navigator.pop(sheetCtx);

                          // Refresh the UI to show "Edit Reminder"
                          setState(() { _builderKey = UniqueKey(); });

                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text("Reminder scheduled for $timeText")),
                            );
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primaryColor,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        ),
                        child: Text("Done", style: GoogleFonts.inter(fontWeight: FontWeight.w900, color: Colors.white)),
                      ),
                    ),
                    const SizedBox(height: 10),
                  ],
                );
              },
            ),
          ),
        );
      },
    );
  }

  // =========================
  // ✅ Rename Logic
  // =========================

  Future<void> _editCaseName(
      BuildContext context,
      DocumentReference<Map<String, dynamic>> caseRef,
      String currentDisplayTitle,
      int fallbackNo,
      ) async {
    final initialText = currentDisplayTitle.startsWith("Wound ") ? "" : currentDisplayTitle;
    final ctrl = TextEditingController(text: initialText);

    final result = await showDialog<String?>(
      context: context,
      useRootNavigator: true,
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
                    Text("Edit case name", style: GoogleFonts.dmSans(fontSize: 18, fontWeight: FontWeight.w900, color: AppColors.textPrimary)),
                    const Spacer(),
                    IconButton(onPressed: () => Navigator.pop(ctx, null), icon: const Icon(Icons.close_rounded)),
                  ],
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: ctrl,
                  autofocus: true,
                  decoration: InputDecoration(hintText: "Example: Left knee", border: OutlineInputBorder(borderRadius: BorderRadius.circular(14))),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  height: 46,
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(ctx, ctrl.text),
                    style: ElevatedButton.styleFrom(backgroundColor: AppColors.primaryColor, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
                    child: Text("Save", style: GoogleFonts.inter(fontWeight: FontWeight.w900, color: Colors.white)),
                  ),
                ),
                const SizedBox(height: 6),
                Text("Leave empty to use Wound $fallbackNo.", style: GoogleFonts.inter(fontSize: 11.5, fontWeight: FontWeight.w600, color: AppColors.textMuted)),
              ],
            ),
          ),
        );
      },
    );

    ctrl.dispose();
    if (result == null) return;

    final newName = result.trim();
    if (!context.mounted) return;

    if (newName.isEmpty) {
      await caseRef.update({
        'caseName': FieldValue.delete(),
        'title': FieldValue.delete(),
        'lastUpdated': FieldValue.serverTimestamp(),
      });
      return;
    }

    await caseRef.update({
      'caseName': newName,
      'title': newName,
      'lastUpdated': FieldValue.serverTimestamp(),
    });
  }

  @override
  Widget build(BuildContext context) {
    final stableCtx = context;
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
        .doc(widget.caseId);

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
                final status = ((data['status'] as String?) ?? 'active').toLowerCase();
                final isClosed = status == 'closed';

                final int fallbackNo = widget.caseNumber ?? _asInt(data['caseNumber']) ?? _asInt(data['caseNo']) ?? 0;

                final rawName = (data['caseName'] ?? data['title'] ?? '').toString().trim();
                final displayTitle = rawName.isNotEmpty
                    ? rawName
                    : (fallbackNo > 0 ? "Wound $fallbackNo" : "Wound case");

                // ✅ FIX: no time shown, date only
                final startValue = data['createdAt'] ?? data['startDate'] ?? data['surgeryDate'];
                final startDateText = _formatDateOnly(startValue);

                final lastValue = data['lastUpdated'] ?? data['createdAt'];
                final lastUpdatedText = _formatDateOnly(lastValue);

                final scoreRaw = data['infectionScore'];
                final int score = (scoreRaw is int) ? scoreRaw : int.tryParse('$scoreRaw') ?? 0;

                final bool isHighRisk = score >= 4;
                final String assessment =
                isHighRisk ? "High sign of infection" : "No sign of infection";

                final Color assessTint =
                isHighRisk ? AppColors.errorColor : AppColors.successColor;

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
                                child: const Icon(Icons.arrow_back_ios_new_rounded, size: 18, color: AppColors.textPrimary),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text("Wound Case details", style: GoogleFonts.dmSans(fontSize: 16, fontWeight: FontWeight.w900, color: AppColors.textPrimary)),
                              ),
                              FutureBuilder<_CaseReminder?>(
                                key: _builderKey,
                                future: _loadReminder(widget.caseId),
                                builder: (context, remSnapshot) {
                                  final hasReminder = remSnapshot.data?.enabled ?? false;
                                  return _WhitePillButton(
                                    onTap: () => _openReminderSheet(context: context, caseId: widget.caseId, caseTitle: displayTitle),
                                    child: Row(
                                      children: [
                                        Icon(Icons.notifications_active_rounded, size: 18, color: AppColors.primaryColor,),
                                        const SizedBox(width: 8),
                                        Text(hasReminder ? "Edit reminder" : "Set reminder", style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w900, color: AppColors.primaryColor)),
                                      ],
                                    ),
                                  );
                                },
                              ),
                            ],
                          ),
                          const SizedBox(height: 14),
                          Row(
                            children: [
                              _FolderBubble(tint: assessTint),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(displayTitle, style: GoogleFonts.dmSans(fontSize: 28, fontWeight: FontWeight.w900, color: AppColors.textPrimary)),
                              ),
                              _WhitePillButton(
                                onTap: () => _editCaseName(context, caseRef, displayTitle, (fallbackNo == 0 ? 1 : fallbackNo)),
                                child: const Icon(Icons.edit_outlined, size: 18, color: AppColors.textPrimary),
                              ),
                            ],
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
                                Divider(height: 1, color: AppColors.dividerColor.withOpacity(0.9)),
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

                                // Infection assessment card
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(22),
                                    color: AppColors.surfaceColor.withOpacity(0.92),
                                    border: Border.all(color: assessTint.withOpacity(0.20)),
                                  ),
                                  child: Row(
                                    children: [
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              "Infection assessment",
                                              style: GoogleFonts.inter(
                                                fontSize: 14,
                                                fontWeight: FontWeight.w800,
                                                color: AppColors.textSecondary,
                                              ),
                                            ),
                                            const SizedBox(height: 8),
                                            _MiniPillText(
                                              text: assessment,
                                              tint: assessTint,
                                            ),
                                          ],
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Container(
                                        width: 48,
                                        height: 48,
                                        decoration: BoxDecoration(
                                          borderRadius: BorderRadius.circular(18),
                                          color: assessTint.withOpacity(0.12),
                                          border: Border.all(
                                            color: assessTint.withOpacity(0.22),
                                          ),
                                        ),
                                        child: Icon(
                                          isHighRisk ? Icons.warning_rounded : Icons.verified_rounded,
                                          color: assessTint,
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
                                        label: "Download medical PDF",
                                        icon: Icons.picture_as_pdf,
                                        disabled: false,
                                        onTap: () async {
                                          try {
                                            await PdfReportGenerator.generateAndPrintReportForCase(
                                              caseId: widget.caseId,
                                            );
                                          } catch (e) {
                                            if (!mounted) return;
                                            ScaffoldMessenger.of(context).showSnackBar(
                                              SnackBar(content: Text("Failed to generate PDF: $e")),
                                            );
                                          }
                                        },
                                    )
                                    )
                                  ]
                                ),


                                const SizedBox(height: 10),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    Align(
                      alignment: Alignment.bottomCenter,
                      child: _BottomDangerBar(
                        disabled: isClosed,
                        onClose: () async => await caseRef.update({'status': 'closed', 'lastUpdated': FieldValue.serverTimestamp()}),
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


class _CaseReminder {
  final bool enabled;
  final int hour;
  final int minute;
  const _CaseReminder({required this.enabled, required this.hour, required this.minute});
  Map<String, dynamic> toJson() => {'enabled': enabled, 'hour': hour, 'minute': minute};
  static _CaseReminder fromJson(Map<String, dynamic> j) => _CaseReminder(
    enabled: j['enabled'] ?? false,
    hour: j['hour'] ?? 20,
    minute: j['minute'] ?? 0,
  );
}

int? _asInt(dynamic v) {
  if (v is int) return v;
  if (v is num) return v.toInt();
  return int.tryParse('$v');
}

String _formatDateOnly(dynamic value) {
  if (value == null) return "--";
  DateTime? dt;
  if (value is Timestamp) dt = value.toDate();
  if (value is DateTime) dt = value;
  if (value is String) dt = DateTime.tryParse(value);
  if (dt == null) return "--";
  return "${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}";
}

class _SecondaryActionButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback onTap;
  const _SecondaryActionButton({required this.label, required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: Container(
        height: 50,
        width: double.infinity,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(999),
          color: Colors.white.withOpacity(0.5),
          border: Border.all(color: AppColors.primaryColor.withOpacity(0.4), width: 1.5),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 20, color: AppColors.primaryColor),
            const SizedBox(width: 10),
            Text(label, style: GoogleFonts.inter(fontSize: 13.5, fontWeight: FontWeight.w900, color: AppColors.primaryColor)),
          ],
        ),
      ),
    );
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
                          const Icon(Icons.delete_outline, color: Colors.white, size: 20),
                          const SizedBox(width: 10),
                          Text(
                            disabled ? "Case already closed" : "Close wound case",
                            style: GoogleFonts.inter(
                              fontSize: 14,
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

/* ===================== Helpers ===================== */
