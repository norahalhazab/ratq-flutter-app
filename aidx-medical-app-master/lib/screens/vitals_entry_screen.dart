import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/smart_watch_simulator_service.dart';
import 'Infection_Assesment.dart';

class VitalsEntryArgs {
  final String caseId;
  final String whqResponseId;

  const VitalsEntryArgs({
    required this.caseId,
    required this.whqResponseId,
  });
}

class VitalsEntryScreen extends StatefulWidget {
  const VitalsEntryScreen({super.key, required this.args});
  final VitalsEntryArgs args;

  @override
  State<VitalsEntryScreen> createState() => _VitalsEntryScreenState();
}

class _VitalsEntryScreenState extends State<VitalsEntryScreen> {
  // Range
  static const double minT = 35.0;
  static const double maxT = 40.0;

  // UI
  static const Color primary = Color(0xFF3B7691);
  static const Color bg = Color(0xFFEAF5FB);

  // state
  double temp = 38.5;
  bool _saving = false;
  String? _error;

  SmartWatchSimulatorService get _service => SmartWatchSimulatorService.instance;

  double get _fill => ((temp - minT) / (maxT - minT)).clamp(0.0, 1.0);

  // smooth color from blue -> red
  Color get _tempColor {
    final t = _fill;
    return Color.lerp(const Color(0xFF38BDF8), const Color(0xFFEF4444), t)!;
  }

  String? _validateTemp(double v) {
    if (v < 30 || v > 45) return "Temperature looks incorrect";
    return null;
  }

  // ✅ NEW: open input dialog when tapping the number
  Future<void> _editTempManually() async {
    if (_saving) return;

    final ctrl = TextEditingController(text: temp.toStringAsFixed(1));

    final newValue = await showDialog<double>(
      context: context,
      barrierDismissible: true,
      builder: (ctx) {
        return AlertDialog(
          title: const Text("Enter temperature"),
          content: TextField(
            controller: ctrl,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(
              hintText: "e.g. 37.7",
            ),
            autofocus: true,
            onSubmitted: (_) {
              final v = double.tryParse(ctrl.text.trim());
              Navigator.pop(ctx, v);
            },
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text("Cancel"),
            ),
            ElevatedButton(
              onPressed: () {
                final v = double.tryParse(ctrl.text.trim());
                Navigator.pop(ctx, v);
              },
              child: const Text("Done"),
            ),
          ],
        );
      },
    );

    if (!mounted || newValue == null) return;

    final err = _validateTemp(newValue);
    if (err != null) {
      setState(() => _error = err);
      return;
    }

