import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';
import 'dart:ui';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:device_info_plus/device_info_plus.dart';
import '../utils/app_colors.dart';
import '../widgets/app_drawer.dart';
import '../services/gemini_service.dart';
import '../services/firebase_service.dart';
import '../utils/theme.dart';
import '../services/database_init.dart';
import '../services/health_id_service.dart';
import '../models/health_id_model.dart';
import '../services/premium_service.dart';


class AISymptomScreen extends StatefulWidget {
  const AISymptomScreen({super.key});

  @override
  State<AISymptomScreen> createState() => _AISymptomScreenState();
}

class _AISymptomScreenState extends State<AISymptomScreen> {
  // Controllers
  final TextEditingController _symptomController = TextEditingController();
  final TextEditingController _ageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  // Services
  final ImagePicker _picker = ImagePicker();
  final GeminiService _geminiService = GeminiService();

  // State
  int _tabIndex = 0; // 0 = detector, 1 = report analyzer, 2 = history
  String? _gender;
  String _intensity = "mild";
  String _duration = "<1d";
  XFile? _pickedImage;
  bool _isAnalyzing = false;
  Map<String, dynamic>? _analysisResult;
  bool _historyLoading = true;
  final List<Map<String, dynamic>> _history = [];
  Uint8List? _imageBytes;
  String? _imageMimeType;
  bool _useLiveVitals = false;
  bool _useHealthIdProfile = false;
  HealthIdModel? _healthId;
  bool _healthIdLoading = false;
  
  // Premium State
  int _remainingAnalyses = 0;
  bool _isPremium = false;

  // Report Analyzer specific state
  final TextEditingController _reportDescriptionController = TextEditingController();
  final TextEditingController _reportAgeController = TextEditingController();
  String? _reportGender;
  String _reportType = "ECG";
  XFile? _reportImage;
  bool _isAnalyzingReport = false;
  Map<String, dynamic>? _reportAnalysisResult;
  Uint8List? _reportImageBytes;
  String? _reportImageMimeType;
  bool _useHealthIdForReport = false;

  @override
  void initState() {
    super.initState();
    print('🚀 AI Symptom Screen initialized');
    _loadHistory();
    _loadHealthIdProfile();
    _initializeReportAnalyzer();
    _checkPremiumStatus();
  }
  
  Future<void> _checkPremiumStatus() async {
    final isPremium = await PremiumService.isPremium();
    final remaining = await PremiumService.getRemainingSymptomAnalyses();
    if (mounted) {
      setState(() {
        _isPremium = isPremium;
        _remainingAnalyses = remaining;
      });
    }
  }

