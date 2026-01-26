import 'package:flutter/material.dart';
import '../widgets/app_drawer.dart';
import '../utils/constants.dart';
import '../utils/app_colors.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';

class PharmacyScreen extends StatefulWidget {
  const PharmacyScreen({super.key});

  @override
  State<PharmacyScreen> createState() => _PharmacyScreenState();
}

class _PharmacyScreenState extends State<PharmacyScreen> {
  final TextEditingController _searchController = TextEditingController();
  List<Map<String, dynamic>> _pharmacies = [];
  List<Map<String, dynamic>> _filteredPharmacies = [];
  bool _isLoading = true;
  Position? _currentPosition;
  
  @override
  void initState() {
    super.initState();
    _loadPharmacies();
    _getCurrentLocation();
  }
  
  Future<void> _getCurrentLocation() async {
    final status = await Permission.location.request();
    
    if (status.isGranted) {
      try {
        final position = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high,
        );
        
        setState(() {
          _currentPosition = position;
        });
        
        // Sort pharmacies by distance if we have location
        if (_currentPosition != null) {
          _sortPharmaciesByDistance();
        }
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error getting location: ${e.toString()}')),
        );
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Location permission denied')),
      );
    }
  }
  
  void _sortPharmaciesByDistance() {
    if (_currentPosition == null) return;
    
    setState(() {
      _pharmacies.sort((a, b) {
        final distanceA = Geolocator.distanceBetween(
          _currentPosition!.latitude,
          _currentPosition!.longitude,
          a['latitude'] as double,
          a['longitude'] as double,
        );
        
        final distanceB = Geolocator.distanceBetween(
          _currentPosition!.latitude,
          _currentPosition!.longitude,
          b['latitude'] as double,
          b['longitude'] as double,
        );
        
        return distanceA.compareTo(distanceB);
      });
      
      _filteredPharmacies = List.from(_pharmacies);
    });
  }

  Future<void> _loadPharmacies() async {
    setState(() {
      _isLoading = true;
    });
    
    try {
      // In a real app, this would load from Firestore or an API
      // For now, we'll use sample data
      _pharmacies = [
        {
          'id': '1',
          'name': 'MediCare Pharmacy',
          'address': '123 Health Street, Downtown',
          'phone': '+1 (555) 123-4567',
          'hours': '9:00 AM - 9:00 PM',
          'latitude': 23.8103,
          'longitude': 90.4125,
          'services': ['Prescription Filling', '24/7 Service', 'Home Delivery'],
          'image': 'assets/images/pharmacy1.jpg',
        },
        {
          'id': '2',
          'name': 'Community Drugstore',
          'address': '456 Wellness Avenue, Midtown',
          'phone': '+1 (555) 987-6543',
          'hours': '8:00 AM - 10:00 PM',
          'latitude': 23.8003,
          'longitude': 90.4025,
          'services': ['Prescription Filling', 'Vaccination', 'Health Consultation'],
          'image': 'assets/images/pharmacy2.jpg',
        },
        {
          'id': '3',
          'name': 'QuickMeds Pharmacy',
          'address': '789 Remedy Road, Uptown',
          'phone': '+1 (555) 456-7890',
          'hours': '24 Hours',
          'latitude': 23.7903,
          'longitude': 90.3925,
          'services': ['Prescription Filling', 'Drive-through', 'Health Screening'],
          'image': 'assets/images/pharmacy3.jpg',
        },
        {
          'id': '4',
          'name': 'HealthPlus Pharmacy',
          'address': '321 Cure Street, Riverside',
          'phone': '+1 (555) 789-0123',
          'hours': '8:30 AM - 8:30 PM',
          'latitude': 23.8203,
          'longitude': 90.4225,
          'services': ['Prescription Filling', 'Compounding', 'Medical Equipment'],
          'image': 'assets/images/pharmacy4.jpg',
        },
      ];
      
      _filteredPharmacies = List.from(_pharmacies);
      
      // If we already have location, sort by distance
      if (_currentPosition != null) {
        _sortPharmaciesByDistance();
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error loading pharmacies: ${e.toString()}')),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }
  
  void _filterPharmacies(String query) {
    setState(() {
      if (query.isEmpty) {
        _filteredPharmacies = List.from(_pharmacies);
      } else {
        _filteredPharmacies = _pharmacies
            .where((pharmacy) =>
                pharmacy['name'].toLowerCase().contains(query.toLowerCase()) ||
                pharmacy['services'].any((service) => 
                    service.toLowerCase().contains(query.toLowerCase())))
            .toList();
      }
    });
  }
  
  Future<void> _launchMaps(double latitude, double longitude, String name) async {
    final url = 'https://www.google.com/maps/search/?api=1&query=$latitude,$longitude';
    final uri = Uri.parse(url);
    
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not launch maps')),
      );
    }
  }
  
  Future<void> _launchPhone(String phoneNumber) async {
    final url = 'tel:$phoneNumber';
    final uri = Uri.parse(url);
    
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not launch phone app')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Nearby Pharmacies'),
        backgroundColor: AppColors.primaryColor,
      ),
      drawer: const AppDrawer(),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                labelText: 'Search pharmacies',
                hintText: 'Enter pharmacy name or service',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              onChanged: _filterPharmacies,
            ),
          ),
          if (_currentPosition == null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: ElevatedButton.icon(
                icon: const Icon(Icons.location_on),
                label: const Text('Get Current Location'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.accentColor,
                  minimumSize: const Size(double.infinity, 40),
                ),
                onPressed: _getCurrentLocation,
              ),
            ),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _filteredPharmacies.isEmpty
                    ? const Center(child: Text('No pharmacies found'))
                    : ListView.builder(
                        padding: const EdgeInsets.all(8.0),
                        itemCount: _filteredPharmacies.length,
                        itemBuilder: (context, index) {
                          final pharmacy = _filteredPharmacies[index];
                          
                          return Card(
                            margin: const EdgeInsets.only(bottom: 16.0),
                            elevation: 3,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Container(
                                  height: 120,
                                  width: double.infinity,
                                  color: Colors.grey[300],
                                  child: const Center(
                                    child: Icon(
                                      Icons.local_pharmacy,
                                      size: 50,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                                Padding(
                                  padding: const EdgeInsets.all(16.0),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        pharmacy['name'],
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 18,
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                      Row(
                                        children: [
                                          Icon(
                                            Icons.access_time,
                                            size: 16,
                                            color: Colors.grey[700],
                                          ),
                                          const SizedBox(width: 4),
                                          Text(
                                            pharmacy['hours'],
                                            style: TextStyle(
                                              color: Colors.grey[700],
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 8),
                                      Row(
                                        children: [
                                          Icon(
                                            Icons.location_on,
                                            size: 16,
                                            color: Colors.grey[700],
                                          ),
                                          const SizedBox(width: 4),
                                          Expanded(
                                            child: Text(
                                              pharmacy['address'],
                                              style: TextStyle(
                                                color: Colors.grey[700],
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 8),
                                      Row(
                                        children: [
                                          Icon(
                                            Icons.phone,
                                            size: 16,
                                            color: Colors.grey[700],
                                          ),
                                          const SizedBox(width: 4),
                                          Text(
                                            pharmacy['phone'],
                                            style: TextStyle(
                                              color: Colors.grey[700],
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 12),
                                      const Text(
                                        'Services:',
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Wrap(
                                        spacing: 8,
                                        runSpacing: 8,
                                        children: (pharmacy['services'] as List<dynamic>)
                                            .map((service) => Chip(
                                                  label: Text(
                                                    service,
                                                    style: const TextStyle(fontSize: 12),
                                                  ),
                                                  backgroundColor: AppColors.primaryColor.withOpacity(0.1),
                                                ))
                                            .toList(),
                                      ),
                                      const SizedBox(height: 16),
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                                        children: [
                                          Expanded(
                                            child: OutlinedButton.icon(
                                              icon: const Icon(Icons.phone),
                                              label: const Text('Call'),
                                              onPressed: () => _launchPhone(pharmacy['phone']),
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          Expanded(
                                            child: ElevatedButton.icon(
                                              icon: const Icon(Icons.directions),
                                              label: const Text('Directions'),
                                              style: ElevatedButton.styleFrom(
                                                backgroundColor: AppColors.accentColor,
                                              ),
                                              onPressed: () => _launchMaps(
                                                pharmacy['latitude'],
                                                pharmacy['longitude'],
                                                pharmacy['name'],
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }
} 