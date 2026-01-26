import 'dart:convert';
import 'dart:typed_data';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../services/gemini_service.dart';
import '../services/firebase_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../utils/theme.dart';
import '../widgets/glass_container.dart';

class ScanPrescriptionScreen extends StatefulWidget {
  const ScanPrescriptionScreen({super.key});

  @override
  _ScanPrescriptionScreenState createState() => _ScanPrescriptionScreenState();
}

class _ScanPrescriptionScreenState extends State<ScanPrescriptionScreen> {
  final GeminiService _geminiService = GeminiService();
  final ImagePicker _picker = ImagePicker();
  final FirebaseService _firebaseService = FirebaseService();

  Uint8List? _imageBytes;
  bool _isLoading = false;
  String? _error;
  List<Map<String, dynamic>> _medications = [];
  String _notes = '';
  final Set<int> _saving = {};
  final Set<int> _saved = {};

  Future<void> _pickImage() async {
    try {
      setState(() { _error = null; });
      final XFile? file = await _picker.pickImage(source: ImageSource.gallery, imageQuality: 85, maxWidth: 1600, maxHeight: 1600);
      if (file == null) return;
      final bytes = await file.readAsBytes();
      setState(() { _imageBytes = bytes; _medications = []; _notes = ''; });
    } catch (e) {
      setState(() { _error = 'Failed to pick image: $e'; });
    }
  }

  Future<void> _analyzePrescription() async {
    if (_imageBytes == null) return;
    setState(() { _isLoading = true; _error = null; _medications = []; _notes = ''; });
    try {
      final result = await _geminiService.analyzePrescription(imageBytes: _imageBytes!);
      final parsed = _geminiService.parsePrescriptionResponse(result);

      if (!mounted) return;
      setState(() {
        _medications = List<Map<String, dynamic>>.from(parsed['medications']);
        _notes = parsed['notes'];
        _isLoading = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_medications.isEmpty ? 'No medications found. Try another image.' : 'Found ${_medications.length} medication(s).'),
          backgroundColor: _medications.isEmpty ? AppTheme.warningColor : AppTheme.successColor,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() { _isLoading = false; _error = 'Analysis failed: $e'; });
    }
  }

