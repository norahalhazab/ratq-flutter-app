import 'package:flutter/material.dart';
import 'package:flutter_feather_icons/flutter_feather_icons.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/doctor_search_service.dart';
import '../services/pharmacy_search_service.dart';
import '../utils/theme.dart';
import '../widgets/glass_container.dart';
import 'dart:ui';

class DoctorSearchScreen extends StatefulWidget {
  const DoctorSearchScreen({super.key});

  @override
  State<DoctorSearchScreen> createState() => _DoctorSearchScreenState();
}

class _DoctorSearchScreenState extends State<DoctorSearchScreen> {
  final DoctorSearchService _doctorService = DoctorSearchService();
  final PharmacySearchService _pharmacyService = PharmacySearchService();
  
  bool _isDoctorSearch = true;
  bool _isLoading = false;
  
  // Hardcoded for reliability and speed in selection
  final Map<String, String> _locations = {
    'Dhaka': 'dhaka',
    'Chittagong': 'chittagong',
    'Sylhet': 'sylhet',
    'Rajshahi': 'rajshahi',
    'Khulna': 'khulna',
    'Barisal': 'barisal',
    'Rangpur': 'rangpur',
    'Mymensingh': 'mymensingh',
    'Comilla': 'cumilla',
    'Narayanganj': 'narayanganj',
    'Bogra': 'bogura',
  };

  final Map<String, String> _specialties = {
    'Cardiologist': 'cardiologist',
    'Medicine Specialist': 'medicine-specialist',
    'Child Specialist': 'pediatrician',
    'Gynecologist': 'gynecologist',
    'Skin Specialist': 'dermatologist',
    'Eye Specialist': 'ophthalmologist',
    'ENT Specialist': 'otolaryngologist',
    'Kidney Specialist': 'nephrologist',
    'Neurologist': 'neurologist',
    'Orthopedic Surgeon': 'orthopedic-specialist',
    'Diabetes Specialist': 'diabetologist',
    'Gastroenterologist': 'gastroenterologist',
    'Dental Doctor': 'dentist',
    'Urologist': 'urologist',
    'Psychiatrist': 'psychiatrist',
    'Cancer Specialist': 'oncologist',
    'Liver Specialist': 'hepatologist',
    'Chest Specialist': 'chest-specialist',
    'Physical Medicine': 'physical-medicine',
    'Pain Specialist': 'pain-specialist',
    'Nutritionist': 'nutritionist',
    'Homeopathy': 'homeopathy',
  };

  String _selectedLocation = 'Dhaka';
  String _selectedSpecialty = 'Cardiologist';
  
  List<Doctor> _doctors = [];
  List<Pharmacy> _pharmacies = [];
  final int _pharmacyPage = 1;

  @override
  void initState() {
    super.initState();
    _performSearch();
  }

  Future<void> _performSearch() async {
    setState(() => _isLoading = true);
    
    try {
      if (_isDoctorSearch) {
        final results = await _doctorService.searchDoctors(
          specialtySlug: _specialties[_selectedSpecialty]!,
          locationSlug: _locations[_selectedLocation]!,
        );
        if (mounted) setState(() => _doctors = results);
      } else {
        final results = await _pharmacyService.searchPharmacies(
          location: _selectedLocation,
        );
        if (mounted) {
          setState(() {
            _pharmacies = results;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: AppTheme.dangerColor),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
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
                _buildToggle(),
                _buildFilters(),
                Expanded(
                  child: _isLoading && (_isDoctorSearch ? _doctors.isEmpty : _pharmacies.isEmpty)
                    ? _buildLoadingState()
                    : _buildResultsList(),
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
            top: -100,
            right: -50,
            child: Container(
              width: 300,
              height: 300,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppTheme.primaryColor.withOpacity(0.1),
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
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 10),
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
              child: const Icon(FeatherIcons.chevronLeft, color: Colors.white, size: 20),
            ),
          ),
          const SizedBox(width: 16),
          const Text(
            'Health Finder',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w900,
              color: Colors.black,
              fontFamily: 'Montserrat',
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildToggle() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.1)),
      ),
      child: Row(
        children: [
          Expanded(
            child: _buildToggleButton('Doctors', _isDoctorSearch, () {
              setState(() {
                _isDoctorSearch = true;
                _performSearch();
              });
            }),
          ),
          Expanded(
            child: _buildToggleButton('Pharmacies', !_isDoctorSearch, () {
              setState(() {
                _isDoctorSearch = false;
                _performSearch();
              });
            }),
          ),
        ],
      ),
    );
  }

