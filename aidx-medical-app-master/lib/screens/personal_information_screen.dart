import 'dart:io';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';


import '../widgets/bottom_nav.dart';

import 'package:aidx/services/auth_service.dart';
import 'package:aidx/services/database_init.dart';

class PersonalInformationScreen extends StatefulWidget {
  const PersonalInformationScreen({super.key});

  @override
  State<PersonalInformationScreen> createState() => _PersonalInformationScreenState();
}

class _PersonalInformationScreenState extends State<PersonalInformationScreen> {
  // UI
  static const bg = Color(0xFFFFFFFF);
  static const primary = Color(0xFF3B7691);
  static const cardBg = Color(0xFFEFF6FB); // light blue card like screenshot
  static const fieldBg = Color(0xFFFFFFFF);
  static const border = Color(0xFFE2E8F0);

  final _formKey = GlobalKey<FormState>();

  bool _loading = true;
  bool _saving = false;

  // image
  File? _pickedImage;
  String? _profileImageUrl;

  // fields (as per screenshot)
  final TextEditingController _firstNameController = TextEditingController();
  final TextEditingController _lastNameController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();

  DateTime? _dob;

  // services
  final DatabaseService _db = DatabaseService();

  bool _dirty = false;

  @override
  void initState() {
    super.initState();
    _loadProfile();
    _firstNameController.addListener(_markDirty);
    _lastNameController.addListener(_markDirty);
    _phoneController.addListener(_markDirty);
  }

