import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_fonts/google_fonts.dart';

import '../widgets/bottom_nav.dart';
import 'upload_wound_image_screen.dart';

class WhqScreen extends StatefulWidget {
  const WhqScreen({super.key, required this.caseId});
  final String caseId;

  @override
  State<WhqScreen> createState() => _WhqScreenState();
}

class _WhqScreenState extends State<WhqScreen> {
  // UI palette
  static const bg = Color(0xFFFFFFFF);
  static const cardBg = Color(0xFFD8E7EF);
  static const primary = Color(0xFF3B7691);
  static const border = Color(0xFFC8D3DF);

  bool _isNavigating = false;

  // ✅ Language toggle
  WhqLang _lang = WhqLang.en;

  bool saving = false;
  int index = 0;

  /// Store answers in a language-agnostic way:
  /// - likert: 0/1/2
  /// - yesNo: 1/0
  final Map<String, int> answers = {};

  // ✅ Options by language (display only)
  List<String> get _likertOptions =>
      _lang == WhqLang.en ? _likertEn : _likertAr;
  List<String> get _yesNoOptions => _lang == WhqLang.en ? _yesNoEn : _yesNoAr;

  static const List<String> _likertEn = ["Not at all", "A little", "A lot"];
  static const List<String> _likertAr = ["أبدًا", "قليلًا", "كثيرًا"];

  static const List<String> _yesNoEn = ["Yes", "No"];
  static const List<String> _yesNoAr = ["نعم", "لا"];

