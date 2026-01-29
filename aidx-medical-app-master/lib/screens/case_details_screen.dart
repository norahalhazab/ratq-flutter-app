import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_fonts/google_fonts.dart';

import '../widgets/bottom_nav.dart';
import 'whq_screen.dart';

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
      bottomNavigationBar: const AppBottomNav(currentIndex: 1),
      body: SafeArea(
        child: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
          stream: caseRef.snapshots(),
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return const Center(child: Text("Something went wrong"));
            }
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (!snapshot.hasData || !snapshot.data!.exists) {
              return const Center(child: Text("Case not found"));
            }

            final data = snapshot.data!.data() ?? {};

            final title = (data['title'] as String?) ?? 'Case';
            final status = ((data['status'] as String?) ?? 'active').toLowerCase();

            // ✅ Start = createdAt (best) then startDate then surgeryDate
            final startValue = data['createdAt'] ?? data['startDate'] ?? data['surgeryDate'];
            final startDateText = _formatDateTime(startValue);

            // ✅ Last Updated = lastUpdated then createdAt fallback
            final lastValue = data['lastUpdated'] ?? data['createdAt'];
            final lastUpdatedText = _formatDateTime(lastValue);

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
                          icon: const Icon(
                            Icons.arrow_back_ios_new,
                            size: 18,
                            color: Color(0xFF0F172A),
                          ),
                        ),
                      ),
                      const SizedBox(height: 6),

                      Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          const _FolderBubble(secondary: secondary),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.dmSans(
                                fontSize: 24,
                                fontWeight: FontWeight.w700,
                                color: const Color(0xFF0F172A),
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
                                Text(
                                  "Case Overview",
                                  style: GoogleFonts.dmSans(
                                    fontSize: 14,
                                    color: const Color(0xFF0F172A),
                                  ),
                                ),
                                const Spacer(),
                                _StatusChip(status: status),
                              ],
                            ),

                            const SizedBox(height: 14),

                            Text(
                              "Start date",
                              style: GoogleFonts.dmSans(
                                fontSize: 14,
                                color: const Color(0xFF36404F),
                              ),
                            ),
                            const SizedBox(height: 8),

                            // ✅ FIXED: show text
                            _InfoRow(
                              icon: Icons.calendar_today_outlined,
                              value: startDateText,
                            ),

                            const SizedBox(height: 14),

                            Text(
                              "Last Updated",
                              style: GoogleFonts.inter(
                                color: const Color(0xFF36404F),
                                fontSize: 12.9,
                              ),
                            ),
                            const SizedBox(height: 8),

                            // ✅ FIXED: show text
                            _InfoRow(
                              icon: Icons.access_time,
                              value: lastUpdatedText,
                            ),

                            const SizedBox(height: 16),

                            Container(
                              padding: const EdgeInsets.only(top: 16),
                              decoration: const BoxDecoration(
                                border: Border(top: BorderSide(color: border)),
                              ),
                              child: Row(
                                children: [
                                  Text(
                                    "Infection Score",
                                    style: GoogleFonts.dmSans(
                                      fontWeight: FontWeight.w500,
                                      color: const Color(0xFF0F172A),
                                    ),
                                  ),
                                  const Spacer(),
                                  Text(
                                    scoreText,
                                    style: GoogleFonts.dmSans(
                                      fontSize: 24,
                                      fontWeight: FontWeight.w700,
                                      color: const Color(0xFF0F172A),
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
                                border: Border.all(color: secondary.withOpacity(0.20)),
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
                                  disabledBackgroundColor: primary.withOpacity(0.35),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  elevation: 0,
                                ),
                                child: Text(
                                  "Start daily check",
                                  style: GoogleFonts.inter(
                                    fontSize: 13.2,
                                    fontWeight: FontWeight.w500,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            ),

                            const SizedBox(height: 6),

                            Text(
                              "Start: $startDateText • Updated: $lastUpdatedText",
                              style: GoogleFonts.inter(
                                fontSize: 11.5,
                                color: const Color(0xFF64748B),
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
                    decoration: BoxDecoration(
                      color: bg,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.06),
                          blurRadius: 16,
                          offset: const Offset(0, -6),
                        ),
                      ],
                    ),
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
                        icon: const Icon(Icons.delete_outline, color: Colors.white),
                        label: Text(
                          "Close wound case",
                          style: GoogleFonts.inter(
                            fontSize: 13.2,
                            fontWeight: FontWeight.w500,
                            color: Colors.white,
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: dangerBtn,
                          disabledBackgroundColor: dangerBtn.withOpacity(0.35),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                          elevation: 0,
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

class _FolderBubble extends StatelessWidget {
  const _FolderBubble({required this.secondary});
  final Color secondary;

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.center,
      children: [
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: secondary.withOpacity(0.18),
          ),
        ),
        Container(
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
          child: const Icon(Icons.folder_outlined, color: Colors.white, size: 22),
        ),
      ],
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({
    required this.icon,
    required this.value,
  });

  final IconData icon;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 16, color: const Color(0xFF0F172A)),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            value,
            style: GoogleFonts.inter(
              fontSize: 12.8,
              fontWeight: FontWeight.w600,
              color: const Color(0xFF0F172A),
            ),
          ),
        ),
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

    final bgColor = isClosed
        ? const Color(0xFF64748B)
        : const Color(0xFF63A2BF).withOpacity(0.18);

    final textColor = isClosed ? Colors.white : const Color(0xFF3B7691);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: bgColor.withOpacity(0.7)),
      ),
      child: Text(
        isClosed ? "Closed" : "Active",
        style: GoogleFonts.inter(
          fontSize: 11.4,
          fontWeight: FontWeight.w600,
          color: textColor,
        ),
      ),
    );
  }
}

String _formatDateTime(dynamic value) {
  if (value == null) return "--";
  try {
    DateTime dt;

    if (value is Timestamp) {
      dt = value.toDate();
    } else if (value is DateTime) {
      dt = value;
    } else if (value is String) {
      dt = DateTime.tryParse(value) ?? DateTime.now();
    } else {
      return "--";
    }

    final yyyy = dt.year.toString();
    final mm = dt.month.toString().padLeft(2, '0');
    final dd = dt.day.toString().padLeft(2, '0');
    final hh = dt.hour.toString().padLeft(2, '0');
    final min = dt.minute.toString().padLeft(2, '0');

    return "$yyyy-$mm-$dd  $hh:$min";
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
