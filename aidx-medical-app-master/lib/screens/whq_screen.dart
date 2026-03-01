import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_fonts/google_fonts.dart';

import '../utils/app_colors.dart';
import '../widgets/bottom_nav.dart';
import 'upload_wound_image_screen.dart';

class WhqScreen extends StatefulWidget {
  const WhqScreen({super.key, required this.caseId});
  final String caseId;

  @override
  State<WhqScreen> createState() => _WhqScreenState();
}

class _WhqScreenState extends State<WhqScreen> {
  bool _isNavigating = false;
  WhqLang _lang = WhqLang.en;
  bool saving = false;
  int index = 0;

  final Map<String, int> answers = {};

  List<String> get _likertOptions => _lang == WhqLang.en ? _likertEn : _likertAr;
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
        type: _QType.likert3),
    _Question(
        id: "q2",
        en: "Has any part of the wound leaked blood-stained fluid?",
        ar: "هل خرج من أي جزء من الجرح سائل ممزوج بالدم؟",
        type: _QType.likert3),
    _Question(
        id: "q3",
        en: "Have the edges of any part of the wound separated or gaped open of their accord?",
        ar: "هل تباعدت حواف أي جزء من الجرح أو انفتحت من تلقاء نفسها؟",
        type: _QType.likert3),
    _Question(
        id: "q4",
        en: "If the wound edges opened: Did the flesh beneath the skin or the inside sutures also separate?",
        ar: "إذا انفتحت حواف الجرح: هل تباعد اللحم تحت الجلد أو الغرز الداخلية أيضًا؟",
        type: _QType.likert3),
    _Question(
        id: "q5",
        en: "Has the area around the wound become swollen?",
        ar: "هل أصبحت المنطقة حول الجرح متورمة؟",
        type: _QType.likert3),
    _Question(
        id: "q6",
        en: "Has the wound been smelly?",
        ar: "هل كانت رائحة الجرح كريهة؟",
        type: _QType.likert3),
    _Question(
        id: "q7",
        en: "Has the wound been painful to touch?",
        ar: "هل كان الجرح مؤلمًا عند اللمس؟",
        type: _QType.likert3),
    _Question(
        id: "q8",
        en: "Has any part of the wound leaked thin, clear fluid?",
        ar: "هل خرج من أي جزء من الجرح سائل شفاف وخفيف؟",
        type: _QType.likert3),
    _Question(
        id: "q9",
        en: "Have you sought advice because of a problem with your wound?",
        ar: "هل طلبتِ/طلبتَ استشارة بسبب مشكلة في الجرح؟",
        type: _QType.yesNo),
    _Question(
        id: "q10",
        en: "Has anything been put on the skin to cover the wound? (dressing)",
        ar: "هل تم وضع شيء على الجلد لتغطية الجرح؟ (ضماد)",
        type: _QType.yesNo),
    _Question(
        id: "q11",
        en: "Have you been back into hospital for a problem with your wound?",
        ar: "هل عدتِ/عدتَ للمستشفى بسبب مشكلة في الجرح؟",
        type: _QType.yesNo),
    _Question(
        id: "q12",
        en: "Have you been given medicines (antibiotics) for your wound?",
        ar: "هل تم إعطاؤك أدوية بسبب مشكلة في الجرح؟",
        type: _QType.yesNo),
    _Question(
        id: "q13",
        en: "Have the edges of your wound been separated by a doctor or nurse?",
        ar: "هل قام طبيب/ممرضة بفصل حواف الجرح؟",
        type: _QType.yesNo),
    _Question(
        id: "q14",
        en: "Has your wound been scraped or cut to remove unwanted flesh?",
        ar: "هل تم كشط/قطع الجرح لإزالة أنسجة غير مرغوبة؟",
        type: _QType.yesNo),
    _Question(
        id: "q15",
        en: "Has pus been drained from your wound by a doctor or nurse?",
        ar: "هل تم تصريف صديد من الجرح بواسطة طبيب/ممرضة؟",
        type: _QType.yesNo),
    _Question(
        id: "q16",
        en: "Have you had to go back to the operating room for your wound?",
        ar: "هل اضطررتِ/اضطررتَ للعودة لغرفة العمليات؟",
        type: _QType.yesNo),
  ];

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return const Scaffold(body: Center(child: Text("User not logged in")));
    }

    final q = questions[index];
    final options = q.type == _QType.likert3 ? _likertOptions : _yesNoOptions;

    final bool isFirst = index == 0;
    final bool isLast = index == questions.length - 1;
    final bool hasAnswer = answers[q.id] != null;

    final titleText = _lang == WhqLang.en
        ? "Wound Healing Questionnaire"
        : "استبيان التئام الجروح";

    final subtitleText = _lang == WhqLang.en
        ? "Answer the following questions"
        : "أجيبي/أجب على الأسئلة التالية";

    final prevText = _lang == WhqLang.en ? "Previous" : "السابق";
    final doneText = _lang == WhqLang.en ? "Done" : "تم";

    final progressValue = (index + 1) / questions.length;

    return Scaffold(
      backgroundColor: AppColors.backgroundColor,
      bottomNavigationBar: AppBottomNav(
        currentIndex: 1,
        onNewTap: () {},
      ),
      body: Stack(
        children: [
          const _BlueGlassyBackground(),
          SafeArea(
            child: Column(
              children: [
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Top bar
                        Row(
                          children: [
                            _WhitePillButton(
                              onTap: () => Navigator.pop(context),
                              child: const Icon(
                                Icons.arrow_back_ios_new_rounded,
                                size: 18,
                                color: AppColors.textPrimary,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                titleText,
                                style: GoogleFonts.dmSans(
                                  fontSize: 22,
                                  fontWeight: FontWeight.w900,
                                  color: AppColors.textPrimary,
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
                          subtitleText,
                          style: GoogleFonts.inter(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textSecondary,
                          ),
                        ),

                        const SizedBox(height: 12),

                        // Progress (NO timer)
                        _GlassyCard(
                          child: Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      _lang == WhqLang.en
                                          ? "Question ${index + 1} of ${questions.length}"
                                          : "سؤال ${index + 1} من ${questions.length}",
                                      style: GoogleFonts.inter(
                                        fontSize: 12.5,
                                        fontWeight: FontWeight.w800,
                                        color: AppColors.textSecondary,
                                      ),
                                    ),
                                    const SizedBox(height: 10),
                                    ClipRRect(
                                      borderRadius: BorderRadius.circular(999),
                                      child: LinearProgressIndicator(
                                        value: progressValue,
                                        minHeight: 8,
                                        backgroundColor: AppColors.dividerColor
                                            .withOpacity(0.35),
                                        valueColor:
                                        AlwaysStoppedAnimation<Color>(
                                            AppColors.primaryColor),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 12),

                        // Question card
                        _GlassyCard(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _lang == WhqLang.en ? q.en : q.ar,
                                textDirection: _lang == WhqLang.ar
                                    ? TextDirection.rtl
                                    : TextDirection.ltr,
                                style: GoogleFonts.inter(
                                  fontSize: 16, // ✅ bigger question
                                  fontWeight: FontWeight.w800,
                                  color: AppColors.textPrimary,
                                  height: 1.35,
                                ),
                              ),
                              const SizedBox(height: 14),

                              Column(
                                children: List.generate(options.length, (i) {
                                  final opt = options[i];
                                  final selected =
                                      answers[q.id] == _optionValue(q.type, i);

                                  return Padding(
                                    padding: const EdgeInsets.only(bottom: 10),
                                    child: InkWell(
                                      onTap: (saving || _isNavigating)
                                          ? null
                                          : () async {
                                        setState(() {
                                          answers[q.id] =
                                              _optionValue(q.type, i);
                                          if (!isLast) {
                                            _isNavigating = true;
                                          }
                                        });

                                        if (isLast) return;

                                        await Future.delayed(
                                            const Duration(
                                                milliseconds: 220));
                                        if (!mounted) return;

                                        setState(() {
                                          index++;
                                          _isNavigating = false;
                                        });
                                      },
                                      borderRadius: BorderRadius.circular(18),
                                      child: AnimatedContainer(
                                        duration:
                                        const Duration(milliseconds: 180),
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 14, vertical: 14),
                                        decoration: BoxDecoration(
                                          borderRadius:
                                          BorderRadius.circular(18),
                                          color: Colors.white.withOpacity(
                                              selected ? 0.95 : 0.80),
                                          border: Border.all(
                                            color: selected
                                                ? AppColors.primaryColor
                                                : AppColors.dividerColor
                                                .withOpacity(0.9),
                                            width: selected ? 2.0 : 1.0,
                                          ),
                                          boxShadow: [
                                            BoxShadow(
                                              color: Colors.black
                                                  .withOpacity(0.05),
                                              blurRadius: 16,
                                              offset: const Offset(0, 10),
                                            ),
                                          ],
                                        ),
                                        child: Row(
                                          children: [
                                            Container(
                                              width: 20,
                                              height: 20,
                                              decoration: BoxDecoration(
                                                shape: BoxShape.circle,
                                                border: Border.all(
                                                  color: selected
                                                      ? AppColors.primaryColor
                                                      : AppColors.textMuted
                                                      .withOpacity(0.5),
                                                  width: 2,
                                                ),
                                              ),
                                              child: AnimatedContainer(
                                                duration: const Duration(
                                                    milliseconds: 160),
                                                margin: const EdgeInsets.all(4),
                                                decoration: BoxDecoration(
                                                  shape: BoxShape.circle,
                                                  color: selected
                                                      ? AppColors.primaryColor
                                                      : Colors.transparent,
                                                ),
                                              ),
                                            ),
                                            const SizedBox(width: 12),
                                            Expanded(
                                              child: Text(
                                                opt,
                                                textDirection: _lang ==
                                                    WhqLang.ar
                                                    ? TextDirection.rtl
                                                    : TextDirection.ltr,
                                                style: GoogleFonts.inter(
                                                  fontSize:
                                                  14.5, // ✅ answers style
                                                  fontWeight: selected
                                                      ? FontWeight.w800
                                                      : FontWeight.w600,
                                                  color: AppColors.textPrimary,
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

                // Bottom controls (above nav bar)
                SafeArea(
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
                            border: Border.all(
                                color:
                                AppColors.dividerColor.withOpacity(0.9)),
                            boxShadow: const [
                              BoxShadow(
                                color: Color(0x22000000),
                                blurRadius: 22,
                                offset: Offset(0, 12),
                              ),
                            ],
                          ),
                          child: Row(
                            children: [
                              if (!isFirst)
                                Expanded(
                                  child: OutlinedButton(
                                    onPressed: saving
                                        ? null
                                        : () => setState(() => index--),
                                    style: OutlinedButton.styleFrom(
                                      side: BorderSide(
                                          color: AppColors.primaryColor
                                              .withOpacity(0.95),
                                          width: 1.2),
                                      shape: RoundedRectangleBorder(
                                        borderRadius:
                                        BorderRadius.circular(999),
                                      ),
                                      padding: const EdgeInsets.symmetric(
                                          vertical: 12),
                                    ),
                                    child: Text(
                                      prevText,
                                      style: GoogleFonts.inter(
                                        fontWeight: FontWeight.w900,
                                        color: AppColors.primaryColor,
                                      ),
                                    ),
                                  ),
                                ),
                              if (!isFirst && isLast)
                                const SizedBox(width: 12),
                              if (isLast)
                                Expanded(
                                  child: ElevatedButton(
                                    onPressed: (saving || !hasAnswer)
                                        ? null
                                        : () async =>
                                        _submitAllAnswers(user.uid),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor:
                                      AppColors.primaryColor,
                                      foregroundColor: Colors.white,
                                      elevation: 0,
                                      shape: RoundedRectangleBorder(
                                        borderRadius:
                                        BorderRadius.circular(999),
                                      ),
                                      padding: const EdgeInsets.symmetric(
                                          vertical: 12),
                                    ),
                                    child: saving
                                        ? const SizedBox(
                                      width: 18,
                                      height: 18,
                                      child:
                                      CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Colors.white,
                                      ),
                                    )
                                        : Text(
                                      doneText,
                                      style: GoogleFonts.inter(
                                        fontWeight: FontWeight.w900,
                                      ),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  int _optionValue(_QType type, int optionIndex) =>
      (type == _QType.likert3) ? optionIndex : (optionIndex == 0 ? 1 : 0);

  Future<void> _submitAllAnswers(String uid) async {
    setState(() => saving = true);

    final now = DateTime.now();
    final submissionId = now.millisecondsSinceEpoch.toString();
    final int questionnaireScore = _computeScore(answers);

    await FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('cases')
        .doc(widget.caseId)
        .collection('whqResponses')
        .doc(submissionId)
        .set({
      "caseId": widget.caseId,
      "createdAt": FieldValue.serverTimestamp(),
      "userResponse": {
        "answers": answers,
        "questionnaireScore": questionnaireScore,
        "language": _lang.name
      },
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
    int s = 0;
    for (var q in questions) {
      if (a[q.id] != null) s += a[q.id]!;
    }
    return s;
  }
}

enum WhqLang { en, ar }
enum _QType { likert3, yesNo }

class _Question {
  final String id, en, ar;
  final _QType type;
  _Question(
      {required this.id,
        required this.en,
        required this.ar,
        required this.type});
}

class _LangToggle extends StatelessWidget {
  const _LangToggle({required this.value, required this.onChanged});
  final WhqLang value;
  final ValueChanged<WhqLang> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 36,
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.92),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: AppColors.dividerColor.withOpacity(0.9)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 14,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _chip("EN", value == WhqLang.en, () => onChanged(WhqLang.en)),
          _chip("عربي", value == WhqLang.ar, () => onChanged(WhqLang.ar)),
        ],
      ),
    );
  }

  Widget _chip(String t, bool s, VoidCallback o) => InkWell(
    onTap: o,
    borderRadius: BorderRadius.circular(999),
    child: AnimatedContainer(
      duration: const Duration(milliseconds: 160),
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: s ? AppColors.primaryColor : Colors.transparent,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Center(
        child: Text(
          t,
          style: GoogleFonts.inter(
            fontSize: 12,
            fontWeight: FontWeight.w900,
            color: s ? Colors.white : AppColors.primaryColor,
          ),
        ),
      ),
    ),
  );
}

/* ===================== Background: blue glassy (match other pages) ===================== */

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
      child: ClipRRect(
        borderRadius: BorderRadius.circular(999),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(999),
              color: Colors.white.withOpacity(0.90),
              border:
              Border.all(color: AppColors.dividerColor.withOpacity(0.9)),
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