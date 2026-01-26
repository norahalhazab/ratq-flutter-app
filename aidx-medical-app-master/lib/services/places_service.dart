import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:geolocator/geolocator.dart';
import '../config/api_config.dart';

class PlacesService {

  /// Search for doctors by specialty and location
  Future<List<Map<String, dynamic>>> searchDoctors({
    required Position location,
    required String specialty,
    required double radius,
    String? city,
  }) async {
    try {
      // Use real Google Places API
      final query = city != null && city.isNotEmpty
          ? '$specialty doctor in $city, Bangladesh'
          : '$specialty doctor in Bangladesh';
      final results = await _searchPlacesReal(
        location: location,
        query: query,
        radius: radius,
        type: 'doctor',
      );
      if (results.isEmpty) {
        return _getSampleDoctors(specialty, location, radius);
      }
      // Enhance results with additional details
      final enhancedResults = await Future.wait(
        results.map((place) => _enhanceDoctorData(place, specialty)).toList(),
      );
      
      return enhancedResults;
    } catch (e) {
      print('Error searching doctors: $e');
      // Fallback to sample data if API fails
      return _getSampleDoctors(specialty, location, radius);
    }
  }

  /// Search for pharmacies by location
  Future<List<Map<String, dynamic>>> searchPharmacies({
    required Position location,
    required double radius,
    String? city,
  }) async {
    try {
      // Use real Google Places API
      final query = city != null ? 'pharmacy in $city, Bangladesh' : 'pharmacy in Bangladesh';
      final results = await _searchPlacesReal(
        location: location,
        query: query,
        radius: radius,
        type: 'pharmacy',
      );
      
      // Enhance results with additional details
      final enhancedResults = await Future.wait(
        results.map((place) => _enhancePharmacyData(place)).toList(),
      );
      
      return enhancedResults;
    } catch (e) {
      print('Error searching pharmacies: $e');
      // Fallback to sample data if API fails
      return _getSamplePharmacies(location, radius, city);
    }
  }