  Future<void> _saveMedicationAt(int index) async {
    if (index < 0 || index >= _medications.length) return;
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please log in to save medications'), backgroundColor: AppTheme.dangerColor),
      );
      return;
    }

    final med = _medications[index];
    setState(() { _saving.add(index); });
    try {
      final medicationData = {
        'name': med['name'] ?? '',
        'dosage': med['dosage'] ?? '',
        'frequency': med['frequency'] ?? '',
        'timing': med['timing'] ?? '',
        'duration': med['duration'] ?? '',
        'startDate': DateTime.now(),
        'endDate': null,
        'instructions': _buildInstructions(med),
        'prescribedBy': 'AI Scanned Prescription',
        'pharmacy': '',
        'isActive': true,
      };
      await _firebaseService.addMedication(user.uid, medicationData);
      if (!mounted) return;
      setState(() { _saved.add(index); });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Saved: ${med['name']}'), backgroundColor: AppTheme.successColor),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to save: $e'), backgroundColor: AppTheme.dangerColor),
      );
    } finally {
      if (!mounted) return;
      setState(() { _saving.remove(index); });
    }
  }

  String _buildInstructions(Map<String, dynamic> med) {
    final lines = <String>[];
    if ((med['dosage'] ?? '').isNotEmpty) lines.add('Dosage: ${med['dosage']}');
    if ((med['frequency'] ?? '').isNotEmpty) lines.add('Frequency: ${med['frequency']}');
    if ((med['timing'] ?? '').isNotEmpty) lines.add('Timing: ${med['timing']}');
    if ((med['duration'] ?? '').isNotEmpty) lines.add('Duration: ${med['duration']}');
    if (_notes.isNotEmpty) lines.add('Notes: $_notes');
    return lines.isEmpty ? 'As prescribed' : lines.join('\n');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bgDark,
      appBar: AppBar(
        title: const Text('AI Prescription Scanner', style: TextStyle(fontFamily: 'Montserrat', fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [AppTheme.bgDark, AppTheme.bgDarkSecondary],
          ),
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildImageSection(),
              const SizedBox(height: 24),
              if (_error != null) _buildErrorCard(),
              if (_isLoading) _buildLoadingIndicator()
              else if (_medications.isNotEmpty) _buildResultsList(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildImageSection() {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: AppTheme.primaryColor.withOpacity(0.15),
            blurRadius: 20,
            spreadRadius: -5,
          ),
        ],
      ),
      child: GlassContainer(
        child: Column(
          children: [
            if (_imageBytes != null)
              ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Image.memory(_imageBytes!, height: 300, width: double.infinity, fit: BoxFit.cover),
              )
            else
              Container(
                height: 200,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.white.withOpacity(0.1)),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.document_scanner_outlined, size: 64, color: Colors.white.withOpacity(0.3)),
                    const SizedBox(height: 16),
                    Text(
                      "Upload a clear image of the prescription",
                      style: TextStyle(color: Colors.white.withOpacity(0.5), fontFamily: 'Montserrat'),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: _buildActionButton(
                    "Select Image",
                    Icons.add_photo_alternate_outlined,
                    _pickImage,
                    AppTheme.primaryColor,
                    false,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildActionButton(
                    "Analyze",
                    Icons.auto_awesome,
                    (_imageBytes != null && !_isLoading) ? _analyzePrescription : null,
                    AppTheme.accentColor,
                    true,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButton(String label, IconData icon, VoidCallback? onPressed, Color color, bool isPrimary) {
    return ElevatedButton(
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: isPrimary ? color.withOpacity(0.8) : Colors.white.withOpacity(0.1),
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(vertical: 16),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: isPrimary ? BorderSide.none : BorderSide(color: color.withOpacity(0.5)),
        ),
        elevation: isPrimary ? 8 : 0,
        shadowColor: isPrimary ? color.withOpacity(0.4) : null,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 20),
          const SizedBox(width: 8),
          Text(label, style: const TextStyle(fontWeight: FontWeight.bold, fontFamily: 'Montserrat')),
        ],
      ),
    );
  }

  Widget _buildErrorCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.dangerColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.dangerColor.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline, color: AppTheme.dangerColor),
          const SizedBox(width: 12),
          Expanded(child: Text(_error!, style: const TextStyle(color: Colors.white))),
        ],
      ),
    );
  }

  Widget _buildLoadingIndicator() {
    return Center(
      child: Column(
        children: [
          const SizedBox(height: 40),
          const CircularProgressIndicator(color: AppTheme.accentColor),
          const SizedBox(height: 16),
          Text(
            "Analyzing prescription...",
            style: TextStyle(color: Colors.white.withOpacity(0.7), fontFamily: 'Montserrat', fontSize: 16),
          ),
        ],
      ),
    );
  }

  Widget _buildResultsList() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              "Detected Medications",
              style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold, fontFamily: 'Montserrat'),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: AppTheme.accentColor.withOpacity(0.2),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                "${_medications.length} Found",
                style: TextStyle(color: AppTheme.accentColor, fontWeight: FontWeight.bold, fontSize: 12),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: _medications.length,
          separatorBuilder: (_, __) => const SizedBox(height: 12),
          itemBuilder: (context, index) => _buildMedicationCard(index),
        ),
        if (_notes.isNotEmpty) ...[
          const SizedBox(height: 24),
          Text(
            "Notes",
            style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 14, fontWeight: FontWeight.bold, fontFamily: 'Montserrat'),
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.05),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white.withOpacity(0.1)),
            ),
            child: Text(
              _notes,
              style: TextStyle(color: Colors.white.withOpacity(0.9), height: 1.5, fontFamily: 'Montserrat'),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildMedicationCard(int index) {
    final med = _medications[index];
    final isSaved = _saved.contains(index);
    final isSaving = _saving.contains(index);

    return Container(
      decoration: BoxDecoration(
        color: AppTheme.bgGlassMedium,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AppTheme.primaryColor.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(Icons.medication_outlined, color: AppTheme.primaryColor, size: 24),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            med['name'] ?? 'Unknown',
                            style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold, fontFamily: 'Montserrat'),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            med['type']?.toString().toUpperCase() ?? 'MEDICINE',
                            style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: (isSaved || isSaving) ? null : () => _saveMedicationAt(index),
                      icon: isSaving
                          ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.accentColor))
                          : Icon(
                              isSaved ? Icons.check_circle : Icons.add_circle_outline,
                              color: isSaved ? AppTheme.successColor : AppTheme.accentColor,
                              size: 28,
                            ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                _buildInfoGrid(med),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInfoGrid(Map<String, dynamic> med) {
    return Row(
      children: [
        Expanded(child: _buildInfoItem(Icons.scale_outlined, "Dosage", med['dosage'])),
        const SizedBox(width: 8),
        Expanded(child: _buildInfoItem(Icons.update, "Frequency", med['frequency'])),
        const SizedBox(width: 8),
        Expanded(child: _buildInfoItem(Icons.schedule, "Timing", med['timing'])),
      ],
    );
  }

  Widget _buildInfoItem(IconData icon, String label, String? value) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 12, color: Colors.white.withOpacity(0.5)),
              const SizedBox(width: 4),
              Text(
                label,
                style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 10, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            (value == null || value.isEmpty) ? "--" : value,
            style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}


