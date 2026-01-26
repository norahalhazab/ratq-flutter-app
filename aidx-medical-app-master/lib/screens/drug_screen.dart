import 'package:flutter/material.dart';
import '../services/gemini_service.dart';
import '../services/firebase_service.dart';
import '../services/premium_service.dart';
import '../utils/theme.dart';
import 'dart:ui';
import 'package:auto_size_text/auto_size_text.dart';
import 'package:flutter_feather_icons/flutter_feather_icons.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'inbox_screen.dart';
import '../services/supabase_places_service.dart';
import 'package:provider/provider.dart';
import '../services/auth_service.dart';

class DrugScreen extends StatefulWidget {
  const DrugScreen({super.key});

  @override
  State<DrugScreen> createState() => _DrugScreenState();
}

class _DrugScreenState extends State<DrugScreen> with SingleTickerProviderStateMixin {
  final TextEditingController _controller = TextEditingController();
  final GeminiService _geminiService = GeminiService();
  final FirebaseService _firebaseService = FirebaseService();
  Map<String, dynamic>? _drugInfo;
  String? _error;
  bool _loading = false;
  bool _saving = false;
  String? _saveMessage;
  final bool _sendSmsResults = false;
  final SupabasePlacesService _supabasePlacesService = SupabasePlacesService();
  late AnimationController _animController;
  late Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(vsync: this, duration: const Duration(milliseconds: 700));
    _fadeAnim = CurvedAnimation(parent: _animController, curve: Curves.easeInOut);
  }

  @override
  void dispose() {
    _animController.dispose();
    _controller.dispose();
    super.dispose();
  }

  Future<void> _search() async {
    // Check premium limit
    final canUse = await PremiumService.canUseDrugInfo();
    if (!canUse) {
      final remaining = await PremiumService.getRemainingDrugRequests();
      if (!mounted) return;
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          backgroundColor: const Color(0xFF1a1a2e),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Row(
            children: [
              const Icon(Icons.lock, color: Color(0xFFFFD700)),
              const SizedBox(width: 10),
              Text(
                'Daily Limit Reached',
                style: TextStyle(color: Colors.white.withOpacity(0.9)),
              ),
            ],
          ),
          content: Text(
            'You\'ve used all $remaining free drug lookups today.\n\nUpgrade to Premium for unlimited lookups!',
            style: TextStyle(color: Colors.white.withOpacity(0.7)),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('Later', style: TextStyle(color: Colors.white.withOpacity(0.5))),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                Navigator.pushNamed(context, '/welcome-subscription');
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFFFD700),
                foregroundColor: Colors.black87,
              ),
              child: const Text('Subscribe Now'),
            ),
          ],
        ),
      );
      return;
    }

    final name = _controller.text.trim();
    if (name.isEmpty) return;
    setState(() { _loading = true; _error = null; _drugInfo = null; _saveMessage = null; });
    try {
      // Increment usage counter
      await PremiumService.incrementDrugUsage();
      
      final info = await _geminiService.searchDrug(name, brief: true);
      if (info.containsKey('error')) {
        setState(() { _error = info['error']; _loading = false; });
      } else {
        setState(() { _drugInfo = info; _loading = false; });
        _animController.forward(from: 0);

        if (_sendSmsResults) {
          try {
            String? phone;
            // Try to read phone from user profile in Firestore
            final user = FirebaseAuth.instance.currentUser;
            if (user != null) {
              final doc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
              if (doc.exists) {
                phone = doc.data()?['profile']?['phone'];
              }
            }
            if (phone != null && phone.isNotEmpty) {
              await _supabasePlacesService.sendSmsResults(
                type: 'medicine',
                userPhone: phone,
                query: name,
              );
            } else {
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please login and add phone number to receive SMS')));
            }
          } catch (e) {
            print('SMS send error: $e');
          }
        }
      }
    } catch (e) {
      setState(() { _error = 'Failed to fetch information.'; _loading = false; });
    }
  }

  Future<void> _saveMedication() async {
    if (_drugInfo == null) return;
    setState(() { _saving = true; _saveMessage = null; });
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception('User not authenticated');
      
      await _firebaseService.addMedication(user.uid, {
        'name': _drugInfo!['name'] ?? '',
        'dosage': _drugInfo!['dosage'] ?? '',
        'frequency': 'as needed',
        'startDate': DateTime.now(),
        'endDate': null,
        'instructions': _drugInfo!['warnings'] ?? '',
        'isActive': true,
      });
      
      final reminderDateTime = DateTime.now().add(const Duration(hours: 1));
      await _firebaseService.addReminder(user.uid, {
        'title': 'Take ${_drugInfo!['name']}',
        'description': 'Dosage: ${_drugInfo!['dosage'] ?? 'As prescribed'}\nUses: ${_drugInfo!['uses'] ?? 'As needed'}',
        'type': 'medication',
        'dateTime': reminderDateTime,
        'frequency': 'once',
        'isActive': true,
        'dosage': _drugInfo!['dosage'] ?? 'As prescribed',
        'relatedId': null,
      });
      
      setState(() { _saveMessage = 'Medication saved and reminder set!'; _saving = false; });
    } catch (e) {
      setState(() { _saveMessage = 'Failed to save: ${e.toString()}'; _saving = false; });
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
            ],
            flexibleSpace: FlexibleSpaceBar(
              title: Column(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  const Text('Drug Information', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                  FutureBuilder<int>(
                    future: PremiumService.getRemainingDrugRequests(),
                    builder: (context, snapshot) {
                      if (snapshot.hasData) {
                        final remaining = snapshot.data!;
                        return Text(
                          '$remaining lookups left today',
                          style: TextStyle(
                            color: remaining == 0 ? Colors.red.shade300 : Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                          ),
                        );
                      }
                      return const SizedBox.shrink();
                    },
                  ),
                ],
              ),
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
                children: [
                  _buildSearchBar(),
                  const SizedBox(height: 20),
                  _buildContent(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return FutureBuilder<int>(
      future: PremiumService.getRemainingDrugRequests(),
      builder: (context, snapshot) {
        final hasRemaining = snapshot.hasData && snapshot.data! > 0;
        return Container(
      decoration: BoxDecoration(
        color: AppTheme.bgGlassMedium,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.1)),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 8, offset: const Offset(0, 4))],
      ),
      child: TextField(
        controller: _controller,
            enabled: hasRemaining,
        style: const TextStyle(color: Colors.white),
        decoration: InputDecoration(
          hintText: hasRemaining ? 'Search drug name (e.g., Paracetamol)' : 'Daily limit reached - Upgrade to Premium',
          hintStyle: TextStyle(color: Colors.white.withOpacity(0.5)),
          prefixIcon: Icon(hasRemaining ? FeatherIcons.search : Icons.lock, color: AppTheme.primaryColor),
          suffixIcon: _loading 
              ? const Padding(padding: EdgeInsets.all(12), child: CircularProgressIndicator(strokeWidth: 2))
              : (hasRemaining ? IconButton(icon: Icon(FeatherIcons.arrowRight, color: AppTheme.primaryColor), onPressed: _search) : null),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        ),
        onSubmitted: hasRemaining ? (_) => _search() : null,
      ),
        );
      },
    );
  }

  Widget _buildContent() {
    if (_error != null) {
      return Center(child: Text(_error!, style: TextStyle(color: AppTheme.dangerColor)));
    }
    if (_drugInfo == null && !_loading) {
      return Center(
        child: Column(
          children: [
            Icon(FeatherIcons.info, size: 48, color: Colors.white.withOpacity(0.3)),
            const SizedBox(height: 16),
            Text("Search for a drug to see details", style: TextStyle(color: Colors.white.withOpacity(0.5))),
          ],
        ),
      );
    }
    if (_drugInfo == null) return const SizedBox.shrink();

    return FadeTransition(
      opacity: _fadeAnim,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: AppTheme.bgGlassMedium,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: Colors.white.withOpacity(0.05)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryColor.withOpacity(0.2),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.medication, color: AppTheme.primaryColor, size: 32),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      AutoSizeText(
                        _drugInfo!['name']?.toString().toUpperCase() ?? '',
                        style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
                        maxLines: 1,
                      ),
                      if (_drugInfo!['generic_formula'] != null)
                        Text(
                          _drugInfo!['generic_formula'],
                          style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 12),
                        ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            _buildInfoSection('Uses', _drugInfo!['uses'], FeatherIcons.info, AppTheme.infoColor),
            _buildInfoSection('Dosage', _drugInfo!['dosage'], FeatherIcons.activity, AppTheme.primaryColor),
            _buildInfoSection('Side Effects', _drugInfo!['side_effects'], FeatherIcons.alertCircle, AppTheme.dangerColor),
            _buildInfoSection('Warnings', _drugInfo!['warnings'], FeatherIcons.alertTriangle, AppTheme.warningColor),
            const SizedBox(height: 24),
            if (_saveMessage != null)
              Container(
                padding: const EdgeInsets.all(12),
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: _saveMessage!.contains('Failed') ? AppTheme.dangerColor.withOpacity(0.2) : AppTheme.successColor.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Icon(_saveMessage!.contains('Failed') ? FeatherIcons.alertCircle : FeatherIcons.checkCircle, size: 16, color: Colors.white),
                    const SizedBox(width: 8),
                    Expanded(child: Text(_saveMessage!, style: const TextStyle(color: Colors.white, fontSize: 12))),
                  ],
                ),
              ),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _saving ? null : _saveMedication,
                icon: _saving ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Icon(FeatherIcons.bookmark),
                label: const Text("Save to My Medications"),
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
      ),
    );
  }

  Widget _buildInfoSection(String title, String? content, IconData icon, Color color) {
    if (content == null || content.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 14)),
                const SizedBox(height: 4),
                Text(content, style: TextStyle(color: Colors.white.withOpacity(0.8), fontSize: 14, height: 1.4)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}