  /// Get sample doctor data
  List<Map<String, dynamic>> _getSampleDoctors(String specialty, Position location, double radius) {
    final baseLat = location.latitude;
    final baseLng = location.longitude;
    
    // Different doctors for each specialty
    final Map<String, List<Map<String, dynamic>>> specialtyDoctors = {
      'orthopedic': [
        {
          'name': 'Dr. Ahmed Rahman',
          'specialty': 'Orthopedic',
          'address': '123 Bone & Joint Center, Dhaka',
          'phone': '+880 1711-123456',
          'rating': 4.5,
          'distance': (radius * 0.3).toStringAsFixed(1),
          'latitude': baseLat + 0.001,
          'longitude': baseLng + 0.001,
          'image': 'assets/images/doctor1.jpg',
          'experience': '15 years',
          'qualifications': 'MBBS, MS (Ortho), FRCS',
          'consultation_fee': '৳800',
          'available': true,
          'place_id': 'sample_ortho_1',
        },
        {
          'name': 'Dr. Fatima Khan',
          'specialty': 'Orthopedic',
          'address': '456 Joint Care Hospital, Dhaka',
          'phone': '+880 1811-234567',
          'rating': 4.8,
          'distance': (radius * 0.6).toStringAsFixed(1),
          'latitude': baseLat + 0.002,
          'longitude': baseLng + 0.002,
          'image': 'assets/images/doctor2.jpg',
          'experience': '12 years',
          'qualifications': 'MBBS, FCPS (Ortho)',
          'consultation_fee': '৳700',
          'available': true,
          'place_id': 'sample_ortho_2',
        },
      ],
      'gynecologist': [
        {
          'name': 'Dr. Ayesha Begum',
          'specialty': 'Gynecologist',
          'address': '321 Women\'s Health Center, Dhaka',
          'phone': '+880 1611-456789',
          'rating': 4.7,
          'distance': (radius * 0.4).toStringAsFixed(1),
          'latitude': baseLat + 0.004,
          'longitude': baseLng + 0.004,
          'image': 'assets/images/doctor3.jpg',
          'experience': '20 years',
          'qualifications': 'MBBS, FCPS (Obs & Gynae)',
          'consultation_fee': '৳900',
          'available': true,
          'place_id': 'sample_gynae_1',
        },
        {
          'name': 'Dr. Nasreen Akter',
          'specialty': 'Gynecologist',
          'address': '654 Maternal Care Hospital, Dhaka',
          'phone': '+880 1511-567890',
          'rating': 4.3,
          'distance': (radius * 0.7).toStringAsFixed(1),
          'latitude': baseLat + 0.005,
          'longitude': baseLng + 0.005,
          'image': 'assets/images/doctor4.jpg',
          'experience': '10 years',
          'qualifications': 'MBBS, MS (Obs & Gynae)',
          'consultation_fee': '৳750',
          'available': true,
          'place_id': 'sample_gynae_2',
        },
      ],
      'cardiologist': [
        {
          'name': 'Dr. Hasan Mahmud',
          'specialty': 'Cardiologist',
          'address': '123 Heart Care Center, Dhaka',
          'phone': '+880 1711-111111',
          'rating': 4.9,
          'distance': (radius * 0.2).toStringAsFixed(1),
          'latitude': baseLat + 0.007,
          'longitude': baseLng + 0.007,
          'image': 'assets/images/doctor1.jpg',
          'experience': '18 years',
          'qualifications': 'MBBS, MD (Cardiology), FRCP',
          'consultation_fee': '৳1200',
          'available': true,
          'place_id': 'sample_cardio_1',
        },
        {
          'name': 'Dr. Kamal Hossain',
          'specialty': 'Cardiologist',
          'address': '456 Cardiac Hospital, Dhaka',
          'phone': '+880 1811-222222',
          'rating': 4.4,
          'distance': (radius * 0.5).toStringAsFixed(1),
          'latitude': baseLat + 0.008,
          'longitude': baseLng + 0.008,
          'image': 'assets/images/doctor2.jpg',
          'experience': '12 years',
          'qualifications': 'MBBS, FCPS (Cardiology)',
          'consultation_fee': '৳1000',
          'available': true,
          'place_id': 'sample_cardio_2',
        },
      ],
      'dermatologist': [
        {
          'name': 'Dr. Farhana Islam',
          'specialty': 'Dermatologist',
          'address': '123 Skin Care Clinic, Dhaka',
          'phone': '+880 1711-444444',
          'rating': 4.6,
          'distance': (radius * 0.3).toStringAsFixed(1),
          'latitude': baseLat + 0.010,
          'longitude': baseLng + 0.010,
          'image': 'assets/images/doctor3.jpg',
          'experience': '11 years',
          'qualifications': 'MBBS, MD (Dermatology)',
          'consultation_fee': '৳600',
          'available': true,
          'place_id': 'sample_derma_1',
        },
        {
          'name': 'Dr. Tania Rahman',
          'specialty': 'Dermatologist',
          'address': '456 Dermatology Center, Dhaka',
          'phone': '+880 1811-555555',
          'rating': 4.3,
          'distance': (radius * 0.6).toStringAsFixed(1),
          'latitude': baseLat + 0.011,
          'longitude': baseLng + 0.011,
          'image': 'assets/images/doctor4.jpg',
          'experience': '8 years',
          'qualifications': 'MBBS, FCPS (Dermatology)',
          'consultation_fee': '৳500',
          'available': true,
          'place_id': 'sample_derma_2',
        },
      ],
      'neurologist': [
        {
          'name': 'Dr. Shahidul Islam',
          'specialty': 'Neurologist',
          'address': '123 Neurology Institute, Dhaka',
          'phone': '+880 1711-666666',
          'rating': 4.8,
          'distance': (radius * 0.4).toStringAsFixed(1),
          'latitude': baseLat + 0.012,
          'longitude': baseLng + 0.012,
          'image': 'assets/images/doctor1.jpg',
          'experience': '16 years',
          'qualifications': 'MBBS, MD (Neurology), PhD',
          'consultation_fee': '৳1000',
          'available': true,
          'place_id': 'sample_neuro_1',
        },
        {
          'name': 'Dr. Nusrat Jahan',
          'specialty': 'Neurologist',
          'address': '456 Brain & Spine Center, Dhaka',
          'phone': '+880 1811-777777',
          'rating': 4.5,
          'distance': (radius * 0.7).toStringAsFixed(1),
          'latitude': baseLat + 0.013,
          'longitude': baseLng + 0.013,
          'image': 'assets/images/doctor2.jpg',
          'experience': '13 years',
          'qualifications': 'MBBS, FCPS (Neurology)',
          'consultation_fee': '৳900',
          'available': true,
          'place_id': 'sample_neuro_2',
        },
      ],
      'psychiatrist': [
        {
          'name': 'Dr. Anisur Rahman',
          'specialty': 'Psychiatrist',
          'address': '123 Mental Health Center, Dhaka',
          'phone': '+880 1711-888888',
          'rating': 4.4,
          'distance': (radius * 0.5).toStringAsFixed(1),
          'latitude': baseLat + 0.014,
          'longitude': baseLng + 0.014,
          'image': 'assets/images/doctor3.jpg',
          'experience': '14 years',
          'qualifications': 'MBBS, MD (Psychiatry)',
          'consultation_fee': '৳800',
          'available': true,
          'place_id': 'sample_psych_1',
        },
        {
          'name': 'Dr. Sabina Yasmin',
          'specialty': 'Psychiatrist',
          'address': '456 Psychiatry Clinic, Dhaka',
          'phone': '+880 1811-999999',
          'rating': 4.7,
          'distance': (radius * 0.8).toStringAsFixed(1),
          'latitude': baseLat + 0.015,
          'longitude': baseLng + 0.015,
          'image': 'assets/images/doctor4.jpg',
          'experience': '10 years',
          'qualifications': 'MBBS, FCPS (Psychiatry)',
          'consultation_fee': '৳700',
          'available': true,
          'place_id': 'sample_psych_2',
        },
      ],
      'pediatrician': [
        {
          'name': 'Dr. Mominul Haque',
          'specialty': 'Pediatrician',
          'address': '123 Children\'s Hospital, Dhaka',
          'phone': '+880 1711-000000',
          'rating': 4.9,
          'distance': (radius * 0.2).toStringAsFixed(1),
          'latitude': baseLat + 0.016,
          'longitude': baseLng + 0.016,
          'image': 'assets/images/doctor1.jpg',
          'experience': '17 years',
          'qualifications': 'MBBS, MD (Pediatrics)',
          'consultation_fee': '৳600',
          'available': true,
          'place_id': 'sample_pedia_1',
        },
        {
          'name': 'Dr. Sharmin Akter',
          'specialty': 'Pediatrician',
          'address': '456 Kids Care Center, Dhaka',
          'phone': '+880 1811-111111',
          'rating': 4.6,
          'distance': (radius * 0.5).toStringAsFixed(1),
          'latitude': baseLat + 0.017,
          'longitude': baseLng + 0.017,
          'image': 'assets/images/doctor2.jpg',
          'experience': '12 years',
          'qualifications': 'MBBS, FCPS (Pediatrics)',
          'consultation_fee': '৳550',
          'available': true,
          'place_id': 'sample_pedia_2',
        },
      ],
      'ophthalmologist': [
        {
          'name': 'Dr. Ziaul Haque',
          'specialty': 'Ophthalmologist',
          'address': '123 Eye Care Center, Dhaka',
          'phone': '+880 1711-222222',
          'rating': 4.5,
          'distance': (radius * 0.3).toStringAsFixed(1),
          'latitude': baseLat + 0.018,
          'longitude': baseLng + 0.018,
          'image': 'assets/images/doctor3.jpg',
          'experience': '15 years',
          'qualifications': 'MBBS, MS (Ophthalmology)',
          'consultation_fee': '৳700',
          'available': true,
          'place_id': 'sample_ophthal_1',
        },
        {
          'name': 'Dr. Nasreen Sultana',
          'specialty': 'Ophthalmologist',
          'address': '456 Vision Institute, Dhaka',
          'phone': '+880 1811-333333',
          'rating': 4.8,
          'distance': (radius * 0.6).toStringAsFixed(1),
          'latitude': baseLat + 0.019,
          'longitude': baseLng + 0.019,
          'image': 'assets/images/doctor4.jpg',
          'experience': '13 years',
          'qualifications': 'MBBS, FCPS (Ophthalmology)',
          'consultation_fee': '৳650',
          'available': true,
          'place_id': 'sample_ophthal_2',
        },
      ],
      'dentist': [
        {
          'name': 'Dr. Rafiqul Islam',
          'specialty': 'Dentist',
          'address': '123 Dental Care Center, Dhaka',
          'phone': '+880 1711-444444',
          'rating': 4.4,
          'distance': (radius * 0.4).toStringAsFixed(1),
          'latitude': baseLat + 0.020,
          'longitude': baseLng + 0.020,
          'image': 'assets/images/doctor1.jpg',
          'experience': '11 years',
          'qualifications': 'BDS, MDS',
          'consultation_fee': '৳400',
          'available': true,
          'place_id': 'sample_dentist_1',
        },
        {
          'name': 'Dr. Tahmina Begum',
          'specialty': 'Dentist',
          'address': '456 Smile Dental Clinic, Dhaka',
          'phone': '+880 1811-555555',
          'rating': 4.7,
          'distance': (radius * 0.7).toStringAsFixed(1),
          'latitude': baseLat + 0.021,
          'longitude': baseLng + 0.021,
          'image': 'assets/images/doctor2.jpg',
          'experience': '9 years',
          'qualifications': 'BDS, FCPS',
          'consultation_fee': '৳450',
          'available': true,
          'place_id': 'sample_dentist_2',
        },
      ],
      'general': [
        {
          'name': 'Dr. Abdul Kader',
          'specialty': 'General Physician',
          'address': '123 Family Health Center, Dhaka',
          'phone': '+880 1711-666666',
          'rating': 4.3,
          'distance': (radius * 0.2).toStringAsFixed(1),
          'latitude': baseLat + 0.022,
          'longitude': baseLng + 0.022,
          'image': 'assets/images/doctor3.jpg',
          'experience': '12 years',
          'qualifications': 'MBBS, FCPS (Medicine)',
          'consultation_fee': '৳400',
          'available': true,
          'place_id': 'sample_general_1',
        },
        {
          'name': 'Dr. Hasina Begum',
          'specialty': 'General Physician',
          'address': '456 Community Clinic, Dhaka',
          'phone': '+880 1811-777777',
          'rating': 4.6,
          'distance': (radius * 0.5).toStringAsFixed(1),
          'latitude': baseLat + 0.023,
          'longitude': baseLng + 0.023,
          'image': 'assets/images/doctor4.jpg',
          'experience': '8 years',
          'qualifications': 'MBBS, MD (Medicine)',
          'consultation_fee': '৳350',
          'available': true,
          'place_id': 'sample_general_2',
        },
      ],
    };
    
    // Return doctors for the specific specialty, or general doctors if specialty not found
    return specialtyDoctors[specialty] ?? specialtyDoctors['general']!;
  }

