import 'package:flutter/material.dart';
import 'dart:ui';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:share_plus/share_plus.dart';
import '../models/health_id_model.dart';
import '../services/health_id_service.dart';
import '../utils/theme.dart';
import '../utils/constants.dart';
import 'package:flutter_feather_icons/flutter_feather_icons.dart';
import 'health_id_edit_screen.dart';
import 'qr_scanner_screen.dart';
import 'inbox_screen.dart';

class HealthIdScreen extends StatefulWidget {
  const HealthIdScreen({super.key});

  @override
  State<HealthIdScreen> createState() => _HealthIdScreenState();
}

class _HealthIdScreenState extends State<HealthIdScreen> with TickerProviderStateMixin {
  final HealthIdService _healthIdService = HealthIdService();
  HealthIdModel? _healthId;
  bool _isLoading = true;
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
    _loadHealthId();
  }

  void _initializeAnimations() {
    _pulseController = AnimationController(duration: const Duration(seconds: 2), vsync: this);
    _pulseAnimation = Tween<double>(begin: 0.8, end: 1.2).animate(CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut));
    _pulseController.repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  Future<void> _loadHealthId() async {
    setState(() => _isLoading = true);
    try {
      final healthId = await _healthIdService.getHealthId();
      setState(() { _healthId = healthId; _isLoading = false; });
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bgDark,
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 100,
            floating: true,
            pinned: true,
            backgroundColor: AppTheme.bgDark,
            leading: IconButton(
              icon: const Icon(FeatherIcons.arrowLeft, color: Colors.white),
              onPressed: () => Navigator.pop(context),
            ),
            actions: [
              IconButton(
                icon: const Icon(FeatherIcons.inbox, color: Colors.white),
                onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const InboxScreen())),
              ),
              if (_healthId != null)
                PopupMenuButton<String>(
                  icon: const Icon(FeatherIcons.moreVertical, color: Colors.white),
                  color: AppTheme.bgGlassMedium,
                  onSelected: (value) {
                    switch (value) {
                      case 'edit': _navigateToEditScreen(); break;
                      case 'share_summary': _shareSummary(); break;
                      case 'share_qr': _shareQRCode(); break;
                      case 'save_qr': _saveQRCode(); break;
                      case 'scan': _navigateToScanner(); break;
                    }
                  },
                  itemBuilder: (context) => [
                    _buildPopupItem('edit', FeatherIcons.edit, 'Edit Health ID'),
                    _buildPopupItem('share_summary', FeatherIcons.share2, 'Share Summary'),
                    _buildPopupItem('share_qr', Icons.qr_code, 'Share QR Code'),
                    _buildPopupItem('save_qr', FeatherIcons.download, 'Save QR Code'),
                    _buildPopupItem('scan', Icons.qr_code_scanner, 'Scan Health ID'),
                  ],
                ),
            ],
            flexibleSpace: FlexibleSpaceBar(
              title: const Text('Digital Health ID', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
              centerTitle: true,
              background: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [AppTheme.primaryColor.withOpacity(0.2), AppTheme.bgDark],
                  ),
                ),
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildScanButton(),
                  const SizedBox(height: 20),
                  if (_isLoading)
                    const Center(child: CircularProgressIndicator())
                  else if (_healthId != null)
                    _buildHealthIdCard()
                  else
                    _buildEmptyStateCard(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  PopupMenuItem<String> _buildPopupItem(String value, IconData icon, String text) {
    return PopupMenuItem(
      value: value,
      child: Row(
        children: [
          Icon(icon, size: 18, color: Colors.white),
          const SizedBox(width: 12),
          Text(text, style: const TextStyle(color: Colors.white)),
        ],
      ),
    );
  }

  Widget _buildScanButton() {
    return GestureDetector(
      onTap: _navigateToScanner,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: AppTheme.bgGlassMedium,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: AppTheme.primaryColor.withOpacity(0.3)),
          boxShadow: [BoxShadow(color: AppTheme.primaryColor.withOpacity(0.1), blurRadius: 12, offset: const Offset(0, 4))],
        ),
        child: Row(
          children: [
            AnimatedBuilder(
              animation: _pulseAnimation,
              builder: (context, child) => Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppTheme.primaryColor.withOpacity(0.2 * _pulseAnimation.value),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.qr_code_scanner, color: AppTheme.primaryColor, size: 24 * _pulseAnimation.value),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text("Scan Health ID", style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                  Text("Scan other health IDs or QR codes", style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 12)),
                ],
              ),
            ),
            Icon(FeatherIcons.chevronRight, color: Colors.white.withOpacity(0.5)),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyStateCard() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppTheme.bgGlassMedium,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      child: Column(
        children: [
          Icon(FeatherIcons.user, size: 48, color: Colors.white.withOpacity(0.3)),
          const SizedBox(height: 16),
          const Text("No Health ID Found", style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Text("Create your digital health ID to share with healthcare providers", textAlign: TextAlign.center, style: TextStyle(color: Colors.white.withOpacity(0.6))),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _navigateToEditScreen,
              icon: const Icon(FeatherIcons.plus),
              label: const Text("Create Health ID"),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryColor,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHealthIdCard() {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
          ),
          child: Column(
            children: [
              QrImageView(
                data: _healthIdService.generateQRCodeData(_healthId!),
                version: QrVersions.auto,
                size: 200.0,
                backgroundColor: Colors.white,
              ),
              const SizedBox(height: 16),
              const Text("Scan to view profile", style: TextStyle(color: Colors.black54, fontSize: 12)),
            ],
          ),
        ),
        const SizedBox(height: 20),
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: AppTheme.bgGlassMedium,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: Colors.white.withOpacity(0.05)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text("Personal Information", style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              _buildInfoRow("Name", _healthId!.name, FeatherIcons.user),
              if (_healthId!.age != null) _buildInfoRow("Age", _healthId!.age!, FeatherIcons.calendar),
              if (_healthId!.bloodGroup != null) _buildInfoRow("Blood Group", _healthId!.bloodGroup!, FeatherIcons.droplet),
              if (_healthId!.emergencyContacts.isNotEmpty) _buildInfoRow("Emergency Contacts", "${_healthId!.emergencyContacts.length} contacts", FeatherIcons.phone),
              if (_healthId!.allergies.isNotEmpty) _buildInfoRow("Allergies", _healthId!.allergies.join(', '), FeatherIcons.alertTriangle),
              if (_healthId!.activeMedications.isNotEmpty) _buildInfoRow("Active Medications", _healthId!.activeMedications.join(', '), FeatherIcons.plus),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildInfoRow(String label, String value, IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: Colors.white.withOpacity(0.05), borderRadius: BorderRadius.circular(8)),
            child: Icon(icon, size: 16, color: Colors.white70),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 12)),
                Text(value, style: const TextStyle(color: Colors.white, fontSize: 14)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _navigateToEditScreen() {
    Navigator.push(context, MaterialPageRoute(builder: (context) => HealthIdEditScreen(healthId: _healthId))).then((_) => _loadHealthId());
  }

  void _shareSummary() {
    if (_healthId != null) _healthIdService.shareHealthId(_healthId!);
  }

  void _shareQRCode() {
    if (_healthId != null) _healthIdService.shareQRCode(_healthId!);
  }

  void _saveQRCode() async {
    if (_healthId != null) {
      final success = await _healthIdService.saveQRCodeToGallery(_healthId!);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(success ? 'QR Code saved to gallery' : 'Failed to save QR Code')));
    }
  }

  void _navigateToScanner() {
    Navigator.push(context, MaterialPageRoute(builder: (context) => const QRScannerScreen()));
  }
}