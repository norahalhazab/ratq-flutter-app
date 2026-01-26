import 'package:flutter/material.dart';
import 'dart:ui';
import 'dart:io';
import '../utils/theme.dart';
import '../services/firebase_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:geolocator/geolocator.dart';
import 'dart:math' as math;
import 'chat_thread_screen.dart';
import 'inbox_screen.dart';
import 'package:flutter_feather_icons/flutter_feather_icons.dart';
import 'package:provider/provider.dart';
import '../services/auth_service.dart';
import '../services/supabase_places_service.dart';

class BloodDonationScreen extends StatefulWidget {
  const BloodDonationScreen({super.key});

  @override
  State<BloodDonationScreen> createState() => _BloodDonationScreenState();
}

class _BloodDonationScreenState extends State<BloodDonationScreen> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _hospitalController = TextEditingController();
  
  String _selectedBloodType = 'A+';
  String _selectedCity = 'Dhaka';
  double _radius = 10.0;
  bool _useGpsRadius = false;
  bool _sendSmsResults = false;
  Position? _currentPosition;
  bool _isLoading = false;
  bool _showPostForm = false;
  List<Map<String, dynamic>> _donationRequests = [];
  List<Map<String, dynamic>> _donors = [];
  bool _loadingRequests = true;
  bool _loadingDonors = true;
  int _selectedTab = 0; // 0 = Find Donor, 1 = Donate
  
  // Error states
  bool _hasError = false;
  String _errorMessage = '';
  int _retryCount = 0;
  static const int _maxRetries = 3;
  
  final List<String> _bangladeshCities = [
    'Dhaka', 'Chittagong', 'Sylhet', 'Rajshahi', 'Khulna', 'Barisal', 
    'Rangpur', 'Mymensingh', 'Comilla', 'Narayanganj', 'Gazipur', 
    'Tangail', 'Bogra', 'Kushtia', 'Jessore', 'Dinajpur', 'Pabna',
    'Noakhali', 'Feni', 'Cox\'s Bazar', 'Bandarban', 'Rangamati'
  ];

  final List<String> _bloodTypes = ['A+', 'A-', 'B+', 'B-', 'AB+', 'AB-', 'O+', 'O-'];

  @override
  void initState() {
    super.initState();
    _initializeData();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _hospitalController.dispose();
    super.dispose();
  }

  Future<void> _initializeData() async {
    if (!mounted) return;
    setState(() { _hasError = false; _errorMessage = ''; _retryCount = 0; });
    try {
      await _checkConnectivity();
      await Future.wait([_loadDonationRequests(), _loadDonors()]);
    } catch (e) {
      if (mounted) _handleError('Error initializing data: $e');
    }
  }

  Future<void> _checkConnectivity() async {
    try {
      final result = await InternetAddress.lookup('google.com');
      if (result.isEmpty || result[0].rawAddress.isEmpty) throw Exception('No internet connection');
    } on SocketException catch (_) {
      throw Exception('No internet connection');
    }
  }

  void _handleError(String message) {
    if (!mounted) return;
    setState(() {
      _hasError = true;
      _errorMessage = message;
      _loadingRequests = false;
      _loadingDonors = false;
    });
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
              title: const Text('Blood Donation', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
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
                  _buildTabToggle(),
                  const SizedBox(height: 16),
                  if (_hasError) _buildErrorWidget() else _buildMainContent(),
                ],
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: _selectedTab == 0 ? FloatingActionButton.extended(
        onPressed: () => setState(() => _showPostForm = !_showPostForm),
        backgroundColor: AppTheme.primaryColor,
        icon: Icon(_showPostForm ? FeatherIcons.x : FeatherIcons.plus),
        label: Text(_showPostForm ? 'Cancel' : 'Request Blood'),
      ) : null,
    );
  }

  Widget _buildTabToggle() {
    return Container(
      height: 45,
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.3),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withOpacity(0.1)),
      ),
      child: Row(
        children: [
          _buildTabButton("Find Donor", 0, FeatherIcons.search),
          _buildTabButton("Donate", 1, FeatherIcons.heart),
        ],
      ),
    );
  }

  Widget _buildTabButton(String title, int index, IconData icon) {
    final selected = _selectedTab == index;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          setState(() => _selectedTab = index);
          _loadDonors();
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          margin: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: selected ? AppTheme.primaryColor : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
            boxShadow: selected ? [BoxShadow(color: AppTheme.primaryColor.withOpacity(0.3), blurRadius: 8)] : null,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 16, color: selected ? Colors.white : Colors.white54),
              const SizedBox(width: 8),
              Text(title, style: TextStyle(color: selected ? Colors.white : Colors.white54, fontWeight: FontWeight.bold, fontSize: 13)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMainContent() {
    return Column(
      children: [
        if (_showPostForm) _buildPostForm(),
        if (_selectedTab == 0) ...[
          _buildFilters(),
          const SizedBox(height: 16),
          _buildRequestsList(),
          const SizedBox(height: 16),
          _buildDonorsList(),
        ] else ...[
          _buildDonorRegistrationForm(),
          const SizedBox(height: 24),
          _buildDonorsList(), // Shows only current user's registration
        ],
      ],
    );
  }

  Widget _buildFilters() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.bgGlassMedium,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
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
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildCompactDropdown(
                  value: _selectedBloodType,
                  items: _bloodTypes,
                  icon: FeatherIcons.droplet,
                  onChanged: (val) => setState(() => _selectedBloodType = val!),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _buildCompactDropdown(
                  value: _selectedCity,
                  items: _bangladeshCities,
                  icon: FeatherIcons.mapPin,
                  onChanged: (val) {
                    setState(() => _selectedCity = val!);
                    _loadDonationRequests();
                    if (!_useGpsRadius) _loadDonors();
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Icon(FeatherIcons.target, size: 14, color: AppTheme.primaryColor),
              const SizedBox(width: 8),
              Expanded(
                child: SliderTheme(
                  data: SliderTheme.of(context).copyWith(
                    activeTrackColor: AppTheme.primaryColor,
                    thumbColor: AppTheme.primaryColor,
                    overlayColor: AppTheme.primaryColor.withOpacity(0.2),
                    trackHeight: 2,
                  ),
                  child: Slider(
                    value: _radius,
                    min: 1.0,
                    max: 50.0,
                    divisions: 49,
                    label: "${_radius.toInt()} km",
                    onChanged: (value) {
                      setState(() => _radius = value);
                      _loadDonationRequests();
                    },
                  ),
                ),
              ),
              Text("${_radius.toInt()} km", style: const TextStyle(color: Colors.white, fontSize: 12)),
            ],
          ),
          _buildGpsToggle(),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _loadDonors,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryColor.withOpacity(0.2),
                foregroundColor: AppTheme.primaryColor,
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: AppTheme.primaryColor.withOpacity(0.5))),
              ),
              child: const Text("Apply Filters"),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCompactDropdown({required String value, required List<String> items, required IconData icon, required Function(String?) onChanged}) {
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

  Widget _buildGpsToggle() {
    return GestureDetector(
      onTap: () async {
        final newVal = !_useGpsRadius;
        if (newVal) {
          final ok = await _ensureLocation();
          if (!ok) {
            if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Location permission required')));
            return;
          }
        }
        setState(() => _useGpsRadius = newVal);
        _loadDonors();
      },
      child: Row(
        children: [
          Checkbox(
            value: _useGpsRadius,
            activeColor: AppTheme.primaryColor,
            onChanged: (val) async {
              final newVal = val ?? false;
              if (newVal) {
                final ok = await _ensureLocation();
                if (!ok) {
                  if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Location permission required')));
                  return;
                }
              }
              setState(() => _useGpsRadius = newVal);
              _loadDonors();
            },
          ),
          const Text('Use GPS Location', style: TextStyle(color: Colors.white, fontSize: 12)),
        ],
      ),
    );
  }

  Widget _buildPostForm() {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.bgGlassMedium,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.primaryColor.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text("Request Blood", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 16),
          _buildCompactField("Patient Name", _nameController, FeatherIcons.user),
          const SizedBox(height: 12),
          _buildCompactField("Phone", _phoneController, FeatherIcons.phone),
          const SizedBox(height: 12),
          _buildCompactField("Hospital", _hospitalController, FeatherIcons.mapPin),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _isLoading ? null : _postRequest,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryColor,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
              child: _isLoading ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) : const Text("Post Request"),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDonorRegistrationForm() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.bgGlassMedium,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.accentColor.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text("Register as Donor", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 16),
          _buildCompactField("Full Name", _nameController, FeatherIcons.user),
          const SizedBox(height: 12),
          _buildCompactField("Phone", _phoneController, FeatherIcons.phone),
          const SizedBox(height: 12),
          _buildCompactField("Address", _hospitalController, FeatherIcons.mapPin),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildCompactDropdown(
                  value: _selectedBloodType,
                  items: _bloodTypes,
                  icon: FeatherIcons.droplet,
                  onChanged: (val) => setState(() => _selectedBloodType = val!),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _buildCompactDropdown(
                  value: _selectedCity,
                  items: _bangladeshCities,
                  icon: FeatherIcons.mapPin,
                  onChanged: (val) => setState(() => _selectedCity = val!),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _isLoading ? null : _registerAsDonor,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.accentColor,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
              child: _isLoading ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) : const Text("Register Now"),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCompactField(String hint, TextEditingController controller, IconData icon) {
    return TextField(
      controller: controller,
      style: const TextStyle(color: Colors.white, fontSize: 13),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(color: Colors.white.withOpacity(0.5)),
        prefixIcon: Icon(icon, size: 16, color: Colors.white54),
        filled: true,
        fillColor: Colors.black.withOpacity(0.2),
        contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 16),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
      ),
    );
  }

  Widget _buildRequestsList() {
    if (_loadingRequests) return const Center(child: CircularProgressIndicator());
    if (_donationRequests.isEmpty) return Center(child: Text("No requests found", style: TextStyle(color: Colors.white54)));
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.only(bottom: 12),
          child: Text("Recent Requests", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        ),
        ..._donationRequests.map((req) => _buildRequestCard(req)),
      ],
    );
  }

  Widget _buildDonorsList() {
    if (_loadingDonors) return const Center(child: CircularProgressIndicator());
    if (_donors.isEmpty) return Center(child: Text(_selectedTab == 0 ? "No donors found" : "You are not registered", style: TextStyle(color: Colors.white54)));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Text(_selectedTab == 0 ? "Available Donors" : "My Donor Profile", style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        ),
        ..._donors.map((donor) => _buildDonorCard(donor)),
      ],
    );
  }

  Widget _buildRequestCard(Map<String, dynamic> req) {
    return Container(
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
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppTheme.primaryColor.withOpacity(0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(req['bloodType'] ?? '?', style: TextStyle(color: AppTheme.primaryColor, fontWeight: FontWeight.bold, fontSize: 16)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(req['name'] ?? 'Unknown', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                Text("${req['hospital'] ?? ''}, ${req['city'] ?? ''}", style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 12)),
                Text(req['phone'] ?? '', style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 12)),
              ],
            ),
          ),
          if (req['userId'] != FirebaseAuth.instance.currentUser?.uid)
            IconButton(
              icon: Icon(FeatherIcons.messageCircle, color: AppTheme.primaryColor, size: 20),
              onPressed: () => _openChat(req['userId'], req['name'] ?? 'User'),
            ),
        ],
      ),
    );
  }

  Widget _buildDonorCard(Map<String, dynamic> donor) {
    return Container(
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
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppTheme.accentColor.withOpacity(0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(donor['bloodType'] ?? '?', style: TextStyle(color: AppTheme.accentColor, fontWeight: FontWeight.bold, fontSize: 16)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(donor['name'] ?? 'Unknown', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                Text("${donor['city'] ?? ''}", style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 12)),
                Text(donor['phone'] ?? '', style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 12)),
              ],
            ),
          ),
          if (_selectedTab == 0 && donor['userId'] != FirebaseAuth.instance.currentUser?.uid)
            IconButton(
              icon: Icon(FeatherIcons.messageCircle, color: AppTheme.accentColor, size: 20),
              onPressed: () => _openChat(donor['userId'], donor['name'] ?? 'User'),
            ),
        ],
      ),
    );
  }

  Widget _buildErrorWidget() {
    return Center(
      child: Column(
        children: [
          const Icon(FeatherIcons.alertTriangle, color: Colors.red, size: 40),
          const SizedBox(height: 16),
          Text(_errorMessage, style: const TextStyle(color: Colors.white), textAlign: TextAlign.center),
          const SizedBox(height: 16),
          ElevatedButton(onPressed: _initializeData, child: const Text("Retry")),
        ],
      ),
    );
  }

  // Logic methods (preserved)
  Future<bool> _ensureLocation() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) return false;
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) return false;
      }
      if (permission == LocationPermission.deniedForever) return false;
      _currentPosition = await Geolocator.getCurrentPosition();
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<void> _postRequest() async {
    final name = _nameController.text.trim();
    final phone = _phoneController.text.trim();
    final hospital = _hospitalController.text.trim();
    if (name.isEmpty || phone.isEmpty || hospital.isEmpty) return;

    setState(() => _isLoading = true);
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception('User not authenticated');
      await FirebaseFirestore.instance.collection('blood_requests').add({
        'userId': user.uid,
        'name': name,
        'phone': phone,
        'hospital': hospital,
        'bloodType': _selectedBloodType,
        'city': _selectedCity,
        'timestamp': FieldValue.serverTimestamp(),
        'status': 'active',
      });
      if (mounted) {
        _nameController.clear(); _phoneController.clear(); _hospitalController.clear();
        setState(() => _showPostForm = false);
        _loadDonationRequests();
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _registerAsDonor() async {
    final name = _nameController.text.trim();
    final phone = _phoneController.text.trim();
    final address = _hospitalController.text.trim();
    if (name.isEmpty || phone.isEmpty || address.isEmpty) return;

    setState(() => _isLoading = true);
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception('User not authenticated');
      double? lat, lng;
      if (_currentPosition != null) { lat = _currentPosition!.latitude; lng = _currentPosition!.longitude; }
      
      await FirebaseFirestore.instance.collection('blood_donors').add({
        'userId': user.uid,
        'name': name,
        'phone': phone,
        'address': address,
        'bloodType': _selectedBloodType,
        'city': _selectedCity,
        'timestamp': FieldValue.serverTimestamp(),
        'status': 'active',
        if (lat != null) 'latitude': lat,
        if (lng != null) 'longitude': lng,
      });
      if (mounted) {
        _nameController.clear(); _phoneController.clear(); _hospitalController.clear();
        _loadDonors();
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _handleSmsSending() async {
    try {
      final authService = Provider.of<AuthService>(context, listen: false);
      final user = authService.currentUser;
      
      String? phoneNumber;
      
      if (user != null) {
        final doc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
        if (doc.exists) {
          phoneNumber = doc.data()?['profile']?['phone'];
        }
      }

      if (phoneNumber == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Please login and add phone number to receive SMS results')),
          );
        }
        return;
      }

      phoneNumber = phoneNumber.replaceAll('tel:', '');

      final supabaseService = SupabasePlacesService();
      final success = await supabaseService.sendSmsResults(
        city: _selectedCity,
        area: 'All Areas',
        type: 'blood',
        userPhone: phoneNumber,
        bloodType: _selectedBloodType,
      );

      if (mounted) {
        if (success) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Results sent via SMS (Charge: 2.00 TK)')),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Failed to send SMS results')),
          );
        }
      }
    } catch (e) {
      print('SMS Error: $e');
    }
  }

  Future<void> _loadDonationRequests() async {
    setState(() => _loadingRequests = true);
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;
      final snapshot = await FirebaseFirestore.instance.collection('blood_requests')
          .orderBy('timestamp', descending: true).limit(50).get();
      
      final requests = snapshot.docs.map((doc) => doc.data()).toList();
      // Relaxed filtering: only filter by status and exclude current user
      final filtered = requests.where((req) {
        return req['status'] == 'active' && 
               req['userId'] != user.uid;
      }).toList();
      
      if (mounted) setState(() { _donationRequests = filtered; _loadingRequests = false; });
    } catch (e) {
      if (mounted) setState(() => _loadingRequests = false);
    }
  }

  Future<void> _loadDonors() async {
    setState(() => _loadingDonors = true);
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;
      
      // Ensure we have current position if GPS mode is enabled
      if (_useGpsRadius) {
        final locationOk = await _ensureLocation();
        if (!locationOk) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Unable to get GPS location. Using city filter instead.')),
            );
            setState(() => _useGpsRadius = false);
          }
        }
      }
      
      final snapshot = await FirebaseFirestore.instance.collection('blood_donors')
          .orderBy('timestamp', descending: true).limit(50).get();
      
      final donors = snapshot.docs.map((doc) => doc.data()).toList();
      final filtered = donors.where((d) {
        if (_selectedTab == 0) {
          // Relaxed filtering: only filter by status and exclude current user
          return d['status'] == 'active' && d['userId'] != user.uid;
        } else {
          return d['userId'] == user.uid && d['status'] == 'active';
        }
      }).toList();
      
      if (mounted) {
        setState(() { _donors = filtered; _loadingDonors = false; });
        
        // Send SMS if toggle is enabled and we have results
        if (_sendSmsResults && filtered.isNotEmpty && _selectedTab == 0) {
          await _handleSmsSending();
        }
      }
    } catch (e) {
      if (mounted) setState(() => _loadingDonors = false);
    }
  }

  void _openChat(String peerId, String peerName) {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null || currentUser.uid == peerId) return;
    Navigator.push(context, MaterialPageRoute(builder: (_) => ChatThreadScreen(
      currentUserId: currentUser.uid, peerId: peerId, peerName: peerName, category: 'blood'
    )));
  }
}