  /// Get sample pharmacy data
  List<Map<String, dynamic>> _getSamplePharmacies(Position location, double radius, String? city) {
    final baseLat = location.latitude;
    final baseLng = location.longitude;
    final cityName = city ?? 'Dhaka';
    
    return [
      {
        'name': 'MediCare Pharmacy',
        'address': '123 Health Street, $cityName',
        'phone': '+880 1711-111111',
        'rating': 4.3,
        'distance': (radius * 0.2).toStringAsFixed(1),
        'latitude': baseLat + 0.001,
        'longitude': baseLng + 0.001,
        'image': 'assets/images/pharmacy1.jpg',
        'hours': '9:00 AM - 9:00 PM',
        'services': ['Prescription Filling', '24/7 Service', 'Home Delivery'],
        'isOpen24Hours': false,
        'place_id': 'sample_pharmacy_1',
      },
      {
        'name': 'Community Drugstore',
        'address': '456 Wellness Avenue, $cityName',
        'phone': '+880 1811-222222',
        'rating': 4.6,
        'distance': (radius * 0.5).toStringAsFixed(1),
        'latitude': baseLat + 0.002,
        'longitude': baseLng + 0.002,
        'image': 'assets/images/pharmacy2.jpg',
        'hours': '8:00 AM - 10:00 PM',
        'services': ['Prescription Filling', 'Vaccination', 'Health Consultation'],
        'isOpen24Hours': false,
        'place_id': 'sample_pharmacy_2',
      },
      {
        'name': 'QuickMeds Pharmacy',
        'address': '789 Remedy Road, $cityName',
        'phone': '+880 1911-333333',
        'rating': 4.1,
        'distance': (radius * 0.8).toStringAsFixed(1),
        'latitude': baseLat + 0.003,
        'longitude': baseLng + 0.003,
        'image': 'assets/images/pharmacy3.jpg',
        'hours': '24 Hours',
        'services': ['Prescription Filling', 'Drive-through', 'Health Screening'],
        'isOpen24Hours': true,
        'place_id': 'sample_pharmacy_3',
      },
      {
        'name': 'HealthPlus Pharmacy',
        'address': '321 Cure Street, $cityName',
        'phone': '+880 1611-444444',
        'rating': 4.4,
        'distance': (radius * 1.1).toStringAsFixed(1),
        'latitude': baseLat + 0.004,
        'longitude': baseLng + 0.004,
        'image': 'assets/images/pharmacy4.jpg',
        'hours': '8:30 AM - 8:30 PM',
        'services': ['Prescription Filling', 'Compounding', 'Medical Equipment'],
        'isOpen24Hours': false,
        'place_id': 'sample_pharmacy_4',
      },
    ];
  }