  Widget _buildToggleButton(String title, bool isActive, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          gradient: isActive ? LinearGradient(colors: [AppTheme.primaryColor, AppTheme.accentColor]) : null,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Center(
          child: Text(
            title,
            style: TextStyle(
              color: isActive ? Colors.white : Colors.white.withOpacity(0.5),
              fontWeight: isActive ? FontWeight.w800 : FontWeight.w600,
              fontSize: 14,
              fontFamily: 'Montserrat',
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFilters() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      child: Row(
        children: [
          Expanded(
            child: _buildCompactDropdown(
              value: _selectedLocation,
              items: _locations.keys.toList(),
              icon: FeatherIcons.mapPin,
              onChanged: (val) {
                if (val != null) {
                  setState(() => _selectedLocation = val);
                  _performSearch();
                }
              },
            ),
          ),
          if (_isDoctorSearch) ...[
            const SizedBox(width: 12),
            Expanded(
              child: _buildCompactDropdown(
                value: _selectedSpecialty,
                items: _specialties.keys.toList(),
                icon: FeatherIcons.activity,
                onChanged: (val) {
                  if (val != null) {
                    setState(() => _selectedSpecialty = val);
                    _performSearch();
                  }
                },
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildCompactDropdown({
    required String value,
    required List<String> items,
    required IconData icon,
    required ValueChanged<String?> onChanged,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withOpacity(0.1)),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: value,
          isExpanded: true,
          dropdownColor: AppTheme.bgDark,
          icon: Icon(icon, color: AppTheme.accentColor, size: 14),
          style: const TextStyle(color: Colors.black, fontSize: 13, fontWeight: FontWeight.w600, fontFamily: 'Montserrat'),
          items: items.map((item) => DropdownMenuItem(
            value: item,
            child: Text(item, overflow: TextOverflow.ellipsis),
          )).toList(),
          onChanged: onChanged,
        ),
      ),
    );
  }

  Widget _buildLoadingState() {
    return const Center(child: CircularProgressIndicator(color: AppTheme.accentColor));
  }

  Widget _buildResultsList() {
    if (_isDoctorSearch) {
      if (_doctors.isEmpty) return _buildEmptyState('No doctors found');
      return ListView.builder(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        itemCount: _doctors.length,
        itemBuilder: (context, index) => _buildDoctorCard(_doctors[index]),
      );
    } else {
      if (_pharmacies.isEmpty) return _buildEmptyState('No pharmacies found');
      return ListView.builder(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        itemCount: _pharmacies.length,
        itemBuilder: (context, index) => _buildPharmacyCard(_pharmacies[index]),
      );
    }
  }

  Widget _buildEmptyState(String message) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(FeatherIcons.search, size: 48, color: Colors.white.withOpacity(0.1)),
          const SizedBox(height: 16),
          Text(message, style: TextStyle(color: Colors.white.withOpacity(0.5), fontFamily: 'Montserrat')),
        ],
      ),
    );
  }

  Widget _buildDoctorCard(Doctor doctor) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: GlassContainer(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(color: AppTheme.primaryColor.withOpacity(0.2), shape: BoxShape.circle),
                  child: const Icon(FeatherIcons.user, color: AppTheme.primaryColor, size: 18),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(doctor.name, style: const TextStyle(color: Colors.black, fontSize: 15, fontWeight: FontWeight.w800, fontFamily: 'Montserrat')),
                      Text(doctor.qualifications, style: TextStyle(color: AppTheme.accentColor.withOpacity(0.8), fontSize: 11, fontWeight: FontWeight.w600), maxLines: 1, overflow: TextOverflow.ellipsis),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (doctor.chamber != null) ...[
              Row(
                children: [
                  Icon(FeatherIcons.home, color: Colors.white.withOpacity(0.4), size: 12),
                  const SizedBox(width: 8),
                  Expanded(child: Text(doctor.chamber!, style: TextStyle(color: Colors.black.withOpacity(0.7), fontSize: 12))),
                ],
              ),
              const SizedBox(height: 4),
            ],
            Text(doctor.position, style: TextStyle(color: Colors.black.withOpacity(0.5), fontSize: 11, height: 1.4), maxLines: 2, overflow: TextOverflow.ellipsis),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: () => _showDoctorDetails(doctor),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.05),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.white.withOpacity(0.1)),
                      ),
                      child: const Center(child: Text('Details', style: TextStyle(color: Colors.black, fontWeight: FontWeight.w700, fontSize: 12))),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: GestureDetector(
                    onTap: () => _launchUrl(doctor.profileUrl),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(colors: [AppTheme.primaryColor, AppTheme.accentColor]),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Center(child: Text('Profile', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 12))),
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

