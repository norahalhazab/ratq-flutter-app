import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:math';
import '../utils/theme.dart';
import '../utils/constants.dart';
import '../widgets/hospital_card.dart';
import 'package:flutter_feather_icons/flutter_feather_icons.dart';
import '../config/api_config.dart';
import 'package:provider/provider.dart';
import '../services/auth_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/supabase_places_service.dart';

class HospitalScreen extends StatefulWidget {
  const HospitalScreen({super.key});

  @override
  State<HospitalScreen> createState() => _HospitalScreenState();
}

class _HospitalScreenState extends State<HospitalScreen> {
  List<Map<String, dynamic>> _hospitals = [];
  bool _isLoading = false;
  String _statusMessage = '';
  bool _sendSmsResults = false;

  // Caching mechanism for performance optimization
  Map<String, dynamic>? _cachedLocation;
  List<Map<String, dynamic>>? _cachedHospitals;
  DateTime? _locationCacheTime;
  DateTime? _hospitalsCacheTime;
  static const Duration _locationCacheDuration = Duration(minutes: 30);
  static const Duration _hospitalsCacheDuration = Duration(minutes: 10);

  // Cache management methods
  bool _isLocationCacheValid() {
    if (_cachedLocation == null || _locationCacheTime == null) return false;
    return DateTime.now().difference(_locationCacheTime!) < _locationCacheDuration;
  }

  bool _isHospitalsCacheValid(double lat, double lon) {
    if (_cachedHospitals == null || _hospitalsCacheTime == null) return false;
    if (DateTime.now().difference(_hospitalsCacheTime!) > _hospitalsCacheDuration) return false;

    // Check if location has changed significantly (>1km)
    final cachedLat = _cachedLocation?['lat'] ?? 0.0;
    final cachedLon = _cachedLocation?['lon'] ?? 0.0;
    final distance = _haversineDistance(lat, lon, cachedLat, cachedLon);
    return distance < 1000; // 1km threshold
  }

  void _updateLocationCache(Map<String, dynamic> locationData) {
    _cachedLocation = locationData;
    _locationCacheTime = DateTime.now();
  }

  void _updateHospitalsCache(List<Map<String, dynamic>> hospitals) {
    _cachedHospitals = hospitals;
    _hospitalsCacheTime = DateTime.now();
  }
  
  // Helper function to compute distance using Haversine formula
  double _haversineDistance(double lat1, double lon1, double lat2, double lon2) {
    const double R = 6371e3; // Earth's radius in meters
    final double dLat = _toRadians(lat2 - lat1);
    final double dLon = _toRadians(lon2 - lon1);
    final double a = sin(dLat / 2) * sin(dLat / 2) +
        cos(_toRadians(lat1)) * cos(_toRadians(lat2)) * sin(dLon / 2) * sin(dLon / 2);
    return R * 2 * atan2(sqrt(a), sqrt(1 - a));
  }
  
  double _toRadians(double degrees) {
    return degrees * pi / 180;
  }

