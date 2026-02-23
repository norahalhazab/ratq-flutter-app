import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:ui';
import '../services/smart_watch_simulator_service.dart';
import '../widgets/bottom_nav.dart';

import 'cases_screen.dart';


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
  String _tempSource = "manual"; // "manual" or "watch"

  // watch check state (NEW)
  bool _checkingWatch = true;
  bool _watchConnected = false;
  String? _tempError;
  final TextEditingController _tempCtrl = TextEditingController();

  SmartWatchSimulatorService get _service => SmartWatchSimulatorService.instance;

  @override
  void initState() {
    super.initState();
    _simulateWatchCheck();
  }

  Future<void> _simulateWatchCheck() async {
    setState(() => _checkingWatch = true);

    // UX: give it a moment so it feels like a real check
    await Future.delayed(const Duration(seconds: 1));

    if (!mounted) return;
    setState(() {
      _watchConnected = _service.isConnected;
      _checkingWatch = false;
    });
  }

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

  void _selectManual() {
    setState(() {
      _tempSource = "manual";
      _tempCtrl.clear(); // ✅ clear value when switching to manual
    });
  }

  void _useWatchTemp() {
    // Don’t allow while checking
    if (_checkingWatch) return;

    if (!_watchConnected) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Smart Watch not connected")),
      );
      return;
    }

    setState(() {
      _tempSource = "watch";
      _tempCtrl.text = _service.temperature.toStringAsFixed(1);
    });
  }

  Map<String, dynamic> _buildVitalsMap() {
    final enteredTemp = _parseTemp();

    return {
      "temperature": enteredTemp,
      // You can keep saving these even if you don't show them:
      "heartRate": _service.heartRate,
      "bloodPressure": _service.bloodPressure,
      "fromWatch": _service.isConnected,
      "tempSource": _tempSource,
      "capturedAt": FieldValue.serverTimestamp(),
    };
  }


  //Saving vitals into WHQ--vitals
  Future<void> _saveVitals() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    // ✅ choose temperature based on source
    double? tempToSave;

    if (_tempSource == "watch") {
      if (!_service.isConnected) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Smart Watch not connected")),
        );
        return;
      }
      tempToSave = _service.temperature;
    } else {
      tempToSave = _parseTemp();
      final err = _validateTemp(tempToSave);
      if (err != null) {
        setState(() => _tempError = err);
        return;
      }
    }

    setState(() => _saving = true);

    try {
      final vitalsData = <String, dynamic>{
        "temperature": tempToSave,
        "heartRate": _service.heartRate,
        "bloodPressure": _service.bloodPressure,
        "fromWatch": _service.isConnected,
        "tempSource": _tempSource, // "manual" or "watch"
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
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {

    return Scaffold(
      backgroundColor: Colors.transparent,
      // 1. Keep the navigation bar
      bottomNavigationBar: const AppBottomNav(currentIndex: 1),
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Color(0xFF0F172A)),
        title: Text(
          "Vitals",
          style: GoogleFonts.dmSans(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            color: const Color(0xFF0F172A),
          ),
        ),
      ),
      body: Stack(
        children: [

          const _BlueGlassyBackground(),

          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(18, 14, 18, 22),
              child: Column(
                children: [
                  // --------- Temperature source options ----------
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.92), // ✅ more glassy
                      borderRadius: BorderRadius.circular(22),
                      border: Border.all(color: border),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "How would you like to enter your temperature?",
                          style: GoogleFonts.inter(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w800,
                            color: const Color(0xFF0F172A),
                          ),
                        ),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            Expanded(
                              child: _sourceChip(
                                label: "Manual",
                                selected: _tempSource == "manual",
                                onTap: _selectManual,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: _sourceChip(
                                label: "Smart Watch",
                                selected: _tempSource == "watch",
                                onTap: _useWatchTemp,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 14),

                  // ✅ Watch connection status ONLY
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: cardBg.withOpacity(0.92), // ✅ blend with background
                      borderRadius: BorderRadius.circular(22),
                    ),
                    child: Row(
                      children: [
                        if (_checkingWatch) ...[
                          const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              "Checking smart watch connection…",
                              style: GoogleFonts.inter(
                                fontSize: 13,
                                fontWeight: FontWeight.w800,
                                color: const Color(0xFF0F172A),
                              ),
                            ),
                          ),
                        ] else ...[
                          Icon(
                            _watchConnected ? Icons.check_circle : Icons.error_outline,
                            color: _watchConnected ? Colors.green : Colors.orange,
                            size: 18,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _watchConnected
                                  ? "Smart Watch Connected"
                                  : "Smart Watch Not Connected",
                              style: GoogleFonts.inter(
                                fontSize: 13,
                                fontWeight: FontWeight.w800,
                                color: const Color(0xFF0F172A),
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),

                  const SizedBox(height: 14),



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
                          const TextInputType.numberWithOptions(decimal: true),
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
                                color: _tempError != null ? Colors.red : border,
                              ),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                              borderSide: BorderSide(
                                color: _tempError != null ? Colors.red : primary,
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


                  //----------------------------Finish Button-----------------
                  const SizedBox(height: 18),
                  SizedBox(
                    width: double.infinity,
                    height: 54,
                    child: ElevatedButton(
                      onPressed: _saving
                          ? null
                          : () async {
                        if (_tempSource == "manual" && _tempCtrl.text.trim().isEmpty) {
                          setState(() {
                            _tempError = "Please enter temperature";
                          });
                          return;
                        }

                        setState(() {
                          _tempError = null;
                        });

                        await _saveVitals();
                        if (!context.mounted) return;

                        Navigator.pushAndRemoveUntil(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const CasesScreen(),
                          ),
                              (route) => false,
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
        ],
      ),
    );
  }

  Widget _sourceChip({
    required String label,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        curve: Curves.easeOutCubic,
        height: 44,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected ? primary : Colors.transparent,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: selected ? primary : border),
        ),
        child: Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 13,
            fontWeight: FontWeight.w800,
            color: selected ? Colors.white : const Color(0xFF0F172A),
          ),
        ),
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
        Positioned(
          top: -170,
          left: -150,
          child: _Blob(size: 520, color: Color(0xFFBFDCEB)), // approx secondary opacity
        ),
        Positioned(
          top: 120,
          right: -180,
          child: _Blob(size: 560, color: Color(0xFF3B7691)), // primary
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