  late final List<_Question> questions = [
    _Question(
      id: "q1",
      en: "Was the area around the wound warmer than the surrounding skin?",
      ar: "هل كانت المنطقة حول الجرح أدفأ من الجلد المحيط؟",
      type: _QType.likert3,
    ),
    _Question(
      id: "q2",
      en: "Has any part of the wound leaked blood-stained fluid?",
      ar: "هل خرج من أي جزء من الجرح سائل ممزوج بالدم؟",
      type: _QType.likert3,
    ),
    _Question(
      id: "q3",
      en: "Have the edges of any part of the wound separated or gaped open of their accord?",
      ar: "هل تباعدت حواف أي جزء من الجرح أو انفتحت من تلقاء نفسها؟",
      type: _QType.likert3,
    ),
    _Question(
      id: "q4",
      en: "If the wound edges opened: Did the flesh beneath the skin or the inside sutures also separate?",
      ar: "إذا انفتحت حواف الجرح: هل تباعد اللحم تحت الجلد أو الغرز الداخلية أيضًا؟",
      type: _QType.likert3,
    ),
    _Question(
      id: "q5",
      en: "Has the area around the wound become swollen?",
      ar: "هل أصبحت المنطقة حول الجرح متورمة؟",
      type: _QType.likert3,
    ),
    _Question(
      id: "q6",
      en: "Has the wound been smelly?",
      ar: "هل كانت رائحة الجرح كريهة؟",
      type: _QType.likert3,
    ),
    _Question(
      id: "q7",
      en: "Has the wound been painful to touch?",
      ar: "هل كان الجرح مؤلمًا عند اللمس؟",
      type: _QType.likert3,
    ),
    _Question(
      id: "q8",
      en: "Has any part of the wound leaked thin, clear fluid?",
      ar: "هل خرج من أي جزء من الجرح سائل شفاف وخفيف؟",
      type: _QType.likert3,
    ),
    _Question(
      id: "q9",
      en: "Have you sought advice because of a problem with your wound, other than at a planned follow-up appointment?",
      ar: "هل طلبتِ/طلبتَ استشارة بسبب مشكلة في الجرح غير موعد المتابعة المخطط له؟",
      type: _QType.yesNo,
    ),
    _Question(
      id: "q10",
      en: "Has anything been put on the skin to cover the wound? (dressing)",
      ar: "هل تم وضع شيء على الجلد لتغطية الجرح؟ (ضماد)",
      type: _QType.yesNo,
    ),
    _Question(
      id: "q11",
      en: "Have you been back into hospital for a problem with your wound?",
      ar: "هل عدتِ/عدتَ للمستشفى بسبب مشكلة في الجرح؟",
      type: _QType.yesNo,
    ),
    _Question(
      id: "q12",
      en: "Have you been given medicines (antibiotics) for a problem with your wound?",
      ar: "هل تم إعطاؤك أدوية (مثل المضادات الحيوية) بسبب مشكلة في الجرح؟",
      type: _QType.yesNo,
    ),
    _Question(
      id: "q13",
      en: "Have the edges of your wound been separated by a doctor or nurse?",
      ar: "هل قام طبيب/ممرضة بفصل حواف الجرح؟",
      type: _QType.yesNo,
    ),
    _Question(
      id: "q14",
      en: "Has your wound been scraped or cut to remove any unwanted flesh?",
      ar: "هل تم كشط/قطع الجرح لإزالة أنسجة غير مرغوبة؟",
      type: _QType.yesNo,
    ),
    _Question(
      id: "q15",
      en: "Has thick, yellow or green fluid (pus) been drained from your wound by a doctor or nurse?",
      ar: "هل تم تصريف سائل سميك أصفر أو أخضر (صديد) من الجرح بواسطة طبيب/ممرضة؟",
      type: _QType.yesNo,
    ),
    _Question(
      id: "q16",
      en: "Have you had to go back to the operating room for treatment of a problem with your wound?",
      ar: "هل اضطررتِ/اضطررتَ للعودة لغرفة العمليات لعلاج مشكلة في الجرح؟",
      type: _QType.yesNo,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return const Scaffold(body: Center(child: Text("User not logged in")));
    }

    final q = questions[index];
    final options = q.type == _QType.likert3 ? _likertOptions : _yesNoOptions;

    final remaining = (questions.length - 1) - index;
    final bool isFirst = index == 0;
    final bool isLast = index == questions.length - 1;
    final bool hasAnswer = answers[q.id] != null;

    final titleText = _lang == WhqLang.en
        ? "Wound Healing Questionnaire"
        : "استبيان التئام الجروح";

    final remainingText = _lang == WhqLang.en
        ? "$remaining questions remaining"
        : "متبقي $remaining سؤال";

    final prevText = _lang == WhqLang.en ? "Previous" : "السابق";
    final doneText = _lang == WhqLang.en ? "Done" : "تم";

    return Scaffold(
      backgroundColor: bg,

      bottomNavigationBar: SafeArea(
        top: false,
        child: Container(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
          decoration: BoxDecoration(
            color: bg,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 14,
                offset: const Offset(0, -6),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Previous / Done row
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (!isFirst)
                    SizedBox(
                      width: 120,
                      height: 44,
                      child: OutlinedButton(
                        onPressed: saving ? null : () => setState(() => index--),
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: primary, width: 1.2),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(999),
                          ),
                        ),
                        child: Text(
                          prevText,
                          style: GoogleFonts.inter(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: primary,
                          ),
                        ),
                      ),
                    ),
                  if (!isFirst && isLast) const SizedBox(width: 12),
                  if (isLast)
                    SizedBox(
                      width: 120,
                      height: 44,
                      child: OutlinedButton(
                        onPressed: (saving || !hasAnswer)
                            ? null
                            : () async => _submitAllAnswers(user.uid),
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: primary, width: 1.2),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(999),
                          ),
                        ),
                        child: saving
                            ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                            : Text(
                          doneText,
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
              const AppBottomNav(currentIndex: 1),
            ],
          ),
        ),
      ),

      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 170),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Back
              IconButton(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(
                  Icons.arrow_back_ios_new,
                  size: 18,
                  color: Color(0xFF0F172A),
                ),
              ),
              const SizedBox(height: 6),

              // ✅ Language toggle row (top)
              Row(
                children: [
                  Expanded(
                    child: Text(
                      titleText,
                      style: GoogleFonts.dmSans(
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF0F172A),
                      ),
                    ),
                  ),
                  _LangToggle(
                    value: _lang,
                    onChanged: (v) => setState(() => _lang = v),
                  ),
                ],
              ),
              const SizedBox(height: 6),

              Text(
                remainingText,
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
                      padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.45),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Text(
                        _lang == WhqLang.en
                            ? "Question ${index + 1} of ${questions.length}"
                            : "سؤال ${index + 1} من ${questions.length}",
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFF0F172A),
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),

                    Text(
                      _lang == WhqLang.en ? q.en : q.ar,
                      textDirection: _lang == WhqLang.ar
                          ? TextDirection.rtl
                          : TextDirection.ltr,
                      style: GoogleFonts.inter(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFF1F2937),
                        height: 1.35,
                      ),
                    ),
                    const SizedBox(height: 14),

                    Column(
                      children: List.generate(options.length, (i) {
                        final opt = options[i];
                        final selected = answers[q.id] == _optionValue(q.type, i);

                        return Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: InkWell(
                            onTap: (saving || _isNavigating)
                                ? null
                                : () async {
                              setState(() {
                                answers[q.id] = _optionValue(q.type, i);
                                _isNavigating = true;
                              });

                              await Future.delayed(
                                const Duration(milliseconds: 250),
                              );
                              if (!mounted) return;

                              if (!isLast) {
                                setState(() {
                                  index++;
                                  _isNavigating = false;
                                });
                              } else {
                                await _submitAllAnswers(user.uid);
                                if (mounted) {
                                  setState(() => _isNavigating = false);
                                }
                              }
                            },
                            borderRadius: BorderRadius.circular(10),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              width: double.infinity,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 12,
                              ),
                              decoration: BoxDecoration(
                                color: selected ? Colors.white : Colors.transparent,
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  color: selected ? primary : border,
                                  width: selected ? 2.0 : 1,
                                ),
                                boxShadow: selected
                                    ? [
                                  BoxShadow(
                                    color: primary.withOpacity(0.1),
                                    blurRadius: 4,
                                    offset: const Offset(0, 2),
                                  )
                                ]
                                    : [],
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    width: 18,
                                    height: 18,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                        color: selected
                                            ? primary
                                            : Colors.grey[400]!,
                                        width: selected ? 5 : 1,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Text(
                                      opt,
                                      textDirection: _lang == WhqLang.ar
                                          ? TextDirection.rtl
                                          : TextDirection.ltr,
                                      style: GoogleFonts.inter(
                                        fontSize: 13.5,
                                        color: const Color(0xFF111827),
                                        fontWeight: selected
                                            ? FontWeight.w700
                                            : FontWeight.w500,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      }),
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

  /// Convert option index to stored numeric value
  /// likert3: 0,1,2
  /// yesNo: Yes=1, No=0 (index 0 => 1, index 1 => 0)
  int _optionValue(_QType type, int optionIndex) {
    if (type == _QType.likert3) return optionIndex; // 0..2
    // yesNo: ["Yes","No"] or ["نعم","لا"]
    return optionIndex == 0 ? 1 : 0;
  }

  Future<void> _submitAllAnswers(String uid) async {
    setState(() => saving = true);

    final now = DateTime.now();
    final dayId =
        "${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}";
    final submissionId = now.millisecondsSinceEpoch.toString();

    final responsesRef = FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('cases')
        .doc(widget.caseId)
        .collection('whqResponses')
        .doc(submissionId);

    final int questionnaireScore = _computeScore(answers);

    // Store answers as numeric (language independent) + store chosen language for UI
    await responsesRef.set({
      "caseId": widget.caseId,
      "createdAt": FieldValue.serverTimestamp(),
      "updatedAt": FieldValue.serverTimestamp(),

      "finalScore": null,

      "userResponse": {
        "answers": answers, // ✅ numeric
        "questionnaireScore": questionnaireScore,
        "dateId": dayId,
        "version": 1,
        "language": _lang.name, // "en" or "ar"
      },

      "image": null,
      "vitals": null,
    }, SetOptions(merge: true));

    await FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('cases')
        .doc(widget.caseId)
        .set({
      "lastWhqAt": FieldValue.serverTimestamp(),
      "lastWhqScore": questionnaireScore,
      "lastUpdated": FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    if (!mounted) return;
    setState(() => saving = false);

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => UploadWoundImageScreen(
          caseId: widget.caseId,
          whqResponseId: submissionId,
        ),
      ),
    );
  }

  int _computeScore(Map<String, int> a) {
    // Your current scoring is simply summing:
    // likert: 0/1/2
    // yesNo: 1/0
    int s = 0;
    for (final q in questions) {
      final v = a[q.id];
      if (v == null) continue;
      s += v;
    }
    return s;
  }
}

enum WhqLang { en, ar }
enum _QType { likert3, yesNo }

class _Question {
  final String id;
  final String en;
  final String ar;
  final _QType type;
  _Question({
    required this.id,
    required this.en,
    required this.ar,
    required this.type,
  });
}

/// Small segmented toggle: EN / عربي
class _LangToggle extends StatelessWidget {
  const _LangToggle({required this.value, required this.onChanged});
  final WhqLang value;
  final ValueChanged<WhqLang> onChanged;

  static const primary = Color(0xFF3B7691);

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 36,
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: primary.withOpacity(0.25)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _chip(
            text: "EN",
            selected: value == WhqLang.en,
            onTap: () => onChanged(WhqLang.en),
          ),
          _chip(
            text: "عربي",
            selected: value == WhqLang.ar,
            onTap: () => onChanged(WhqLang.ar),
          ),
        ],
      ),
    );
  }

  Widget _chip({
    required String text,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        curve: Curves.easeOutCubic,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: selected ? primary : Colors.transparent,
          borderRadius: BorderRadius.circular(999),
        ),
        child: Text(
          text,
          style: GoogleFonts.inter(
            fontSize: 12.5,
            fontWeight: FontWeight.w800,
            color: selected ? Colors.white : primary,
          ),
        ),
      ),
    );
  }
}