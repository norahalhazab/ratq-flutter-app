import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:ui';

import '../services/smart_watch_simulator_service.dart';
import '../widgets/bottom_nav.dart';
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
  // UI palette
  static const bg = Color(0xFFFFFFFF);
  static const cardBg = Color(0xFFD8E7EF);
  static const primary = Color(0xFF3B7691);
  static const border = Color(0xFFC8D3DF);

  // state
  bool _saving = false;

  String? _tempError;
  final TextEditingController _tempCtrl = TextEditingController();

  SmartWatchSimulatorService get _service => SmartWatchSimulatorService.instance;

  @override
  void dispose() {
    _tempCtrl.dispose();
    super.dispose();
  }

  double? _parseTemp() {
    final raw = _tempCtrl.text.trim().replaceAll(',', '.');
    if (raw.isEmpty) return null;
    return double.tryParse(raw);
  }

  String? _validateTemp(double? v) {
    if (v == null) return "Please enter temperature";
    if (v < 30 || v > 45) return "Temperature looks incorrect";
    return null;
  }

  // Saving vitals into WHQ--vitals
  Future<bool> _saveVitals() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return false;

    final tempToSave = _parseTemp();
    final err = _validateTemp(tempToSave);
    if (err != null) {
      setState(() => _tempError = err);
      return false;
    }

    setState(() => _saving = true);

    try {
      final vitalsData = <String, dynamic>{
        "temperature": tempToSave, // ✅ manual only
        "heartRate": _service.heartRate, // ✅ from watch service
        "bloodPressure": _service.bloodPressure, // ✅ from watch service
        "fromWatch": _service.isConnected,
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
      return false;
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      bottomNavigationBar: const AppBottomNav(currentIndex: 1),
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Color(0xFF0F172A)),
        title: Text(
          "Vitals",
          style: GoogleFonts.dmSans(
            fontSize: 28, // ✅ requested
            fontWeight: FontWeight.w800,
            color: const Color(0xFF0F172A),
          ),
        ),
        centerTitle: true,
      ),
      body: Stack(
        children: [
          const _BlueGlassyBackground(),

          SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) {
                return SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(18, 14, 18, 22),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      minHeight: constraints.maxHeight, // ✅ fill full phone height
                    ),
                    child: IntrinsicHeight(
                      child: Column(
                        children: [
                          // ---------------- Temperature input ----------------
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.92),
                              borderRadius: BorderRadius.circular(22),
                              border: Border.all(color: border),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  "Temperature (°C)",
                                  style: GoogleFonts.inter(
                                    fontSize: 13.5,
                                    fontWeight: FontWeight.w800,
                                    color: const Color(0xFF0F172A),
                                  ),
                                ),
                                const SizedBox(height: 10),
                                TextField(
                                  controller: _tempCtrl,
                                  keyboardType:
                                  const TextInputType.numberWithOptions(
                                      decimal: true),
                                  onChanged: (_) {
                                    if (_tempError != null) {
                                      setState(() => _tempError = null);
                                    }
                                  },
                                  decoration: InputDecoration(
                                    hintText: "e.g. 36.7",
                                    filled: true,
                                    fillColor: const Color(0xFFF8FAFC),
                                    contentPadding: const EdgeInsets.symmetric(
                                      horizontal: 14,
                                      vertical: 14,
                                    ),
                                    enabledBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(14),
                                      borderSide: BorderSide(
                                        color: _tempError != null
                                            ? Colors.red
                                            : border,
                                      ),
                                    ),
                                    focusedBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(14),
                                      borderSide: BorderSide(
                                        color: _tempError != null
                                            ? Colors.red
                                            : primary,
                                        width: 1.6,
                                      ),
                                    ),
                                  ),
                                  style: GoogleFonts.inter(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    color: const Color(0xFF0F172A),
                                  ),
                                ),
                                if (_tempError != null) ...[
                                  const SizedBox(height: 6),
                                  Text(
                                    _tempError!,
                                    style: GoogleFonts.inter(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.red,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),

                          const Spacer(), // ✅ pushes button down nicely if screen is tall

                          //----------------------------Finish Button-----------------
                          const SizedBox(height: 18),
                          SizedBox(
                            width: double.infinity,
                            height: 54,
                            child: ElevatedButton(
                              onPressed: _saving
                                  ? null
                                  : () async {
                                if (_tempCtrl.text.trim().isEmpty) {
                                  setState(() {
                                    _tempError = "Please enter temperature";
                                  });
                                  return;
                                }

                                setState(() => _tempError = null);

                                final success = await _saveVitals();
                                if (!context.mounted) return;
                                if (!success) return;

                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) =>
                                        InfectionAssessmentScreen(
                                          caseId: widget.args.caseId,
                                          whqResponseId:
                                          widget.args.whqResponseId,
                                        ),
                                  ),
                                );
                              },
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
                                  : Text(
                                "Finish",
                                style: GoogleFonts.inter(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w800,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

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
        const Positioned(
          top: -170,
          left: -150,
          child: _Blob(size: 520, color: Color(0xFFBFDCEB)),
        ),
        const Positioned(
          top: 120,
          right: -180,
          child: _Blob(size: 560, color: Color(0xFF3B7691)),
        ),
        BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 60, sigmaY: 60),
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
    return Opacity(
      opacity: 0.10,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      ),
    );
  }
}