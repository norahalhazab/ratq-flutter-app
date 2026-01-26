import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter_feather_icons/flutter_feather_icons.dart';
import '../widgets/app_drawer.dart';
import '../utils/app_colors.dart';
import '../utils/constants.dart';
import '../services/places_service.dart';
import '../services/free_places_service.dart';
import '../services/supabase_places_service.dart';
import '../utils/theme.dart';

import 'package:provider/provider.dart';
import '../services/auth_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class ProfessionalsPharmacyScreen extends StatefulWidget {
  const ProfessionalsPharmacyScreen({super.key});

  @override
  State<ProfessionalsPharmacyScreen> createState() => _ProfessionalsPharmacyScreenState();
}

class _ProfessionalsPharmacyScreenState extends State<ProfessionalsPharmacyScreen> {
  bool _isLoading = false;
  String _selectedOption = 'doctors'; // 'doctors' or 'pharmacy'
  String _selectedSpecialty = 'orthopedic';
  String _selectedCity = 'Dhaka';
  String _selectedArea = 'Gulshan';
  List<Map<String, dynamic>> _results = [];
  final FreePlacesService _freePlacesService = FreePlacesService();
  final SupabasePlacesService _supabasePlacesService = SupabasePlacesService();
  final bool _useSupabaseService = false; // Default to Free (OSM) for real data
  bool _sendSmsResults = false; // Toggle for SMS results

  final List<String> _specialties = [
    'orthopedic', 'gynecologist', 'cardiologist', 'dermatologist',
    'neurologist', 'psychiatrist', 'pediatrician', 'ophthalmologist',
    'dentist', 'general practitioner'
  ];

  final List<String> _cities = [
    'Dhaka', 'Chittagong', 'Sylhet', 'Rajshahi', 'Khulna',
    'Barisal', 'Rangpur', 'Mymensingh', 'Comilla', 'Narayanganj'
  ];

  final Map<String, List<String>> _cityAreas = {
    'Dhaka': ['Gulshan', 'Banani', 'Dhanmondi', 'Uttara', 'Mirpur', 'Mohammadpur', 'Old Dhaka'],
    'Chittagong': ['Agrabad', 'Nasirabad', 'Halishahar', 'Pahartali', 'Khulshi'],
    'Sylhet': ['Zindabazar', 'Ambarkhana', 'Tilagor', 'Uposhohor'],
    'Rajshahi': ['Shaheb Bazar', 'Motihar', 'Boalia', 'Rajpara'],
    'Khulna': ['Sonadanga', 'Khalishpur', 'Daulatpur'],
    'Barisal': ['Sadhar', 'Kashipur', 'Uttar Bazar'],
    'Rangpur': ['Jahaj Company', 'Lalbagh', 'Shapla'],
    'Mymensingh': ['Ganginar Par', 'Chhoto Bazar'],
    'Comilla': ['Kandirpar', 'Shashongacha'],
    'Narayanganj': ['Chashara', 'Netaiganj'],
  };

  @override
  void initState() {
    super.initState();
    _searchNearby(); // Auto-search on load
  }

