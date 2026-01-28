import 'dart:io';
import 'dart:convert'; // Required for JSON decoding

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
// Note: We don't need firebase_storage import anymore for this solution
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http; // Required for Cloudinary upload
import 'upload_success_screen.dart';
import '../widgets/bottom_nav.dart';

class UploadWoundImageScreen extends StatefulWidget {
  const UploadWoundImageScreen({
    super.key,
    required this.caseId,
    required this.whqResponseId,
  });

  /// /users/{uid}/cases/{caseId}
  final String caseId;

  /// /users/{uid}/cases/{caseId}/whqResponses/{whqResponseId}
  final String whqResponseId;

  @override
  State<UploadWoundImageScreen> createState() => _UploadWoundImageScreenState();
}

class _UploadWoundImageScreenState extends State<UploadWoundImageScreen> {
  final ImagePicker _picker = ImagePicker();

  File? _selectedImage;
  bool _uploading = false;
  // Cloudinary HTTP upload doesn't give granular progress easily, so we use a simple loading state.
  // If you need a progress bar, you'd need a more advanced HTTP client like 'dio'.

  static const Color _primary = Color(0xFF3B7691);
  static const Color _dark = Color(0xFF0F1729);
  static const Color _cardBorder = Color(0xFFC9DFE9);
  static const Color _uploadBg = Color(0x6663A2BF);

  static const List<String> _photoGuidelines = [
    "Use good lighting",
    "Hold your phone steady",
    "Capture the full wound area",
  ];

  Future<void> _pickFromGallery() async {
    final XFile? x = await _picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 85, // Cloudinary handles large images well, so 85 is fine
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

  /// Uploads image to Cloudinary (Free, No Credit Card, Works in KSA)
  Future<void> _uploadToCloudinary({required String source}) async {
    final file = _selectedImage;
    if (file == null) return;

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("You must be logged in to upload.")),
      );
      return;
    }

    setState(() => _uploading = true);

    try {
      // ---------------------------------------------------------
      // TODO: PASTE YOUR CLOUDINARY DETAILS HERE
      // ---------------------------------------------------------
      const cloudName = "dnrlhiq75"; // e.g., "dxy85..."
      const uploadPreset = "wound_app_preset"; // e.g., "wound_app" (Make sure it is Unsigned)
      // ---------------------------------------------------------

      final url = Uri.parse('https://api.cloudinary.com/v1_1/$cloudName/image/upload');

      // Create the Multipart Request
      final request = http.MultipartRequest('POST', url)
        ..fields['upload_preset'] = uploadPreset
        ..files.add(await http.MultipartFile.fromPath('file', file.path));

      // Send Request
      final response = await request.send();

      if (response.statusCode == 200) {
        // Parse Response
        final responseData = await response.stream.toBytes();
        final responseString = String.fromCharCodes(responseData);
        final jsonMap = jsonDecode(responseString);

        // Get the secure URL from Cloudinary
        final String downloadUrl = jsonMap['secure_url'];

        // Save URL to Firestore
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
            "erythema": null, // Will be calculated later
            "exudate": null,  // Will be calculated later
            "source": source,
          },
          "lastUpdated": FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));

        if (!mounted) return;

        // Navigate to Success Screen
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => const UploadSuccessScreen(),
          ),
        );
      } else {
        // Handle Error
        final responseData = await response.stream.toBytes();
        final responseString = String.fromCharCodes(responseData);
        throw("Cloudinary Error: ${response.statusCode} - $responseString");
      }

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
      bottomNavigationBar: const AppBottomNav(currentIndex: 1),
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
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        IconButton(
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20, color: _dark),
                          onPressed: () => Navigator.pop(context),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Padding(
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
                                        : () => _uploadToCloudinary(source: "camera_or_gallery"),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: _primary,
                                      foregroundColor: Colors.white,
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                      padding: const EdgeInsets.symmetric(vertical: 12),
                                    ),
                                    child: _uploading
                                        ? Row(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: const [
                                        SizedBox(
                                          width: 18,
                                          height: 18,
                                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                        ),
                                        SizedBox(width: 10),
                                        Text("Uploading..."),
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
          ],
        ),
      ),
    );
  }
}