  Widget _buildPharmacyCard(Pharmacy pharmacy) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: GlassContainer(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(color: AppTheme.successColor.withOpacity(0.1), shape: BoxShape.circle),
                  child: const Icon(FeatherIcons.plusSquare, color: AppTheme.successColor, size: 16),
                ),
                const SizedBox(width: 12),
                Expanded(child: Text(pharmacy.name, style: const TextStyle(color: Colors.black, fontSize: 15, fontWeight: FontWeight.w800, fontFamily: 'Montserrat'))),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(FeatherIcons.mapPin, color: Colors.white.withOpacity(0.4), size: 12),
                const SizedBox(width: 8),
                Expanded(child: Text(pharmacy.address, style: TextStyle(color: Colors.black.withOpacity(0.6), fontSize: 12, height: 1.4))),
              ],
            ),
            const SizedBox(height: 16),
            GestureDetector(
              onTap: () => _launchUrl('tel:${pharmacy.phone}'),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  gradient: LinearGradient(colors: [AppTheme.primaryColor, AppTheme.accentColor]),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: const [
                    Icon(FeatherIcons.phone, color: Colors.white, size: 14),
                    SizedBox(width: 8),
                    Text('Call Now', style: TextStyle(color: Colors.black, fontWeight: FontWeight.w800, fontSize: 12)),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showDoctorDetails(Doctor doctor) async {
    showDialog(context: context, barrierDismissible: false, builder: (context) => const Center(child: CircularProgressIndicator(color: AppTheme.accentColor)));
    await _doctorService.fetchDoctorDetails(doctor);
    if (mounted) {
      Navigator.pop(context);
      showModalBottomSheet(
        context: context,
        backgroundColor: Colors.transparent,
        builder: (context) => GlassContainer(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(doctor.name, style: const TextStyle(color: Colors.black, fontSize: 18, fontWeight: FontWeight.w900, fontFamily: 'Montserrat')),
                const SizedBox(height: 20),
                if (doctor.phone != null || doctor.appointmentPhone != null) 
                  _buildDetailRow(FeatherIcons.phone, 'Phone', doctor.phone ?? doctor.appointmentPhone!),
                if (doctor.fee != null) _buildDetailRow(FeatherIcons.dollarSign, 'Visiting Fee', '৳${doctor.fee}'),
                if (doctor.chamber != null) _buildDetailRow(FeatherIcons.home, 'Chamber', doctor.chamber!),
                if (doctor.address != null) _buildDetailRow(FeatherIcons.mapPin, 'Address', doctor.address!),
                if (doctor.visitingHours != null) _buildDetailRow(FeatherIcons.clock, 'Visiting Hours', doctor.visitingHours!),
                const SizedBox(height: 20),
                SizedBox(width: double.infinity, child: ElevatedButton(onPressed: () => Navigator.pop(context), style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryColor, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))), child: const Text('Close', style: TextStyle(color: Colors.black)))),
              ],
            ),
          ),
        ),
      );
    }
  }

  Widget _buildDetailRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Icon(icon, color: AppTheme.accentColor, size: 16),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 10, fontWeight: FontWeight.w600)),
                const SizedBox(height: 2),
                Text(
                  value, 
                  style: const TextStyle(color: Colors.black, fontSize: 14, fontWeight: FontWeight.w700),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _launchUrl(String url) async {
    if (await canLaunchUrl(Uri.parse(url))) {
      await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
    }
  }
}