  // Get coordinates using both live GPS location and IP geolocation (optimized with caching)
  Future<Map<String, dynamic>> _getCoordinates() async {
    // Check cache first
    if (_isLocationCacheValid()) {
      print('Using cached location data');
      return _cachedLocation!;
    }

    Map<String, double>? gpsLocation;
    Map<String, double>? ipLocation;
    
    // Try GPS location first (most accurate) with reduced timeout
    try {
      print('Trying GPS location...');
        final position = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 5), // Reduced from 15 seconds
      );
      gpsLocation = {
        'lat': position.latitude,
        'lon': position.longitude,
      };
      print('GPS location successful: ${position.latitude}, ${position.longitude}');
    } catch (e) {
      print('GPS location failed: $e');
    }

    // Try IP geolocation services in parallel for faster results
    try {
      print('Trying IP geolocation services in parallel...');
    final ipServices = [
      'https://ipapi.co/json/',
      'https://ipinfo.io/json',
        'https://api.myip.com/api/v1/ip',
    ];

      // Create futures for all IP services
      final ipFutures = ipServices.map((service) async {
      try {
        print('Trying IP geolocation with: $service');
        final response = await http.get(
          Uri.parse(service),
          headers: {
            'Accept': 'application/json',
            'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36',
          },
          ).timeout(const Duration(seconds: 3)); // Reduced from 8 seconds
        
        if (response.statusCode == 200) {
          final data = json.decode(response.body);
          
          // Handle different API response formats
          double? lat, lon;
          
          if (service.contains('ipapi.co')) {
            lat = (data['latitude'] as num?)?.toDouble();
            lon = (data['longitude'] as num?)?.toDouble();
          } else if (service.contains('ipinfo.io')) {
            final loc = data['loc']?.split(',');
            if (loc != null && loc.length == 2) {
              lat = double.tryParse(loc[0]);
              lon = double.tryParse(loc[1]);
            }
            } else if (service.contains('myip.com')) {
              lat = (data['latitude'] as num?)?.toDouble();
              lon = (data['longitude'] as num?)?.toDouble();
          }
          
            if (lat != null && lon != null) {
              print('IP geolocation successful with $service: $lat, $lon');
              return {'lat': lat, 'lon': lon};
            }
          }
        } catch (e) {
          print('IP geolocation failed with $service: $e');
        }
        return null;
      });

      // Wait for first successful result with timeout
      final results = await Future.wait(ipFutures).timeout(const Duration(seconds: 4));

      // Find first successful result
      for (final result in results) {
        if (result != null) {
          final lat = result['lat'];
          final lon = result['lon'];
          if (lat != null && lon != null) {
              ipLocation = {'lat': lat, 'lon': lon};
              break;
          }
      }
    }
    } catch (e) {
      print('IP geolocation completely failed: $e');
    }

    // Determine which location to use
    Map<String, dynamic> locationData;
    if (gpsLocation != null) {
      // GPS is available - use it as primary, IP as backup info
      locationData = {
        'lat': gpsLocation['lat']!,
        'lon': gpsLocation['lon']!,
        'source': 'GPS',
        'accuracy': 'High',
        'ip_lat': ipLocation?['lat'],
        'ip_lon': ipLocation?['lon'],
        'has_backup': ipLocation != null,
      };
    } else if (ipLocation != null) {
      // Only IP location available
      locationData = {
        'lat': ipLocation['lat']!,
        'lon': ipLocation['lon']!,
        'source': 'IP',
        'accuracy': 'Approximate',
        'ip_lat': ipLocation['lat'],
        'ip_lon': ipLocation['lon'],
        'has_backup': false,
      };
    } else {
      // Fallback to default location
    print('Using default location');
      locationData = {
      'lat': 40.7128, // New York City coordinates as fallback
      'lon': -74.0060,
        'source': 'Default',
        'accuracy': 'Unknown',
        'ip_lat': null,
        'ip_lon': null,
        'has_backup': false,
    };
    }

    // Cache the location data
    _updateLocationCache(locationData);
    return locationData;
      }

  // Fallback sample hospitals
  List<Map<String, dynamic>> _getSampleHospitals(double userLat, double userLon) {
    // Generate sample hospitals around the user's location with basic info only
    final hospitals = [
      {
        'tags': {
          'name': 'City General Hospital', 
        },
        'distance': 1200.0,
        'center': {'lat': userLat + 0.01, 'lon': userLon + 0.01},
      },
      {
        'tags': {
          'name': 'Community Medical Center', 
        },
        'distance': 2500.0,
        'center': {'lat': userLat - 0.008, 'lon': userLon + 0.015},
      },
      {
        'tags': {
          'name': 'University Hospital', 
        },
        'distance': 3800.0,
        'center': {'lat': userLat + 0.015, 'lon': userLon - 0.012},
      },
      {
        'tags': {
          'name': 'Riverside Health Clinic', 
        },
        'distance': 4200.0,
        'center': {'lat': userLat - 0.012, 'lon': userLon - 0.008},
      },
      {
        'tags': {
          'name': 'Emergency Care Center', 
        },
        'distance': 5500.0,
        'center': {'lat': userLat + 0.018, 'lon': userLon + 0.020},
      },
    ];
    
    return hospitals;
  }

  // Simple hospital fetching - include multiple healthcare tags and no artificial limit
  Future<List<Map<String, dynamic>>> _fetchHospitalsRadius(
      double lat, double lon, int radius) async {
    // Include both classic and newer OSM healthcare tagging schemes
    final query = '[out:json];('
        'node(around:$radius,$lat,$lon)["amenity"~"hospital|clinic|health_centre"];'
        'way(around:$radius,$lat,$lon)["amenity"~"hospital|clinic|health_centre"];'
        'relation(around:$radius,$lat,$lon)["amenity"~"hospital|clinic|health_centre"];'
        'node(around:$radius,$lat,$lon)["healthcare"~"hospital|clinic|centre"];'
        'way(around:$radius,$lat,$lon)["healthcare"~"hospital|clinic|centre"];'
        'relation(around:$radius,$lat,$lon)["healthcare"~"hospital|clinic|centre"];'
        ');out center;';
    final url = 'https://overpass-api.de/api/interpreter?data=${Uri.encodeComponent(query)}';
    
    try {
      print('Fetching hospitals with radius ${radius}m...');
      final response = await http.get(
        Uri.parse(url),
        headers: {
          'Accept': 'application/json',
          'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36',
        },
      ).timeout(const Duration(seconds: 15)); // Reduced timeout for faster loading
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final hospitals = (data['elements'] as List).cast<Map<String, dynamic>>();

        // Only keep basic hospital information (preserve id/type/center; tags only name for UI)
        final basicHospitals = hospitals.map((hospital) {
          return {
            ...hospital,
            'tags': {
              'name': hospital['tags']?['name'] ?? 'Unnamed Hospital',
            }
          };
        }).toList();

        print('Found ${basicHospitals.length} hospitals with radius ${radius}m');
        return basicHospitals;
      } else {
        print('Overpass API error: ${response.statusCode}');
        return [];
      }
    } catch (e) {
      print('Overpass API request failed: $e');
      return [];
    }
  }

  // Google Places: single radius search (for parallel execution)
  Future<List<Map<String, dynamic>>> _fetchHospitalsGoogleSingleRadius(
      double lat, double lon, int radius) async {
    final List<Map<String, dynamic>> results = [];
    const apiKey = ApiConfig.googlePlacesApiKey;
      final url = Uri.parse(
        '${ApiConfig.googlePlacesBaseUrl}/textsearch/json?'
        'query=hospital'
        '&location=$lat,$lon'
        '&radius=$radius'
        '&type=hospital'
        '&key=$apiKey',
      );

      try {
      final response = await http.get(url).timeout(const Duration(seconds: 15)); // Reduced timeout
      if (response.statusCode != 200) return results;
        final data = json.decode(response.body);
      if (data['status'] != 'OK') return results;

      final List apiResults = (data['results'] as List);

      for (final raw in apiResults) {
          final geometry = raw['geometry'] as Map<String, dynamic>?;
          final loc = geometry != null ? geometry['location'] as Map<String, dynamic>? : null;
          final pLat = (loc != null ? (loc['lat'] as num?) : null)?.toDouble() ?? 0.0;
          final pLon = (loc != null ? (loc['lng'] as num?) : null)?.toDouble() ?? 0.0;

          final distanceMeters = _haversineDistance(lat, lon, pLat, pLon);

        results.add({
            'type': 'google_place',
            'place_id': raw['place_id'],
            'center': {'lat': pLat, 'lon': pLon},
            'distance': distanceMeters,
            'tags': {
              'name': raw['name'] ?? 'Unnamed Hospital',
            },
          });
        }
      } catch (e) {
      print('Google Places fetch error for radius $radius: $e');
    }

    return results;
  }



  // Extract deduplication logic to separate method
  List<Map<String, dynamic>> _deduplicateHospitals(List<Map<String, dynamic>> hospitals) {
    final Map<String, Map<String, dynamic>> uniqueByKey = {};

    for (final h in hospitals) {
      final dynamic type = h['type'];
      final dynamic id = h['id'];
      final dynamic placeId = h['place_id'];
      final center = h['center'] ?? (h['type'] == 'node' ? h : null) ?? {};
      final double cLat = (center['lat'] as num?)?.toDouble() ?? 0.0;
      final double cLon = (center['lon'] as num?)?.toDouble() ?? 0.0;
      final String name = h['tags']?['name'] ?? 'Unnamed Hospital';

      String key;
      if (id != null && type is String && (type == 'node' || type == 'way' || type == 'relation')) {
        key = 'osm:$type:$id';
      } else if (placeId is String && placeId.isNotEmpty) {
        key = 'g:$placeId';
      } else {
        // Fallback: coordinate bucket + name
        final String latBucket = (cLat.toStringAsFixed(5));
        final String lonBucket = (cLon.toStringAsFixed(5));
        key = 'geo:$latBucket,$lonBucket:$name';
      }

      // Keep the closest distance if duplicates exist
      if (!uniqueByKey.containsKey(key)) {
        uniqueByKey[key] = h;
      } else {
        final existing = uniqueByKey[key]!;
        final double existingDist = (existing['distance'] as num?)?.toDouble() ?? double.infinity;
        final double newDist = (h['distance'] as num?)?.toDouble() ?? double.infinity;
        if (newDist < existingDist) {
          uniqueByKey[key] = h;
        }
      }
    }

    return uniqueByKey.values.toList();
  }

  Future<void> _findHospitals() async {
    setState(() {
      _isLoading = true;
      _statusMessage = 'Getting your location...';
      _hospitals.clear();
    });
    
    try {
      final locationData = await _getCoordinates();
      final coords = {'lat': locationData['lat'], 'lon': locationData['lon']};
      
      // Update status message based on location source
      String statusMsg = 'Searching for nearby hospitals...';
      if (locationData['source'] == 'GPS') {
        statusMsg = 'Using GPS location (high accuracy) - searching for hospitals...';
      } else if (locationData['source'] == 'IP') {
        statusMsg = 'Using IP location (approximate) - searching for hospitals...';
      } else {
        statusMsg = 'Using default location - searching for hospitals...';
      }
      
      setState(() {
        _statusMessage = statusMsg;
      });
      
      // Start progressive hospital fetching
      await _fetchHospitalsProgressive(coords['lat']!, coords['lon']!, locationData);

    } catch (e) {
      print('Error in _findHospitals: $e');
      setState(() {
        _statusMessage = 'Unable to find hospitals. Please try again.';
        _isLoading = false;
      });
    }
  }

  // Progressive hospital fetching - shows results as they arrive
  Future<void> _fetchHospitalsProgressive(double lat, double lon, Map<String, dynamic> locationData) async {
    // Check cache first
    if (_isHospitalsCacheValid(lat, lon)) {
      print('Using cached hospital data');
      final processedHospitals = _processHospitals(_cachedHospitals!, lat, lon);
      setState(() {
        _hospitals = processedHospitals.take(50).toList();
        _statusMessage = 'Found ${processedHospitals.length} hospitals (from cache)';
        _isLoading = false;
      });
      return;
    }

    final List<Map<String, dynamic>> allHospitals = [];

    // Start with fast local search (small radius) - OpenStreetMap only
    setState(() {
      _statusMessage = 'Searching nearby hospitals...';
    });

    // Use only OpenStreetMap (no API key required, more reliable)
    final fastFutures = [
      _fetchHospitalsRadius(lat, lon, 5000),
    ];

    try {
      final fastResults = await Future.wait(fastFutures, eagerError: false);

      for (final result in fastResults) {
        allHospitals.addAll(result);
      }

      // Show initial results immediately if we have any
      if (allHospitals.isNotEmpty) {
        final processedHospitals = _processHospitals(allHospitals, lat, lon);
        setState(() {
          _hospitals = processedHospitals.take(20).toList(); // Show top 20
          _statusMessage = 'Found ${processedHospitals.length} hospitals nearby (showing closest 20)...';
          _isLoading = false; // Allow user interaction while we continue searching
        });
      }
    } catch (e) {
      print('Error in fast hospital search: $e');
    }

    // Continue with medium radius search in background
    setState(() {
      _statusMessage = 'Expanding search area...';
    });

    final mediumFutures = [
      _fetchHospitalsRadius(lat, lon, 10000),
    ];

    try {
      final mediumResults = await Future.wait(mediumFutures, eagerError: false);

      for (final result in mediumResults) {
        allHospitals.addAll(result);
      }

      // Update results if we have more
      if (allHospitals.length > _hospitals.length) {
        final processedHospitals = _processHospitals(allHospitals, lat, lon);
        setState(() {
          _hospitals = processedHospitals.take(30).toList(); // Show top 30
          _statusMessage = 'Found ${processedHospitals.length} hospitals (showing closest 30)...';
        });
      }
    } catch (e) {
      print('Error in medium hospital search: $e');
    }

    // Final search with larger radius (only if we still have few results)
    if (allHospitals.length < 15) {
      setState(() {
        _statusMessage = 'Searching wider area...';
      });

      final largeFutures = [
        _fetchHospitalsRadius(lat, lon, 20000),
      ];

      try {
        final largeResults = await Future.wait(largeFutures, eagerError: false);

        for (final result in largeResults) {
          allHospitals.addAll(result);
        }
      } catch (e) {
        print('Error in large hospital search: $e');
      }
    }

    // Final processing and update
    final processedHospitals = _processHospitals(allHospitals, lat, lon);

    // Send SMS if toggle is enabled
    if (_sendSmsResults && processedHospitals.isNotEmpty) {
      await _handleSmsSending(lat, lon);
    }

    if (processedHospitals.isEmpty) {
        // Fallback to sample hospitals if API fails
        print('No hospitals found via OpenStreetMap API, using sample data');
      final sampleHospitals = _getSampleHospitals(lat, lon);
        setState(() {
          _hospitals = sampleHospitals;
          _statusMessage = 'Showing sample hospitals (OpenStreetMap data unavailable)';
        });
        return;
      }

      // Create final status message with location info
      String finalStatus = '';
      if (locationData['source'] == 'GPS') {
        finalStatus = 'Found ${processedHospitals.length} hospitals using GPS location (high accuracy)';
        if (locationData['has_backup'] == true) {
          finalStatus += ' • IP location also available as backup';
        }
      } else if (locationData['source'] == 'IP') {
        finalStatus = 'Found ${processedHospitals.length} hospitals using IP location (approximate)';
      } else {
        finalStatus = 'Found ${processedHospitals.length} hospitals using default location';
      }

    // Cache the hospital data for future use
    _updateHospitalsCache(processedHospitals);

      setState(() {
      _hospitals = processedHospitals.take(50).toList(); // Limit to top 50 for performance
        _statusMessage = finalStatus;
        _isLoading = false;
      });
    }

  Future<void> _handleSmsSending(double lat, double lon) async {
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
        city: 'Current Location',
        area: 'Nearby',
        type: 'hospital',
        userPhone: phoneNumber,
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

  // Helper method to process hospitals (calculate distances, sort, etc.)
  List<Map<String, dynamic>> _processHospitals(List<Map<String, dynamic>> hospitals, double userLat, double userLon) {
    final deduplicated = _deduplicateHospitals(hospitals);

    final processedHospitals = deduplicated.map((hospital) {
      final centerRaw = hospital['type'] == 'node' ? hospital : (hospital['center'] ?? {});
      final cLat = (centerRaw['lat'] as num?)?.toDouble() ?? 0.0;
      final cLon = (centerRaw['lon'] as num?)?.toDouble() ?? 0.0;
      final distance = (hospital['distance'] is num)
          ? (hospital['distance'] as num).toDouble()
          : _haversineDistance(userLat, userLon, cLat, cLon);
      return {
        ...hospital,
        'distance': distance,
        'center': {'lat': cLat, 'lon': cLon},
      };
    }).toList();

    processedHospitals.sort((a, b) => a['distance'].compareTo(b['distance']));
    return processedHospitals;
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
            leading: IconButton(icon: const Icon(FeatherIcons.arrowLeft, color: Colors.white), onPressed: () => Navigator.pop(context)),
            actions: [
              IconButton(icon: const Icon(FeatherIcons.logOut, color: Colors.white), onPressed: () => Navigator.of(context).pushReplacementNamed(AppConstants.routeLogin)),
            ],
            flexibleSpace: FlexibleSpaceBar(
              title: const Text('Hospital Finder', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
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
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppTheme.bgGlassMedium,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.white.withOpacity(0.1)),
                    ),
                    child: SwitchListTile(
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
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _isLoading ? null : _findHospitals,
                      icon: _isLoading ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Icon(FeatherIcons.search, size: 16),
                      label: Text(_isLoading ? 'Finding...' : 'Find Hospitals Near Me'),
                      style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryColor, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 14)),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(color: AppTheme.bgGlassMedium, borderRadius: BorderRadius.circular(12)),
                    child: const Text('Uses GPS (high accuracy) and IP location (backup) to find nearby hospitals', style: TextStyle(color: Colors.white70, fontSize: 12), textAlign: TextAlign.center),
                  ),
                  const SizedBox(height: 12),
                  if (_statusMessage.isNotEmpty)
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(color: AppTheme.bgGlassMedium, borderRadius: BorderRadius.circular(12)),
                      child: Text(_statusMessage, style: const TextStyle(color: Colors.white, fontSize: 14), textAlign: TextAlign.center),
                    ),
                  const SizedBox(height: 12),
                  if (_hospitals.isNotEmpty || _isLoading)
                    ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: _hospitals.length,
                      itemBuilder: (context, index) => HospitalCard(hospital: _hospitals[index], parentContext: context),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}