import 'package:flutter/material.dart';
import 'package:flutter_feather_icons/flutter_feather_icons.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/pharmacy_search_service.dart';
import '../utils/theme.dart';
import '../widgets/glass_container.dart';
import 'dart:ui';

class PharmacySearchScreen extends StatefulWidget {
  const PharmacySearchScreen({super.key});

  @override
  State<PharmacySearchScreen> createState() => _PharmacySearchScreenState();
}

class _PharmacySearchScreenState extends State<PharmacySearchScreen> {
  final PharmacySearchService _searchService = PharmacySearchService();
  List<Pharmacy> _pharmacies = [];
  bool _isLoading = false;
  int _currentPage = 1;

  @override
  void initState() {
    super.initState();
    _loadPharmacies();
  }

  Future<void> _loadPharmacies({bool loadMore = false}) async {
    if (_isLoading) return;
    
    setState(() => _isLoading = true);
    
    if (!loadMore) {
      _currentPage = 1;
      _pharmacies = [];
    }

    try {
      final results = await _searchService.searchPharmacies(location: 'Dhaka');
      if (mounted) {
        setState(() {
          _pharmacies.addAll(results);
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: AppTheme.dangerColor),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bgDark,
      body: Stack(
        children: [
          _buildBackground(),
          SafeArea(
            child: Column(
              children: [
                _buildHeader(),
                Expanded(
                  child: _pharmacies.isEmpty && _isLoading
                    ? _buildLoadingState()
                    : _pharmacies.isEmpty
                      ? _buildEmptyState()
                      : _buildPharmacyList(),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBackground() {
    return Positioned.fill(
      child: Stack(
        children: [
          Container(color: AppTheme.bgDark),
          Positioned(
            bottom: -100,
            left: -50,
            child: Container(
              width: 300,
              height: 300,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppTheme.accentColor.withOpacity(0.1),
              ),
            ),
          ),
          Positioned.fill(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 80, sigmaY: 80),
              child: Container(color: Colors.transparent),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.05),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.white.withOpacity(0.1)),
              ),
              child: const Icon(FeatherIcons.chevronLeft, color: Colors.white),
            ),
          ),
          const SizedBox(width: 20),
          const Text(
            'Pharmacy Finder',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w900,
              color: Colors.white,
              fontFamily: 'Montserrat',
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingState() {
    return const Center(
      child: CircularProgressIndicator(color: AppTheme.accentColor),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(FeatherIcons.plusSquare, size: 64, color: Colors.white.withOpacity(0.1)),
          const SizedBox(height: 16),
          const Text(
            'No pharmacies found',
            style: TextStyle(color: Colors.white70, fontFamily: 'Montserrat'),
          ),
        ],
      ),
    );
  }

  Widget _buildPharmacyList() {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      itemCount: _pharmacies.length + 1,
      itemBuilder: (context, index) {
        if (index == _pharmacies.length) {
          return _isLoading 
            ? const Padding(padding: EdgeInsets.all(20), child: Center(child: CircularProgressIndicator()))
            : Padding(
                padding: const EdgeInsets.all(20),
                child: TextButton(
                  onPressed: () => _loadPharmacies(loadMore: true),
                  child: const Text('Load More', style: TextStyle(color: AppTheme.accentColor)),
                ),
              );
        }
        final pharmacy = _pharmacies[index];
        return _buildPharmacyCard(pharmacy);
      },
    );
  }

  Widget _buildPharmacyCard(Pharmacy pharmacy) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      child: GlassContainer(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppTheme.successColor.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(FeatherIcons.plusSquare, color: AppTheme.successColor, size: 20),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Text(
                    pharmacy.name,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                      fontFamily: 'Montserrat',
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(FeatherIcons.mapPin, color: Colors.white.withOpacity(0.4), size: 14),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    pharmacy.address,
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.6),
                      fontSize: 13,
                      height: 1.4,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: () => _makeCall(pharmacy.phone),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(colors: [AppTheme.primaryColor, AppTheme.accentColor]),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: const [
                          Icon(FeatherIcons.phone, color: Colors.white, size: 16),
                          SizedBox(width: 8),
                          Text(
                            'Call Now',
                            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 13),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _makeCall(String phone) async {
    final url = 'tel:$phone';
    if (await canLaunchUrl(Uri.parse(url))) {
      await launchUrl(Uri.parse(url));
    }
  }
}
