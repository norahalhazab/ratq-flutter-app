// whq_screen.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_fonts/google_fonts.dart';

// Update these imports to match your project paths
import 'dashboard_screen.dart';
import 'cases_screen.dart';
import 'settings_screen.dart';

class WhqScreen extends StatefulWidget {
  const WhqScreen({super.key, required this.caseId});
  final String caseId;

  @override
  State<WhqScreen> createState() => _WhqScreenState();
}

class _WhqScreenState extends State<WhqScreen> {
  static const bg = Color(0xFFFFFFFF);
  static const cardBg = Color(0xFFD8E7EF);
  static const primary = Color(0xFF3B7691);
  static const border = Color(0xFFC8D3DF);

  static const likertOptions = ["Not at all", "A little bit", "Quite a bit", "A lot"];
  static const yesNoOptions = ["Yes", "No"];

  late final List<_Question> questions = [
    _Question(id: "q1", text: "Was the area around the wound warmer than the surrounding skin?", type: _QType.likert4),
    _Question(id: "q2", text: "Has any part of the wound leaked blood-stained fluid? (haemoserous exudate)", type: _QType.likert4),
    _Question(id: "q3", text: "Have the edges of any part of the wound separated/gaped open on their own accord? (spontaneous dehiscence)", type: _QType.likert4),
    _Question(id: "q4", text: "If yes, Did the deeper tissue also separate?", type: _QType.likert4),
    _Question(id: "q5", text: "Has the area around the wound become swollen?", type: _QType.likert4),
    _Question(id: "q6", text: "Has the wound been smelly?", type: _QType.likert4),
    _Question(id: "q7", text: "Has the wound been painful to touch?", type: _QType.likert4),
    _Question(
      id: "q8",
      text: "Have you sought advice because of a problem with your wound, other than at a planned follow-up appointment?",
      type: _QType.yesNo,
    ),
    _Question(id: "q9", text: "Has anything been put on the skin to cover the wound? (dressing)", type: _QType.yesNo),
    _Question(id: "q10", text: "Have you been back into hospital for treatment of a problem with your wound?", type: _QType.yesNo),
    _Question(id: "q11", text: "Have you been back into hospital for treatment of a problem with your wound?", type: _QType.yesNo),
    _Question(id: "q12", text: "Have you been given antibiotics for a problem with your wound?", type: _QType.yesNo),
    _Question(id: "q13", text: "Have the edges of your wound been deliberately separated by a doctor or nurse?", type: _QType.yesNo),
    _Question(id: "q14", text: "Has your wound been scraped or cut to remove any unwanted tissue?", type: _QType.yesNo),
    _Question(id: "q15", text: "Has your wound been drained?", type: _QType.yesNo),
  ];

  int index = 0;
  bool saving = false;
  final Map<String, String> answers = {};

  int selectedNavIndex = 1; // 0 Home, 1 Cases, 2 Alerts, 3 Settings

