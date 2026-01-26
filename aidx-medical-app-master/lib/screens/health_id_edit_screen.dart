import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/health_id_model.dart';
import '../services/health_id_service.dart';
import '../utils/app_colors.dart';
import '../widgets/glass_container.dart';

class HealthIdEditScreen extends StatefulWidget {
  final HealthIdModel? healthId;

  const HealthIdEditScreen({super.key, this.healthId});

  @override
  State<HealthIdEditScreen> createState() => _HealthIdEditScreenState();
}

class _HealthIdEditScreenState extends State<HealthIdEditScreen> {
  final HealthIdService _healthIdService = HealthIdService();
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _phoneNumberController = TextEditingController();
  final _ageController = TextEditingController();
  final _addressController = TextEditingController();
  final _medicalConditionsController = TextEditingController();
  final _notesController = TextEditingController();
  
  String? _selectedBloodGroup;
  List<String> _selectedAllergies = [];
  List<EmergencyContact> _emergencyContacts = [];
  
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _initializeData();
  }

  void _initializeData() {
    if (widget.healthId != null) {
      _nameController.text = widget.healthId!.name;
      _phoneNumberController.text = widget.healthId!.phoneNumber ?? '';
      _ageController.text = widget.healthId!.age ?? '';
      _addressController.text = widget.healthId!.address ?? '';
      _selectedBloodGroup = widget.healthId!.bloodGroup;
      _selectedAllergies = List.from(widget.healthId!.allergies);
      _emergencyContacts = List.from(widget.healthId!.emergencyContacts);
      _medicalConditionsController.text = widget.healthId!.medicalConditions ?? '';
      _notesController.text = widget.healthId!.notes ?? '';
    } else {
      // Set default name from Firebase Auth
      final user = FirebaseAuth.instance.currentUser;
      if (user != null && user.displayName != null) {
        _nameController.text = user.displayName!;
      }
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneNumberController.dispose();
    _ageController.dispose();
    _addressController.dispose();
    _medicalConditionsController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.healthId == null ? 'Create Health ID' : 'Edit Health ID',
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: AppColors.primaryColor,
        elevation: 0,
        actions: [
          TextButton(
            onPressed: _isLoading ? null : _saveHealthId,
            child: _isLoading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  )
                : const Text(
                    'Save',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Basic Information
              GlassContainer(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Basic Information',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _nameController,
                      decoration: const InputDecoration(
                        labelText: 'Full Name *',
                        border: OutlineInputBorder(),
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter your name';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _phoneNumberController,
                      keyboardType: TextInputType.phone,
                      decoration: const InputDecoration(
                        labelText: 'Phone Number *',
                        border: OutlineInputBorder(),
                        hintText: '01XXXXXXXXX',
                        prefixIcon: Icon(Icons.phone),
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter your phone number';
                        }
                        final digitsOnly = value.replaceAll(RegExp(r'[^\d]'), '');
                        if (digitsOnly.length < 10) {
                          return 'Please enter a valid phone number';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _ageController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Age',
                        border: OutlineInputBorder(),
                      ),
                      validator: (value) {
                        if (value != null && value.isNotEmpty) {
                          final age = int.tryParse(value);
                          if (age == null || age < 0 || age > 150) {
                            return 'Please enter a valid age (0-150)';
                          }
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _addressController,
                      decoration: const InputDecoration(
                        labelText: 'Address',
                        border: OutlineInputBorder(),
                        hintText: 'City, Country',
                        prefixIcon: Icon(Icons.location_on),
                      ),
                      maxLines: 2,
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<String>(
                      initialValue: _selectedBloodGroup,
                      decoration: const InputDecoration(
                        labelText: 'Blood Group',
                        border: OutlineInputBorder(),
                      ),
                      items: _healthIdService.getBloodGroupOptions()
                          .map((group) => DropdownMenuItem(
                                value: group,
                                child: Text(group),
                              ))
                          .toList(),
                      onChanged: (value) {
                        setState(() {
                          _selectedBloodGroup = value;
                        });
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Allergies
              GlassContainer(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Allergies',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),
                    _buildAllergiesSection(),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Emergency Contacts
              GlassContainer(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Emergency Contacts',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        IconButton(
                          onPressed: _addEmergencyContact,
                          icon: const Icon(Icons.add_circle, color: AppColors.primaryColor),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    _buildEmergencyContactsSection(),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Medical Information
              GlassContainer(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Medical Information',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _medicalConditionsController,
                      decoration: const InputDecoration(
                        labelText: 'Medical Conditions',
                        border: OutlineInputBorder(),
                        hintText: 'e.g., Diabetes, Hypertension, etc.',
                      ),
                      maxLines: 3,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _notesController,
                      decoration: const InputDecoration(
                        labelText: 'Additional Notes',
                        border: OutlineInputBorder(),
                        hintText: 'Any additional medical information...',
                      ),
                      maxLines: 3,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAllergiesSection() {
    return Column(
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: _healthIdService.getCommonAllergies().map((allergy) {
            final isSelected = _selectedAllergies.contains(allergy);
            return FilterChip(
              label: Text(allergy),
              selected: isSelected,
              onSelected: (selected) {
                setState(() {
                  if (selected) {
                    _selectedAllergies.add(allergy);
                  } else {
                    _selectedAllergies.remove(allergy);
                  }
                });
              },
              selectedColor: AppColors.primaryColor.withOpacity(0.2),
              checkmarkColor: AppColors.primaryColor,
            );
          }).toList(),
        ),
        const SizedBox(height: 16),
        TextFormField(
          decoration: const InputDecoration(
            labelText: 'Add Custom Allergy',
            border: OutlineInputBorder(),
            hintText: 'Type and press Enter to add',
          ),
          onFieldSubmitted: (value) {
            if (value.isNotEmpty && !_selectedAllergies.contains(value)) {
              setState(() {
                _selectedAllergies.add(value);
              });
            }
          },
        ),
      ],
    );
  }

  Widget _buildEmergencyContactsSection() {
    if (_emergencyContacts.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Text(
            'No emergency contacts added yet.\nTap the + button to add one.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey),
          ),
        ),
      );
    }

    return Column(
      children: _emergencyContacts.asMap().entries.map((entry) {
        final index = entry.key;
        final contact = entry.value;
        return _buildContactCard(index, contact);
      }).toList(),
    );
  }

  Widget _buildContactCard(int index, EmergencyContact contact) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white.withOpacity(0.2)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      contact.name,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    Text(
                      contact.relationship,
                      style: const TextStyle(color: Colors.grey),
                    ),
                    Text(contact.phone),
                    if (contact.email != null) Text(contact.email!),
                  ],
                ),
              ),
              IconButton(
                onPressed: () => _editEmergencyContact(index),
                icon: const Icon(Icons.edit, color: AppColors.primaryColor),
              ),
              IconButton(
                onPressed: () => _removeEmergencyContact(index),
                icon: const Icon(Icons.delete, color: Colors.red),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _addEmergencyContact() {
    _showContactDialog();
  }

  void _editEmergencyContact(int index) {
    _showContactDialog(contact: _emergencyContacts[index], index: index);
  }

  void _removeEmergencyContact(int index) {
    setState(() {
      _emergencyContacts.removeAt(index);
    });
  }

  void _showContactDialog({EmergencyContact? contact, int? index}) {
    final nameController = TextEditingController(text: contact?.name ?? '');
    final relationshipController = TextEditingController(text: contact?.relationship ?? '');
    final phoneController = TextEditingController(text: contact?.phone ?? '');
    final emailController = TextEditingController(text: contact?.email ?? '');

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(contact == null ? 'Add Emergency Contact' : 'Edit Emergency Contact'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: const InputDecoration(
                  labelText: 'Name *',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: relationshipController,
                decoration: const InputDecoration(
                  labelText: 'Relationship *',
                  border: OutlineInputBorder(),
                  hintText: 'e.g., Spouse, Parent, Friend',
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: phoneController,
                decoration: const InputDecoration(
                  labelText: 'Phone Number *',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.phone,
              ),
              const SizedBox(height: 16),
              TextField(
                controller: emailController,
                decoration: const InputDecoration(
                  labelText: 'Email (Optional)',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.emailAddress,
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
            onPressed: () {
              if (nameController.text.isNotEmpty &&
                  relationshipController.text.isNotEmpty &&
                  phoneController.text.isNotEmpty) {
                final newContact = EmergencyContact(
                  name: nameController.text,
                  relationship: relationshipController.text,
                  phone: phoneController.text,
                  email: emailController.text.isNotEmpty ? emailController.text : null,
                );

                setState(() {
                  if (index != null) {
                    _emergencyContacts[index] = newContact;
                  } else {
                    _emergencyContacts.add(newContact);
                  }
                });

                Navigator.pop(context);
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  Future<void> _saveHealthId() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('User not authenticated')),
        );
        return;
      }

      final healthId = HealthIdModel(
        id: widget.healthId?.id,
        userId: user.uid,
        name: _nameController.text,
        phoneNumber: _phoneNumberController.text.isNotEmpty ? _phoneNumberController.text : null,
        age: _ageController.text.isNotEmpty ? _ageController.text : null,
        bloodGroup: _selectedBloodGroup,
        address: _addressController.text.isNotEmpty ? _addressController.text : null,
        allergies: _selectedAllergies,
        emergencyContacts: _emergencyContacts,
        activeMedications: [], // Will be populated by service
        medicalConditions: _medicalConditionsController.text.isNotEmpty
            ? _medicalConditionsController.text
            : null,
        notes: _notesController.text.isNotEmpty
            ? _notesController.text
            : null,
        createdAt: widget.healthId?.createdAt ?? DateTime.now(),
        updatedAt: DateTime.now(),
      );

      final savedHealthId = await _healthIdService.saveHealthId(healthId);
      
      if (savedHealthId != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              widget.healthId == null 
                  ? 'Health ID created successfully!' 
                  : 'Health ID updated successfully!'
            ),
          ),
        );
        Navigator.pop(context);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to save Health ID')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }
} 