  void _showPremiumDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.bgDark,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: AppTheme.primaryColor.withOpacity(0.5)),
        ),
        title: const Text(
          "Daily Limit Reached",
          style: TextStyle(color: Colors.white, fontFamily: 'Montserrat', fontWeight: FontWeight.bold),
        ),
        content: const Text(
          "You have reached your daily limit of free AI analyses. Upgrade to Premium for unlimited access.",
          style: TextStyle(color: Colors.white70, fontFamily: 'Montserrat'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("OK", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _initializeReportAnalyzer() {
    // Pre-fill report age from Health ID if available
    if (_healthId != null && _healthId!.age != null && _healthId!.age!.isNotEmpty) {
      final ageInt = int.tryParse(_healthId!.age!);
      if (ageInt != null) {
        _reportAgeController.text = ageInt.toString();
      }
    }
  }

  @override
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bgDark,
      body: Stack(
        children: [
          // Animated Background
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    AppTheme.bgDark,
                    AppTheme.bgMedium,
                    AppTheme.bgLight,
                  ],
                ),
              ),
            ),
          ),
          // Glass Overlay
          Positioned.fill(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
              child: Container(color: Colors.transparent),
            ),
          ),
          SafeArea(
            child: CustomScrollView(
              controller: _scrollController,
              slivers: [
                SliverAppBar(
                  expandedHeight: 120,
                  floating: true,
                  pinned: true,
                  backgroundColor: Colors.transparent,
                  elevation: 0,
                  leading: IconButton(
                    icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white),
                    onPressed: () => Navigator.pop(context),
                  ),
                  actions: [
                    _buildLogoutButton(),
                    const SizedBox(width: 16),
                  ],
                  flexibleSpace: FlexibleSpaceBar(
                    title: const Text(
                      "AI Health Assistant",
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        fontFamily: 'Montserrat',
                      ),
                    ),
                    centerTitle: true,
                    background: Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            AppTheme.primaryColor.withOpacity(0.2),
                            Colors.transparent,
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    child: _buildTabToggle(),
                  ),
                ),
                SliverFillRemaining(
                  hasScrollBody: true,
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 400),
                    switchInCurve: Curves.easeOutCubic,
                    switchOutCurve: Curves.easeInCubic,
                    child: _tabIndex == 0 
                        ? _buildAnalyzerView() 
                        : _tabIndex == 1 
                            ? _buildReportAnalyzerView() 
                            : _buildHistoryView(),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLogoutButton() {
    return GestureDetector(
      onTap: _logout,
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: AppTheme.dangerColor.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppTheme.dangerColor.withOpacity(0.3)),
        ),
        child: Icon(Icons.logout_rounded, color: AppTheme.dangerColor, size: 20),
      ),
    );
  }

  Widget _buildTabToggle() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppTheme.bgGlassMedium,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      child: Row(
        children: [
          _buildTabButton("Symptoms", 0),
          _buildTabButton("Reports", 1),
          _buildTabButton("History", 2),
        ],
      ),
    );
  }

  Widget _buildTabButton(String title, int index) {
    final selected = _tabIndex == index;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _tabIndex = index),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: selected ? Colors.white.withOpacity(0.1) : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Center(
            child: Text(
              title,
              style: TextStyle(
                color: selected ? Colors.white : Colors.white.withOpacity(0.5),
                fontSize: 14,
                fontWeight: selected ? FontWeight.bold : FontWeight.w500,
                fontFamily: 'Montserrat',
              ),
            ),
          ),
        ),
      ),
    );
  }

  // Main content views
  Widget _buildAnalyzerView() {
        return SingleChildScrollView(
      controller: _scrollController,
      physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.all(16),
            child: _buildAnalyzerCard(),
    );
  }

  Widget _buildReportAnalyzerView() {
    return SingleChildScrollView(
      controller: _scrollController,
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.all(16),
      child: _buildReportAnalyzerCard(),
    );
  }

  Widget _buildUsageCounter() {
    if (_isPremium) return const SizedBox.shrink();
    
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: AppTheme.primaryColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.primaryColor.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Icon(Icons.bolt, color: AppTheme.primaryColor, size: 16),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              "Free analyses remaining today: $_remainingAnalyses",
              style: TextStyle(
                color: Colors.white.withOpacity(0.9),
                fontSize: 12,
                fontFamily: 'Montserrat',
                fontWeight: FontWeight.w500,
              ),
            ),
          ),

        ],
      ),
    );
  }

  Widget _buildAnalyzerCard() {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.bgGlassMedium,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.1)),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionHeader("Describe Symptoms", Icons.psychology_rounded),
          const SizedBox(height: 8),
          _buildUsageCounter(),
          _buildSymptomInput(),
          const SizedBox(height: 8),
          _buildDetailInputs(),
          const SizedBox(height: 8),
          _buildImageUploadSection(),
          const SizedBox(height: 12),
          _buildAnalyzeButton(),
          if (_analysisResult != null || _isAnalyzing) ...[
            const SizedBox(height: 16),
            _buildResultCard(),
          ],
        ],
      ),
    );
  }

  Widget _buildReportAnalyzerCard() {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.bgGlassMedium,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.1)),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionHeader("Analyze Report", Icons.assignment_rounded),
          const SizedBox(height: 8),
          // Info banner
          Container(
            padding: const EdgeInsets.all(8),
            margin: const EdgeInsets.only(bottom: 8),
            decoration: BoxDecoration(
              color: Colors.blue.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.blue.withOpacity(0.3)),
            ),
            child: Row(
              children: [
                Icon(Icons.info_outline, color: Colors.blueAccent, size: 16),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Upload ECG, X-ray, blood test, or any medical report for AI analysis',
                    style: TextStyle(
                      color: Colors.blue[200],
                      fontSize: 11,
                      fontFamily: 'Montserrat',
                    ),
                  ),
                ),
              ],
            ),
          ),
          _buildUsageCounter(),
          _buildReportDescriptionInput(),
          const SizedBox(height: 8),
          _buildReportDetailInputs(),
          const SizedBox(height: 8),
          _buildReportTypeSelector(),
          const SizedBox(height: 8),
          _buildReportImageUploadSection(),
          const SizedBox(height: 12),
          _buildAnalyzeReportButton(),
          if (_reportAnalysisResult != null || _isAnalyzingReport) ...[
            const SizedBox(height: 16),
            _buildReportResultCard(),
          ],
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title, IconData icon) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: AppTheme.accentColor.withOpacity(0.2),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: AppTheme.accentColor, size: 16),
        ),
        const SizedBox(width: 8),
        Text(
          title,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 14,
            fontWeight: FontWeight.bold,
            fontFamily: 'Montserrat',
          ),
        ),
      ],
    );
  }

  Widget _buildSymptomInput() {
    return TextField(
      controller: _symptomController,
      style: const TextStyle(color: Colors.white, fontFamily: 'Montserrat', fontSize: 13),
      maxLines: 3,
      decoration: InputDecoration(
        filled: true,
        fillColor: Colors.white.withOpacity(0.05),
        hintText: "Describe your symptoms...",
        hintStyle: TextStyle(color: Colors.white.withOpacity(0.3), fontFamily: 'Montserrat', fontSize: 13),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
        contentPadding: const EdgeInsets.all(12),
        isDense: true,
      ),
    );
  }

  Widget _buildDetailInputs() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _buildSectionHeader("Patient Details", Icons.person_outline),
            _buildHealthIdToggle(),
          ],
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.03),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white.withOpacity(0.05)),
          ),
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: _buildCompactDropdown(
                      value: _gender,
                      items: const ["Male", "Female", "Other"],
                      hint: "Gender",
                      icon: Icons.person_outline,
                      onChanged: (v) => setState(() => _gender = v),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _buildCompactTextField(
                      controller: _ageController,
                      hint: "Age",
                      icon: Icons.cake_outlined,
                      enabled: !(_useHealthIdProfile && _healthId?.age != null),
                      isHealthIdValue: _useHealthIdProfile && _healthId?.age != null,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: _buildCompactDropdown(
                      value: _intensity,
                      items: const ["mild", "moderate", "severe"],
                      hint: "Intensity",
                      icon: Icons.bolt_outlined,
                      onChanged: (v) => setState(() => _intensity = v ?? "mild"),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _buildCompactDropdown(
                      value: _duration,
                      items: const ["<1d", "1-3d", "1w", ">1w"],
                      hint: "Duration",
                      icon: Icons.timer_outlined,
                      onChanged: (v) => setState(() => _duration = v ?? "<1d"),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        _buildVitalsToggle(),
      ],
    );
  }

  Widget _buildHealthIdToggle() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          "Health ID",
          style: TextStyle(
            color: _useHealthIdProfile ? AppTheme.accentColor : Colors.white54,
            fontSize: 12,
            fontWeight: FontWeight.w600,
            fontFamily: 'Montserrat',
          ),
        ),
        const SizedBox(width: 6),
        SizedBox(
          height: 24,
          width: 40,
          child: Switch(
            value: _useHealthIdProfile,
            onChanged: _healthId == null ? null : (val) => setState(() => _useHealthIdProfile = val),
            activeThumbColor: AppTheme.accentColor,
            activeTrackColor: AppTheme.accentColor.withOpacity(0.3),
            inactiveThumbColor: Colors.white54,
            inactiveTrackColor: Colors.white.withOpacity(0.1),
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
        ),
      ],
    );
  }

  Widget _buildVitalsToggle() {
    return InkWell(
      onTap: () => setState(() => _useLiveVitals = !_useLiveVitals),
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 32,
              height: 18,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(10),
                color: _useLiveVitals ? AppTheme.primaryColor : Colors.white.withOpacity(0.1),
              ),
              child: AnimatedAlign(
                duration: const Duration(milliseconds: 200),
                alignment: _useLiveVitals ? Alignment.centerRight : Alignment.centerLeft,
                child: Container(
                  width: 14,
                  height: 14,
                  margin: const EdgeInsets.symmetric(horizontal: 2),
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              "Include Live Vitals",
              style: TextStyle(
                color: Colors.white.withOpacity(0.7),
                fontSize: 12,
                fontFamily: 'Montserrat',
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCompactDropdown({
    required String? value,
    required List<String> items,
    required String hint,
    required IconData icon,
    required Function(String?) onChanged,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: value,
          hint: Row(
            children: [
              Icon(icon, size: 14, color: Colors.white38),
              const SizedBox(width: 6),
              Text(hint, style: const TextStyle(color: Colors.white38, fontSize: 12)),
            ],
          ),
          icon: const Icon(Icons.keyboard_arrow_down, size: 16, color: Colors.white38),
          dropdownColor: AppTheme.bgGlassHeavy,
          style: const TextStyle(color: Colors.white, fontSize: 12, fontFamily: 'Montserrat'),
          isExpanded: true,
          items: items.map((String item) {
            return DropdownMenuItem<String>(
              value: item,
              child: Text(item),
            );
          }).toList(),
          onChanged: onChanged,
        ),
      ),
    );
  }

  Widget _buildCompactTextField({
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    bool enabled = true,
    bool isHealthIdValue = false,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: isHealthIdValue ? Colors.green.withOpacity(0.1) : Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
        border: isHealthIdValue ? Border.all(color: Colors.green.withOpacity(0.2)) : null,
      ),
      child: Row(
        children: [
          Icon(icon, size: 14, color: isHealthIdValue ? Colors.greenAccent : Colors.white38),
          const SizedBox(width: 6),
          Expanded(
            child: TextField(
              controller: controller,
              keyboardType: TextInputType.number,
              enabled: enabled,
              style: const TextStyle(color: Colors.white, fontSize: 12, fontFamily: 'Montserrat'),
              decoration: InputDecoration(
                hintText: hint,
                hintStyle: const TextStyle(color: Colors.white38, fontSize: 12),
                border: InputBorder.none,
                isDense: true,
                contentPadding: EdgeInsets.zero,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReportDescriptionInput() {
    return TextField(
      controller: _reportDescriptionController,
      style: const TextStyle(color: Colors.white, fontFamily: 'Montserrat', fontSize: 13),
      maxLines: 3,
      decoration: InputDecoration(
        filled: true,
        fillColor: Colors.black.withOpacity(0.25),
        hintText: "Describe report...",
        hintStyle: TextStyle(color: Colors.white.withOpacity(0.5), fontFamily: 'Montserrat', fontSize: 13),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
        contentPadding: const EdgeInsets.all(12),
        isDense: true,
      ),
    );
  }

  Widget _buildReportDetailInputs() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _buildSectionHeader("Patient Details", Icons.person_outline),
            _buildReportHealthIdToggle(),
          ],
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.03),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.white.withOpacity(0.05)),
          ),
          child: Row(
            children: [
              Expanded(
                child: _buildCompactDropdown(
                  value: _reportGender,
                  items: const ["Male", "Female", "Other"],
                  hint: "Gender",
                  icon: Icons.person_outline,
                  onChanged: (v) => setState(() => _reportGender = v),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _buildCompactTextField(
                  controller: _reportAgeController,
                  hint: "Age",
                  icon: Icons.cake_outlined,
                  enabled: !(_useHealthIdForReport && _healthId?.age != null),
                  isHealthIdValue: _useHealthIdForReport && _healthId?.age != null,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildReportHealthIdToggle() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: _useHealthIdForReport ? AppTheme.accentColor.withOpacity(0.15) : Colors.black.withOpacity(0.2),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: _useHealthIdForReport ? AppTheme.accentColor.withOpacity(0.3) : Colors.white.withOpacity(0.1),
        ),
      ),
      child: InkWell(
        onTap: _healthId == null ? null : () => setState(() => _useHealthIdForReport = !_useHealthIdForReport),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              _healthId != null ? Icons.verified_user : Icons.person_off_outlined,
              color: _useHealthIdForReport ? AppTheme.accentColor : Colors.white54,
              size: 14,
            ),
            const SizedBox(width: 6),
            Text(
              _healthIdLoading ? "..." : (_healthId == null ? "No ID" : "Health ID"),
              style: TextStyle(
                color: _useHealthIdForReport ? Colors.white : Colors.white54,
                fontSize: 11,
                fontWeight: FontWeight.w600,
                fontFamily: 'Montserrat',
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildReportTypeSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.medical_services, color: Colors.white, size: 24),
            const SizedBox(width: 10),
            const Expanded(
              child: Text(
                "Report Type",
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  fontFamily: 'Montserrat',
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          "Select the type of medical report you're analyzing for better accuracy.",
          style: TextStyle(
            color: Colors.white.withOpacity(0.7),
            fontSize: 14,
            fontFamily: 'Montserrat',
            height: 1.3,
          ),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            "ECG", "X-Ray", "CT Scan", "MRI", "Blood Test", "Urine Test", 
            "Ultrasound", "Biopsy", "Pathology", "Other"
          ].map((type) => _buildReportTypeChip(type)).toList(),
        ),
      ],
    );
  }

  Widget _buildReportTypeChip(String type) {
    final isSelected = _reportType == type;
    return GestureDetector(
      onTap: () => setState(() => _reportType = type),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          gradient: isSelected
              ? LinearGradient(
                  colors: [AppTheme.primaryColor, AppTheme.accentColor],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                )
              : null,
          color: isSelected ? null : Colors.white.withOpacity(0.1),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? AppTheme.primaryColor : Colors.white.withOpacity(0.3),
            width: 1,
          ),
        ),
        child: Text(
          type,
          style: TextStyle(
            color: isSelected ? Colors.white : Colors.white.withOpacity(0.8),
            fontSize: 13,
            fontWeight: FontWeight.w600,
            fontFamily: 'Montserrat',
          ),
        ),
      ),
    );
  }

  Widget _buildReportImageUploadSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.photo_camera, color: Colors.white, size: 24),
            const SizedBox(width: 10),
            const Expanded(
              child: Text(
                "Upload Medical Report",
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  fontFamily: 'Montserrat',
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          "Upload photos of your medical reports like ECG, X-ray, blood test results, or any other medical documents for AI analysis.",
          style: TextStyle(
            color: Colors.white.withOpacity(0.7),
            fontSize: 14,
            fontFamily: 'Montserrat',
            height: 1.3,
          ),
        ),
        const SizedBox(height: 12),
        _buildReportImageUpload(),
      ],
    );
  }

  Widget _buildReportImageUpload() {
    final hasImage = _reportImage != null && (!kIsWeb || (kIsWeb && _reportImageBytes != null));
    
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        ElevatedButton.icon(
          onPressed: _pickReportImage,
          icon: Icon(hasImage ? Icons.check_circle : Icons.upload_file, size: 20),
          label: Text(hasImage ? "Change Report" : "Upload Report"),
          style: ElevatedButton.styleFrom(
            foregroundColor: Colors.white,
            backgroundColor: hasImage 
                ? Colors.green.withOpacity(0.6)
                : AppTheme.primaryColor.withOpacity(0.4),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            elevation: 0,
            shadowColor: Colors.transparent,
            side: BorderSide(
              color: hasImage 
                  ? Colors.green.withOpacity(0.8)
                  : AppTheme.primaryColor.withOpacity(0.6),
            ),
          ),
        ),
        if (hasImage) ...[
          const SizedBox(width: 12),
          Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: AppTheme.accentColor.withOpacity(0.18),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
              border: Border.all(color: AppTheme.primaryColor.withOpacity(0.18), width: 1.2),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: kIsWeb
                  ? Image.memory(
                      _reportImageBytes!,
                      width: 50,
                      height: 50,
                      fit: BoxFit.cover,
                    )
                  : Image.file(
                      File(_reportImage!.path),
                      width: 50,
                      height: 50,
                      fit: BoxFit.cover,
                    ),
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: () {
              setState(() {
                _reportImage = null;
                _reportImageBytes = null;
                _reportImageMimeType = null;
              });
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Report image removed'),
                  duration: Duration(seconds: 1),
                ),
              );
            },
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: Colors.red.withOpacity(0.8),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                Icons.close,
                color: Colors.white,
                size: 16,
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildAnalyzeReportButton() {
    return Center(
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: AppTheme.accentColor.withOpacity(0.3),
              blurRadius: 15,
              spreadRadius: 2,
            ),
          ],
        ),
        child: ElevatedButton(
          onPressed: _isAnalyzingReport ? null : _analyzeReport,
          style: ElevatedButton.styleFrom(
            foregroundColor: Colors.white,
            backgroundColor: AppTheme.accentColor.withOpacity(0.8),
            padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 18),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            elevation: 0,
            side: BorderSide(color: AppTheme.accentColor.withOpacity(0.5), width: 1.5),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _isAnalyzingReport 
                  ? const SizedBox(
                      width: 20, 
                      height: 20, 
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      )
                    )
                  : const Icon(Icons.analytics_outlined, size: 20),
              const SizedBox(width: 12),
              const Text(
                "Analyze Report",
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.5,
                  fontFamily: 'Montserrat',
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildReportResultCard() {
    if (_isAnalyzingReport) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(AppTheme.accentColor),
            ),
            const SizedBox(height: 16),
            Text(
              "Analyzing your medical report...",
              style: TextStyle(color: Colors.white.withOpacity(0.8), fontFamily: 'Montserrat'),
            ),
          ],
        ),
      );
    }

    final severity = (_reportAnalysisResult?["severity"] ?? "normal").toString().toLowerCase();
    Color severityColor = Colors.greenAccent;
    IconData severityIcon = Icons.check_circle_outline;
    
    if (severity == 'critical') {
      severityColor = Colors.redAccent;
      severityIcon = Icons.warning_amber_rounded;
    } else if (severity == 'abnormal') {
      severityColor = Colors.orangeAccent;
      severityIcon = Icons.info_outline;
    }

    return Container(
      margin: const EdgeInsets.only(top: 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: severityColor.withOpacity(0.1),
            blurRadius: 20,
            spreadRadius: -5,
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.05),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: severityColor.withOpacity(0.3), width: 1.5),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: severityColor.withOpacity(0.2),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(severityIcon, color: severityColor, size: 20),
                        ),
                        const SizedBox(width: 12),
                        const Text(
                          "Report Analysis",
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            fontFamily: 'Montserrat',
                          ),
                        ),
                      ],
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: severityColor.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: severityColor.withOpacity(0.3)),
                      ),
                      child: Text(
                        severity.toUpperCase(),
                        style: TextStyle(
                          color: severityColor,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                
                _buildCompactResultSection(
                  "SUMMARY",
                  Icons.summarize_outlined,
                  _reportAnalysisResult?["summary"],
                  Colors.white70,
                  isFullWidth: true,
                ),
                const SizedBox(height: 12),
                
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: _buildCompactResultSection(
                        "FINDINGS",
                        Icons.search_outlined,
                        _reportAnalysisResult?["findings"],
                        Colors.blueAccent,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildCompactResultSection(
                        "ADVICE",
                        Icons.recommend_outlined,
                        _reportAnalysisResult?["recommendations"],
                        Colors.greenAccent,
                      ),
                    ),
                  ],
                ),
                
                const SizedBox(height: 12),
                _buildCompactResultSection(
                  "NEXT STEPS",
                  Icons.next_plan_outlined,
                  _reportAnalysisResult?["next_steps"],
                  Colors.orangeAccent,
                  isFullWidth: true,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // Simplified content builders for concise display
  Widget _buildMedicationContent(String medicationText) {
    return Text(
      medicationText.isEmpty ? "Paracetamol 500mg every 4-6h, Ibuprofen 200mg every 4-6h" : medicationText,
      style: const TextStyle(
        color: Colors.white,
        fontSize: 14,
        fontFamily: 'Montserrat',
        height: 1.4,
      ),
    );
  }

  Widget _buildReportSummaryContent(String summaryText) {
    return Text(
      summaryText.isEmpty ? "Report analysis completed successfully" : _brief(summaryText, sentences: 2, maxChars: 220),
      style: const TextStyle(
        color: Colors.white,
        fontSize: 14,
        fontFamily: 'Montserrat',
        height: 1.4,
      ),
    );
  }

  Widget _buildReportFindingsContent(String findingsText) {
    if (findingsText.trim().isEmpty) {
      return const Text(
        "No significant abnormalities detected",
        style: TextStyle(
          color: Colors.white,
          fontSize: 14,
          fontFamily: 'Montserrat',
          height: 1.4,
        ),
      );
    }
    return _buildColoredFindingsList(findingsText);
  }

  Widget _buildReportRecommendationsContent(String recommendationsText) {
    return Text(
      recommendationsText.isEmpty ? "Continue regular monitoring as advised by your healthcare provider" : _brief(recommendationsText, sentences: 3, maxChars: 240),
      style: const TextStyle(
        color: Colors.white,
        fontSize: 14,
        fontFamily: 'Montserrat',
        height: 1.4,
      ),
    );
  }

  Widget _buildReportNextStepsContent(String nextStepsText) {
    return Text(
      nextStepsText.isEmpty ? "Follow up with your doctor for any concerns" : _brief(nextStepsText, sentences: 3, maxChars: 240),
      style: const TextStyle(
        color: Colors.white,
        fontSize: 14,
        fontFamily: 'Montserrat',
        height: 1.4,
      ),
    );
  }

  Widget _buildDropdown({
    required String? value,
    required List<String> items,
    required String hint,
    required IconData icon,
    required void Function(String?) onChanged,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.3),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.primaryColor.withOpacity(0.2)),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: value?.isEmpty == true ? null : value,
          icon: Icon(icon, color: AppTheme.primaryColor.withOpacity(0.8), size: 14),
          dropdownColor: Colors.black.withOpacity(0.9),
          style: const TextStyle(color: Colors.white, fontFamily: 'Montserrat', fontSize: 12),
          hint: Text(hint, style: TextStyle(color: Colors.white.withOpacity(0.6), fontFamily: 'Montserrat', fontSize: 12)),
          items: items
              .map((e) => DropdownMenuItem(
                    value: e,
                    child: Text(e, style: const TextStyle(fontFamily: 'Montserrat', fontSize: 12)),
                  ))
              .toList(),
          onChanged: onChanged,
          isDense: true,
        ),
      ),
    );
  }

  Widget _buildImageUploadSection() {
    return Row(
      children: [
        Icon(Icons.photo_camera, color: Colors.white, size: 18),
        const SizedBox(width: 8),
        const Text(
          "Photo (Optional)",
          style: TextStyle(
            color: Colors.white,
            fontSize: 14,
            fontWeight: FontWeight.bold,
            fontFamily: 'Montserrat',
          ),
        ),
        const Spacer(),
        _buildImageUpload(),
      ],
    );
  }

  Widget _buildImageUpload() {
    final hasImage = _pickedImage != null && (!kIsWeb || (kIsWeb && _imageBytes != null));
    
    if (hasImage) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppTheme.primaryColor.withOpacity(0.3)),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: kIsWeb
                  ? Image.memory(_imageBytes!, width: 30, height: 30, fit: BoxFit.cover)
                  : Image.file(File(_pickedImage!.path), width: 30, height: 30, fit: BoxFit.cover),
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: () {
              setState(() {
                _pickedImage = null;
                _imageBytes = null;
                _imageMimeType = null;
              });
            },
            child: Icon(Icons.close, color: Colors.red.withOpacity(0.8), size: 18),
          ),
        ],
      );
    }

    return GestureDetector(
      onTap: _pickImage,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: AppTheme.primaryColor.withOpacity(0.2),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppTheme.primaryColor.withOpacity(0.3)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.upload, color: AppTheme.primaryColor, size: 14),
            const SizedBox(width: 4),
            Text(
              "Upload",
              style: TextStyle(
                color: AppTheme.primaryColor,
                fontSize: 12,
                fontWeight: FontWeight.w600,
                fontFamily: 'Montserrat',
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAnalyzeButton() {
    return Center(
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: AppTheme.accentColor.withOpacity(0.3),
              blurRadius: 15,
              spreadRadius: 2,
            ),
          ],
        ),
        child: ElevatedButton(
          onPressed: _isAnalyzing ? null : _analyze,
          style: ElevatedButton.styleFrom(
            foregroundColor: Colors.white,
            backgroundColor: AppTheme.accentColor.withOpacity(0.8),
            padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 18),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            elevation: 0,
            side: BorderSide(color: AppTheme.accentColor.withOpacity(0.5), width: 1.5),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _isAnalyzing 
                  ? const SizedBox(
                      width: 20, 
                      height: 20, 
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      )
                    )
                  : const Icon(Icons.auto_awesome, size: 20),
              const SizedBox(width: 12),
              const Text(
                "Analyze Symptoms",
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.5,
                  fontFamily: 'Montserrat',
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  bool _isSevereCondition(List conditions) {
    if (conditions.isEmpty) return false;
    final joined = conditions.join(' ').toLowerCase();

    // Check if AI response explicitly indicates severe condition
    if (joined.contains('severity: severe') || joined.contains('severe (emergency)')) {
      return true;
    }

    // Define severe conditions that require immediate medical attention
    const severeKeywords = [
      'heart attack', 'myocardial infarction', 'stroke', 'kidney failure', 'renal failure',
      'sepsis', 'anaphylaxis', 'pulmonary embolism', 'pe', 'aortic dissection',
      'meningitis', 'intracranial hemorrhage', 'hemorrhage', 'gi bleed', 'diabetic ketoacidosis', 'dka',
      'status asthmaticus', 'respiratory failure', 'acute liver failure', 'encephalitis',
      'appendicitis with perforation', 'ectopic pregnancy', 'testicular torsion',
      'acute coronary syndrome', 'acs', 'shock', 'cardiac arrest', 'cancer', 'tumor',
      'pneumonia', 'tuberculosis', 'hiv', 'aids', 'hepatitis', 'cirrhosis',
      'pancreatitis', 'peritonitis', 'osteomyelitis', 'endocarditis', 'myocarditis'
    ];

    for (final kw in severeKeywords) {
      if (joined.contains(kw)) return true;
    }

    // Also check for high confidence with severe intensity
    final hasHighPercent = RegExp(r'\(\s*(9[0-9]|100)\s*%\s*\)').hasMatch(joined);
    if (hasHighPercent && _intensity.toLowerCase() == 'severe') return true;

    return false;
  }

  Widget _buildResultCard() {
    if (_isAnalyzing) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(AppTheme.primaryColor),
            ),
            const SizedBox(height: 16),
            Text(
              "Analyzing your symptoms...",
              style: TextStyle(color: Colors.white.withOpacity(0.8), fontFamily: 'Montserrat'),
            ),
          ],
        ),
      );
    }

    final conditions = (_analysisResult?["possibleConditions"] as List?) ?? [];
    final bool isSevere = _isSevereCondition(conditions);
    final String severity = isSevere ? "High Severity" : "Normal Severity";
    final Color severityColor = isSevere ? Colors.redAccent : AppTheme.primaryColor;

    return Container(
      margin: const EdgeInsets.only(top: 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: severityColor.withOpacity(0.15),
            blurRadius: 20,
            spreadRadius: -5,
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.05),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: severityColor.withOpacity(0.3), width: 1.5),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: severityColor.withOpacity(0.2),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(Icons.analytics_outlined, color: severityColor, size: 20),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: const Text(
                              "Analysis Results",
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                fontFamily: 'Montserrat',
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: severityColor.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: severityColor.withOpacity(0.3)),
                      ),
                      child: Text(
                        severity.toUpperCase(),
                        style: TextStyle(
                          color: severityColor,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                
                // Conditions - Horizontal Scroll
                const Text(
                  "POSSIBLE CONDITIONS",
                  style: TextStyle(
                    color: Colors.white38,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.5,
                  ),
                ),
                const SizedBox(height: 10),
                SizedBox(
                  height: 45,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: conditions.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 8),
                    itemBuilder: (context, index) {
                      final c = conditions[index];
                      return _buildConditionBubble(
                        c['condition'] ?? 'Unknown',
                        c['probability'] ?? '?',
                      );
                    },
                  ),
                ),
                
                const SizedBox(height: 20),
                
                // Grid for Actions & Recommendations
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: _buildCompactResultSection(
                        "IMMEDIATE ACTIONS",
                        Icons.flash_on,
                        _analysisResult?['immediateActions'],
                        Colors.orangeAccent,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildCompactResultSection(
                        "RECOMMENDATIONS",
                        Icons.lightbulb_outline,
                        _analysisResult?['recommendations'],
                        Colors.blueAccent,
                      ),
                    ),
                  ],
                ),
                
                const SizedBox(height: 16),
                
                // OTC Medicines & Home Remedies Row
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: _buildCompactResultSection(
                        "OTC MEDICINES",
                        Icons.medication_outlined,
                        _analysisResult?['otcMedicines'],
                        Colors.purpleAccent,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildCompactResultSection(
                        "HOME REMEDIES",
                        Icons.home_outlined,
                        _analysisResult?['homeRemedies'],
                        Colors.greenAccent,
                      ),
                    ),
                  ],
                ),
                
                const SizedBox(height: 16),
                _buildCompactResultSection(
                  "WHEN TO SEEK HELP",
                  Icons.help_outline,
                  [_analysisResult?['whenToSeekHelp'] ?? ""],
                  Colors.redAccent,
                  isFullWidth: true,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildConditionBubble(String name, String prob) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: AppTheme.bgDark.withOpacity(0.8),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.accentColor.withOpacity(0.5)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            name,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 13,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: AppTheme.accentColor,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              prob,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 11,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCompactResultSection(String title, IconData icon, dynamic content, Color color, {bool isFullWidth = false}) {
    String text = "";
    if (content is List) {
      text = content.join("\n");
    } else {
      text = content?.toString() ?? "";
    }
    
    if (text.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 14, color: color),
            const SizedBox(width: 6),
            Text(
              title,
              style: TextStyle(
                color: color.withOpacity(0.7),
                fontSize: 10,
                fontWeight: FontWeight.bold,
                letterSpacing: 1,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.03),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            text,
            style: TextStyle(
              color: Colors.white.withOpacity(0.8),
              fontSize: 11,
              height: 1.4,
              fontFamily: 'Montserrat',
            ),
          ),
        ),
      ],
    );
  }


  Widget _buildHomeRemedyContent(String remedyText) {
    return Text(
      remedyText.isEmpty ? "Rest, hydrate, cool compress for fever" : _brief(remedyText, sentences: 3, maxChars: 200),
      style: const TextStyle(
        color: Colors.white,
        fontSize: 14,
        fontFamily: 'Montserrat',
        height: 1.4,
      ),
    );
  }

  Widget _buildMeasuresContent(String measuresText) {
    return Text(
      measuresText.isEmpty ? "Monitor symptoms, seek care if worsens" : _brief(measuresText, sentences: 3, maxChars: 200),
      style: const TextStyle(
        color: Colors.white,
        fontSize: 14,
        fontFamily: 'Montserrat',
        height: 1.4,
      ),
    );
  }

  String _brief(String text, {int sentences = 3, int maxChars = 260}) {
    String t = text.trim();
    final parts = _splitIntoSentences(t);
    String clipped = parts.take(sentences).join(' ').trim();
    if (clipped.length > maxChars) {
      clipped = clipped.substring(0, maxChars).trimRight();
      final lastBreak = clipped.lastIndexOf(RegExp(r'[\.\!\?]\s|\s'));
      if (lastBreak > 40) {
        clipped = clipped.substring(0, lastBreak).trimRight();
      }
      clipped += '…';
    }
    return clipped;
  }

  List<String> _splitIntoSentences(String text) {
    final clean = text.replaceAll('\n', ' ').replaceAll(RegExp(r'\s+'), ' ').trim();
    final matches = RegExp(r'[^.!?]+[.!?]?').allMatches(clean);
    final sentences = matches.map((m) => m.group(0)!.trim()).where((s) => s.isNotEmpty).toList();
    return sentences.isEmpty ? [clean] : sentences;
  }

  // ===== Key Findings formatting (no raw '*', color-coded) =====
  Widget _buildColoredFindingsList(String text) {
    final items = _extractFindingItems(text);
    // Limit to first 6 to keep brief
    final limited = items.take(6).toList();
    if (limited.isEmpty) {
      return Text(
        _brief(text, sentences: 3, maxChars: 260),
        style: const TextStyle(
          color: Colors.white,
          fontSize: 14,
          fontFamily: 'Montserrat',
          height: 1.4,
        ),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: limited.map((line) {
        final color = _findingColor(line.toLowerCase());
        return Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 8,
                height: 8,
                margin: const EdgeInsets.only(top: 6, right: 8),
                decoration: BoxDecoration(
                  color: color,
                  shape: BoxShape.circle,
                ),
              ),
              Expanded(
                child: Text(
                  line,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontFamily: 'Montserrat',
                    height: 1.4,
                  ),
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  List<String> _extractFindingItems(String text) {
    // Normalize bullets and split into list items
    String t = text.replaceAll('\r', '\n');
    // Replace common bullet markers with newlines to split
    t = t.replaceAll('•', '\n').replaceAll('*', '\n').replaceAll('- ', '\n- ');
    // Split by lines and also by numbering patterns
    final rawLines = t.split('\n')
        .expand((line) => line.split(RegExp(r'\d+\)\s|\d+\.\s'))) // split numbered lists
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();
    final List<String> items = [];
    for (final l in rawLines) {
      var s = l;
      // Strip leading bullet/number characters
      s = s.replaceFirst(RegExp(r'^(\*|\-|•|\d+\.|\d+\))\s*'), '');
      // Remove trailing punctuation duplication
      s = s.replaceAll(RegExp(r'\s+'), ' ').trim();
      if (s.isNotEmpty) items.add(s);
    }
    // If we ended up with a single long paragraph, try sentence split as fallback
    if (items.length <= 1) {
      final sentences = _splitIntoSentences(text);
      return sentences.map((s) => s.replaceFirst(RegExp(r'^(\*|\-|•)\s*'), '').trim()).where((s) => s.isNotEmpty).toList();
    }
    return items;
  }

  Color _findingColor(String lower) {
    // Simple heuristic color mapping
    const normalKeys = ['normal', 'within normal', 'unremarkable', 'no acute', 'negative', 'benign'];
    const cautionKeys = ['mild', 'borderline', 'slightly', 'suggest', 'recommend', 'consider'];
    const alertKeys = ['fracture', 'mass', 'lesion', 'abnormal', 'infarct', 'effusion', 'consolidation', 'positive', 'severe'];

    if (alertKeys.any((k) => lower.contains(k))) return Colors.orangeAccent;
    if (cautionKeys.any((k) => lower.contains(k))) return Colors.yellowAccent;
    if (normalKeys.any((k) => lower.contains(k))) return Colors.greenAccent;
    return Colors.cyanAccent; // default neutral
  }





  Widget _buildResultTextSection(String title, String content) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.label, color: Colors.white, size: 18),
            const SizedBox(width: 8),
            Text(
              title,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.bold,
                fontFamily: 'Montserrat',
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          content,
          style: const TextStyle(color: Colors.white70, fontFamily: 'Montserrat'),
          softWrap: true,
        ),
      ],
    );
  }

  Widget _buildChip(String label) {
    return Chip(
      label: Text(
        label,
        style: const TextStyle(color: Colors.white, fontFamily: 'Montserrat'),
      ),
      backgroundColor: Colors.white.withOpacity(0.1),
      padding: EdgeInsets.zero,
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
    );
  }

  Widget _buildHistoryView() {
    if (_historyLoading) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 16),
            Text(
              'Loading symptom history...',
              style: TextStyle(
                color: Colors.white70, 
                fontFamily: 'Montserrat'
              ),
            ),
          ],
        ),
      );
    }
    
        if (_history.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.history, color: Colors.white.withOpacity(0.5), size: 50),
            const SizedBox(height: 8),
            Text(
              "No symptom history yet",
              style: TextStyle(
                color: Colors.white.withOpacity(0.7),
                fontFamily: 'Montserrat',
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              "Your AI symptom analyses will appear here",
              style: TextStyle(
                color: Colors.white.withOpacity(0.5),
                fontFamily: 'Montserrat',
                fontSize: 14,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ElevatedButton.icon(
                  onPressed: _refreshHistory,
                  icon: const Icon(Icons.refresh, size: 18),
                  label: const Text('Refresh'),
                  style: ElevatedButton.styleFrom(
                    foregroundColor: Colors.white,
                    backgroundColor: AppTheme.primaryColor.withOpacity(0.6),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  ),
                ),
                const SizedBox(width: 12),
                ElevatedButton.icon(
                  onPressed: () => setState(() => _tabIndex = 0),
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('Analyze Symptoms'),
                  style: ElevatedButton.styleFrom(
                    foregroundColor: Colors.white,
                    backgroundColor: AppTheme.accentColor.withOpacity(0.6),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              "Tip: Complete a symptom analysis to start building your health history",
              style: TextStyle(
                color: Colors.white.withOpacity(0.4),
                fontFamily: 'Montserrat',
                fontSize: 12,
                fontStyle: FontStyle.italic,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            // Debug section
            Container(
              padding: const EdgeInsets.all(12),
              margin: const EdgeInsets.symmetric(horizontal: 20),
              decoration: BoxDecoration(
                color: AppTheme.bgGlassHeavy,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.white.withOpacity(0.1)),
              ),
              child: Column(
                children: [
                  Text(
                    "Debug Info",
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.7),
                      fontFamily: 'Montserrat',
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    "User: ${FirebaseService().currentUser?.email ?? 'Not logged in'}",
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.5),
                      fontFamily: 'Montserrat',
                      fontSize: 10,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    "History count: ${_history.length}",
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.5),
                      fontFamily: 'Montserrat',
                      fontSize: 10,
                    ),
                  ),
                  const SizedBox(height: 8),
                  ElevatedButton(
                    onPressed: _createTestRecord,
                    style: ElevatedButton.styleFrom(
                      foregroundColor: Colors.white,
                      backgroundColor: Colors.orange.withOpacity(0.6),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                      minimumSize: const Size(0, 32),
                    ),
                    child: const Text(
                      'Create Test Record',
                      style: TextStyle(fontSize: 10),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }
    
    return RefreshIndicator(
      onRefresh: _refreshHistory,
      color: AppTheme.primaryColor,
      backgroundColor: Colors.black,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _history.length,
        itemBuilder: (context, index) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: _buildHistoryItem(_history[index]),
          );
        },
      ),
    );
  }

  Widget _buildHistoryItem(Map<String, dynamic> record) {
    final timestamp = (record['timestamp'] as Timestamp?)?.toDate();
    final formattedDate = timestamp != null ? DateFormat('MMM dd, yyyy').format(timestamp) : 'No date';
    
    return Card(
      color: Colors.transparent,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Colors.black.withOpacity(0.5),
                  Colors.black.withOpacity(0.3),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppTheme.primaryColor.withOpacity(0.2)),
            ),
            child: Padding(
              padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                      Icon(Icons.medical_services, color: AppTheme.primaryColor, size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                        child: Text(
                          record['name'] ?? 'Unknown',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                            fontFamily: 'Montserrat',
                    ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Text(
                        formattedDate,
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.6),
                          fontSize: 12,
                          fontFamily: 'Montserrat',
                        ),
                      ),
                  ],
                ),
                  if (record['analysis'] != null) ...[
                    const SizedBox(height: 8),
                    _buildAnalysisSummary(record['analysis']),
                  ],
              ],
            ),
          ),
          ),
        ),
      ),
    );
  }

  Widget _buildAnalysisSummary(Map<String, dynamic> analysis) {
    final List<String> summaryParts = [];

    try {
      // Handle possible conditions
      if (analysis['possibleConditions'] != null) {
        final conditions = analysis['possibleConditions'];
        String conditionsText = '';

        if (conditions is List) {
          if (conditions.isNotEmpty && conditions.first is Map) {
            conditionsText = conditions.map((c) {
              if (c is Map && c['condition'] != null) {
                final probability = c['probability'] ?? '';
                return probability.isNotEmpty ? '${c['condition']} ($probability)' : c['condition'];
              }
              return c.toString();
            }).join(', ');
          } else {
            conditionsText = conditions.join(', ');
          }
        } else if (conditions is String) {
          conditionsText = conditions;
        }

        if (conditionsText.isNotEmpty) {
          summaryParts.add("Conditions: $conditionsText");
        }
      }

      // Handle severity
      if (analysis['severity'] != null) {
        summaryParts.add("Severity: ${analysis['severity']}");
      }

      // Handle immediate actions
      if (analysis['immediateActions'] != null) {
        final actions = analysis['immediateActions'];
        String actionsText = '';
        if (actions is List) {
          actionsText = actions.join(', ');
        } else if (actions is String) {
          actionsText = actions;
        }
        if (actionsText.isNotEmpty) {
          summaryParts.add("Actions: $actionsText");
        }
      }

      // Handle recommendations
      if (analysis['recommendations'] != null) {
        final recs = analysis['recommendations'];
        String recsText = '';
        if (recs is List) {
          recsText = recs.join(', ');
        } else if (recs is String) {
          recsText = recs;
        }
        if (recsText.isNotEmpty) {
          summaryParts.add("Recommendations: $recsText");
        }
      }

      // Handle when to seek help
      if (analysis['whenToSeekHelp'] != null) {
        summaryParts.add("Seek Help: ${analysis['whenToSeekHelp']}");
      }

    } catch (e) {
      print('Error building analysis summary: $e');
      summaryParts.add("Analysis data available");
    }

    if (summaryParts.isEmpty) {
      return const Text(
        "Analysis data available",
        style: TextStyle(
          color: Colors.white,
          fontFamily: 'Montserrat',
          fontSize: 13,
        ),
      );
    }

    return Text(
      summaryParts.join('\n'),
      style: const TextStyle(
        color: Colors.white,
        fontFamily: 'Montserrat',
        fontSize: 13,
        height: 1.3,
      ),
      overflow: TextOverflow.ellipsis,
      maxLines: 4,
    );
  }

  // Logic methods
  Future<void> _loadHealthIdProfile() async {
    setState(() => _healthIdLoading = true);
    try {
      final svc = HealthIdService();
      final profile = await svc.getHealthId();
      if (!mounted) return;
      print('Symptom Screen - Loaded Health ID: ${profile?.name}, Age: ${profile?.age}');
      setState(() {
        _healthId = profile;
        _healthIdLoading = false;

        // Pre-fill age from Health ID if available and valid
        if (profile != null && profile.age != null && profile.age!.isNotEmpty) {
          final ageInt = int.tryParse(profile.age!);
          if (ageInt != null) {
            _ageController.text = ageInt.toString();
            print('Symptom Screen - Pre-filled age: $ageInt');
          } else {
            print('Symptom Screen - Could not parse age: ${profile.age}');
          }
        } else {
          print('Symptom Screen - No age in Health ID profile');
        }
      });
    } catch (e) {
      print('Symptom Screen - Error loading Health ID: $e');
      setState(() => _healthIdLoading = false);
      // Silently ignore profile load errors
    }
  }

  void _refreshAgeDisplay() {
    // Update age field display based on Health ID toggle state
    if (_useHealthIdProfile && _healthId != null && _healthId!.age != null && _healthId!.age!.isNotEmpty) {
      final ageInt = int.tryParse(_healthId!.age!);
      if (ageInt != null && ageInt > 0 && ageInt <= 150) {
        // Valid age in Health ID, update the controller
        _ageController.text = ageInt.toString();
      }
    }
  }

  void _refreshReportAgeDisplay() {
    // Update report age field display based on Health ID toggle state
    if (_useHealthIdForReport && _healthId != null && _healthId!.age != null && _healthId!.age!.isNotEmpty) {
      final ageInt = int.tryParse(_healthId!.age!);
      if (ageInt != null && ageInt > 0 && ageInt <= 150) {
        // Valid age in Health ID, update the controller
        _reportAgeController.text = ageInt.toString();
      }
    }
  }

  String _appendPatientProfile(String baseDescription) {
    if (_healthId == null || !_useHealthIdProfile) return baseDescription;
    final profile = _healthId!;
    final List<String> lines = [];
    if ((profile.bloodGroup ?? '').trim().isNotEmpty) {
      lines.add('Blood Group: ${profile.bloodGroup}');
    }
    if (profile.allergies.isNotEmpty) {
      lines.add('Allergies: ${profile.allergies.join(', ')}');
    }
    if (profile.activeMedications.isNotEmpty) {
      lines.add('Active Medications: ${profile.activeMedications.join(', ')}');
    }
    if ((profile.medicalConditions ?? '').trim().isNotEmpty) {
      lines.add('Known Conditions: ${profile.medicalConditions}');
    }
    if ((profile.notes ?? '').trim().isNotEmpty) {
      lines.add('Notes: ${profile.notes}');
    }
    if (lines.isEmpty) return baseDescription;
    return '$baseDescription\n\nPatient Profile (from Digital Health ID):\n${lines.join('\n')}';
  }

  Future<void> _pickImage() async {
    try {
      // Show bottom sheet with options
      await showModalBottomSheet(
        context: context,
        backgroundColor: Colors.transparent,
        builder: (BuildContext context) {
          return Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Colors.black.withOpacity(0.8),
                  AppTheme.bgGlassMedium.withOpacity(0.9),
                ],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(20),
                topRight: Radius.circular(20),
              ),
              border: Border.all(
                color: AppTheme.primaryColor.withOpacity(0.3),
                width: 1,
              ),
            ),
            child: ClipRRect(
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(20),
                topRight: Radius.circular(20),
              ),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text(
                        "Choose Image Source",
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          fontFamily: 'Montserrat',
                        ),
                      ),
                      const SizedBox(height: 20),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          _buildImageSourceOption(
                            icon: Icons.camera_alt,
                            label: "Camera",
                            onTap: () async {
                              Navigator.pop(context);
                              await _getImageFromSource(ImageSource.camera);
                            },
                          ),
                          _buildImageSourceOption(
                            icon: Icons.photo_library,
                            label: "Gallery",
                            onTap: () async {
                              Navigator.pop(context);
                              await _getImageFromSource(ImageSource.gallery);
                            },
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error showing image options: ${e.toString()}')),
      );
    }
  }

  Widget _buildImageSourceOption({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 70,
            height: 70,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  AppTheme.primaryColor.withOpacity(0.7),
                  AppTheme.accentColor.withOpacity(0.7),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(15),
              boxShadow: [
                BoxShadow(
                  color: AppTheme.primaryColor.withOpacity(0.2),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Icon(
              icon,
              color: Colors.white,
              size: 32,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.w500,
              fontFamily: 'Montserrat',
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _getImageFromSource(ImageSource source) async {
    try {
      // Check permissions first
      if (source == ImageSource.camera && !kIsWeb) {
        // For camera, we need to check camera permission
        final hasPermission = await _checkCameraPermission();
        if (!hasPermission) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Camera permission is required to take photos'),
              backgroundColor: Colors.orange,
            ),
          );
          return;
        }
      } else if (source == ImageSource.gallery && !kIsWeb) {
        // For gallery, check storage permission
        final hasPermission = await _checkStoragePermission();
        if (!hasPermission) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Storage permission is required to access photos'),
              backgroundColor: Colors.orange,
            ),
          );
          return;
        }
      }

      // Show loading indicator
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Processing image...'),
            duration: Duration(seconds: 1),
          ),
        );
      }

      final img = await _picker.pickImage(
        source: source,
        imageQuality: 85, // Slightly higher quality
        maxWidth: 1024,
        maxHeight: 1024,
      );
      
      if (img != null) {
        setState(() => _pickedImage = img);
        
        try {
          // Read bytes (works on web and mobile)
          final bytes = await img.readAsBytes();
          
          // Validate size (< 4MB) for safer upload/analysis
          if (bytes.lengthInBytes > 4 * 1024 * 1024) {
            setState(() {
              _pickedImage = null;
              _imageBytes = null;
              _imageMimeType = null;
            });
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Image too large. Please select an image under 4MB.'),
                backgroundColor: Colors.red,
              ),
            );
            return;
          }

          // Detect mime type: use provided, else infer from file name extension
          String? mime = img.mimeType;
          if (mime == null || mime.isEmpty) {
            final name = img.name.isNotEmpty ? img.name : img.path;
            final lower = name.toLowerCase();
            if (lower.endsWith('.jpg') || lower.endsWith('.jpeg')) {
              mime = 'image/jpeg';
            } else if (lower.endsWith('.png')) mime = 'image/png';
            else if (lower.endsWith('.webp')) mime = 'image/webp';
            else if (lower.endsWith('.gif')) mime = 'image/gif';
            else mime = 'image/jpeg';
          }

          setState(() {
            _imageBytes = bytes;
            _imageMimeType = mime;
          });

          // Success feedback
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Image uploaded successfully!'),
                backgroundColor: Colors.green,
                duration: Duration(seconds: 2),
              ),
            );
          }
        } catch (e) {
          print('Error processing image: $e');
          setState(() {
            _pickedImage = null;
            _imageBytes = null;
            _imageMimeType = null;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error processing image: ${e.toString()}'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      print('Error in image picker: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error picking image: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _analyze() async {
    // Check premium limits
    if (!_isPremium) {
      final canUse = await PremiumService.canUseSymptomAnalysis();
      if (!canUse) {
        _showPremiumDialog();
        return;
      }
    }

    final desc = _symptomController.text.trim();
    if (desc.isEmpty && _pickedImage == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please describe symptoms or attach an image')),
      );
      return;
    }
    FocusScope.of(context).unfocus();
    setState(() {
      _isAnalyzing = true;
      _analysisResult = null;
    });
    try {
      File? imageFile;
      if (!kIsWeb && _pickedImage != null) {
        imageFile = File(_pickedImage!.path);
        if (!imageFile.existsSync()) {
          throw Exception('Selected image file no longer exists');
        }
        final fileSize = await imageFile.length();
        if (fileSize > 4 * 1024 * 1024) {
          throw Exception('Image file is too large. Please use an image smaller than 4MB.');
        }
      }
      Map<String, dynamic>? vitals;
      if (_useLiveVitals) {
        final dbService = DatabaseService();
        final userId = dbService.getCurrentUserId();
        if (userId != null) {
          vitals = await dbService.getLatestVitals(userId);
        }
      }

      // Enrich description with patient profile from Digital Health ID for accuracy
      final enrichedDesc = _appendPatientProfile(desc);

      // Use health ID data if available and enabled, otherwise use manual inputs
      int? analysisAge;
      String? analysisGender;

      // First try to get age from Health ID if enabled
      if (_useHealthIdProfile && _healthId != null && _healthId!.age != null && _healthId!.age!.isNotEmpty) {
        analysisAge = int.tryParse(_healthId!.age!.trim());
        if (analysisAge != null && analysisAge > 0 && analysisAge <= 150) {
          // Successfully parsed valid age from Health ID
          print('Using Health ID age: $analysisAge');
        } else {
          // Invalid age in Health ID, fall back to manual input
          print('Invalid Health ID age: ${_healthId!.age}, falling back to manual input');
          analysisAge = int.tryParse(_ageController.text.trim());
        }
      } else {
        // Health ID not enabled or no age data, use manual input
        analysisAge = int.tryParse(_ageController.text.trim());
      }

      // Validate that age is provided and valid
      if (analysisAge == null || analysisAge <= 0 || analysisAge > 150) {
        setState(() => _isAnalyzing = false);
        String errorMessage = 'Age field is required. ';
        if (_useHealthIdProfile && _healthId != null) {
          errorMessage += 'Please add a valid age to your Health ID profile or enter it manually.';
        } else {
          errorMessage += 'Please enter your age.';
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMessage),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      analysisGender = _gender;

      // Ensure mime type fallback on web if missing
      final mimeForAnalysis = _imageMimeType == null || _imageMimeType!.isEmpty
          ? (kIsWeb ? 'image/jpeg' : null)
          : _imageMimeType;

      print('🔍 Starting symptom analysis...');
      print('📝 Description: $enrichedDesc');
      print('👤 Age: $analysisAge, Gender: $analysisGender');
      print('📊 Intensity: $_intensity, Duration: $_duration');
      print('🖼️ Image attached: ${_pickedImage != null}, Image bytes: ${_imageBytes?.length ?? 0}');
      
      final resText = await _geminiService.analyzeSymptoms(
        symptoms: [enrichedDesc],
        age: analysisAge?.toString(),
        gender: analysisGender,
        duration: _duration,
        intensity: _intensity,
        imageAttached: _pickedImage != null,
        imageFile: (_pickedImage != null && !kIsWeb) ? File(_pickedImage!.path) : null,
        imageBytes: _imageBytes,
        imageMimeType: mimeForAnalysis,
      );
      
      print('✅ Gemini response received: ${resText.length} characters');
      // If the result is a user-friendly error string, show error and return
      if (resText.startsWith('Sorry, the AI analysis could not be completed')) {
        setState(() => _isAnalyzing = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(resText),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }
      print('🔧 Parsing Gemini response...');
      final parsed = _geminiService.parseResponse(resText);
      print('📋 Parsed result: $parsed');
      setState(() {
        _analysisResult = parsed;
        _isAnalyzing = false;
      });
      
      // Increment usage if not premium
      if (!_isPremium) {
        await PremiumService.incrementSymptomUsage();
        _checkPremiumStatus();
      }

      Future.delayed(const Duration(milliseconds: 300), () {
        if (_scrollController.hasClients) {
          _scrollController.animateTo(
            _scrollController.position.maxScrollExtent,
            duration: const Duration(milliseconds: 500),
            curve: Curves.easeOut,
          );
        }
      });
      await _saveRecord(desc, parsed);
    } catch (e) {
      setState(() => _isAnalyzing = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Sorry, the AI analysis could not be completed at this time. Please try again later.'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }



  Future<void> _saveRecord(String name, Map<String, dynamic> analysis) async {
    final firebaseService = FirebaseService();
    final user = firebaseService.currentUser;
    if (user != null) {
      try {
        print('💾 Saving symptom record for user: ${user.uid}');
        print('📝 Record data: name="$name", severity="$_intensity", duration="$_duration"');
        print('🔍 Analysis data keys: ${analysis.keys.toList()}');

        final recordData = {
          'userId': user.uid,
          'name': name,
          'analysis': analysis,
          'severity': _intensity,
          'duration': _duration,
          'timestamp': FieldValue.serverTimestamp(),
          'createdAt': FieldValue.serverTimestamp(),
          'hasImage': _pickedImage != null,
          'age': _ageController.text.isNotEmpty ? int.tryParse(_ageController.text) : null,
          'gender': _gender,
        };

        print('📊 Complete record data: $recordData');

        await firebaseService.saveSymptomRecord(user.uid, recordData);
        print('✅ Symptom record saved successfully');

        // Show success message
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Symptom analysis saved to history!'),
              backgroundColor: Colors.green,
              duration: Duration(seconds: 2),
            ),
          );
        }

        // Add a small delay before loading history to ensure Firestore sync
        await Future.delayed(const Duration(milliseconds: 1000));
        await _loadHistory();
      } catch (e) {
        print('❌ Error saving symptom record: $e');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error saving record: $e'),
              backgroundColor: Colors.red,
              action: SnackBarAction(
                label: 'Retry',
                onPressed: () => _saveRecord(name, analysis),
              ),
            ),
          );
        }
      }
    } else {
      print('⚠️ Cannot save record: User not logged in');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please log in to save your analysis'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    }
  }

  Future<void> _loadHistory() async {
    setState(() => _historyLoading = true);
    final firebaseService = FirebaseService();
    final user = firebaseService.currentUser;

    if (user != null) {
      try {
        print('🔍 Loading symptom history for user: ${user.uid}');
        print('🔍 User email: ${user.email}');
        
        final hist = await firebaseService.getSymptomHistory(user.uid);

        print('📊 Loaded ${hist.length} symptom history records');

        if (hist.isNotEmpty) {
          print('📋 Sample record structure:');
          print('   - Name: ${hist.first['name']}');
          print('   - Timestamp: ${hist.first['timestamp']}');
          print('   - Has analysis: ${hist.first['analysis'] != null}');
          print('   - Severity: ${hist.first['severity']}');
          print('   - Duration: ${hist.first['duration']}');
          if (hist.first['analysis'] != null) {
            print('   - Analysis keys: ${hist.first['analysis'].keys.join(', ')}');
          }
        } else {
          print('ℹ️ No symptom history found for user');
          print('🔍 Checking if user document exists...');
          
          // Try to check if user exists in Firestore
          try {
            final userDoc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
            print('🔍 User document exists: ${userDoc.exists}');
          } catch (e) {
            print('❌ Error checking user document: $e');
          }
        }

        if (mounted) {
          setState(() {
            _history
              ..clear()
              ..addAll(hist);
            _historyLoading = false;
          });
        }
        print('✅ History loaded and state updated');
      } catch (e) {
        print('❌ Error loading symptom history: $e');
        print('❌ Error type: ${e.runtimeType}');
        print('❌ Error toString: ${e.toString()}');
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error loading symptom history: $e'),
              backgroundColor: Colors.red,
              action: SnackBarAction(
                label: 'Retry',
                onPressed: _loadHistory,
              ),
            ),
          );
          setState(() {
            _history.clear();
            _historyLoading = false;
          });
        }
      }
    } else {
      print('⚠️ No user logged in, cannot load symptom history');
      if (mounted) {
        setState(() {
          _history.clear();
          _historyLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please log in to view symptom history'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    }
  }

  // Add a method to manually refresh history
  Future<void> _refreshHistory() async {
    await _loadHistory();
  }

  // Test method to create a test record
  Future<void> _createTestRecord() async {
    final firebaseService = FirebaseService();
    final user = firebaseService.currentUser;
    if (user != null) {
      try {
        print('🧪 Creating test symptom record...');
        
        final testAnalysis = {
          'conditions': ['Test Condition (85%)', 'Another Condition (60%)'],
          'medication': 'Test medication 500mg every 6 hours',
          'homemade_remedies': 'Rest and hydration',
          'measures': 'Monitor symptoms and consult doctor if worsens',
        };

        await _saveRecord('Test Symptom Analysis', testAnalysis);
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Test record created successfully!'),
              backgroundColor: Colors.green,
              duration: Duration(seconds: 2),
            ),
          );
        }
      } catch (e) {
        print('❌ Error creating test record: $e');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error creating test record: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please log in to create test records'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    }
  }

  void _logout() async {
    final firebaseService = FirebaseService();
    await firebaseService.signOut();
    if (mounted) Navigator.pop(context);
  }

  // Permission checking methods
  Future<bool> _checkCameraPermission() async {
    if (kIsWeb) return true; // Web doesn't need explicit permission
    
    try {
      final permission = await Permission.camera.request();
      return permission == PermissionStatus.granted;
    } catch (e) {
      print('Error checking camera permission: $e');
      return false;
    }
  }

  Future<bool> _checkStoragePermission() async {
    if (kIsWeb) return true; // Web doesn't need explicit permission
    
    try {
      // For Android 13+ (API 33+), we need READ_MEDIA_IMAGES
      if (Platform.isAndroid) {
        final androidInfo = await DeviceInfoPlugin().androidInfo;
        if (androidInfo.version.sdkInt >= 33) {
          final permission = await Permission.photos.request();
          return permission == PermissionStatus.granted;
        }
      }
      
      // For older Android versions and iOS
      final permission = await Permission.photos.request();
      return permission == PermissionStatus.granted;
    } catch (e) {
      print('Error checking storage permission: $e');
      return false;
    }
  }

  // Report Analyzer Methods
  Future<void> _pickReportImage() async {
    try {
      // Show bottom sheet with options
      await showModalBottomSheet(
        context: context,
        backgroundColor: Colors.transparent,
        builder: (BuildContext context) {
          return Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Colors.black.withOpacity(0.8),
                  AppTheme.bgGlassMedium.withOpacity(0.9),
                ],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(20),
                topRight: Radius.circular(20),
              ),
              border: Border.all(
                color: AppTheme.primaryColor.withOpacity(0.3),
                width: 1,
              ),
            ),
            child: ClipRRect(
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(20),
                topRight: Radius.circular(20),
              ),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text(
                        "Choose Report Image Source",
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          fontFamily: 'Montserrat',
                        ),
                      ),
                      const SizedBox(height: 20),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          _buildImageSourceOption(
                            icon: Icons.camera_alt,
                            label: "Camera",
                            onTap: () async {
                              Navigator.pop(context);
                              await _getReportImageFromSource(ImageSource.camera);
                            },
                          ),
                          _buildImageSourceOption(
                            icon: Icons.photo_library,
                            label: "Gallery",
                            onTap: () async {
                              Navigator.pop(context);
                              await _getReportImageFromSource(ImageSource.gallery);
                            },
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error showing image options: ${e.toString()}')),
      );
    }
  }

  Future<void> _getReportImageFromSource(ImageSource source) async {
    try {
      // Check permissions first
      if (source == ImageSource.camera && !kIsWeb) {
        final hasPermission = await _checkCameraPermission();
        if (!hasPermission) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Camera permission is required to take photos'),
              backgroundColor: Colors.orange,
            ),
          );
          return;
        }
      } else if (source == ImageSource.gallery && !kIsWeb) {
        final hasPermission = await _checkStoragePermission();
        if (!hasPermission) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Storage permission is required to access photos'),
              backgroundColor: Colors.orange,
            ),
          );
          return;
        }
      }

      // Show loading indicator
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Processing report image...'),
            duration: Duration(seconds: 1),
          ),
        );
      }

      final img = await _picker.pickImage(
        source: source,
        imageQuality: 85,
        maxWidth: 1024,
        maxHeight: 1024,
      );
      
      if (img != null) {
        setState(() => _reportImage = img);
        
        try {
          // Read bytes (works on web and mobile)
          final bytes = await img.readAsBytes();
          
          // Validate size (< 4MB) for safer upload/analysis
          if (bytes.lengthInBytes > 4 * 1024 * 1024) {
            setState(() {
              _reportImage = null;
              _reportImageBytes = null;
              _reportImageMimeType = null;
            });
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Image too large. Please select an image under 4MB.'),
                backgroundColor: Colors.red,
              ),
            );
            return;
          }

          // Detect mime type
          String? mime = img.mimeType;
          if (mime == null || mime.isEmpty) {
            final name = img.name.isNotEmpty ? img.name : img.path;
            final lower = name.toLowerCase();
            if (lower.endsWith('.jpg') || lower.endsWith('.jpeg')) {
              mime = 'image/jpeg';
            } else if (lower.endsWith('.png')) mime = 'image/png';
            else if (lower.endsWith('.webp')) mime = 'image/webp';
            else if (lower.endsWith('.gif')) mime = 'image/gif';
            else mime = 'image/jpeg';
          }

          setState(() {
            _reportImageBytes = bytes;
            _reportImageMimeType = mime;
          });

          // Success feedback
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Report image uploaded successfully!'),
                backgroundColor: Colors.green,
                duration: Duration(seconds: 2),
              ),
            );
          }
        } catch (e) {
          print('Error processing report image: $e');
          setState(() {
            _reportImage = null;
            _reportImageBytes = null;
            _reportImageMimeType = null;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error processing report image: ${e.toString()}'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      print('Error in report image picker: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error picking report image: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _analyzeReport() async {
    // Check premium limits
    if (!_isPremium) {
      final canUse = await PremiumService.canUseSymptomAnalysis(); // Using same quota for now
      if (!canUse) {
        _showPremiumDialog();
        return;
      }
    }

    final desc = _reportDescriptionController.text.trim();
    if (desc.isEmpty && _reportImage == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please describe the report or attach an image')),
      );
      return;
    }
    FocusScope.of(context).unfocus();
    setState(() {
      _isAnalyzingReport = true;
      _reportAnalysisResult = null;
    });
    try {
      File? imageFile;
      if (!kIsWeb && _reportImage != null) {
        imageFile = File(_reportImage!.path);
        if (!imageFile.existsSync()) {
          throw Exception('Selected report image file no longer exists');
        }
        final fileSize = await imageFile.length();
        if (fileSize > 4 * 1024 * 1024) {
          throw Exception('Report image file is too large. Please use an image smaller than 4MB.');
        }
      }

      // Enrich description with patient profile from Digital Health ID for accuracy
      final enrichedDesc = _appendReportPatientProfile(desc);

      // Use health ID data if available and enabled, otherwise use manual inputs
      int? analysisAge;
      String? analysisGender;

      // First try to get age from Health ID if enabled
      if (_useHealthIdForReport && _healthId != null && _healthId!.age != null && _healthId!.age!.isNotEmpty) {
        analysisAge = int.tryParse(_healthId!.age!.trim());
        if (analysisAge != null && analysisAge > 0 && analysisAge <= 150) {
          print('Using Health ID age for report: $analysisAge');
        } else {
          analysisAge = int.tryParse(_reportAgeController.text.trim());
        }
      } else {
        analysisAge = int.tryParse(_reportAgeController.text.trim());
      }

      // Validate that age is provided and valid
      if (analysisAge == null || analysisAge <= 0 || analysisAge > 150) {
        setState(() => _isAnalyzingReport = false);
        String errorMessage = 'Age field is required for report analysis. ';
        if (_useHealthIdForReport && _healthId != null) {
          errorMessage += 'Please add a valid age to your Health ID profile or enter it manually.';
        } else {
          errorMessage += 'Please enter your age.';
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMessage),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      analysisGender = _reportGender;

      // Ensure mime type fallback on web if missing
      final mimeForAnalysis = _reportImageMimeType == null || _reportImageMimeType!.isEmpty
          ? (kIsWeb ? 'image/jpeg' : null)
          : _reportImageMimeType;

      final resText = await _geminiService.analyzeMedicalReport(
        description: enrichedDesc,
        reportType: _reportType,
        age: analysisAge,
        gender: analysisGender,
        imageAttached: _reportImage != null,
        imageFile: imageFile,
        imageBytes: _reportImageBytes,
        imageMimeType: mimeForAnalysis,
      );

      // Check for error responses including quota issues
      if (resText.startsWith('Sorry, the AI analysis could not be completed') || 
          resText.contains('quota exceeded') || 
          resText.contains('Unable to analyze')) {
        setState(() => _isAnalyzingReport = false);
        
        final isQuotaError = resText.contains('quota') || resText.contains('Unable to analyze');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              isQuotaError 
                ? '⚠️ API quota exceeded. Please wait a few minutes and try again, or update your API key.'
                : resText,
            ),
            backgroundColor: isQuotaError ? Colors.orange : Colors.red,
            duration: Duration(seconds: isQuotaError ? 6 : 4),
            action: SnackBarAction(
              label: 'OK',
              textColor: Colors.white,
              onPressed: () {},
            ),
          ),
        );
        return;
      }

      final parsed = _geminiService.parseReportResponse(resText);
      setState(() {
        _reportAnalysisResult = parsed;
        _isAnalyzingReport = false;
      });

      // Increment usage if not premium
      if (!_isPremium) {
        await PremiumService.incrementSymptomUsage();
        _checkPremiumStatus();
      }

      Future.delayed(const Duration(milliseconds: 300), () {
        if (_scrollController.hasClients) {
          _scrollController.animateTo(
            _scrollController.position.maxScrollExtent,
            duration: const Duration(milliseconds: 500),
            curve: Curves.easeOut,
          );
        }
      });

      await _saveReportRecord(desc, parsed);
    } catch (e) {
      setState(() => _isAnalyzingReport = false);
      
      // Detect if it's a quota/rate limit error
      final errorMsg = e.toString().toLowerCase();
      final isQuotaError = errorMsg.contains('quota') || 
                          errorMsg.contains('429') || 
                          errorMsg.contains('resource_exhausted') ||
                          errorMsg.contains('rate limit');
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            isQuotaError 
              ? '⚠️ API quota exceeded. Please wait and try again later, or get a new API key from Google AI Studio.'
              : '❌ Analysis failed: ${e.toString().replaceAll('Exception: ', '')}. Please check your connection and try again.',
          ),
          backgroundColor: isQuotaError ? Colors.orange : Colors.red,
          duration: Duration(seconds: isQuotaError ? 7 : 4),
          action: SnackBarAction(
            label: 'Dismiss',
            textColor: Colors.white,
            onPressed: () {},
          ),
        ),
      );
    }
  }

  String _appendReportPatientProfile(String baseDescription) {
    if (_healthId == null || !_useHealthIdForReport) return baseDescription;
    final profile = _healthId!;
    final List<String> lines = [];
    if ((profile.bloodGroup ?? '').trim().isNotEmpty) {
      lines.add('Blood Group: ${profile.bloodGroup}');
    }
    if (profile.allergies.isNotEmpty) {
      lines.add('Allergies: ${profile.allergies.join(', ')}');
    }
    if (profile.activeMedications.isNotEmpty) {
      lines.add('Active Medications: ${profile.activeMedications.join(', ')}');
    }
    if ((profile.medicalConditions ?? '').trim().isNotEmpty) {
      lines.add('Known Conditions: ${profile.medicalConditions}');
    }
    if ((profile.notes ?? '').trim().isNotEmpty) {
      lines.add('Notes: ${profile.notes}');
    }
    if (lines.isEmpty) return baseDescription;
    return '$baseDescription\n\nPatient Profile (from Digital Health ID):\n${lines.join('\n')}';
  }

  Future<void> _saveReportRecord(String description, Map<String, dynamic> analysis) async {
    final firebaseService = FirebaseService();
    final user = firebaseService.currentUser;
    if (user != null) {
      try {
        print('💾 Saving report analysis record for user: ${user.uid}');
        print('📝 Report data: description="$description", type="$_reportType"');
        print('🔍 Analysis data keys: ${analysis.keys.toList()}');

        final recordData = {
          'userId': user.uid,
          'description': description,
          'reportType': _reportType,
          'analysis': analysis,
          'timestamp': FieldValue.serverTimestamp(),
          'createdAt': FieldValue.serverTimestamp(),
          'hasImage': _reportImage != null,
          'age': _reportAgeController.text.isNotEmpty ? int.tryParse(_reportAgeController.text) : null,
          'gender': _reportGender,
        };

        print('📊 Complete report record data: $recordData');

        await firebaseService.saveReportRecord(user.uid, recordData);
        print('✅ Report analysis record saved successfully');

        // Show success message
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Report analysis saved to history!'),
              backgroundColor: Colors.green,
              duration: Duration(seconds: 2),
            ),
          );
        }
      } catch (e) {
        print('❌ Error saving report record: $e');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error saving report record: $e'),
              backgroundColor: Colors.red,
              action: SnackBarAction(
                label: 'Retry',
                onPressed: () => _saveReportRecord(description, analysis),
              ),
            ),
          );
        }
      }
    } else {
      print('⚠️ Cannot save report record: User not logged in');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please log in to save your report analysis'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    }
  }
} 