  Future<void> _searchNearby() async {
    setState(() { _isLoading = true; _results = []; });

    try {
      if (_selectedOption == 'doctors') {
        await _searchDoctors();
      } else {
        await _searchPharmacies();
      }

      if (_sendSmsResults) {
        await _handleSmsSending();
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: ${e.toString()}')));
    } finally {
      setState(() { _isLoading = false; });
    }
  }

  Future<void> _handleSmsSending() async {
    try {
      final authService = Provider.of<AuthService>(context, listen: false);
      final user = authService.currentUser;
      
      String? phoneNumber;
      
      if (user != null) {
        // Try to get phone from profile
        final doc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
        if (doc.exists) {
          phoneNumber = doc.data()?['profile']?['phone'];
        }
      }

      if (phoneNumber == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please login and add phone number to receive SMS results')),
        );
        return;
      }

      // Normalize phone number (remove +880 or 880 if present, then add it back cleanly if needed, 
      // but the service expects 880...)
      // Assuming the service handles it or we pass it as is if it's valid.
      // The edge function expects just the number, it adds 'tel:'.
      // Let's strip 'tel:' if present.
      phoneNumber = phoneNumber.replaceAll('tel:', '');

      final success = await _supabasePlacesService.sendSmsResults(
        city: _selectedCity,
        area: _selectedArea,
        type: _selectedOption == 'doctors' ? 'doctor' : 'pharmacy',
        userPhone: phoneNumber,
        specialty: _selectedOption == 'doctors' ? _selectedSpecialty : null,
      );

      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Results sent via SMS (Charge: 2.00 TK)')),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to send SMS results')),
        );
      }
    } catch (e) {
      print('SMS Error: $e');
    }
  }

  Future<void> _searchDoctors() async {
    final results = _useSupabaseService
      ? await _supabasePlacesService.searchDoctors(city: _selectedCity, area: _selectedArea, specialty: _selectedSpecialty)
      : await _freePlacesService.searchDoctors(
          location: Position(latitude: 23.8103, longitude: 90.4125, timestamp: DateTime.now(), accuracy: 0, altitude: 0, heading: 0, speed: 0, speedAccuracy: 0, altitudeAccuracy: 0, headingAccuracy: 0),
          specialty: _selectedSpecialty,
          radius: 5.0,
          city: _selectedCity,
        );
    setState(() { _results = results; });
  }

  Future<void> _searchPharmacies() async {
    final results = _useSupabaseService
      ? await _supabasePlacesService.searchPharmacies(city: _selectedCity, area: _selectedArea)
      : await _freePlacesService.searchPharmacies(
          location: Position(latitude: 23.8103, longitude: 90.4125, timestamp: DateTime.now(), accuracy: 0, altitude: 0, heading: 0, speed: 0, speedAccuracy: 0, altitudeAccuracy: 0, headingAccuracy: 0),
          radius: 5.0,
          city: _selectedCity,
        );
    setState(() { _results = results; });
  }

  Future<void> _launchMaps(double lat, double lon) async {
    final uri = Uri.parse('https://www.google.com/maps/search/?api=1&query=$lat,$lon');
    if (await canLaunchUrl(uri)) await launchUrl(uri);
  }
  
  Future<void> _launchPhone(String phone) async {
    final uri = Uri.parse('tel:$phone');
    if (await canLaunchUrl(uri)) await launchUrl(uri);
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
            flexibleSpace: FlexibleSpaceBar(
              title: const Text('Find Professionals', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
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
                  _buildCompactSearchPanel(),
                  const SizedBox(height: 16),
                  _isLoading 
                      ? const Center(child: CircularProgressIndicator(color: AppTheme.primaryColor))
                      : _results.isEmpty 
                          ? Center(child: Text('No results found', style: TextStyle(color: Colors.white.withOpacity(0.5))))
                          : ListView.builder(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              itemCount: _results.length,
                              itemBuilder: (context, index) => _buildCompactResultCard(_results[index], index),
                            ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCompactSearchPanel() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.bgGlassMedium,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.1)),
      ),
      child: Column(
        children: [
          // Toggle
          Container(
            height: 40,
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.3),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                _buildToggleOption('Doctors', 'doctors', FeatherIcons.user),
                _buildToggleOption('Pharmacy', 'pharmacy', FeatherIcons.briefcase),
              ],
            ),
          ),
          const SizedBox(height: 16),
          // SMS Toggle
          SwitchListTile(
            title: const Text('Receive results via SMS', style: TextStyle(color: Colors.white, fontSize: 14)),
            subtitle: Text('Charge: 2.00 TK', style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 12)),
            value: _sendSmsResults,
            onChanged: (val) {
              setState(() { _sendSmsResults = val; });
            },
            activeThumbColor: AppTheme.primaryColor,
            contentPadding: EdgeInsets.zero,
            dense: true,
          ),
          const SizedBox(height: 10),
          // Filters
          Row(
            children: [
              Expanded(
                child: _buildCompactDropdown(
                  value: _selectedCity,
                  items: _cities,
                  onChanged: (val) {
                    setState(() {
                      _selectedCity = val!;
                      _selectedArea = _cityAreas[_selectedCity]?.first ?? '';
                      _searchNearby();
                    });
                  },
                  icon: FeatherIcons.mapPin,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _buildCompactDropdown(
                  value: _selectedArea,
                  items: _cityAreas[_selectedCity] ?? [],
                  onChanged: (val) {
                    setState(() { _selectedArea = val!; _searchNearby(); });
                  },
                  icon: FeatherIcons.navigation,
                ),
              ),
            ],
          ),
          if (_selectedOption == 'doctors') ...[
            const SizedBox(height: 10),
            _buildCompactDropdown(
              value: _selectedSpecialty,
              items: _specialties,
              onChanged: (val) {
                setState(() { _selectedSpecialty = val!; _searchNearby(); });
              },
              icon: FeatherIcons.activity,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildToggleOption(String title, String value, IconData icon) {
    final isSelected = _selectedOption == value;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          setState(() { _selectedOption = value; _searchNearby(); });
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          margin: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: isSelected ? AppTheme.primaryColor : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
            boxShadow: isSelected ? [BoxShadow(color: AppTheme.primaryColor.withOpacity(0.3), blurRadius: 8)] : null,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 16, color: isSelected ? Colors.white : Colors.white54),
              const SizedBox(width: 6),
              Text(title, style: TextStyle(color: isSelected ? Colors.white : Colors.white54, fontWeight: FontWeight.bold, fontSize: 12)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCompactDropdown({
    required String value,
    required List<String> items,
    required Function(String?) onChanged,
    required IconData icon,
  }) {
    return Container(
      height: 40,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withOpacity(0.1)),
      ),
      child: Row(
        children: [
          Icon(icon, size: 14, color: AppTheme.primaryColor),
          const SizedBox(width: 8),
          Expanded(
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: value,
                isExpanded: true,
                dropdownColor: AppTheme.bgDarkSecondary,
                icon: const Icon(FeatherIcons.chevronDown, size: 14, color: Colors.white54),
                style: const TextStyle(color: Colors.white, fontSize: 12),
                items: items.map((item) => DropdownMenuItem(value: item, child: Text(item))).toList(),
                onChanged: onChanged,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCompactResultCard(Map<String, dynamic> result, int index) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: Duration(milliseconds: 400 + (index * 100)),
      curve: Curves.easeOutCubic,
      builder: (context, value, child) {
        return Transform.translate(
          offset: Offset(0, 20 * (1 - value)),
          child: Opacity(
            opacity: value,
            child: Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTheme.bgGlassMedium,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.white.withOpacity(0.05)),
              ),
              child: Row(
                children: [
                  Container(
                    width: 50,
                    height: 50,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [AppTheme.primaryColor.withOpacity(0.2), AppTheme.accentColor.withOpacity(0.1)],
                      ),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      _selectedOption == 'doctors' ? FeatherIcons.user : FeatherIcons.briefcase,
                      color: AppTheme.primaryColor,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          result['name'] ?? 'Unknown',
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _selectedOption == 'doctors' ? (result['specialty'] ?? '') : (result['address'] ?? ''),
                          style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 11),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Icon(Icons.star, size: 12, color: AppTheme.warningColor),
                            const SizedBox(width: 4),
                            Text('${result['rating']}', style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
                            const SizedBox(width: 8),
                            Icon(FeatherIcons.mapPin, size: 12, color: AppTheme.accentColor),
                            const SizedBox(width: 4),
                            Text('${result['distance']} km', style: const TextStyle(color: Colors.white, fontSize: 11)),
                          ],
                        ),
                      ],
                    ),
                  ),
                  Column(
                    children: [
                      _buildActionButton(FeatherIcons.phone, AppTheme.successColor, () => _launchPhone(result['phone'] ?? '')),
                      const SizedBox(height: 8),
                      _buildActionButton(FeatherIcons.map, AppTheme.infoColor, () => _launchMaps(result['latitude'] ?? 0.0, result['longitude'] ?? 0.0)),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildActionButton(IconData icon, Color color, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: color.withOpacity(0.2),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Icon(icon, size: 16, color: color),
      ),
    );
  }
}