    setState(() {
      // clamp to slider range so UI stays consistent
      temp = newValue.clamp(minT, maxT);
      _error = null;
    });
  }

  Future<bool> _saveVitalsToFirestore() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      setState(() => _error = "User not signed in");
      return false;
    }

    final err = _validateTemp(temp);
    if (err != null) {
      setState(() => _error = err);
      return false;
    }

    setState(() {
      _saving = true;
      _error = null;
    });

    try {
      final vitalsData = <String, dynamic>{
        "temperature": double.parse(temp.toStringAsFixed(1)),
        "heartRate": _service.heartRate,
        "bloodPressure": _service.bloodPressure,
        "fromWatch": _service.isConnected, // (إذا تبينه ينشال قولي)
        "capturedAt": FieldValue.serverTimestamp(),
      };

      final whqDocRef = FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('cases')
          .doc(widget.args.caseId)
          .collection('whqResponses')
          .doc(widget.args.whqResponseId);

      await whqDocRef.set({
        "vitals": vitalsData,
        "updatedAt": FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      return true;
    } catch (_) {
      setState(() => _error = "Failed to save vitals");
      return false;
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _onFinish() async {
    if (_saving) return;

    final ok = await _saveVitalsToFirestore();
    if (!mounted || !ok) return;

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => InfectionAssessmentScreen(
          caseId: widget.args.caseId,
          whqResponseId: widget.args.whqResponseId,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Color(0xFF0F172A)),
        centerTitle: true,
        title: Text(
          "Temperature",
          style: GoogleFonts.dmSans(
            fontSize: 26,
            fontWeight: FontWeight.w900,
            color: const Color(0xFF0F172A),
          ),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(18, 4, 18, 0),
                child: Row(
                  children: [
                    // LEFT: Thermometer (✅ bigger)
                    Expanded(
                      flex: 2,
                      child: Center(
                        child: TweenAnimationBuilder<double>(
                          duration: const Duration(milliseconds: 250),
                          tween: Tween(begin: 0, end: _fill),
                          builder: (_, v, __) {
                            return CustomPaint(
                              size: const Size(170, 520),
                              painter: _ThermometerPainter(fill: v),
                            );
                          },
                        ),
                      ),
                    ),

                    const SizedBox(width: 16),

                    // RIGHT: Small temp card centered
                    Expanded(
                      flex: 3,
                      child: Center(
                        child: Container(
                          width: 270,
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.9),
                            borderRadius: BorderRadius.circular(22),
                            border: Border.all(color: const Color(0x22000000)),
                            boxShadow: const [
                              BoxShadow(
                                blurRadius: 22,
                                offset: Offset(0, 14),
                                color: Color(0x14000000),
                              ),
                            ],
                          ),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              // ✅ CHANGED: tap the number to type manually
                              GestureDetector(
                                onTap: _editTempManually,
                                child: Column(
                                  children: [
                                    Text(
                                      "${temp.toStringAsFixed(1)}°C",
                                      textAlign: TextAlign.center,
                                      style: const TextStyle(
                                        fontSize: 24,
                                        fontWeight: FontWeight.w900,
                                        height: 1.0,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      "Tap to type",
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w700,
                                        color: Colors.black.withOpacity(0.45),
                                      ),
                                    ),
                                  ],
                                ),
                              ),

                              const SizedBox(height: 14),

                              _GradientSlider(
                                value: temp,
                                min: minT,
                                max: maxT,
                                onChanged: (v) => setState(() {
                                  temp = v;
                                  _error = null;
                                }),
                              ),

                              const SizedBox(height: 10),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text("${minT.toStringAsFixed(1)}°C",
                                      style: TextStyle(
                                          fontWeight: FontWeight.w700,
                                          color: Colors.black.withOpacity(0.65))),
                                  Text("37.0°C",
                                      style: TextStyle(
                                          fontWeight: FontWeight.w700,
                                          color: Colors.black.withOpacity(0.65))),
                                  Text("${maxT.toStringAsFixed(1)}°C",
                                      style: TextStyle(
                                          fontWeight: FontWeight.w700,
                                          color: Colors.black.withOpacity(0.65))),
                                ],
                              ),

                              if (_error != null) ...[
                                const SizedBox(height: 10),
                                Text(
                                  _error!,
                                  style: const TextStyle(
                                    color: Colors.red,
                                    fontWeight: FontWeight.w800,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // FINISH BUTTON (big at bottom)
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 10, 18, 22),
              child: SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: _saving ? null : _onFinish,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primary,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(999),
                    ),
                    elevation: 0,
                  ),
                  child: _saving
                      ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                      : const Text(
                    "Finish",
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _GradientSlider extends StatelessWidget {
  const _GradientSlider({
    required this.value,
    required this.min,
    required this.max,
    required this.onChanged,
  });

  final double value;
  final double min;
  final double max;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    final t = ((value - min) / (max - min)).clamp(0.0, 1.0);

    return Stack(
      alignment: Alignment.centerLeft,
      children: [
        Container(
          height: 14,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(999),
            gradient: const LinearGradient(
              colors: [
                Color(0xFF38BDF8),
                Color(0xFF22C55E),
                Color(0xFFF59E0B),
                Color(0xFFEF4444),
              ],
            ),
          ),
        ),
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            trackHeight: 14,
            activeTrackColor: Colors.transparent,
            inactiveTrackColor: Colors.transparent,
            overlayShape: SliderComponentShape.noOverlay,
            thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 12),
            thumbColor: Colors.white,
          ),
          child: Slider(
            value: value,
            min: min,
            max: max,
            onChanged: onChanged,
          ),
        ),
        Positioned.fill(
          child: IgnorePointer(
            child: Align(
              alignment: Alignment(-1 + 2 * t, 0),
              child: Container(
                width: 16,
                height: 16,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.black.withOpacity(0.08),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// ✅ One-piece thermometer + ✅ bigger bulb proportion
class _ThermometerPainter extends CustomPainter {
  _ThermometerPainter({required this.fill});
  final double fill; // 0..1

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    final topPad = h * 0.04;
    final bottomPad = h * 0.04;

    final bodyW = w * 0.44;
    final bodyX = (w - bodyW) / 2;
    final bodyTop = topPad;
    final bodyBottom = h - bottomPad;

    final bulbR = bodyW * 0.78;
    final bulbCy = bodyBottom - bulbR;

    final stemTop = bodyTop;
    final stemBottom = bulbCy;
    final stemRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(bodyX, stemTop, bodyW, stemBottom - stemTop),
      Radius.circular(bodyW / 2),
    );

    final outerPath = Path()
      ..addRRect(stemRect)
      ..addOval(Rect.fromCircle(center: Offset(w / 2, bulbCy), radius: bulbR))
      ..fillType = PathFillType.nonZero;

    canvas.save();
    canvas.translate(8, 14);
    canvas.drawPath(outerPath, Paint()..color = const Color(0x16000000));
    canvas.restore();

    canvas.drawPath(outerPath, Paint()..color = const Color(0xFFE5E7EB));

    const inset = 10.0;
    final innerStemRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(
        bodyX + inset,
        stemTop + inset,
        bodyW - inset * 2,
        (stemBottom - stemTop) - inset * 2,
      ),
      Radius.circular((bodyW - inset * 2) / 2),
    );

    final innerBulbR = bulbR - (inset + 2);

    final innerPath = Path()
      ..addRRect(innerStemRect)
      ..addOval(Rect.fromCircle(center: Offset(w / 2, bulbCy), radius: innerBulbR))
      ..fillType = PathFillType.nonZero;

    canvas.drawPath(innerPath, Paint()..color = Colors.white.withOpacity(0.98));

    canvas.drawPath(
      outerPath,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..color = const Color(0xFFCBD5E1),
    );

    final tubeW = (bodyW - inset * 2) * 0.36;
    final tubeX = (w - tubeW) / 2;
    final tubeTop = stemTop + inset + 18;
    final tubeBottom = bulbCy - 18;

    final tubeRRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(tubeX, tubeTop, tubeW, tubeBottom - tubeTop),
      Radius.circular(tubeW / 2),
    );

    canvas.drawRRect(tubeRRect, Paint()..color = const Color(0xFFEFF4F8));

    final liquidTop = lerpDouble(tubeBottom, tubeTop, fill)!;

    final shader = const LinearGradient(
      begin: Alignment.bottomCenter,
      end: Alignment.topCenter,
      colors: [
        Color(0xFF38BDF8),
        Color(0xFF22C55E),
        Color(0xFFF59E0B),
        Color(0xFFEF4444),
      ],
    ).createShader(Rect.fromLTWH(tubeX, tubeTop, tubeW, tubeBottom - tubeTop));

    canvas.save();
    canvas.clipRRect(tubeRRect);
    canvas.drawRect(
      Rect.fromLTWH(tubeX, liquidTop, tubeW, tubeBottom - liquidTop),
      Paint()..shader = shader,
    );
    canvas.restore();

    canvas.drawCircle(
      Offset(w / 2, bulbCy),
      innerBulbR * 0.86,
      Paint()..shader = shader,
    );

    final hl = Paint()..color = Colors.white.withOpacity(0.35);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(
          tubeX + tubeW * 0.18,
          tubeTop + 12,
          tubeW * 0.22,
          (tubeBottom - tubeTop) - 24,
        ),
        const Radius.circular(999),
      ),
      hl,
    );

    final tickPaint = Paint()
      ..color = const Color(0xFF475569)
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;

    final ticksX = bodyX + bodyW - inset - 6;
    final ticksTop = tubeTop + 4;
    final ticksBottom = tubeBottom - 4;

    for (int i = 0; i <= 18; i++) {
      final y = lerpDouble(ticksTop, ticksBottom, i / 18)!;
      final major = i % 3 == 0;
      final len = major ? 18.0 : 10.0;
      canvas.drawLine(Offset(ticksX, y), Offset(ticksX + len, y), tickPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _ThermometerPainter oldDelegate) {
    return oldDelegate.fill != fill;
  }
}