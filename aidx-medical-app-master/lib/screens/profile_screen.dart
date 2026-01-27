import 'dart:io';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';

import 'package:firebase_storage/firebase_storage.dart';

import 'package:aidx/services/auth_service.dart';
import 'package:aidx/services/database_init.dart';
import 'package:aidx/services/emergency_service.dart';
import 'package:aidx/utils/constants.dart';
import 'package:aidx/utils/theme.dart';
import 'package:aidx/widgets/glass_container.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _formKey = GlobalKey<FormState>();

  bool _isLoading = true;
  bool _isEditing = false;

  File? _pickedImage;
  String? _profileImageUrl;

  // Form controllers
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _ageController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  String _selectedGender = '';

  // Emergency info controllers
  final TextEditingController _addressController = TextEditingController();
  final TextEditingController _emergencyContactController = TextEditingController();
  final TextEditingController _bloodTypeController = TextEditingController();
  final TextEditingController _allergiesController = TextEditingController();
  final TextEditingController _medicationsController = TextEditingController();
  final TextEditingController _conditionsController = TextEditingController();
  final TextEditingController _emergencyInstructionsController = TextEditingController();

  // Emergency lookup state
  final TextEditingController _emergencyPhoneController = TextEditingController();
  bool _isLookingUpEmergency = false;
  Map<String, dynamic>? _emergencyData;
  String? _emergencyError;

  // Services
  final DatabaseService _databaseService = DatabaseService();
  final EmergencyService _emergencyService = EmergencyService();

  @override
  void initState() {
    super.initState();
    _loadUserProfile();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _ageController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _emergencyPhoneController.dispose();

    _addressController.dispose();
    _emergencyContactController.dispose();
    _bloodTypeController.dispose();
    _allergiesController.dispose();
    _medicationsController.dispose();
    _conditionsController.dispose();
    _emergencyInstructionsController.dispose();
    super.dispose();
  }

  // ----------------------- LOAD -----------------------

  Future<void> _loadUserProfile() async {
    setState(() => _isLoading = true);

    try {
      final authService = Provider.of<AuthService>(context, listen: false);
      final user = authService.currentUser;

      if (user == null) {
        setState(() => _isLoading = false);
        return;
      }

      // Defaults from Firebase Auth (first time)
      _nameController.text = user.displayName ?? '';
      _emailController.text = user.email ?? '';
      _profileImageUrl = user.photoURL;

      // Read Firestore profile (if exists)
      final raw = await _databaseService.getUserProfile(user.uid);

      Map<String, dynamic>? profile;
      if (raw == null) {
        profile = null;
      } else if (raw is Map<String, dynamic> && raw['profile'] is Map<String, dynamic>) {
        profile = (raw['profile'] as Map<String, dynamic>);
      } else if (raw is Map<String, dynamic>) {
        // sometimes service returns the profile map directly
        profile = raw;
      }

      if (profile != null) {
        _nameController.text = (profile['name'] ?? _nameController.text).toString();
        _emailController.text = (profile['email'] ?? _emailController.text).toString();

        _selectedGender = (profile['gender'] ?? '').toString();
        _ageController.text = profile['age']?.toString() ?? '';
        _phoneController.text = (profile['phone'] ?? '').toString();

        _addressController.text = (profile['address'] ?? '').toString();
        _emergencyContactController.text = (profile['emergencyContact'] ?? '').toString();
        _bloodTypeController.text = (profile['bloodType'] ?? '').toString();

        _allergiesController.text = _listToComma(profile['allergies']);
        _medicationsController.text = _listToComma(profile['medications']);
        _conditionsController.text = _listToComma(profile['conditions']);

        _emergencyInstructionsController.text = (profile['emergencyInstructions'] ?? '').toString();

        _profileImageUrl = (profile['photo'] ?? _profileImageUrl)?.toString();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load profile: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  String _listToComma(dynamic v) {
    if (v == null) return '';
    if (v is List) return v.map((x) => x.toString()).join(', ');
    return v.toString();
  }

  List<String> _commaToList(String text) {
    final t = text.trim();
    if (t.isEmpty) return [];
    return t.split(',').map((s) => s.trim()).where((s) => s.isNotEmpty).toList();
  }

  // ----------------------- SAVE -----------------------

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final authService = Provider.of<AuthService>(context, listen: false);
      final user = authService.currentUser;

      if (user == null) {
        setState(() => _isLoading = false);
        return;
      }

      // upload image (optional)
      if (_pickedImage != null) {
        final url = await _uploadProfileImage(user.uid);
        if (url != null) _profileImageUrl = url;
      }

      final payload = <String, dynamic>{
        'name': _nameController.text.trim(),
        'email': _emailController.text.trim(),
        'phone': _phoneController.text.trim(),
        'gender': _selectedGender,
        'age': _ageController.text.trim().isEmpty ? null : _ageController.text.trim(),
        'photo': _profileImageUrl,
        'address': _addressController.text.trim(),
        'emergencyContact': _emergencyContactController.text.trim(),
        'bloodType': _bloodTypeController.text.trim(),
        'allergies': _commaToList(_allergiesController.text),
        'medications': _commaToList(_medicationsController.text),
        'conditions': _commaToList(_conditionsController.text),
        'emergencyInstructions': _emergencyInstructionsController.text.trim(),
        'updatedAt': DateTime.now().toIso8601String(),
      };

      await _databaseService.updateUserProfile(user.uid, payload);

      // update Firebase Auth display name (nice-to-have)
      if (_nameController.text.trim().isNotEmpty && _nameController.text.trim() != (user.displayName ?? '')) {
        await user.updateDisplayName(_nameController.text.trim());
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Profile saved successfully')),
        );
      }

      setState(() {
        _isEditing = false;
        _pickedImage = null;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to save profile: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<String?> _uploadProfileImage(String userId) async {
    if (_pickedImage == null) return null;
    try {
      final ref = FirebaseStorage.instance.ref().child('profile_images').child('$userId.jpg');
      await ref.putFile(_pickedImage!);
      final url = await ref.getDownloadURL();
      return url;
    } catch (e) {
      debugPrint('⚠️ Error uploading profile image: $e');
      return null;
    }
  }

  // ----------------------- ACTIONS -----------------------

  Future<void> _signOut() async {
    try {
      final authService = Provider.of<AuthService>(context, listen: false);
      await authService.signOut();

      if (mounted) {
        Navigator.pushNamedAndRemoveUntil(
          context,
          AppConstants.routeLogin,
              (route) => false,
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to sign out: $e')),
        );
      }
    }
  }

  Future<void> _pickImage() async {
    if (!_isEditing) return;
    final picker = ImagePicker();
    final XFile? file = await picker.pickImage(source: ImageSource.gallery, imageQuality: 80);
    if (file != null) {
      setState(() => _pickedImage = File(file.path));
    }
  }

  Future<void> _changePasswordDialog() async {
    final passwordController = TextEditingController();
    final confirmController = TextEditingController();
    final formKey = GlobalKey<FormState>();
    bool loading = false;

    await showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(builder: (context, setState) {
          return AlertDialog(
            title: const Text('Change Password'),
            content: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(
                    controller: passwordController,
                    obscureText: true,
                    decoration: const InputDecoration(labelText: 'New Password'),
                    validator: (v) => v == null || v.length < 6 ? 'Min 6 characters' : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: confirmController,
                    obscureText: true,
                    decoration: const InputDecoration(labelText: 'Confirm Password'),
                    validator: (v) => v != passwordController.text ? 'Passwords do not match' : null,
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
              ElevatedButton(
                onPressed: loading
                    ? null
                    : () async {
                  if (!formKey.currentState!.validate()) return;
                  setState(() => loading = true);
                  try {
                    final authService = Provider.of<AuthService>(context, listen: false);
                    await authService.updatePassword(passwordController.text);
                    if (context.mounted) {
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Password updated successfully')),
                      );
                    }
                  } catch (e) {
                    setState(() => loading = false);
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Failed: $e')),
                      );
                    }
                  }
                },
                child: loading
                    ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Text('Change'),
              ),
            ],
          );
        });
      },
    );

    passwordController.dispose();
    confirmController.dispose();
  }

  Future<void> _lookupEmergencyInfo() async {
    final phoneNumber = _emergencyPhoneController.text.trim();

    if (phoneNumber.isEmpty) {
      setState(() {
        _emergencyError = 'Please enter a phone number';
        _emergencyData = null;
      });
      return;
    }

    if (!_emergencyService.isValidPhoneNumber(phoneNumber)) {
      setState(() {
        _emergencyError = 'Please enter a valid phone number';
        _emergencyData = null;
      });
      return;
    }

    setState(() {
      _isLookingUpEmergency = true;
      _emergencyError = null;
      _emergencyData = null;
    });

    try {
      final data = await _emergencyService.getEmergencyInfo(phoneNumber);
      setState(() {
        _emergencyData = data;
        _isLookingUpEmergency = false;
      });
    } catch (e) {
      setState(() {
        _emergencyError = e.toString().replaceAll('Exception: ', '');
        _emergencyData = null;
        _isLookingUpEmergency = false;
      });
    }
  }

  // ----------------------- UI -----------------------

  @override
  Widget build(BuildContext context) {
    final authService = Provider.of<AuthService>(context);
    final user = authService.currentUser;
    final theme = Theme.of(context);

    return Container(
      decoration: BoxDecoration(gradient: AppTheme.bgGradient),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          title: Text(
            'Profile',
            style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
          ),
          backgroundColor: Colors.transparent,
          elevation: 0,
          actions: [
            if (!_isLoading)
              Padding(
                padding: const EdgeInsets.only(right: 12),
                child: _isEditing
                    ? TextButton(
                  onPressed: _isLoading ? null : _saveProfile,
                  child: const Text('Save', style: TextStyle(color: Colors.white)),
                )
                    : TextButton(
                  onPressed: () => setState(() => _isEditing = true),
                  child: const Text('Edit', style: TextStyle(color: Colors.white)),
                ),
              ),
          ],
        ),
        body: Center(
          child: _isLoading
              ? const CircularProgressIndicator()
              : SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
            child: Column(
              children: [
                GlassContainer(
                  borderRadius: 32,
                  blur: 16,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
                    child: Column(
                      children: [
                        // Avatar
                        Center(
                          child: Stack(
                            children: [
                              CircleAvatar(
                                radius: 48,
                                backgroundColor: theme.colorScheme.primary.withOpacity(0.2),
                                backgroundImage: _pickedImage != null
                                    ? FileImage(_pickedImage!)
                                    : (_profileImageUrl != null ? NetworkImage(_profileImageUrl!) : null) as ImageProvider?,
                                child: (_profileImageUrl == null && _pickedImage == null)
                                    ? Text(
                                  (user?.displayName != null && user!.displayName!.isNotEmpty)
                                      ? user.displayName![0].toUpperCase()
                                      : '?',
                                  style: theme.textTheme.headlineLarge?.copyWith(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                  ),
                                )
                                    : null,
                              ),
                              if (_isEditing)
                                Positioned(
                                  bottom: 0,
                                  right: 0,
                                  child: GestureDetector(
                                    onTap: _pickImage,
                                    child: Container(
                                      decoration: BoxDecoration(
                                        color: theme.colorScheme.primary,
                                        shape: BoxShape.circle,
                                        boxShadow: [
                                          BoxShadow(
                                            color: Colors.black.withOpacity(0.2),
                                            blurRadius: 4,
                                          ),
                                        ],
                                      ),
                                      padding: const EdgeInsets.all(8),
                                      child: const Icon(Icons.edit, color: Colors.white, size: 20),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 16),

                        Text(
                          _nameController.text.isNotEmpty ? _nameController.text : (user?.displayName ?? ''),
                          style: theme.textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _emailController.text.isNotEmpty ? _emailController.text : (user?.email ?? ''),
                          style: theme.textTheme.bodyMedium?.copyWith(color: Colors.white70),
                        ),

                        const SizedBox(height: 16),
                        Divider(color: Colors.white24, thickness: 1),
                        const SizedBox(height: 16),

                        _buildProfileForm(),

                        const SizedBox(height: 24),
                        Divider(color: Colors.white24, thickness: 1),
                        const SizedBox(height: 16),

                        _buildEmergencyLookupSection(),

                        const SizedBox(height: 24),
                        Divider(color: Colors.white24, thickness: 1),
                        const SizedBox(height: 16),

                        if (_isEditing)
                          Align(
                            alignment: Alignment.centerLeft,
                            child: TextButton.icon(
                              onPressed: _changePasswordDialog,
                              icon: const Icon(Icons.lock_outline, color: Colors.white70),
                              label: Text(
                                'Change Password',
                                style: theme.textTheme.bodyMedium?.copyWith(color: Colors.white70),
                              ),
                            ),
                          ),

                        const SizedBox(height: 10),

                        OutlinedButton.icon(
                          onPressed: _signOut,
                          icon: const Icon(Icons.logout, color: Colors.white70),
                          label: Text(
                            'Logout',
                            style: theme.textTheme.bodyMedium?.copyWith(color: Colors.white70),
                          ),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: theme.colorScheme.error,
                            side: BorderSide(color: theme.colorScheme.error),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                if (_isEditing) ...[
                  const SizedBox(height: 12),
                  Text(
                    "Tip: fill what you want only. You can leave fields empty and save later.",
                    style: GoogleFonts.inter(color: Colors.white70, fontSize: 12),
                  )
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildProfileForm() {
    final theme = Theme.of(context);

    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Name (required only when saving)
          TextFormField(
            controller: _nameController,
            enabled: _isEditing,
            style: theme.textTheme.bodyLarge?.copyWith(color: Colors.white),
            decoration: _inputDec(theme, 'Name'),
            validator: (v) {
              if (!_isEditing) return null;
              if (v == null || v.trim().isEmpty) return 'Enter your name';
              return null;
            },
          ),
          const SizedBox(height: 16),

          // Email (required only when saving)
          TextFormField(
            controller: _emailController,
            enabled: _isEditing,
            style: theme.textTheme.bodyLarge?.copyWith(color: Colors.white),
            decoration: _inputDec(theme, 'Email'),
            validator: (v) {
              if (!_isEditing) return null;
              if (v == null || v.trim().isEmpty) return 'Enter your email';
              if (!v.contains('@')) return 'Enter a valid email';
              return null;
            },
          ),
          const SizedBox(height: 16),

          // Age (optional)
          TextFormField(
            controller: _ageController,
            enabled: _isEditing,
            style: theme.textTheme.bodyLarge?.copyWith(color: Colors.white),
            decoration: _inputDec(theme, 'Age'),
            keyboardType: TextInputType.number,
            validator: (v) {
              if (!_isEditing) return null;
              if (v == null || v.trim().isEmpty) return null; // optional
              if (int.tryParse(v) == null) return 'Enter a valid age';
              return null;
            },
          ),
          const SizedBox(height: 16),

          // Gender (optional)
          DropdownButtonFormField<String>(
            value: _selectedGender.isEmpty ? null : _selectedGender,
            items: ['Male', 'Female', 'Other']
                .map((g) => DropdownMenuItem(
              value: g,
              child: Text(g, style: theme.textTheme.bodyLarge?.copyWith(color: Colors.white)),
            ))
                .toList(),
            onChanged: _isEditing ? (v) => setState(() => _selectedGender = v ?? '') : null,
            decoration: _inputDec(theme, 'Gender'),
            dropdownColor: theme.colorScheme.surface.withOpacity(0.95),
          ),

          const SizedBox(height: 24),

          // Emergency Information Section (all optional)
          _sectionCard(
            title: 'Emergency Information',
            subtitle: 'This information will be accessible via emergency lookup',
            icon: Icons.health_and_safety,
            child: Column(
              children: [
                TextFormField(
                  controller: _phoneController,
                  enabled: _isEditing,
                  style: theme.textTheme.bodyLarge?.copyWith(color: Colors.white),
                  decoration: _inputDec(theme, 'Phone Number', hint: '+1234567890'),
                  keyboardType: TextInputType.phone,
                  validator: (v) {
                    if (!_isEditing) return null;
                    if (v == null || v.trim().isEmpty) return null; // optional
                    if (v.trim().length < 8) return 'Enter a valid phone number';
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _addressController,
                  enabled: _isEditing,
                  style: theme.textTheme.bodyLarge?.copyWith(color: Colors.white),
                  decoration: _inputDec(theme, 'Address'),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _emergencyContactController,
                  enabled: _isEditing,
                  style: theme.textTheme.bodyLarge?.copyWith(color: Colors.white),
                  decoration: _inputDec(theme, 'Emergency Contact', hint: '+1234567890 or name'),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _bloodTypeController,
                  enabled: _isEditing,
                  style: theme.textTheme.bodyLarge?.copyWith(color: Colors.white),
                  decoration: _inputDec(theme, 'Blood Type', hint: 'O+, A-, B+, AB-'),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _allergiesController,
                  enabled: _isEditing,
                  style: theme.textTheme.bodyLarge?.copyWith(color: Colors.white),
                  decoration: _inputDec(theme, 'Allergies', hint: 'Peanuts, Penicillin (comma separated)'),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _medicationsController,
                  enabled: _isEditing,
                  style: theme.textTheme.bodyLarge?.copyWith(color: Colors.white),
                  decoration: _inputDec(theme, 'Current Medications', hint: 'comma separated'),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _conditionsController,
                  enabled: _isEditing,
                  style: theme.textTheme.bodyLarge?.copyWith(color: Colors.white),
                  decoration: _inputDec(theme, 'Medical Conditions', hint: 'comma separated'),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _emergencyInstructionsController,
                  enabled: _isEditing,
                  maxLines: 2,
                  style: theme.textTheme.bodyLarge?.copyWith(color: Colors.white),
                  decoration: _inputDec(theme, 'Emergency Instructions', hint: 'Special instructions'),
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // Inline buttons (optional — AppBar has Edit/Save too, but these are nice)
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              if (_isEditing)
                OutlinedButton(
                  onPressed: _isLoading
                      ? null
                      : () async {
                    setState(() => _isEditing = false);
                    await _loadUserProfile(); // revert changes
                  },
                  style: OutlinedButton.styleFrom(
                    foregroundColor: theme.colorScheme.secondary,
                    side: BorderSide(color: theme.colorScheme.secondary),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text('Cancel'),
                ),
              if (_isEditing)
                ElevatedButton(
                  onPressed: _isLoading ? null : _saveProfile,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: theme.colorScheme.primary,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: _isLoading
                      ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  )
                      : const Text('Save'),
                ),
            ],
          ),
        ],
      ),
    );
  }

  InputDecoration _inputDec(ThemeData theme, String label, {String? hint}) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      labelStyle: theme.textTheme.bodyMedium?.copyWith(color: Colors.white70),
      hintStyle: theme.textTheme.bodyMedium?.copyWith(color: Colors.white38),
      filled: true,
      fillColor: Colors.white.withOpacity(0.08),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
    );
  }

  Widget _sectionCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required Widget child,
  }) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withOpacity(0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: theme.colorScheme.primary, size: 20),
              const SizedBox(width: 8),
              Text(
                title,
                style: theme.textTheme.titleSmall?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(subtitle, style: theme.textTheme.bodySmall?.copyWith(color: Colors.white70)),
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }

  // ----------------------- Emergency Lookup UI -----------------------

  Widget _buildEmergencyInfoRow(String label, String? value) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              '$label:',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: Colors.white70,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value ?? 'Not available',
              style: theme.textTheme.bodyMedium?.copyWith(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMedicalInfo(Map<String, dynamic> medicalInfo) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (medicalInfo['bloodType'] != null) _buildEmergencyInfoRow('Blood Type', medicalInfo['bloodType']),
        if (medicalInfo['allergies'] != null && medicalInfo['allergies'] is List)
          _buildEmergencyInfoRow('Allergies', (medicalInfo['allergies'] as List).join(', ')),
        if (medicalInfo['medications'] != null && medicalInfo['medications'] is List)
          _buildEmergencyInfoRow('Medications', (medicalInfo['medications'] as List).join(', ')),
        if (medicalInfo['conditions'] != null && medicalInfo['conditions'] is List)
          _buildEmergencyInfoRow('Conditions', (medicalInfo['conditions'] as List).join(', ')),
        if (medicalInfo['emergencyInstructions'] != null)
          _buildEmergencyInfoRow('Emergency Instructions', medicalInfo['emergencyInstructions']),
      ],
    );
  }

  Widget _buildEmergencyLookupSection() {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.emergency, color: theme.colorScheme.error, size: 24),
              const SizedBox(width: 8),
              Text(
                'Emergency Information Lookup',
                style: theme.textTheme.titleMedium?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'Enter a phone number to retrieve emergency contact and medical information',
            style: theme.textTheme.bodySmall?.copyWith(color: Colors.white70),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  controller: _emergencyPhoneController,
                  style: theme.textTheme.bodyLarge?.copyWith(color: Colors.white),
                  decoration: InputDecoration(
                    labelText: 'Phone Number',
                    labelStyle: theme.textTheme.bodyMedium?.copyWith(color: Colors.white70),
                    hintText: '+1234567890',
                    hintStyle: theme.textTheme.bodyMedium?.copyWith(color: Colors.white38),
                    filled: true,
                    fillColor: Colors.white.withOpacity(0.08),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    prefixIcon: const Icon(Icons.phone, color: Colors.white70),
                  ),
                  keyboardType: TextInputType.phone,
                ),
              ),
              const SizedBox(width: 12),
              ElevatedButton.icon(
                onPressed: _isLookingUpEmergency ? null : _lookupEmergencyInfo,
                icon: _isLookingUpEmergency
                    ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                )
                    : const Icon(Icons.search),
                label: Text(_isLookingUpEmergency ? 'Searching...' : 'Lookup'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: theme.colorScheme.primary,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                ),
              ),
            ],
          ),
          if (_emergencyError != null) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: theme.colorScheme.error.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: theme.colorScheme.error.withOpacity(0.3)),
              ),
              child: Row(
                children: [
                  Icon(Icons.error_outline, color: theme.colorScheme.error, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _emergencyError!,
                      style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.error),
                    ),
                  ),
                ],
              ),
            ),
          ],
          if (_emergencyData != null) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.green.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.green.withOpacity(0.3)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.check_circle, color: Colors.green, size: 20),
                      const SizedBox(width: 8),
                      Text(
                        'Emergency Information Found',
                        style: theme.textTheme.titleSmall?.copyWith(
                          color: Colors.green,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  _buildEmergencyInfoRow('Name', _emergencyData!['name']),
                  _buildEmergencyInfoRow('Address', _emergencyData!['address']),
                  _buildEmergencyInfoRow('Emergency Contact', _emergencyData!['emergencyContact']),
                  if (_emergencyData!['medicalInfo'] != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      'Medical Information:',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    _buildMedicalInfo(_emergencyData!['medicalInfo']),
                  ],
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
