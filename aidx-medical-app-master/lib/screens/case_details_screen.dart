import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_fonts/google_fonts.dart';

import 'whq_screen.dart';
import 'cases_screen.dart';
import 'dashboard_screen.dart';
import 'settings.dart';

class CaseDetailsScreen extends StatelessWidget {
  const CaseDetailsScreen({super.key, required this.caseId});
  final String caseId;

  static const bg = Color(0xFFFFFFFF);
  static const cardBg = Color(0xFFD8E7EF);
  static const primary = Color(0xFF3B7691);
  static const secondary = Color(0xFF63A2BF);
  static const border = Color(0xFFC8D3DF);
  static const dangerBtn = Color(0xCC7A0000);

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      return const Scaffold(
        body: Center(child: Text("User not logged in")),
      );
    }

    final caseRef = FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .collection('cases')
        .doc(caseId);

    return Scaffold(
      backgroundColor: bg,
      bottomNavigationBar: AppBottomNav(
        currentIndex: 1,
        onTap: (index) {
          if (index == 1) return;

          Widget target;
          if (index == 0) {
            target = const DashboardScreen();
          } else if (index == 3) {
            target = const SettingsScreen();
          } else {
            return;
          }

          Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(builder: (_) => target),
                (route) => false,
          );
        },
      ),
      body: SafeArea(
        child: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
          stream: caseRef.snapshots(),
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return const Center(child: Text("Something went wrong"));
            }
            if (!snapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }

            final data = snapshot.data!.data()!;
            final title = data['title'] ?? 'Case';
            final status = (data['status'] ?? 'active').toString().toLowerCase();

            final startDate = _formatDate(data['startDate'] ?? data['surgeryDate']);
            final lastUpdated = _formatDate(data['lastUpdated']);

            final scoreRaw = data['infectionScore'];
            final int? score = scoreRaw is int ? scoreRaw : int.tryParse('$scoreRaw');
            final scoreText = score?.toString() ?? '--';
            final assessment = _assessmentFromScore(score);

            return Stack(
              children: [
                SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(20, 10, 20, 120),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Align(
                        alignment: Alignment.topLeft,
                        child: IconButton(
                          onPressed: () => Navigator.pop(context),
                          icon: const Icon(Icons.arrow_back_ios_new, size: 18),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          _FolderBubble(secondary: secondary),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.dmSans(
                                fontSize: 24,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 18),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: cardBg,
                          borderRadius: BorderRadius.circular(24),
                          boxShadow: [
                            BoxShadow(
                              color: secondary.withOpacity(0.25),
                              blurRadius: 30,
                              offset: const Offset(0, 8),
                              spreadRadius: -8,
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Text("Case Overview"),
                                const Spacer(),
                                _StatusChip(
                                  status: status,
                                ),
                              ],
                            ),
                            const SizedBox(height: 14),
                            const Text("Start date"),
                            const SizedBox(height: 6),
                            _InfoRow(icon: Icons.calendar_today_outlined, value: startDate),
                            const SizedBox(height: 14),
                            const Text("Last Updated"),
                            const SizedBox(height: 6),
                            _InfoRow(icon: Icons.access_time, value: lastUpdated),
                            const SizedBox(height: 16),
                            Container(
                              padding: const EdgeInsets.only(top: 16),
                              decoration: const BoxDecoration(
                                border: Border(top: BorderSide(color: border)),
                              ),
                              child: Row(
                                children: [
                                  const Text("Infection Score"),
                                  const Spacer(),
                                  Text(
                                    scoreText,
                                    style: GoogleFonts.dmSans(
                                      fontSize: 24,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 12),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                              decoration: BoxDecoration(
                                color: secondary.withOpacity(0.10),
                                borderRadius: BorderRadius.circular(999),
                              ),
                              child: Text(
                                assessment,
                                style: GoogleFonts.inter(
                                  fontSize: 11.4,
                                  fontWeight: FontWeight.w600,
                                  color: primary,
                                ),
                              ),
                            ),
                            const SizedBox(height: 14),
                            SizedBox(
                              width: double.infinity,
                              height: 40,
                              child: ElevatedButton(
                                onPressed: status == 'closed'
                                    ? null
                                    : () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => WhqScreen(caseId: caseId),
                                    ),
                                  );
                                },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: primary,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                ),
                                child: const Text("Start daily check"),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                Align(
                  alignment: Alignment.bottomCenter,
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: const BoxDecoration(color: bg),
                    child: SizedBox(
                      width: double.infinity,
                      height: 40,
                      child: ElevatedButton.icon(
                        onPressed: status == 'closed'
                            ? null
                            : () async {
                          await caseRef.update({
                            'status': 'closed',
                            'lastUpdated': FieldValue.serverTimestamp(),
                          });
                        },
                        icon: const Icon(Icons.delete_outline),
                        label: const Text("Close wound case"),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: dangerBtn,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

/* ---------- UI Components ---------- */

class _FolderBubble extends StatelessWidget {
  const _FolderBubble({required this.secondary});
  final Color secondary;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: const Color(0xFF2F3A4A),
        boxShadow: [
          BoxShadow(
            color: secondary.withOpacity(0.35),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: const Icon(Icons.folder_outlined, color: Colors.white),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.icon, required this.value});
  final IconData icon;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 16),
        const SizedBox(width: 8),
        Text(value),
      ],
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.status});
  final String status;

  @override
  Widget build(BuildContext context) {
    final isClosed = status == 'closed';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: isClosed ? const Color(0xFF64748B) : const Color(0xFF63A2BF).withOpacity(0.18),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        isClosed ? "Closed" : "Active",
        style: GoogleFonts.inter(
          fontSize: 11.4,
          fontWeight: FontWeight.w600,
          color: isClosed ? Colors.white : const Color(0xFF3B7691),
        ),
      ),
    );
  }
}

/* ---------- Helpers ---------- */

String _formatDate(dynamic value) {
  if (value == null) return "--";
  try {
    final DateTime dt = value is Timestamp ? value.toDate() : value;
    return "${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}";
  } catch (_) {
    return "--";
  }
}

String _assessmentFromScore(int? score) {
  if (score == null) return "No data yet";
  if (score <= 2) return "No Signs of Infection";
  if (score <= 5) return "Mild Warning";
  return "High Risk — Seek Care";
}
