import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../widgets/bottom_nav.dart';
import 'create_case_screen.dart';
import 'case_details_screen.dart';

class CasesScreen extends StatelessWidget {
  const CasesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final bg = const Color(0xFFFFFFFF);
    final surface = const Color(0xFFF8FAFC);
    final primary = const Color(0xFF3B7691);
    final secondary = const Color(0xFF63A2BF);
    final danger = const Color(0xFFBF121D);

    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      return Scaffold(
        backgroundColor: bg,
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

    return Scaffold(
      backgroundColor: bg,
      body: SafeArea(
        child: Column(
          children: [
            // Header (Back + New Case)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 8),
              child: Row(
                children: [
                  _BackButtonChip(
                    primary: primary,
                    onTap: () => Navigator.pop(context),
                  ),
                  const Spacer(),
                  _PrimaryButton(
                    label: "New Case",
                    color: primary,
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

            // Title + subtitle
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 6, 24, 0),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  "My Cases",
                  style: GoogleFonts.dmSans(
                    fontSize: 24,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF0F172A),
                    height: 32 / 24,
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 4, 24, 12),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  "Track your wound healing progress",
                  style: GoogleFonts.dmSans(
                    fontSize: 16,
                    fontWeight: FontWeight.w400,
                    color: const Color(0xFF0F172A),
                    height: 24 / 16,
                  ),
                ),
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

                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  final docs = snapshot.data?.docs ?? [];

                  if (docs.isEmpty) {
                    return _EmptyState(
                      primary: primary,
                      secondary: secondary,
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

                  // =========================
                  // ✅ Case numbering per user
                  // Case 1 = oldest by createdAt/startDate/surgeryDate
                  // =========================
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

                  final active = <QueryDocumentSnapshot<Map<String, dynamic>>>[];
                  final closed = <QueryDocumentSnapshot<Map<String, dynamic>>>[];

                  for (final d in docs) {
                    final data = d.data();
                    final status =
                    ((data['status'] as String?) ?? 'active').toLowerCase();
                    if (status == 'closed') {
                      closed.add(d);
                    } else {
                      active.add(d);
                    }
                  }

                  return ListView(
                    padding: const EdgeInsets.fromLTRB(0, 0, 0, 96),
                    children: [
                      // Active label
                      Padding(
                        padding: const EdgeInsets.fromLTRB(24, 6, 24, 10),
                        child: Row(
                          children: [
                            Container(
                              width: 8,
                              height: 8,
                              decoration: BoxDecoration(
                                color: secondary,
                                borderRadius: BorderRadius.circular(999),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              "Active Cases",
                              style: GoogleFonts.dmSans(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: const Color(0xFF0F172A),
                                height: 24 / 16,
                              ),
                            ),
                          ],
                        ),
                      ),

                      if (active.isEmpty)
                        Padding(
                          padding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
                          child: Text(
                            "No active cases yet.",
                            style: GoogleFonts.inter(
                              fontSize: 13,
                              color: const Color(0xFF475569),
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        )
                      else
                        ...active.map((doc) {
                          final data = doc.data();
                          final caseId = doc.id;

                          final caseNo = caseNumberById[caseId] ?? 0;
                          final title = caseNo > 0 ? "Case $caseNo" : "Case";

                          final startDate = _formatDate(
                            data['startDate'] ??
                                data['surgeryDate'] ??
                                data['createdAt'],
                          );
                          final lastUpdated = _formatDate(
                            data['lastUpdated'] ?? data['createdAt'],
                          );
                          final score = (data['infectionScore']?.toString()) ?? "--";

                          final tagText = (data['tagText'] as String?) ?? "Active";
                          final isDanger = _isDangerTag(tagText);

                          return Padding(
                            padding: const EdgeInsets.fromLTRB(24, 0, 24, 18),
                            child: CaseCard(
                              surface: surface,
                              primary: primary,
                              accent: secondary,
                              tagText: tagText,
                              tagColor: isDanger ? danger : secondary,
                              tagTextColor: isDanger ? danger : primary,
                              iconGradient: LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: isDanger
                                    ? const [
                                  Color(0xFFBF121D),
                                  Color(0xFFF8FAFC)
                                ]
                                    : const [
                                  Color(0xFF465467),
                                  Color(0xFFA4C9DA)
                                ],
                              ),
                              title: title,
                              day: _computeDayLabel(
                                data['startDate'] ??
                                    data['createdAt'] ??
                                    data['surgeryDate'],
                              ),
                              startDate: startDate,
                              lastUpdated: lastUpdated,
                              score: score,

                              // ✅ FIX: pass caseNumber to details screen
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
                              isDanger: isDanger,
                            ),
                          );
                        }),

                      // Closed label
                      Padding(
                        padding: const EdgeInsets.fromLTRB(24, 6, 24, 10),
                        child: Row(
                          children: [
                            Container(
                              width: 8,
                              height: 8,
                              decoration: BoxDecoration(
                                color: secondary,
                                borderRadius: BorderRadius.circular(999),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              "Closed Cases",
                              style: GoogleFonts.dmSans(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: const Color(0xFF0F172A),
                                height: 24 / 16,
                              ),
                            ),
                          ],
                        ),
                      ),

                      if (closed.isEmpty)
                        Padding(
                          padding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
                          child: Text(
                            "No closed cases yet.",
                            style: GoogleFonts.inter(
                              fontSize: 13,
                              color: const Color(0xFF475569),
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        )
                      else
                        ...closed.map((doc) {
                          final data = doc.data();
                          final caseId = doc.id;

                          final caseNo = caseNumberById[caseId] ?? 0;
                          final title = caseNo > 0 ? "Case $caseNo" : "Case";

                          final startDate = _formatDate(
                            data['startDate'] ??
                                data['surgeryDate'] ??
                                data['createdAt'],
                          );
                          final lastUpdated = _formatDate(
                            data['lastUpdated'] ?? data['createdAt'],
                          );
                          final score = (data['infectionScore']?.toString()) ?? "--";

                          return Padding(
                            padding: const EdgeInsets.fromLTRB(24, 0, 24, 18),
                            child: CaseCard(
                              surface: surface,
                              primary: primary,
                              accent: secondary,
                              tagText: "Closed",
                              tagColor: const Color(0xFF94A3B8),
                              tagTextColor: const Color(0xFF475569),
                              iconGradient: const LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: [Color(0xFF475569), Color(0xFFE2E8F0)],
                              ),
                              title: title,
                              day: _computeDayLabel(
                                data['startDate'] ??
                                    data['createdAt'] ??
                                    data['surgeryDate'],
                              ),
                              startDate: startDate,
                              lastUpdated: lastUpdated,
                              score: score,

                              // ✅ FIX: pass caseNumber to details screen
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
                              isDanger: false,
                            ),
                          );
                        }),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),

      bottomNavigationBar: AppBottomNav(
        currentIndex: 1,
        onNewTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const CreateCaseScreen()),
          );
        },
      ),
    );
  }
}

/* ===================== Helpers ===================== */

bool _isDangerTag(String tag) {
  final t = tag.toLowerCase();
  return t.contains('high') || t.contains('danger') || t.contains('risk');
}

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

/* ===================== Small UI Widgets ===================== */

class _BackButtonChip extends StatelessWidget {
  const _BackButtonChip({required this.primary, required this.onTap});

  final Color primary;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        height: 40,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: primary.withOpacity(0.25)),
          color: primary.withOpacity(0.06),
        ),
        child: Row(
          children: [
            Icon(Icons.arrow_back_ios_new, size: 16, color: primary),
            const SizedBox(width: 6),
            Text(
              "Back",
              style: GoogleFonts.inter(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: primary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PrimaryButton extends StatelessWidget {
  const _PrimaryButton({
    required this.label,
    required this.color,
    required this.icon,
    required this.onTap,
  });

  final String label;
  final Color color;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(15),
      child: Container(
        width: 120,
        height: 40,
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(15),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF63A2BF).withOpacity(0.20),
              blurRadius: 15,
              offset: const Offset(0, 4),
              spreadRadius: -4,
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 16, color: const Color(0xFFF8FAFC)),
            const SizedBox(width: 8),
            Text(
              label,
              style: GoogleFonts.dmSans(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: const Color(0xFFF8FAFC),
                height: 20 / 14,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({
    required this.primary,
    required this.secondary,
    required this.onCreate,
  });

  final Color primary;
  final Color secondary;
  final VoidCallback onCreate;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(24, 18, 24, 90),
      children: [
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(18),
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [primary.withOpacity(0.9), secondary.withOpacity(0.8)],
                  ),
                ),
                child: const Icon(Icons.folder_outlined, color: Colors.white),
              ),
              const SizedBox(height: 12),
              Text(
                "No Cases Yet",
                style: GoogleFonts.dmSans(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF0F172A),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                "Create your first case to start monitoring your wound healing progress.",
                style: GoogleFonts.inter(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w500,
                  color: const Color(0xFF475569),
                  height: 1.3,
                ),
              ),
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: onCreate,
                  icon: const Icon(Icons.add),
                  label: const Text("Create New Case"),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
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
            color: const Color(0xFFBF121D),
            fontWeight: FontWeight.w600,
          ),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}

/* ===================== Case Card ===================== */

class CaseCard extends StatelessWidget {
  const CaseCard({
    super.key,
    required this.surface,
    required this.primary,
    required this.accent,
    required this.tagText,
    required this.tagColor,
    required this.tagTextColor,
    required this.iconGradient,
    required this.title,
    required this.day,
    required this.startDate,
    required this.lastUpdated,
    required this.score,
    required this.onDashboard,
    required this.onDetails,
    this.isDanger = false,
  });

  final Color surface;
  final Color primary;
  final Color accent;

  final String tagText;
  final Color tagColor;
  final Color tagTextColor;

  final LinearGradient iconGradient;

  final String title;
  final String day;
  final String startDate;
  final String lastUpdated;
  final String score;

  final VoidCallback onDashboard;
  final VoidCallback onDetails;

  final bool isDanger;

  @override
  Widget build(BuildContext context) {
    final text = const Color(0xFF0F172A);
    final muted = const Color(0xFF36404F);
    final border = const Color(0xFFC8D3DF);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: accent.withOpacity(0.25),
            blurRadius: 30,
            offset: const Offset(0, 8),
            spreadRadius: -8,
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _IconBadge(gradient: iconGradient),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: GoogleFonts.dmSans(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: text,
                        height: 28 / 18,
                      ),
                    ),
                    Text(
                      day,
                      style: GoogleFonts.dmSans(
                        fontSize: 14,
                        fontWeight: FontWeight.w400,
                        color: text,
                        height: 20 / 14,
                      ),
                    ),
                  ],
                ),
              ),
              _TagChip(
                text: tagText,
                color: tagColor,
                textColor: tagTextColor,
              ),
            ],
          ),
          const SizedBox(height: 14),

          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              "      Start Date                           Last Updated",
              style: GoogleFonts.inter(
                fontSize: 12.9,
                fontWeight: FontWeight.w400,
                color: muted,
                height: 20 / 12.9,
              ),
            ),
          ),
          const SizedBox(height: 10),

          Row(
            children: [
              _DateRow(icon: Icons.calendar_today_outlined, label: startDate),
              const SizedBox(width: 16),
              _DateRow(icon: Icons.access_time, label: lastUpdated),
            ],
          ),
          const SizedBox(height: 16),

          Container(
            padding: const EdgeInsets.only(top: 16),
            decoration: BoxDecoration(
              border: Border(top: BorderSide(color: border, width: 1)),
            ),
            child: Row(
              children: [
                Text(
                  "Infection Score",
                  style: GoogleFonts.dmSans(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: text,
                    height: 20 / 14,
                  ),
                ),
                const Spacer(),
                Text(
                  score,
                  style: GoogleFonts.dmSans(
                    fontSize: 24,
                    fontWeight: FontWeight.w700,
                    color: text,
                    height: 32 / 24,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          SizedBox(
            height: 26,
            child: Row(
              children: [
                _ActionChip(
                  label: "View Details",
                  color: accent,
                  textColor: primary,
                  onTap: onDetails,
                ),
                const SizedBox(width: 10),
                _ActionChip(
                  label: "View Dashboard",
                  color: accent,
                  textColor: primary,
                  onTap: onDashboard,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DateRow extends StatelessWidget {
  const _DateRow({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Row(
        children: [
          Icon(icon, size: 16, color: const Color(0xFF0F172A)),
          const SizedBox(width: 8),
          Text(
            label,
            style: GoogleFonts.dmSans(
              fontSize: 14,
              fontWeight: FontWeight.w400,
              color: const Color(0xFF0F172A),
              height: 20 / 14,
            ),
          ),
        ],
      ),
    );
  }
}

class _IconBadge extends StatelessWidget {
  const _IconBadge({required this.gradient});
  final LinearGradient gradient;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: gradient,
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF63A2BF).withOpacity(0.25),
            blurRadius: 30,
            offset: const Offset(0, 8),
            spreadRadius: -8,
          ),
        ],
      ),
      child: const Center(
        child: Icon(Icons.folder_outlined, color: Colors.white, size: 24),
      ),
    );
  }
}

class _TagChip extends StatelessWidget {
  const _TagChip({
    required this.text,
    required this.color,
    required this.textColor,
  });

  final String text;
  final Color color;
  final Color textColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.10),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withOpacity(0.20)),
      ),
      child: Text(
        text,
        style: GoogleFonts.inter(
          fontSize: 11.4,
          fontWeight: FontWeight.w600,
          color: textColor,
          height: 16 / 11.4,
        ),
      ),
    );
  }
}

class _ActionChip extends StatelessWidget {
  const _ActionChip({
    required this.label,
    required this.color,
    required this.textColor,
    required this.onTap,
  });

  final String label;
  final Color color;
  final Color textColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: Container(
          height: 26,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: color.withOpacity(0.10),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: color.withOpacity(0.20)),
          ),
          child: Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 13.1,
              fontWeight: FontWeight.w500,
              color: textColor,
              height: 20 / 13.1,
            ),
          ),
        ),
      ),
    );
  }
}
