import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as p;
import 'upload_success_screen.dart';

class UploadWoundImageScreen extends StatefulWidget {
  const UploadWoundImageScreen({
    super.key,
    required this.caseId,
    required this.whqResponseId,
  });

  /// /users/{uid}/cases/{caseId}
  final String caseId;

  /// /users/{uid}/cases/{caseId}/whqResponses/{whqResponseId}
  /// This should be UNIQUE per WHQ submission (e.g., millisecondsSinceEpoch).
  final String whqResponseId;

  @override
  State<UploadWoundImageScreen> createState() => _UploadWoundImageScreenState();
}

class _UploadWoundImageScreenState extends State<UploadWoundImageScreen> {
  final ImagePicker _picker = ImagePicker();

  File? _selectedImage;
  bool _uploading = false;
  double _progress = 0;

  static const Color _primary = Color(0xFF3B7691);
  static const Color _dark = Color(0xFF0F1729);
  static const Color _cardBorder = Color(0xFFC9DFE9);
  static const Color _uploadBg = Color(0x6663A2BF); // #63a2bf40

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

  Future<void> _uploadToFirebase({required String source}) async {
    final file = _selectedImage;
    if (file == null) return;

    // --- TEMPORARY BYPASS: Comment out Auth check if needed for testing UI only ---
    /*
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("You must be logged in to upload.")),
      );
      return;
    }
    */

    setState(() {
      _uploading = true;
      _progress = 0;
    });

    try {
      // --- SIMULATION START ---
      // We simulate a network delay instead of actual uploading
      for (int i = 1; i <= 10; i++) {
        await Future.delayed(const Duration(milliseconds: 100));
        if (mounted) {
          setState(() => _progress = i / 10);
        }
      }

      // --- COMMENTED OUT ACTUAL FIREBASE LOGIC ---
      /*
      final uid = user.uid;
      final ext = p.extension(file.path).toLowerCase();
      final safeExt = (ext == '.png') ? '.png' : '.jpg';

      final storagePath = "wounds/$uid/${widget.caseId}/${widget.whqResponseId}$safeExt";
      final ref = FirebaseStorage.instance.ref(storagePath);
      // ... metadata setup ...
      final uploadTask = ref.putFile(file, metadata);
      // ... listen to events ...
      await uploadTask;
      final url = await snap.ref.getDownloadURL();

      // ... Firestore write ...
      await whqDocRef.set({...}, SetOptions(merge: true));
      */
      // --- SIMULATION END ---

      if (!mounted) return;

      // Navigate to the Success Screen
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => const UploadSuccessScreen(),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Upload failed: $e")),
      );
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      bottomNavigationBar: const _BottomNav(),
      body: SafeArea(
        child: Stack(
          children: [
            SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 24, 16, 90),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: Row(
                      // 1. Change this from center to start
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        IconButton(
                          // Remove default padding constraints to align it perfectly to the top-left if needed,
                          // or keep as is.
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20, color: _dark),
                          onPressed: () => Navigator.pop(context),
                        ),
                        const SizedBox(width: 12), // Increased width slightly for better spacing
                        Expanded(
                          child: Padding(
                            // 2. Add top padding here to push the text down relative to the arrow
                            padding: const EdgeInsets.only(top: 8.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: const [
                                Text(
                                  "Capture Wound Image",
                                  style: TextStyle(
                                    fontFamily: "DM Sans",
                                    fontSize: 24,
                                    fontWeight: FontWeight.w700,
                                    color: _dark,
                                    height: 32 / 24,
                                  ),
                                ),
                                SizedBox(height: 2),
                                Text(
                                  "Take a clear photo of your wound for analysis",
                                  style: TextStyle(
                                    fontFamily: "DM Sans",
                                    fontSize: 16,
                                    fontWeight: FontWeight.w400,
                                    color: _dark,
                                    height: 24 / 16,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 18),


                  // Upload area
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: _uploadBg,
                      borderRadius: BorderRadius.circular(32),
                    ),
                    child: Column(
                      children: [
                        Container(
                          width: 88,
                          height: 88,
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.2),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.camera_alt_outlined, size: 34, color: _dark),
                        ),
                        const SizedBox(height: 14),

                        if (_selectedImage != null) ...[
                          ClipRRect(
                            borderRadius: BorderRadius.circular(18),
                            child: Image.file(
                              _selectedImage!,
                              height: 180,
                              width: double.infinity,
                              fit: BoxFit.cover,
                            ),
                          ),
                          const SizedBox(height: 14),
                        ],

                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 16),
                          decoration: BoxDecoration(
                            color: _uploadBg,
                            borderRadius: BorderRadius.circular(30),
                            border: Border.all(color: _dark, width: 1),
                          ),
                          child: Column(
                            children: [
                              const Text(
                                "Drag your photo to start the analysis",
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontFamily: "Inter",
                                  fontSize: 14,
                                  color: Color(0xFF0B0B0B),
                                  height: 20 / 14,
                                ),
                              ),
                              const SizedBox(height: 10),

                              Row(
                                children: const [
                                  Expanded(child: Divider(color: Color(0xFFE7E7E7))),
                                  Padding(
                                    padding: EdgeInsets.symmetric(horizontal: 10),
                                    child: Text(
                                      "OR",
                                      style: TextStyle(
                                        fontFamily: "Inter",
                                        fontSize: 12,
                                        color: Color(0xFF6D6D6D),
                                      ),
                                    ),
                                  ),
                                  Expanded(child: Divider(color: Color(0xFFE7E7E7))),
                                ],
                              ),

                              const SizedBox(height: 10),

                              Wrap(
                                spacing: 10,
                                runSpacing: 10,
                                alignment: WrapAlignment.center,
                                children: [
                                  OutlinedButton.icon(
                                    onPressed: _uploading ? null : _takePhoto,
                                    icon: const Icon(Icons.photo_camera_outlined),
                                    label: const Text("Take photo"),
                                    style: OutlinedButton.styleFrom(
                                      foregroundColor: _primary,
                                      side: const BorderSide(color: _primary),
                                      backgroundColor: Colors.white,
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                    ),
                                  ),
                                  OutlinedButton.icon(
                                    onPressed: _uploading ? null : _pickFromGallery,
                                    icon: const Icon(Icons.photo_library_outlined),
                                    label: const Text("Upload image"),
                                    style: OutlinedButton.styleFrom(
                                      foregroundColor: _primary,
                                      side: const BorderSide(color: _primary),
                                      backgroundColor: Colors.white,
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                    ),
                                  ),
                                ],
                              ),

                              const SizedBox(height: 14),

                              if (_selectedImage != null)
                                SizedBox(
                                  width: double.infinity,
                                  child: ElevatedButton(
                                    onPressed: _uploading
                                        ? null
                                        : () => _uploadToFirebase(source: "camera_or_gallery"),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: _primary,
                                      foregroundColor: Colors.white,
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                      padding: const EdgeInsets.symmetric(vertical: 12),
                                    ),
                                    child: _uploading
                                        ? Row(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        const SizedBox(
                                          width: 18,
                                          height: 18,
                                          child: CircularProgressIndicator(strokeWidth: 2),
                                        ),
                                        const SizedBox(width: 10),
                                        Text("Uploading… ${(100 * _progress).toStringAsFixed(0)}%"),
                                      ],
                                    )
                                        : const Text("Start analysis"),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 18),

                  // Guidelines card
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: _cardBorder),
                      boxShadow: const [BoxShadow(blurRadius: 1, offset: Offset(0, 1), color: Colors.white)],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          "• Photo Guidelines",
                          style: TextStyle(
                            fontFamily: "Inter",
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                            color: Color(0xFF003147),
                            height: 20 / 13,
                          ),
                        ),
                        const SizedBox(height: 8),
                        for (int i = 0; i < _photoGuidelines.length; i++)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 4),
                            child: Text(
                              "${i + 1}. ${_photoGuidelines[i]}",
                              style: const TextStyle(
                                fontFamily: "Inter",
                                fontWeight: FontWeight.w400,
                                fontSize: 13,
                                color: _primary,
                                height: 20 / 13,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // Back button

          ],
        ),
      ),
    );
  }
}

class _BottomNav extends StatelessWidget {
  const _BottomNav();

  static const Color primary = Color(0xFF3B7691);
  static const Color muted = Color(0xFF475569);

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
        children: const [
          _NavItem(label: "Home", icon: Icons.home_outlined, selected: true),
          _NavItem(label: "Cases", icon: Icons.folder_outlined, selected: false),
          _NavItem(label: "Alerts", icon: Icons.notifications_none, selected: false),
          _NavItem(label: "Settings", icon: Icons.settings_outlined, selected: false),
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
  });

  final String label;
  final IconData icon;
  final bool selected;

  static const Color primary = Color(0xFF3B7691);
  static const Color muted = Color(0xFF475569);

  @override
  Widget build(BuildContext context) {
    final color = selected ? primary : muted;

    return InkWell(
      onTap: () {
        // TODO: connect to your existing navigation
      },
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
              style: const TextStyle(
                fontFamily: "Inter",
                fontSize: 11.6,
                fontWeight: FontWeight.w600,
                height: 16 / 11.6,
              ).copyWith(color: color),
            ),
          ],
        ),
      ),
    );
  }
}
