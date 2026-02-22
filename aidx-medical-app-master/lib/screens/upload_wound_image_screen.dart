import 'dart:io';
import 'dart:convert';
import 'dart:ui'; // Required for ImageFilter

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart'; // Ensure you have this package
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;

import 'upload_success_screen.dart';
import '../widgets/bottom_nav.dart';
import '../utils/app_colors.dart'; // Assuming you have this file

class UploadWoundImageScreen extends StatefulWidget {
  const UploadWoundImageScreen({
    super.key,
    required this.caseId,
    required this.whqResponseId,
  });

  final String caseId;
  final String whqResponseId;

  @override
  State<UploadWoundImageScreen> createState() => _UploadWoundImageScreenState();
}

class _UploadWoundImageScreenState extends State<UploadWoundImageScreen> {
  final ImagePicker _picker = ImagePicker();
  File? _selectedImage;
  bool _uploading = false;

  static const List<String> _photoGuidelines = [
    "Use good lighting",
    "Hold your phone steady",
    "Capture the full wound area",
  ];

  Future<void> _pickFromGallery() async {
    final XFile? x = await _picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 85,
    );
    if (x == null) return;
    setState(() => _selectedImage = File(x.path));
  }

  Future<void> _takePhoto() async {
    final XFile? x = await _picker.pickImage(
      source: ImageSource.camera,
      imageQuality: 85,
      preferredCameraDevice: CameraDevice.rear,
    );
    if (x == null) return;
    setState(() => _selectedImage = File(x.path));
  }

  Future<void> _uploadToCloudinary({required String source}) async {
    final file = _selectedImage;
    if (file == null) return;

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    setState(() => _uploading = true);

    try {
      // 1. UPLOAD TO CLOUDINARY
      const cloudName = "dnrlhiq75";
      const uploadPreset = "wound_app_preset";

      final url = Uri.parse('https://api.cloudinary.com/v1_1/$cloudName/image/upload');
      final request = http.MultipartRequest('POST', url)
        ..fields['upload_preset'] = uploadPreset
        ..files.add(await http.MultipartFile.fromPath('file', file.path));

      final response = await request.send();

      if (response.statusCode != 200) throw("Image upload failed. Please try again.");

      final responseData = await response.stream.toBytes();
      final responseString = String.fromCharCodes(responseData);
      final jsonMap = jsonDecode(responseString);

      final String downloadUrl = jsonMap['secure_url'];

      // -----------------------------------------------------
      // 2. CALL BOTH AI MODELS IN PARALLEL
      // -----------------------------------------------------
      final exudateAiUrl = Uri.parse('https://laura-potato-ratq-ai.hf.space/analyze');
      final erythemaAiUrl = Uri.parse('https://norahalhozab-ratq-erthyma.hf.space/analyze');

      print("🚀 Starting AI Analysis on both servers...");

      // We start both requests at the same time to save time
      final results = await Future.wait([
        http.post(
          exudateAiUrl,
          headers: {"Content-Type": "application/json"},
          body: jsonEncode({"imageUrl": downloadUrl}),
        ).timeout(const Duration(seconds: 90)),

        http.post(
          erythemaAiUrl,
          headers: {"Content-Type": "application/json"},
          body: jsonEncode({"imageUrl": downloadUrl}),
        ).timeout(const Duration(seconds: 90)),

      ]);

      final exuResponse = results[0];
      final eryResponse = results[1];

      int? detectedExudate;
      int? detectedErythema;

      // Parse Exudate Result
      if (exuResponse.statusCode == 200) {
        final data = jsonDecode(exuResponse.body);
        detectedExudate = data['exudate'];
        print("✅ Exudate Result: $detectedExudate");
      }

      // Parse Erythema Result
      if (eryResponse.statusCode == 200) {
        final data = jsonDecode(eryResponse.body);
        detectedErythema = data['erthyma'];
        print("✅ Erythema Result: $detectedErythema");
      }

      if (detectedExudate == null ) {
        throw "detectedExudate failed to return a result.";
      }

      if (detectedErythema == null) {
        throw "detectedErythema failed to return a result.";
      }

      // -----------------------------------------------------
      // 3. SAVE TO FIRESTORE (Both results combined)
      // -----------------------------------------------------
      final uid = user.uid;
      final whqDocRef = FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection('cases')
          .doc(widget.caseId)
          .collection('whqResponses')
          .doc(widget.whqResponseId);

      await whqDocRef.set({
        "image": {
          "url": downloadUrl,
          "date": FieldValue.serverTimestamp(),
          "erythema": detectedErythema, // Now saving the real 0 or 1
          "exudate": detectedExudate,   // Now saving the real 0 or 1
          "source": source,
        },
        "lastUpdated": FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      if (!mounted) return;

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const UploadSuccessScreen()),
      );

    } catch (e) {
      print("Upload Error: $e");
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Analysis Failed: $e"),
          backgroundColor: AppColors.errorColor,
          duration: const Duration(seconds: 4),
        ),
      );
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundColor,
      bottomNavigationBar: const AppBottomNav(currentIndex: 1),
      body: Stack(
        children: [
          // 1. Consistent Blue Glassy Background
          const _BlueGlassyBackground(),

          SafeArea(
            child: Column(
              children: [
                // ===== Header =====
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                  child: Row(
                    children: [
                      _WhitePillButton(
                        onTap: () => Navigator.pop(context),
                        child: const Icon(
                          Icons.arrow_back_ios_new_rounded,
                          size: 18,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              "Capture Wound Image",
                              style: GoogleFonts.dmSans(
                                fontSize: 18, // Matches cases screen headers
                                fontWeight: FontWeight.w900,
                                color: AppColors.textPrimary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 18),

                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Column(
                      children: [
                        // ===== 2. Glassy Upload Card =====
                        _GlassyCard(
                          child: Column(
                            children: [
                              // Icon Circle
                              Container(
                                width: 80,
                                height: 80,
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                    colors: [
                                      AppColors.primaryColor.withOpacity(0.15),
                                      AppColors.primaryColor.withOpacity(0.05),
                                    ],
                                  ),
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: AppColors.primaryColor.withOpacity(0.2),
                                    width: 1.5,
                                  ),
                                ),
                                child: Icon(
                                    Icons.camera_alt_outlined,
                                    size: 32,
                                    color: AppColors.primaryColor
                                ),
                              ),
                              const SizedBox(height: 20),

                              // Preview Image
                              if (_selectedImage != null) ...[
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(18),
                                  child: Image.file(
                                    _selectedImage!,
                                    height: 220,
                                    width: double.infinity,
                                    fit: BoxFit.cover,
                                  ),
                                ),
                                const SizedBox(height: 20),
                              ],

                              Text(
                                "Upload or take a photo",
                                textAlign: TextAlign.center,
                                style: GoogleFonts.dmSans(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w900,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                "Ensure the wound is clearly visible",
                                textAlign: TextAlign.center,
                                style: GoogleFonts.inter(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.textSecondary,
                                ),
                              ),

                              const SizedBox(height: 24),

                              // Camera / Gallery Buttons
                              Row(
                                children: [
                                  Expanded(
                                    child: _SecondaryActionButton(
                                      label: "Camera",
                                      icon: Icons.camera_alt_outlined,
                                      onTap: _uploading ? null : _takePhoto,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: _SecondaryActionButton(
                                      label: "Gallery",
                                      icon: Icons.photo_library_outlined,
                                      onTap: _uploading ? null : _pickFromGallery,
                                    ),
                                  ),
                                ],
                              ),

                              const SizedBox(height: 20),

                              // ===== 3. Gradient Start Button =====
                              SizedBox(
                                width: double.infinity,
                                child: _PrimaryGradientButton(
                                  label: _uploading ? "Analyzing..." : "Start Analysis",
                                  icon: Icons.auto_awesome,
                                  isLoading: _uploading,
                                  onTap: (_selectedImage != null && !_uploading)
                                      ? () => _uploadToCloudinary(source: "camera_or_gallery")
                                      : null, // Disabled if no image
                                ),
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 20),

                        // Guidelines Section
                        _GlassyCard(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(Icons.info_outline_rounded, size: 18, color: AppColors.primaryColor),
                                  const SizedBox(width: 8),
                                  Text(
                                    "Photo Guidelines",
                                    style: GoogleFonts.dmSans(
                                      fontWeight: FontWeight.w900,
                                      fontSize: 15,
                                      color: AppColors.textPrimary,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              for (var guide in _photoGuidelines)
                                Padding(
                                  padding: const EdgeInsets.only(bottom: 8),
                                  child: Row(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Container(
                                        margin: const EdgeInsets.only(top: 6),
                                        width: 6,
                                        height: 6,
                                        decoration: BoxDecoration(
                                          color: AppColors.primaryColor.withOpacity(0.6),
                                          shape: BoxShape.circle,
                                        ),
                                      ),
                                      const SizedBox(width: 10),
                                      Expanded(
                                        child: Text(
                                          guide,
                                          style: GoogleFonts.inter(
                                            fontSize: 13,
                                            fontWeight: FontWeight.w600,
                                            color: AppColors.textSecondary,
                                            height: 1.4,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 100), // Bottom padding
                      ],
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
}

// =================================================================
// REUSABLE WIDGETS (Copied/Adapted from Case Details Screen)
// =================================================================

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
              colors: [Color(0xFFEAF5FB), Color(0xFFDCEEF7), Color(0xFFF7FBFF)],
            ),
          ),
        ),
        Positioned(
          top: -170, left: -150,
          child: _Blob(size: 520, color: AppColors.secondaryColor.withOpacity(0.22)),
        ),
        Positioned(
          top: 120, right: -180,
          child: _Blob(size: 560, color: AppColors.primaryColor.withOpacity(0.10)),
        ),
        // Glass Blur
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
    return Container(
      width: size, height: size,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
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
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(26),
            color: Colors.white.withOpacity(0.92),
            border: Border.all(color: AppColors.dividerColor.withOpacity(0.9)),
            boxShadow: const [
              BoxShadow(
                color: Color(0x11000000),
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

class _WhitePillButton extends StatelessWidget {
  const _WhitePillButton({required this.child, required this.onTap});
  final Widget child;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(999),
          color: Colors.white.withOpacity(0.90),
          border: Border.all(color: AppColors.dividerColor.withOpacity(0.9)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.06),
              blurRadius: 18,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: child,
      ),
    );
  }
}

// -----------------------------------------------------------
// NEW BUTTON STYLES
// -----------------------------------------------------------

class _PrimaryGradientButton extends StatelessWidget {
  const _PrimaryGradientButton({
    required this.label,
    required this.icon,
    required this.onTap,
    this.isLoading = false,
  });

  final String label;
  final IconData icon;
  final VoidCallback? onTap;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    final isDisabled = onTap == null;

    return Opacity(
      opacity: isDisabled ? 0.5 : 1.0,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          height: 54,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            gradient: AppColors.primaryGradient, // Liquid gradient style
            boxShadow: [
              BoxShadow(
                color: AppColors.primaryColor.withOpacity(0.3),
                blurRadius: 20,
                offset: const Offset(0, 10),
                spreadRadius: -5,
              ),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (isLoading)
                const SizedBox(
                  width: 20, height: 20,
                  child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5),
                )
              else
                Icon(icon, color: Colors.white, size: 22),

              const SizedBox(width: 10),

              Text(
                label,
                style: GoogleFonts.dmSans(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
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

class _SecondaryActionButton extends StatelessWidget {
  const _SecondaryActionButton({
    required this.label,
    required this.icon,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        height: 50,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          color: Colors.white,
          border: Border.all(color: AppColors.primaryColor.withOpacity(0.3)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: AppColors.primaryColor, size: 20),
            const SizedBox(width: 8),
            Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 13.5,
                fontWeight: FontWeight.w700,
                color: AppColors.primaryColor,
              ),
            ),
          ],
        ),
      ),
    );
  }
}