  /// Real Google Places API implementation
  Future<List<Map<String, dynamic>>> _searchPlacesReal({
    required Position location,
    required String query,
    required double radius,
    String? type,
  }) async {
    final apiKey = ApiConfig.googlePlacesApiKey;
    
    final url = Uri.parse(
      '${ApiConfig.googlePlacesBaseUrl}/textsearch/json?'
      'query=${Uri.encodeComponent(query)}'
      '&location=${location.latitude},${location.longitude}'
      '&radius=${(radius * 1000).round()}'
      '${type != null ? '&type=$type' : ''}'
      '&key=$apiKey'
    );

    try {
      final response = await http.get(url);
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        
        if (data['status'] == 'OK') {
          final results = data['results'] as List;
          
          return results.map((place) {
            final geometry = place['geometry'];
            final placeLocation = geometry['location'];
            
            return {
              'name': place['name'] ?? '',
              'address': place['formatted_address'] ?? '',
              'rating': place['rating'] ?? 0.0,
              'latitude': placeLocation['lat'] ?? 0.0,
              'longitude': placeLocation['lng'] ?? 0.0,
              'place_id': place['place_id'] ?? '',
              'phone': '', // Will be enhanced later
              'distance': _calculateDistance(
                location.latitude,
                location.longitude,
                placeLocation['lat'] ?? 0.0,
                placeLocation['lng'] ?? 0.0,
              ).toStringAsFixed(1),
              'opening_hours': place['opening_hours'] ?? {},
              'photos': place['photos'] ?? [],
              'types': place['types'] ?? [],
            };
          }).toList();
        } else {
          print('Google Places API error: ${data['status']} - ${data['error_message'] ?? 'Unknown error'}');
          throw Exception('Google Places API error: ${data['status']}');
        }
      } else {
        throw Exception('HTTP error: ${response.statusCode}');
      }
    } catch (e) {
      print('Error calling Google Places API: $e');
      rethrow;
    }
  }

  /// Enhance doctor data with additional details
  Future<Map<String, dynamic>> _enhanceDoctorData(Map<String, dynamic> place, String specialty) async {
    // Get additional details from Google Places Details API
    final details = await _getPlaceDetails(place['place_id']);
    
    return {
      ...place,
      'specialty': specialty.capitalize(),
      'experience': 'Available on request',
      'qualifications': 'MBBS, MD',
      'consultation_fee': '৳500-1000',
      'available': true,
      'phone': details['phone'] ?? '+880 1XXX-XXXXXX',
      'hours': details['hours'] ?? '9:00 AM - 6:00 PM',
      'website': details['website'] ?? '',
    };
  }

  /// Enhance pharmacy data with additional details
  Future<Map<String, dynamic>> _enhancePharmacyData(Map<String, dynamic> place) async {
    // Get additional details from Google Places Details API
    final details = await _getPlaceDetails(place['place_id']);
    
    return {
      ...place,
      'phone': details['phone'] ?? '+880 1XXX-XXXXXX',
      'hours': details['hours'] ?? '9:00 AM - 9:00 PM',
      'services': ['Prescription Filling', 'Over-the-counter', 'Health Consultation'],
      'isOpen24Hours': false,
      'website': details['website'] ?? '',
    };
  }

  /// Get detailed information about a place
  Future<Map<String, dynamic>> _getPlaceDetails(String placeId) async {
    final apiKey = ApiConfig.googlePlacesApiKey;
    
    final url = Uri.parse(
      '${ApiConfig.googlePlacesBaseUrl}/details/json?'
      'place_id=$placeId'
      '&fields=formatted_phone_number,opening_hours,website'
      '&key=$apiKey'
    );

    try {
      final response = await http.get(url);
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        
        if (data['status'] == 'OK') {
          final result = data['result'];
          final openingHours = result['opening_hours'] ?? {};
          
          return {
            'phone': result['formatted_phone_number'] ?? '',
            'hours': _formatOpeningHours(openingHours),
            'website': result['website'] ?? '',
          };
        }
      }
    } catch (e) {
      print('Error getting place details: $e');
    }
    
    return {
      'phone': '',
      'hours': '',
      'website': '',
    };
  }

  /// Format opening hours for display
  String _formatOpeningHours(Map<String, dynamic> openingHours) {
    try {
      final periods = openingHours['periods'] as List?;
      if (periods != null && periods.isNotEmpty) {
        final firstPeriod = periods.first;
        final open = firstPeriod['open'];
        final close = firstPeriod['close'];
        
        if (open != null && close != null) {
          return '${open['time']} - ${close['time']}';
        }
      }
    } catch (e) {
      print('Error formatting opening hours: $e');
    }
    
    return 'Hours not available';
  }

  double _calculateDistance(double lat1, double lng1, double lat2, double lng2) {
    return Geolocator.distanceBetween(lat1, lng1, lat2, lng2) / 1000; // Convert to km
  }
}

extension StringExtension on String {
  String capitalize() {
    return "${this[0].toUpperCase()}${substring(1)}";
  }
} 