  void _onNavTap(int i) {
    setState(() => selectedNavIndex = i);

    switch (i) {
      case 0:
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (_) => const DashboardScreen()),
              (route) => false,
        );
        break;
      case 1:
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (_) => const CasesScreen()),
              (route) => false,
        );
        break;
      case 2:
      // If you have Alerts, replace this later.
        break;
      case 3:
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (_) => const SettingsScreen()),
              (route) => false,
        );
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return const Scaffold(body: Center(child: Text("User not logged in")));
    }

    final q = questions[index];
    final options = q.type == _QType.likert4 ? likertOptions : yesNoOptions;

    final remaining = (questions.length - 1) - index;
    final bool isFirst = index == 0;
    final bool isLast = index == questions.length - 1;
    final bool hasAnswer = answers[q.id] != null;

    return Scaffold(
      backgroundColor: bg,

      // ✅ Fixed bottom area with buttons + nav
      bottomNavigationBar: Padding(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (!isFirst)
                  SizedBox(
                    width: 120,
                    height: 44,
                    child: OutlinedButton(
                      onPressed: saving
                          ? null
                          : () {
                        setState(() => index--);
                      },
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: primary, width: 1.2),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
                      ),
                      child: Text(
                        "Previous",
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: primary,
                        ),
                      ),
                    ),
                  ),
                if (!isFirst) const SizedBox(width: 12),
                SizedBox(
                  width: 120,
                  height: 44,
                  child: OutlinedButton(
                    onPressed: saving
                        ? null
                        : (!hasAnswer
                        ? null
                        : () async {
                      if (!isLast) {
                        setState(() => index++);
                      } else {
                        await _submitAllAnswers(user.uid);
                      }
                    }),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: primary, width: 1.2),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
                    ),
                    child: saving
                        ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                        : Text(
                      isLast ? "Done" : "Next",
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: primary,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _AppBottomNav(currentIndex: 1, onTap: _onNavTap),
          ],
        ),
      ),

      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 210),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              IconButton(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.arrow_back_ios_new, size: 18, color: Color(0xFF0F172A)),
              ),
              const SizedBox(height: 6),
              Text(
                "Wound Healing Questionnaire",
                style: GoogleFonts.dmSans(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF0F172A),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                "$remaining questions remaining",
                style: GoogleFonts.inter(fontSize: 13, color: Colors.grey[600]),
              ),
              const SizedBox(height: 22),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: cardBg,
                  borderRadius: BorderRadius.circular(22),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.45),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Text(
                        "Question ${index + 1} of ${questions.length}",
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFF0F172A),
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    Text(
                      q.text,
                      style: GoogleFonts.inter(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFF1F2937),
                        height: 1.35,
                      ),
                    ),
                    const SizedBox(height: 14),
                    Column(
                      children: options.map((opt) {
                        final selected = answers[q.id] == opt;
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: InkWell(
                            onTap: saving
                                ? null
                                : () {
                              setState(() {
                                answers[q.id] = opt;
                              });
                            },
                            borderRadius: BorderRadius.circular(10),
                            child: Container(
                              width: double.infinity,
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                              decoration: BoxDecoration(
                                color: selected ? Colors.white : Colors.transparent,
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  color: selected ? primary : border,
                                  width: selected ? 1.4 : 1,
                                ),
                              ),
                              child: Text(
                                opt,
                                style: GoogleFonts.inter(
                                  fontSize: 13.5,
                                  color: const Color(0xFF111827),
                                  fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                                ),
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _submitAllAnswers(String uid) async {
    setState(() => saving = true);

    final now = DateTime.now();
    final dayId = "${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}";

    final responsesRef = FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('cases')
        .doc(widget.caseId)
        .collection('whqResponses')
        .doc(dayId);

    final int whqScore = _computeScore(answers);

    await responsesRef.set({
      "caseId": widget.caseId,
      "dateId": dayId,
      "createdAt": FieldValue.serverTimestamp(),
      "updatedAt": FieldValue.serverTimestamp(),
      "score": whqScore,
      "answers": answers,
      "version": 1,
    }, SetOptions(merge: true));

    await FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('cases')
        .doc(widget.caseId)
        .set({
      "lastWhqAt": FieldValue.serverTimestamp(),
      "lastWhqScore": whqScore,
      "lastUpdated": FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    if (!mounted) return;
    setState(() => saving = false);

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Questionnaire saved successfully")),
    );
    Navigator.pop(context);
  }

  int _computeScore(Map<String, String> a) {
    int s = 0;

    int likertValue(String v) {
      switch (v) {
        case "Not at all":
          return 0;
        case "A little bit":
          return 1;
        case "Quite a bit":
          return 2;
        case "A lot":
          return 3;
        default:
          return 0;
      }
    }

    int yesNoValue(String v) => v == "Yes" ? 1 : 0;

    for (final q in questions) {
      final v = a[q.id];
      if (v == null) continue;
      if (q.type == _QType.likert4) s += likertValue(v);
      if (q.type == _QType.yesNo) s += yesNoValue(v);
    }
    return s;
  }
}

enum _QType { likert4, yesNo }

class _Question {
  final String id;
  final String text;
  final _QType type;
  _Question({required this.id, required this.text, required this.type});
}

class _AppBottomNav extends StatelessWidget {
  const _AppBottomNav({
    required this.currentIndex,
    required this.onTap,
  });

  final int currentIndex;
  final ValueChanged<int> onTap;

  static const primary = Color(0xFF3B7691);
  static const muted = Color(0xFF475569);

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 57,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: const Border(top: BorderSide(color: Color(0x26000000), width: 1)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _NavItem(
            label: "Home",
            icon: Icons.home_outlined,
            selected: currentIndex == 0,
            primary: primary,
            muted: muted,
            onTap: () => onTap(0),
          ),
          _NavItem(
            label: "Cases",
            icon: Icons.folder_outlined,
            selected: currentIndex == 1,
            primary: primary,
            muted: muted,
            onTap: () => onTap(1),
          ),
          _NavItem(
            label: "Alerts",
            icon: Icons.notifications_none,
            selected: currentIndex == 2,
            primary: primary,
            muted: muted,
            onTap: () => onTap(2),
          ),
          _NavItem(
            label: "Settings",
            icon: Icons.settings_outlined,
            selected: currentIndex == 3,
            primary: primary,
            muted: muted,
            onTap: () => onTap(3),
          ),
        ],
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.label,
    required this.icon,
    required this.selected,
    required this.primary,
    required this.muted,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final Color primary;
  final Color muted;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = selected ? primary : muted;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: SizedBox(
        width: 80,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 20, color: color),
            const SizedBox(height: 4),
            Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 11.6,
                fontWeight: FontWeight.w600,
                color: color,
                height: 16 / 11.6,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
