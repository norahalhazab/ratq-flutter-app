import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:aidx/services/auth_service.dart';
import 'package:aidx/utils/theme.dart';
import 'package:aidx/widgets/glass_container.dart';
import 'package:flutter_feather_icons/flutter_feather_icons.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:io';
import 'package:aidx/utils/constants.dart';
import 'package:aidx/services/database_init.dart';
import 'package:aidx/main.dart' show routeObserver;
import 'package:aidx/services/emergency_service.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> with RouteAware {
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = true;
  bool _isEditing = false;
  File? _pickedImage;
  
  // Form controllers
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _ageController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _genderController = TextEditingController();
  final TextEditingController _emergencyPhoneController = TextEditingController();
  String _selectedGender = '';
  String? _profileImageUrl;
  final DatabaseService _databaseService = DatabaseService();
  final EmergencyService _emergencyService = EmergencyService();
  bool _dataChanged = false;

  // Emergency lookup state
  bool _isLookingUpEmergency = false;
  Map<String, dynamic>? _emergencyData;
  String? _emergencyError;

  // Emergency information controllers
  final TextEditingController _addressController = TextEditingController();
  final TextEditingController _emergencyContactController = TextEditingController();
  final TextEditingController _bloodTypeController = TextEditingController();
  final TextEditingController _allergiesController = TextEditingController();
  final TextEditingController _medicationsController = TextEditingController();
  final TextEditingController _conditionsController = TextEditingController();
  final TextEditingController _emergencyInstructionsController = TextEditingController();
  
  @override
  void initState() {
    super.initState();
    _loadUserProfile();
    
    // Add listeners to detect changes
    _nameController.addListener(_markAsChanged);
    _ageController.addListener(_markAsChanged);
    _emailController.addListener(_markAsChanged);
    _phoneController.addListener(_markAsChanged);
    _genderController.addListener(_markAsChanged);
    _addressController.addListener(_markAsChanged);
    _emergencyContactController.addListener(_markAsChanged);
    _bloodTypeController.addListener(_markAsChanged);
    _allergiesController.addListener(_markAsChanged);
    _medicationsController.addListener(_markAsChanged);
    _conditionsController.addListener(_markAsChanged);
    _emergencyInstructionsController.addListener(_markAsChanged);
  }
  
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final ModalRoute<dynamic>? route = ModalRoute.of(context);
    if (route != null) {
      routeObserver.subscribe(this, route);
    }
  }
  
  @override
  void didPop() {
    // Save data when navigating back
    if (_dataChanged && (_formKey.currentState?.validate() ?? false)) {
      _saveProfileData();
    }
    super.didPop();
  }
  
  @override
  void didPushNext() {
    // Save data when navigating to another screen
    if (_dataChanged && (_formKey.currentState?.validate() ?? false)) {
      _saveProfileData();
    }
    super.didPushNext();
  }
  
  void _markAsChanged() {
    setState(() {
      _dataChanged = true;
    });
  }
  
  @override
  void dispose() {
    routeObserver.unsubscribe(this);
    
    // Remove listeners
    _nameController.removeListener(_markAsChanged);
    _ageController.removeListener(_markAsChanged);
    _emailController.removeListener(_markAsChanged);
    _phoneController.removeListener(_markAsChanged);
    _genderController.removeListener(_markAsChanged);
    _addressController.removeListener(_markAsChanged);
    _emergencyContactController.removeListener(_markAsChanged);
    _bloodTypeController.removeListener(_markAsChanged);
    _allergiesController.removeListener(_markAsChanged);
    _medicationsController.removeListener(_markAsChanged);
    _conditionsController.removeListener(_markAsChanged);
    _emergencyInstructionsController.removeListener(_markAsChanged);
    
    _nameController.dispose();
    _ageController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _genderController.dispose();
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
  
  // Method to save profile data without requiring edit mode
  Future<void> _saveProfileData() async {
    try {
      final authService = Provider.of<AuthService>(context, listen: false);
      final user = authService.currentUser;
      
      if (user != null && _dataChanged) {
        // Only save if data has changed
        // Upload image first if a new one was chosen
        if (_pickedImage != null) {
          await _uploadProfileImage(user.uid);
        }
        
        await _databaseService.updateUserProfile(user.uid, {
          'name': _nameController.text,
          'email': _emailController.text,
          'phone': _phoneController.text,
          'gender': _selectedGender,
          'age': _ageController.text.isNotEmpty ? _ageController.text : null,
          'photo': _profileImageUrl,
          'address': _addressController.text,
          'emergencyContact': _emergencyContactController.text,
          'bloodType': _bloodTypeController.text,
          'allergies': _allergiesController.text.isNotEmpty 
              ? _allergiesController.text.split(',').map((s) => s.trim()).toList() 
              : [],
          'medications': _medicationsController.text.isNotEmpty 
              ? _medicationsController.text.split(',').map((s) => s.trim()).toList() 
              : [],
          'conditions': _conditionsController.text.isNotEmpty 
              ? _conditionsController.text.split(',').map((s) => s.trim()).toList() 
              : [],
          'emergencyInstructions': _emergencyInstructionsController.text,
        });

        // Update display name in Firebase Auth
        if (_nameController.text != user.displayName) {
          await user.updateDisplayName(_nameController.text);
        }
        
        debugPrint('✅ Profile data saved automatically');
        _dataChanged = false;
      }
    } catch (e) {
      debugPrint('⚠️ Error auto-saving profile: $e');
    }
  }
  
  Future<void> _loadUserProfile() async {
    setState(() {
      _isLoading = true;
      _dataChanged = false;
    });
    
    try {
      final authService = Provider.of<AuthService>(context, listen: false);
      final user = authService.currentUser;
      
      if (user != null) {
        // Get user profile from Firestore
        final profileData = await _databaseService.getUserProfile(user.uid);
        
        if (profileData != null && profileData['profile'] != null) {
          final profile = profileData['profile'] as Map<String, dynamic>;
          
          setState(() {
            _nameController.text = profile['name'] ?? user.displayName ?? '';
            _emailController.text = profile['email'] ?? user.email ?? '';
            _genderController.text = profile['gender'] ?? '';
            _selectedGender = profile['gender'] ?? '';
            _ageController.text = profile['age']?.toString() ?? '';
            _phoneController.text = profile['phone'] ?? '';
            _addressController.text = profile['address'] ?? '';
            _emergencyContactController.text = profile['emergencyContact'] ?? '';
            _bloodTypeController.text = profile['bloodType'] ?? '';
            _allergiesController.text = profile['allergies'] != null 
                ? (profile['allergies'] is List ? (profile['allergies'] as List).join(', ') : profile['allergies']) 
                : '';
            _medicationsController.text = profile['medications'] != null 
                ? (profile['medications'] is List ? (profile['medications'] as List).join(', ') : profile['medications']) 
                : '';
            _conditionsController.text = profile['conditions'] != null 
                ? (profile['conditions'] is List ? (profile['conditions'] as List).join(', ') : profile['conditions']) 
                : '';
            _emergencyInstructionsController.text = profile['emergencyInstructions'] ?? '';
            _profileImageUrl = profile['photo'] ?? user.photoURL;
          });
        } else {
          // If no profile exists, use data from Firebase Auth
          setState(() {
            _nameController.text = user.displayName ?? '';
            _emailController.text = user.email ?? '';
            _profileImageUrl = user.photoURL;
          });
        }
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to load profile: $e')),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }
  
  Future<void> _updateProfile() async {
    if (!_isEditing) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final authService = Provider.of<AuthService>(context, listen: false);
      final user = authService.currentUser;

      if (user != null) {
        // Upload image if a new one has been picked
        if (_pickedImage != null) {
          await _uploadProfileImage(user.uid);
        }

        // Update user profile in Firestore
        await _databaseService.updateUserProfile(user.uid, {
          'name': _nameController.text,
          'email': _emailController.text,
          'phone': _phoneController.text,
          'gender': _selectedGender,
          'age': _ageController.text.isNotEmpty ? _ageController.text : null,
          'photo': _profileImageUrl,
          'address': _addressController.text,
          'emergencyContact': _emergencyContactController.text,
          'bloodType': _bloodTypeController.text,
          'allergies': _allergiesController.text.isNotEmpty 
              ? _allergiesController.text.split(',').map((s) => s.trim()).toList() 
              : [],
          'medications': _medicationsController.text.isNotEmpty 
              ? _medicationsController.text.split(',').map((s) => s.trim()).toList() 
              : [],
          'conditions': _conditionsController.text.isNotEmpty 
              ? _conditionsController.text.split(',').map((s) => s.trim()).toList() 
              : [],
          'emergencyInstructions': _emergencyInstructionsController.text,
        });

        // Update display name in Firebase Auth
        if (_nameController.text != user.displayName) {
          await user.updateDisplayName(_nameController.text);
        }

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Profile updated successfully')),
        );
        
        _dataChanged = false;
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to update profile: $e')),
      );
    } finally {
      setState(() {
        _isLoading = false;
        _isEditing = false;
      });
    }
  }
  
  Future<void> _signOut() async {
    try {
      final authService = Provider.of<AuthService>(context, listen: false);
      await authService.signOut();
      
      if (mounted) {
        // Navigate to the login screen and remove all previous routes
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

  Future<void> _pickImage() async {
    final ImagePicker picker = ImagePicker();
    final XFile? file = await picker.pickImage(source: ImageSource.gallery, imageQuality: 80);
    if (file != null) {
      setState(() {
        _pickedImage = File(file.path);
        _dataChanged = true; // Mark data as changed when a new image is selected
      });
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
        return StatefulBuilder(
          builder: (context, setState) {
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
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: loading
                      ? null
                      : () async {
                          if (!formKey.currentState!.validate()) return;
                          setState(() => loading = true);
                          try {
                            final authService = Provider.of<AuthService>(context, listen: false);
                            await authService.updatePassword(passwordController.text);
                            if (mounted) {
                              Navigator.pop(context);
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Password updated successfully')),
                              );
                            }
                          } catch (e) {
                            setState(() => loading = false);
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Failed: $e')),
                            );
                          }
                        },
                  child: loading
                      ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Text('Change'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  // Upload the selected profile image to Firebase Storage and return the download URL
  Future<String?> _uploadProfileImage(String userId) async {
    if (_pickedImage == null) return null;
    try {
      final ref = FirebaseStorage.instance
          .ref()
          .child('profile_images')
          .child('$userId.jpg');

      // Upload the file
      await ref.putFile(_pickedImage!);

      // Retrieve the download URL
      final url = await ref.getDownloadURL();

      setState(() {
        _profileImageUrl = url;
        _pickedImage = null; // Clear picked image once uploaded
      });

      return url;
    } catch (e) {
      debugPrint('⚠️ Error uploading profile image: $e');
      return null;
    }
  }

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
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (medicalInfo['bloodType'] != null)
          _buildEmergencyInfoRow('Blood Type', medicalInfo['bloodType']),
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

  Widget _buildProfileForm() {
    final theme = Theme.of(context);
    final user = context.watch<AuthService>().currentUser;

    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Name
          TextFormField(
            controller: _nameController,
            enabled: _isEditing,
            style: theme.textTheme.bodyLarge?.copyWith(color: Colors.white),
            decoration: InputDecoration(
              labelText: 'Name',
              labelStyle: theme.textTheme.bodyMedium?.copyWith(color: Colors.white70),
              filled: true,
              fillColor: Colors.white.withOpacity(0.08),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
            ),
            validator: (value) {
              if (value == null || value.isEmpty) return 'Enter your name';
              return null;
            },
          ),
          const SizedBox(height: 16),
          // Email
          TextFormField(
            controller: _emailController,
            enabled: _isEditing,
            style: theme.textTheme.bodyLarge?.copyWith(color: Colors.white),
            decoration: InputDecoration(
              labelText: 'Email',
              labelStyle: theme.textTheme.bodyMedium?.copyWith(color: Colors.white70),
              filled: true,
              fillColor: Colors.white.withOpacity(0.08),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
            ),
            validator: (value) {
              if (value == null || value.isEmpty) return 'Enter your email';
              if (!value.contains('@')) return 'Enter a valid email';
              return null;
            },
          ),
          const SizedBox(height: 16),
          // Age
          TextFormField(
            controller: _ageController,
            enabled: _isEditing,
            style: theme.textTheme.bodyLarge?.copyWith(color: Colors.white),
            decoration: InputDecoration(
              labelText: 'Age',
              labelStyle: theme.textTheme.bodyMedium?.copyWith(color: Colors.white70),
              filled: true,
              fillColor: Colors.white.withOpacity(0.08),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
            ),
            keyboardType: TextInputType.number,
            validator: (value) {
              if (value == null || value.isEmpty) return 'Enter your age';
              if (int.tryParse(value) == null) return 'Enter a valid age';
              return null;
            },
          ),
          const SizedBox(height: 16),
          // Gender
          DropdownButtonFormField<String>(
            initialValue: _selectedGender.isEmpty ? null : _selectedGender,
            items: ['Male', 'Female', 'Other']
                .map((g) => DropdownMenuItem(
                      value: g,
                      child: Text(g, style: theme.textTheme.bodyLarge?.copyWith(color: Colors.white)),
                    ))
                .toList(),
            onChanged: _isEditing
                ? (value) => setState(() => _selectedGender = value ?? '')
                : null,
            decoration: InputDecoration(
              labelText: 'Gender',
              labelStyle: theme.textTheme.bodyMedium?.copyWith(color: Colors.white70),
              filled: true,
              fillColor: Colors.white.withOpacity(0.08),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
            ),
            dropdownColor: theme.colorScheme.surface.withOpacity(0.95),
          ),
          const SizedBox(height: 24),
          // Emergency Information Section
          Container(
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
                    Icon(Icons.health_and_safety, color: theme.colorScheme.primary, size: 20),
                    const SizedBox(width: 8),
                    Text(
                      'Emergency Information',
                      style: theme.textTheme.titleSmall?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  'This information will be accessible via emergency lookup',
                  style: theme.textTheme.bodySmall?.copyWith(color: Colors.white70),
                ),
                const SizedBox(height: 16),
                // Phone Number (moved to emergency section)
                TextFormField(
                  controller: _phoneController,
                  enabled: _isEditing,
                  style: theme.textTheme.bodyLarge?.copyWith(color: Colors.white),
                  decoration: InputDecoration(
                    labelText: 'Phone Number',
                    labelStyle: theme.textTheme.bodyMedium?.copyWith(color: Colors.white70),
                    hintText: '+1234567890',
                    hintStyle: theme.textTheme.bodyMedium?.copyWith(color: Colors.white38),
                    filled: true,
                    fillColor: Colors.white.withOpacity(0.08),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  keyboardType: TextInputType.phone,
                  validator: (value) {
                    if (value == null || value.isEmpty) return 'Enter your phone number';
                    if (value.length < 8) return 'Enter a valid phone number';
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                // Address
                TextFormField(
                  controller: _addressController,
                  enabled: _isEditing,
                  style: theme.textTheme.bodyLarge?.copyWith(color: Colors.white),
                  decoration: InputDecoration(
                    labelText: 'Address',
                    labelStyle: theme.textTheme.bodyMedium?.copyWith(color: Colors.white70),
                    filled: true,
                    fillColor: Colors.white.withOpacity(0.08),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
                const SizedBox(height: 12),
                // Emergency Contact
                TextFormField(
                  controller: _emergencyContactController,
                  enabled: _isEditing,
                  style: theme.textTheme.bodyLarge?.copyWith(color: Colors.white),
                  decoration: InputDecoration(
                    labelText: 'Emergency Contact',
                    labelStyle: theme.textTheme.bodyMedium?.copyWith(color: Colors.white70),
                    hintText: '+1234567890 or name',
                    hintStyle: theme.textTheme.bodyMedium?.copyWith(color: Colors.white38),
                    filled: true,
                    fillColor: Colors.white.withOpacity(0.08),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
                const SizedBox(height: 12),
                // Blood Type
                TextFormField(
                  controller: _bloodTypeController,
                  enabled: _isEditing,
                  style: theme.textTheme.bodyLarge?.copyWith(color: Colors.white),
                  decoration: InputDecoration(
                    labelText: 'Blood Type',
                    labelStyle: theme.textTheme.bodyMedium?.copyWith(color: Colors.white70),
                    hintText: 'O+, A-, B+, AB-, etc.',
                    hintStyle: theme.textTheme.bodyMedium?.copyWith(color: Colors.white38),
                    filled: true,
                    fillColor: Colors.white.withOpacity(0.08),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
                const SizedBox(height: 12),
                // Allergies
                TextFormField(
                  controller: _allergiesController,
                  enabled: _isEditing,
                  style: theme.textTheme.bodyLarge?.copyWith(color: Colors.white),
                  decoration: InputDecoration(
                    labelText: 'Allergies',
                    labelStyle: theme.textTheme.bodyMedium?.copyWith(color: Colors.white70),
                    hintText: 'Peanuts, Penicillin, etc. (comma separated)',
                    hintStyle: theme.textTheme.bodyMedium?.copyWith(color: Colors.white38),
                    filled: true,
                    fillColor: Colors.white.withOpacity(0.08),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
                const SizedBox(height: 12),
                // Medications
                TextFormField(
                  controller: _medicationsController,
                  enabled: _isEditing,
                  style: theme.textTheme.bodyLarge?.copyWith(color: Colors.white),
                  decoration: InputDecoration(
                    labelText: 'Current Medications',
                    labelStyle: theme.textTheme.bodyMedium?.copyWith(color: Colors.white70),
                    hintText: 'Lisinopril 10mg daily, etc. (comma separated)',
                    hintStyle: theme.textTheme.bodyMedium?.copyWith(color: Colors.white38),
                    filled: true,
                    fillColor: Colors.white.withOpacity(0.08),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
                const SizedBox(height: 12),
                // Medical Conditions
                TextFormField(
                  controller: _conditionsController,
                  enabled: _isEditing,
                  style: theme.textTheme.bodyLarge?.copyWith(color: Colors.white),
                  decoration: InputDecoration(
                    labelText: 'Medical Conditions',
                    labelStyle: theme.textTheme.bodyMedium?.copyWith(color: Colors.white70),
                    hintText: 'Hypertension, Diabetes, etc. (comma separated)',
                    hintStyle: theme.textTheme.bodyMedium?.copyWith(color: Colors.white38),
                    filled: true,
                    fillColor: Colors.white.withOpacity(0.08),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
                const SizedBox(height: 12),
                // Emergency Instructions
                TextFormField(
                  controller: _emergencyInstructionsController,
                  enabled: _isEditing,
                  maxLines: 2,
                  style: theme.textTheme.bodyLarge?.copyWith(color: Colors.white),
                  decoration: InputDecoration(
                    labelText: 'Emergency Instructions',
                    labelStyle: theme.textTheme.bodyMedium?.copyWith(color: Colors.white70),
                    hintText: 'Special instructions for emergency responders',
                    hintStyle: theme.textTheme.bodyMedium?.copyWith(color: Colors.white38),
                    filled: true,
                    fillColor: Colors.white.withOpacity(0.08),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          // Buttons
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              if (_isEditing)
                OutlinedButton(
                  onPressed: _isLoading ? null : () => setState(() => _isEditing = false),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: theme.colorScheme.secondary,
                    side: BorderSide(color: theme.colorScheme.secondary),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text('Cancel'),
                ),
              if (_isEditing)
                ElevatedButton(
                  onPressed: _isLoading ? null : _updateProfile,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: theme.colorScheme.primary,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: _isLoading
                      ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Text('Save'),
                ),
              if (!_isEditing)
                OutlinedButton(
                  onPressed: _isLoading ? null : () => setState(() => _isEditing = true),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: theme.colorScheme.primary,
                    side: BorderSide(color: theme.colorScheme.primary),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text('Edit'),
                ),
            ],
          ),
          const SizedBox(height: 16),
          // Change Password Button
          if (_isEditing)
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: _changePasswordDialog,
                icon: const Icon(Icons.lock_outline, color: Colors.white70),
                label: Text('Change Password', style: theme.textTheme.bodyMedium?.copyWith(color: Colors.white70)),
              ),
            ),
        ],
      ),
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
                    prefixIcon: Icon(Icons.phone, color: Colors.white70),
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
                      Icon(Icons.check_circle, color: Colors.green, size: 20),
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

  @override
  Widget build(BuildContext context) {
    final authService = Provider.of<AuthService>(context);
    final user = authService.currentUser;
    final theme = Theme.of(context);

    return WillPopScope(
      onWillPop: () async {
        // Save profile data when leaving the page if form is valid
        if (_dataChanged && (_formKey.currentState?.validate() ?? false)) {
          await _saveProfileData();
        }
        return true;
      },
      child: Container(
        decoration: BoxDecoration(
          gradient: AppTheme.bgGradient,
        ),
        child: Scaffold(
          backgroundColor: Colors.transparent,
          appBar: AppBar(
            title: Text('Profile', style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
            backgroundColor: Colors.transparent,
            elevation: 0,
          ),
          body: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    decoration: BoxDecoration(
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.1),
                          blurRadius: 16,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: GlassContainer(
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
                                        : _profileImageUrl != null
                                            ? NetworkImage(_profileImageUrl!) as ImageProvider
                                            : null,
                                    child: _profileImageUrl == null && _pickedImage == null
                                        ? Text(
                                            user?.displayName != null && user!.displayName!.isNotEmpty
                                                ? user.displayName![0].toUpperCase()
                                                : '?',
                                            style: theme.textTheme.headlineLarge?.copyWith(color: Colors.white, fontWeight: FontWeight.bold),
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
                            // Name
                            Text(
                              _nameController.text.isNotEmpty ? _nameController.text : (user?.displayName ?? ''),
                              style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold, color: Colors.white),
                            ),
                            const SizedBox(height: 4),
                            // Email subtitle
                            Text(
                              _emailController.text.isNotEmpty ? _emailController.text : (user?.email ?? ''),
                              style: theme.textTheme.bodyMedium?.copyWith(color: Colors.white70),
                            ),
                            const SizedBox(height: 16),
                            Divider(color: Colors.white24, thickness: 1),
                            const SizedBox(height: 16),
                            // Form
                            _buildProfileForm(),
                            const SizedBox(height: 24),
                            Divider(color: Colors.white24, thickness: 1),
                            const SizedBox(height: 16),
                            // Emergency Information Lookup Section
                            _buildEmergencyLookupSection(),
                            const SizedBox(height: 24),
                            Divider(color: Colors.white24, thickness: 1),
                            const SizedBox(height: 16),
                            // Logout
                            OutlinedButton.icon(
                              onPressed: _signOut,
                              icon: const Icon(Icons.logout, color: Colors.white70),
                              label: Text('Logout', style: theme.textTheme.bodyMedium?.copyWith(color: Colors.white70)),
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
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}