  void _markDirty() {
    if (!_dirty) setState(() => _dirty = true);
  }

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  // ---------------- LOAD ----------------
  Future<void> _loadProfile() async {
    setState(() {
      _loading = true;
      _dirty = false;
    });

    try {
      final auth = Provider.of<AuthService>(context, listen: false);
      final user = auth.currentUser;

      if (user == null) {
        setState(() => _loading = false);
        return;
      }

      // ✅ default: EMPTY fields (no Alexander)
      _firstNameController.text = '';
      _lastNameController.text = '';
      _phoneController.text = '';
      _dob = null;
      _profileImageUrl = null;

      // ✅ BUT: show the name user typed in signup (if available)
      // - from FirebaseAuth.displayName
      // - OR from Firestore if you saved it there
      final authName = (user.displayName ?? '').trim();
      if (authName.isNotEmpty) {
        _firstNameController.text = authName; // use it as First Name
      }

      // Read Firestore profile (if exists)
      final raw = await _db.getUserProfile(user.uid);

      Map<String, dynamic>? profile;
      if (raw is Map<String, dynamic>) {
        if (raw['profile'] is Map<String, dynamic>) {
          profile = Map<String, dynamic>.from(raw['profile']);
        } else {
          profile = raw; // in case your service returns it directly
        }
      }

      if (profile != null) {
        // If your Firestore stores 'name' only, still map it to firstName
        final firstName = (profile['firstName'] ?? '').toString().trim();
        final lastName = (profile['lastName'] ?? '').toString().trim();
        final phone = (profile['phone'] ?? '').toString().trim();
        final photo = (profile['photo'] ?? '').toString().trim();

        final nameFallback = (profile['name'] ?? '').toString().trim();

        if (firstName.isNotEmpty) {
          _firstNameController.text = firstName;
        } else if (_firstNameController.text.isEmpty && nameFallback.isNotEmpty) {
          _firstNameController.text = nameFallback;
        }

        _lastNameController.text = lastName;
        _phoneController.text = phone;

        if (photo.isNotEmpty) _profileImageUrl = photo;

        final dobRaw = profile['dob'];
        // Accept common formats: iso string, Timestamp-like map, or yyyy-mm-dd string
        if (dobRaw != null) {
          final parsed = _parseDob(dobRaw);
          if (parsed != null) _dob = parsed;
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load profile: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  DateTime? _parseDob(dynamic dobRaw) {
    try {
      if (dobRaw is String) {
        // ISO 8601 or yyyy-mm-dd
        return DateTime.tryParse(dobRaw);
      }

      // If you ever saved Timestamp as milliseconds
      if (dobRaw is int) {
        return DateTime.fromMillisecondsSinceEpoch(dobRaw);
      }

      // If you saved map like {"seconds":..., "nanoseconds":...}
      if (dobRaw is Map) {
        final seconds = dobRaw['seconds'];
        if (seconds is int) {
          return DateTime.fromMillisecondsSinceEpoch(seconds * 1000);
        }
      }
    } catch (_) {}
    return null;
  }

  // ---------------- SAVE ----------------
  Future<void> _save() async {
    if (_saving) return;

    // Allow empty fields (except first name if you want required)
    // You said: first open should be empty, user can fill. But since signup has name, we keep it.
    if (!_formKey.currentState!.validate()) return;

    setState(() => _saving = true);

    try {
      final auth = Provider.of<AuthService>(context, listen: false);
      final user = auth.currentUser;
      if (user == null) return;

      // upload image (optional)
      if (_pickedImage != null) {
        final url = await _uploadProfileImage(user.uid);
        if (url != null) _profileImageUrl = url;
      }

      final payload = <String, dynamic>{
        // ✅ store new fields exactly for this screen
        'firstName': _firstNameController.text.trim(),
        'lastName': _lastNameController.text.trim(),
        'phone': _phoneController.text.trim(),
        'dob': _dob?.toIso8601String(), // store as ISO string
        'photo': _profileImageUrl,
        'updatedAt': DateTime.now().toIso8601String(),

        // ✅ optional backward compatibility (if your app uses "name" somewhere)
        'name': _firstNameController.text.trim(),
      };

      await _db.updateUserProfile(user.uid, payload);

      // ✅ also update FirebaseAuth displayName to keep it consistent
      final first = _firstNameController.text.trim();
      if (first.isNotEmpty && first != (user.displayName ?? '')) {
        await user.updateDisplayName(first);
      }

      if (!mounted) return;
      setState(() {
        _dirty = false;
        _pickedImage = null;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Saved ✅')),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to save: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<String?> _uploadProfileImage(String userId) async {
    if (_pickedImage == null) return null;
    try {
      final ref = FirebaseStorage.instance.ref().child('profile_images').child('$userId.jpg');
      await ref.putFile(_pickedImage!);
      return await ref.getDownloadURL();
    } catch (e) {
      debugPrint('⚠️ upload image error: $e');
      return null;
    }
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final XFile? file = await picker.pickImage(source: ImageSource.gallery, imageQuality: 85);
    if (file != null) {
      setState(() {
        _pickedImage = File(file.path);
        _dirty = true;
      });
    }
  }

  Future<void> _pickDob() async {
    final initial = _dob ?? DateTime(2000, 1, 1);
    final picked = await showDatePicker(
      context: context,
      firstDate: DateTime(1900),
      lastDate: DateTime.now(),
      initialDate: initial,
    );
    if (picked != null) {
      setState(() {
        _dob = picked;
        _dirty = true;
      });
    }
  }

  String _dobText() {
    if (_dob == null) return '';
    final d = _dob!;
    final dd = d.day.toString().padLeft(2, '0');
    final mm = d.month.toString().padLeft(2, '0');
    final yyyy = d.year.toString();
    return '$dd/$mm/$yyyy';
  }

  // ---------------- UI ----------------
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: bg,
        elevation: 0,
        leading: TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(
            'Cancel',
            style: GoogleFonts.inter(
              color: primary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        leadingWidth: 86,
        centerTitle: true,
        title: Text(
          'Personal information',
          style: GoogleFonts.inter(
            color: const Color(0xFF0F172A),
            fontSize: 15.5,
            fontWeight: FontWeight.w600,
          ),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: ElevatedButton(
              onPressed: (_loading || _saving) ? null : _save,
              style: ElevatedButton.styleFrom(
                backgroundColor: primary,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
                elevation: 0,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              ),
              child: _saving
                  ? const SizedBox(height: 16, width: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : Text(
                'Save',
                style: GoogleFonts.inter(fontWeight: FontWeight.w600, color: Colors.white),
              ),
            ),
          ),
        ],
      ),

      body: SafeArea(
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(18, 18, 18, 110),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.person_outline, color: Color(0xFF64748B)),
                    const SizedBox(width: 10),
                    Text(
                      'User profile',
                      style: GoogleFonts.dmSans(
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF0F172A),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Card container
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: cardBg,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: border),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // avatar
                      Center(
                        child: Column(
                          children: [
                            CircleAvatar(
                              radius: 44,
                              backgroundColor: const Color(0xFFE2E8F0),
                              backgroundImage: _pickedImage != null
                                  ? FileImage(_pickedImage!)
                                  : (_profileImageUrl != null && _profileImageUrl!.isNotEmpty ? NetworkImage(_profileImageUrl!) : null)
                              as ImageProvider?,
                              child: (_pickedImage == null && (_profileImageUrl == null || _profileImageUrl!.isEmpty))
                                  ? const Icon(Icons.person, size: 34, color: Color(0xFF64748B))
                                  : null,
                            ),
                            const SizedBox(height: 8),
                            InkWell(
                              onTap: _pickImage,
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Icon(Icons.photo_camera_outlined, size: 16, color: primary),
                                  const SizedBox(width: 6),
                                  Text(
                                    'Change photo',
                                    style: GoogleFonts.inter(
                                      color: primary,
                                      fontWeight: FontWeight.w600,
                                      fontSize: 12.5,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 18),

                      _label('First name'),
                      _field(
                        controller: _firstNameController,
                        hint: ' ',
                        validator: (v) {
                          // You can decide required or not:
                          // Since signup already has name, usually it won't be empty.
                          if (v == null || v.trim().isEmpty) return 'First name is required';
                          return null;
                        },
                      ),
                      const SizedBox(height: 12),

                      _label('Last name'),
                      _field(
                        controller: _lastNameController,
                        hint: ' ',
                        // optional
                      ),
                      const SizedBox(height: 12),

                      _label('Date of birth'),
                      InkWell(
                        onTap: _pickDob,
                        borderRadius: BorderRadius.circular(14),
                        child: Container(
                          height: 52,
                          padding: const EdgeInsets.symmetric(horizontal: 14),
                          decoration: BoxDecoration(
                            color: fieldBg,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: border),
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  _dob == null ? '' : _dobText(),
                                  style: GoogleFonts.inter(
                                    fontSize: 14.5,
                                    color: const Color(0xFF0F172A),
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                              const Icon(Icons.calendar_month_outlined, color: Color(0xFF64748B)),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),

                      _label('Phone number'),
                      _field(
                        controller: _phoneController,
                        hint: '05X XXX XXXX',
                        keyboardType: TextInputType.phone,
                        // optional
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),

      // ✅ navigation bar موجود هنا
      bottomNavigationBar: const Padding(
        padding: EdgeInsets.all(10),
        child: AppBottomNav(currentIndex: 3), // settings tab highlighted
      ),
    );
  }

  Widget _label(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text(
        text,
        style: GoogleFonts.inter(
          color: const Color(0xFF334155),
          fontSize: 13,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _field({
    required TextEditingController controller,
    required String hint,
    TextInputType keyboardType = TextInputType.text,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      validator: validator,
      style: GoogleFonts.inter(
        fontSize: 14.5,
        color: const Color(0xFF0F172A),
        fontWeight: FontWeight.w600,
      ),
      decoration: InputDecoration(
        hintText: hint,
        filled: true,
        fillColor: fieldBg,
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: border)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: border)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: primary, width: 1.2)),
      ),
    );
  }
}
