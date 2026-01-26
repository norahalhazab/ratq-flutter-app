import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';

class PersonalInformationScreen extends StatefulWidget {
  const PersonalInformationScreen({super.key});

  @override
  State<PersonalInformationScreen> createState() => _PersonalInformationScreenState();
}

class _PersonalInformationScreenState extends State<PersonalInformationScreen> {
  final _firstName = TextEditingController(text: "Alexander");
  final _lastName = TextEditingController(text: "Johnson");
  final _dob = TextEditingController(text: "05/07/1989");
  final _phone = TextEditingController(text: "");

  String _countryCode = "+966";
  File? _pickedImage;

  // TODO: connect this to your existing Firebase save method
  Future<void> _onSave() async {
    // Example: call your _saveProfileData() or updateUserProfile(...)
    // await _saveProfileData();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Saved (connect to Firebase here)")),
    );
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final XFile? file = await picker.pickImage(source: ImageSource.gallery, imageQuality: 85);
    if (file == null) return;
    setState(() => _pickedImage = File(file.path));
  }

  void _deletePhoto() {
    setState(() => _pickedImage = null);
    // TODO: also delete from Firebase Storage / clear photo url if you want
  }

  Future<void> _pickDate() async {
    // Try to parse existing text (MM/DD/YYYY) safely
    DateTime initial = DateTime(1989, 5, 7);
    final parts = _dob.text.split('/');
    if (parts.length == 3) {
      final mm = int.tryParse(parts[0]);
      final dd = int.tryParse(parts[1]);
      final yy = int.tryParse(parts[2]);
      if (mm != null && dd != null && yy != null) {
        initial = DateTime(yy, mm, dd);
      }
    }

    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(1900, 1, 1),
      lastDate: DateTime.now(),
    );

    if (picked == null) return;

    final mm = picked.month.toString().padLeft(2, '0');
    final dd = picked.day.toString().padLeft(2, '0');
    final yy = picked.year.toString();
    setState(() => _dob.text = "$mm/$dd/$yy");
  }

  @override
  void dispose() {
    _firstName.dispose();
    _lastName.dispose();
    _dob.dispose();
    _phone.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const pageBg = Color(0xFFFFFFFF);
    const cardBg = Color(0xFFE7F2F7); // light blue like screenshot
    const textDark = Color(0xFF0F172A);
    const muted = Color(0xFF64748B);

    return Scaffold(
      backgroundColor: pageBg,
      body: SafeArea(
        child: Column(
          children: [
            // Top bar
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: const Text(
                      "Cancel",
                      style: TextStyle(
                        color: Color(0xFF1E3A8A),
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const Spacer(),
                  const Text(
                    "Personal information",
                    style: TextStyle(
                      color: textDark,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const Spacer(),
                  SizedBox(
                    height: 28,
                    child: ElevatedButton(
                      onPressed: _onSave,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF2B6CB0),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(999),
                        ),
                        elevation: 0,
                      ),
                      child: const Text(
                        "Save",
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Title row
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 6, 16, 10),
              child: Row(
                children: const [
                  _IconTile(),
                  SizedBox(width: 10),
                  Text(
                    "User profile",
                    style: TextStyle(
                      color: textDark,
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ),

            // Card
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 6, 16, 16),
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: cardBg,
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: Column(
                    children: [
                      // Avatar
                      Center(
                        child: Column(
                          children: [
                            GestureDetector(
                              onTap: _pickImage,
                              child: CircleAvatar(
                                radius: 42,
                                backgroundColor: const Color(0xFFCBD5E1),
                                backgroundImage: _pickedImage != null ? FileImage(_pickedImage!) : null,
                                child: _pickedImage == null
                                    ? const Icon(Icons.person, size: 42, color: Color(0xFF334155))
                                    : null,
                              ),
                            ),
                            const SizedBox(height: 8),
                            GestureDetector(
                              onTap: _deletePhoto,
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: const [
                                  Icon(Icons.delete_outline, size: 16, color: Colors.red),
                                  SizedBox(width: 6),
                                  Text(
                                    "Delete photo",
                                    style: TextStyle(
                                      color: Colors.red,
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 14),

                      _FieldLabel("First name"),
                      _RoundedField(controller: _firstName),

                      const SizedBox(height: 12),

                      _FieldLabel("Last name"),
                      _RoundedField(controller: _lastName),

                      const SizedBox(height: 12),

                      _FieldLabel("Date of birth"),
                      GestureDetector(
                        onTap: _pickDate,
                        child: AbsorbPointer(
                          child: _RoundedField(
                            controller: _dob,
                            suffix: const Icon(Icons.calendar_today_outlined, size: 18, color: muted),
                          ),
                        ),
                      ),

                      const SizedBox(height: 12),

                      _FieldLabel("Phone number"),
                      Row(
                        children: [
                          Container(
                            height: 48,
                            padding: const EdgeInsets.symmetric(horizontal: 10),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(color: const Color(0xFFE2E8F0)),
                            ),
                            child: Row(
                              children: [
                                const Text("🇸🇦", style: TextStyle(fontSize: 16)),
                                const SizedBox(width: 8),
                                DropdownButtonHideUnderline(
                                  child: DropdownButton<String>(
                                    value: _countryCode,
                                    items: const [
                                      DropdownMenuItem(value: "+966", child: Text("+966")),
                                      DropdownMenuItem(value: "+1", child: Text("+1")),
                                      DropdownMenuItem(value: "+44", child: Text("+44")),
                                    ],
                                    onChanged: (v) => setState(() => _countryCode = v ?? "+966"),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: _RoundedField(
                              controller: _phone,
                              hint: "000 000 0000",
                              keyboardType: TextInputType.phone,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
      // keep your bottom nav outside this file if you already have it
    );
  }
}

class _IconTile extends StatelessWidget {
  const _IconTile();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 34,
      height: 34,
      decoration: BoxDecoration(
        color: const Color(0xFFE2E8F0),
        borderRadius: BorderRadius.circular(10),
      ),
      child: const Icon(Icons.person_outline, size: 18, color: Color(0xFF334155)),
    );
  }
}

class _FieldLabel extends StatelessWidget {
  const _FieldLabel(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Text(
          text,
          style: const TextStyle(
            color: Color(0xFF475569),
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}

class _RoundedField extends StatelessWidget {
  const _RoundedField({
    required this.controller,
    this.hint,
    this.suffix,
    this.keyboardType,
  });

  final TextEditingController controller;
  final String? hint;
  final Widget? suffix;
  final TextInputType? keyboardType;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      decoration: InputDecoration(
        hintText: hint,
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
        ),
        suffixIcon: suffix,
      ),
    );
  }
}
