import 'dart:io';

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';

import '../widgets/bottom_nav.dart';

class PersonalInformationScreen extends StatefulWidget {
  const PersonalInformationScreen({super.key});

  @override
  State<PersonalInformationScreen> createState() => _PersonalInformationScreenState();
}

class _PersonalInformationScreenState extends State<PersonalInformationScreen> {
  // UI
  static const bg = Color(0xFFFFFFFF);
  static const primary = Color(0xFF3B7691);
  static const cardBg = Color(0xFFEFF6FB);
  static const fieldBg = Color(0xFFFFFFFF);
  static const border = Color(0xFFE2E8F0);

  final _formKey = GlobalKey<FormState>();

  bool _loading = true;
  bool _saving = false;

  // image
  File? _pickedImage;
  String? _profileImageUrl;

  // fields
  final TextEditingController _firstNameController = TextEditingController();
  final TextEditingController _lastNameController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  DateTime? _dob;

  // Firestore doc (fixed path)
  DocumentReference<Map<String, dynamic>> _profileDoc(String uid) {
    return FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('profile')
        .doc('personal');
  }

  @override
  void initState() {
    super.initState();
    _loadProfile();
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
    setState(() => _loading = true);

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        setState(() => _loading = false);
        return;
      }

      // 1) Start empty
      _firstNameController.text = '';
      _lastNameController.text = '';
      _phoneController.text = '';
      _dob = null;
      _profileImageUrl = null;
      _pickedImage = null;

      // 2) Fill from FirebaseAuth name (from signup) if exists
      final authName = (user.displayName ?? '').trim();
      if (authName.isNotEmpty) {
        _firstNameController.text = authName;
      }

      // 3) Read from Firestore (latest saved)
      final snap = await _profileDoc(user.uid).get();
      final data = snap.data();

      if (data != null) {
        final firstName = (data['firstName'] ?? '').toString().trim();
        final lastName = (data['lastName'] ?? '').toString().trim();
        final phone = (data['phone'] ?? '').toString().trim();
        final photo = (data['photo'] ?? '').toString().trim();

        if (firstName.isNotEmpty) _firstNameController.text = firstName;
        _lastNameController.text = lastName;
        _phoneController.text = phone;
        if (photo.isNotEmpty) _profileImageUrl = photo;

        final dobRaw = data['dob'];
        _dob = _parseDob(dobRaw);
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

  DateTime? _parseDob(dynamic v) {
    try {
      if (v == null) return null;

      if (v is Timestamp) return v.toDate();
      if (v is String) return DateTime.tryParse(v);
      if (v is int) return DateTime.fromMillisecondsSinceEpoch(v);

      if (v is Map) {
        final seconds = v['seconds'];
        if (seconds is int) return DateTime.fromMillisecondsSinceEpoch(seconds * 1000);
      }
    } catch (_) {}
    return null;
  }

  // ---------------- SAVE ----------------
  Future<void> _save() async {
    if (_saving) return;
    if (!_formKey.currentState!.validate()) return;

    setState(() => _saving = true);

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      // upload image (optional)
      if (_pickedImage != null) {
        final url = await _uploadProfileImage(user.uid);
        if (url != null) _profileImageUrl = url;
      }

      final payload = <String, dynamic>{
        'firstName': _firstNameController.text.trim(),
        'lastName': _lastNameController.text.trim(),
        'phone': _phoneController.text.trim(),
        // store as Timestamp (أفضل من string)
        'dob': _dob == null ? null : Timestamp.fromDate(_dob!),
        'photo': _profileImageUrl,
        'updatedAt': FieldValue.serverTimestamp(),
      };

      // save to fixed doc
      await _profileDoc(user.uid).set(payload, SetOptions(merge: true));

      // update FirebaseAuth displayName too (so it appears elsewhere)
      final first = _firstNameController.text.trim();
      if (first.isNotEmpty && first != (user.displayName ?? '')) {
        await user.updateDisplayName(first);
      }

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Saved ✅')),
      );

      // ✅ reload to make sure the UI reflects latest saved values
      await _loadProfile();
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
      setState(() => _pickedImage = File(file.path));
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
      setState(() => _dob = picked);
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
            style: GoogleFonts.inter(color: primary, fontWeight: FontWeight.w600),
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
                  ? const SizedBox(
                height: 16,
                width: 16,
                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
              )
                  : Text('Save', style: GoogleFonts.inter(fontWeight: FontWeight.w600, color: Colors.white)),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : RefreshIndicator(
          onRefresh: _loadProfile,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
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
                        Center(
                          child: Column(
                            children: [
                              CircleAvatar(
                                radius: 44,
                                backgroundColor: const Color(0xFFE2E8F0),
                                backgroundImage: _pickedImage != null
                                    ? FileImage(_pickedImage!)
                                    : (_profileImageUrl != null && _profileImageUrl!.isNotEmpty
                                    ? NetworkImage(_profileImageUrl!)
                                    : null)
                                as ImageProvider?,
                                child: (_pickedImage == null &&
                                    (_profileImageUrl == null || _profileImageUrl!.isEmpty))
                                    ? const Icon(Icons.person, size: 34, color: Color(0xFF64748B))
                                    : null,
                              ),
                              const SizedBox(height: 8),
                              InkWell(
                                onTap: _pickImage,
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    const Icon(Icons.photo_camera_outlined,
                                        size: 16, color: primary),
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
                          hint: '',
                          validator: (v) {
                            if (v == null || v.trim().isEmpty) return 'First name is required';
                            return null;
                          },
                        ),
                        const SizedBox(height: 12),

                        _label('Last name'),
                        _field(controller: _lastNameController, hint: ''),
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
                                    _dobText(),
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
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
      bottomNavigationBar: const Padding(
        padding: EdgeInsets.all(10),
        child: AppBottomNav(currentIndex: 3),
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
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: primary, width: 1.2),
        ),
      ),
    );
  }
}
