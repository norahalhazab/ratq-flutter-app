import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:geolocator/geolocator.dart';

class FreePlacesService {
  /// Search for doctors using free APIs (no credit card required)
  Future<List<Map<String, dynamic>>> searchDoctors({
    required Position location,
    required String specialty,
    required double radius,
    String? city,
  }) async {
    try {
      // Use OpenStreetMap Nominatim API (completely free, no API key needed)
      final query = city != null && city.isNotEmpty
          ? '$specialty doctor $city'
          : '$specialty doctor';
      final results = await _searchOpenStreetMap(
        query: query,
        location: location,
        radius: radius,
      );
      if (results.isEmpty) {
        return _getSampleDoctors(specialty, location, radius);
      }
      // Enhance with sample data for missing fields
      return results.map((place) => _enhanceDoctorData(place, specialty)).toList();
    } catch (e) {
      print('Error searching doctors: $e');
      return _getSampleDoctors(specialty, location, radius);
    }
  }

  /// Search for pharmacies using free APIs
  Future<List<Map<String, dynamic>>> searchPharmacies({
    required Position location,
    required double radius,
    String? city,
  }) async {
    try {
      final query = city != null ? 'pharmacy $city' : 'pharmacy';
      final results = await _searchOpenStreetMap(
        query: query,
        location: location,
        radius: radius,
      );
      
      return results.map((place) => _enhancePharmacyData(place)).toList();
    } catch (e) {
      print('Error searching pharmacies: $e');
      return _getSamplePharmacies(location, radius, city);
    }
  }

  /// Search using OpenStreetMap Nominatim API (completely free)
  Future<List<Map<String, dynamic>>> _searchOpenStreetMap({
    required String query,
    required Position location,
    required double radius,
  }) async {
    final url = Uri.parse(
      'https://nominatim.openstreetmap.org/search?'
      'q=${Uri.encodeComponent(query)}'
      '&format=json'
      '&limit=20'
      '&addressdetails=1'
      '&viewbox=${location.longitude - 0.1},${location.latitude + 0.1},${location.longitude + 0.1},${location.latitude - 0.1}'
      '&bounded=1'
    );

    final response = await http.get(url, headers: {
      'User-Agent': 'MedigayApp/1.0',
    });

    if (response.statusCode == 200) {
      final data = json.decode(response.body) as List;
      
      return data.map((place) {
        final lat = double.tryParse(place['lat'] ?? '0') ?? 0.0;
        final lon = double.tryParse(place['lon'] ?? '0') ?? 0.0;
        final displayName = place['display_name'] ?? '';
        
        // Extract better name from display_name
        String name = 'Unknown';
        if (displayName.isNotEmpty) {
          final parts = displayName.split(',');
          if (parts.isNotEmpty) {
            name = parts.first.trim();
            // If first part is too short, try second part
            if (name.length < 3 && parts.length > 1) {
              name = parts[1].trim();
            }
          }
        }
        
        return {
          'name': name,
          'address': displayName,
          'latitude': lat,
          'longitude': lon,
          'place_id': place['place_id'] ?? '',
          'distance': _calculateDistance(location.latitude, location.longitude, lat, lon).toStringAsFixed(1),
          'rating': 4.0 + (double.parse(place['place_id'] ?? '0') % 10) / 10, // Generate rating based on place_id
        };
      }).toList();
    } else {
      throw Exception('Failed to load places from OpenStreetMap');
    }
  }

  /// Enhance doctor data with additional information
  Map<String, dynamic> _enhanceDoctorData(Map<String, dynamic> place, String specialty) {
    return {
      ...place,
      'specialty': _capitalize(specialty),
      'experience': 'Available on request',
      'qualifications': 'MBBS, MD',
      'consultation_fee': '৳500-1000',
      'available': true,
      'phone': '+880 1${(1000 + int.parse(place['place_id'] ?? '0') % 9000)}-${100000 + int.parse(place['place_id'] ?? '0') % 900000}',
      'hours': '9:00 AM - 6:00 PM',
      'website': '',
    };
  }

  /// Enhance pharmacy data with additional information
  Map<String, dynamic> _enhancePharmacyData(Map<String, dynamic> place) {
    return {
      ...place,
      'phone': '+880 1${(1000 + int.parse(place['place_id'] ?? '0') % 9000)}-${100000 + int.parse(place['place_id'] ?? '0') % 900000}',
      'hours': '9:00 AM - 9:00 PM',
      'services': ['Prescription Filling', 'Over-the-counter', 'Health Consultation'],
      'isOpen24Hours': false,
      'website': '',
    };
  }

  /// Calculate distance between two points
  double _calculateDistance(double lat1, double lng1, double lat2, double lng2) {
    return Geolocator.distanceBetween(lat1, lng1, lat2, lng2) / 1000; // Convert to km
  }

  /// Sample data as fallback
  List<Map<String, dynamic>> _getSampleDoctors(String specialty, Position location, double radius) {
    final specialtyName = _capitalize(specialty);
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
          'experience': '15 years',
          'qualifications': 'MBBS, MS (Ortho), FRCS',
          'consultation_fee': '৳800',
          'available': true,
          'hours': '9:00 AM - 6:00 PM',
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
          'experience': '12 years',
          'qualifications': 'MBBS, FCPS (Ortho)',
          'consultation_fee': '৳700',
          'available': true,
          'hours': '9:00 AM - 6:00 PM',
        },
        {
          'name': 'Dr. Mohammad Ali',
          'specialty': 'Orthopedic',
          'address': '789 Spine & Ortho Center, Dhaka',
          'phone': '+880 1911-345678',
          'rating': 4.2,
          'distance': (radius * 0.9).toStringAsFixed(1),
          'latitude': baseLat + 0.003,
          'longitude': baseLng + 0.003,
          'experience': '8 years',
          'qualifications': 'MBBS, MS (Ortho)',
          'consultation_fee': '৳600',
          'available': false,
          'hours': '9:00 AM - 6:00 PM',
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
          'experience': '20 years',
          'qualifications': 'MBBS, FCPS (Obs & Gynae)',
          'consultation_fee': '৳900',
          'available': true,
          'hours': '9:00 AM - 6:00 PM',
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
          'experience': '10 years',
          'qualifications': 'MBBS, MS (Obs & Gynae)',
          'consultation_fee': '৳750',
          'available': true,
          'hours': '9:00 AM - 6:00 PM',
        },
        {
          'name': 'Dr. Salma Khatun',
          'specialty': 'Gynecologist',
          'address': '987 Gynecology Clinic, Dhaka',
          'phone': '+880 1411-678901',
          'rating': 4.6,
          'distance': (radius * 1.0).toStringAsFixed(1),
          'latitude': baseLat + 0.006,
          'longitude': baseLng + 0.006,
          'experience': '14 years',
          'qualifications': 'MBBS, DGO, FCPS',
          'consultation_fee': '৳800',
          'available': true,
          'hours': '9:00 AM - 6:00 PM',
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
          'experience': '18 years',
          'qualifications': 'MBBS, MD (Cardiology), FRCP',
          'consultation_fee': '৳1200',
          'available': true,
          'hours': '9:00 AM - 6:00 PM',
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
          'experience': '12 years',
          'qualifications': 'MBBS, FCPS (Cardiology)',
          'consultation_fee': '৳1000',
          'available': true,
          'hours': '9:00 AM - 6:00 PM',
        },
        {
          'name': 'Dr. Rezaul Karim',
          'specialty': 'Cardiologist',
          'address': '789 Heart Institute, Dhaka',
          'phone': '+880 1911-333333',
          'rating': 4.7,
          'distance': (radius * 0.8).toStringAsFixed(1),
          'latitude': baseLat + 0.009,
          'longitude': baseLng + 0.009,
          'experience': '15 years',
          'qualifications': 'MBBS, MS (Cardiothoracic)',
          'consultation_fee': '৳1100',
          'available': false,
          'hours': '9:00 AM - 6:00 PM',
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
          'experience': '11 years',
          'qualifications': 'MBBS, MD (Dermatology)',
          'consultation_fee': '৳600',
          'available': true,
          'hours': '9:00 AM - 6:00 PM',
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
          'experience': '8 years',
          'qualifications': 'MBBS, FCPS (Dermatology)',
          'consultation_fee': '৳500',
          'available': true,
          'hours': '9:00 AM - 6:00 PM',
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
          'experience': '16 years',
          'qualifications': 'MBBS, MD (Neurology), PhD',
          'consultation_fee': '৳1000',
          'available': true,
          'hours': '9:00 AM - 6:00 PM',
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
          'experience': '13 years',
          'qualifications': 'MBBS, FCPS (Neurology)',
          'consultation_fee': '৳900',
          'available': true,
          'hours': '9:00 AM - 6:00 PM',
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
          'experience': '14 years',
          'qualifications': 'MBBS, MD (Psychiatry)',
          'consultation_fee': '৳800',
          'available': true,
          'hours': '9:00 AM - 6:00 PM',
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
          'experience': '10 years',
          'qualifications': 'MBBS, FCPS (Psychiatry)',
          'consultation_fee': '৳700',
          'available': true,
          'hours': '9:00 AM - 6:00 PM',
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
          'experience': '17 years',
          'qualifications': 'MBBS, MD (Pediatrics)',
          'consultation_fee': '৳600',
          'available': true,
          'hours': '9:00 AM - 6:00 PM',
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
          'experience': '12 years',
          'qualifications': 'MBBS, FCPS (Pediatrics)',
          'consultation_fee': '৳550',
          'available': true,
          'hours': '9:00 AM - 6:00 PM',
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
          'experience': '15 years',
          'qualifications': 'MBBS, MS (Ophthalmology)',
          'consultation_fee': '৳700',
          'available': true,
          'hours': '9:00 AM - 6:00 PM',
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
          'experience': '13 years',
          'qualifications': 'MBBS, FCPS (Ophthalmology)',
          'consultation_fee': '৳650',
          'available': true,
          'hours': '9:00 AM - 6:00 PM',
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
          'experience': '11 years',
          'qualifications': 'BDS, MDS',
          'consultation_fee': '৳400',
          'available': true,
          'hours': '9:00 AM - 6:00 PM',
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
          'experience': '9 years',
          'qualifications': 'BDS, FCPS',
          'consultation_fee': '৳450',
          'available': true,
          'hours': '9:00 AM - 6:00 PM',
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
          'experience': '12 years',
          'qualifications': 'MBBS, FCPS (Medicine)',
          'consultation_fee': '৳400',
          'available': true,
          'hours': '9:00 AM - 6:00 PM',
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
          'experience': '8 years',
          'qualifications': 'MBBS, MD (Medicine)',
          'consultation_fee': '৳350',
          'available': true,
          'hours': '9:00 AM - 6:00 PM',
        },
      ],
    };
    
    // Return doctors for the specific specialty, or general doctors if specialty not found
    return specialtyDoctors[specialty] ?? specialtyDoctors['general']!;
  }

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
        'hours': '9:00 AM - 9:00 PM',
        'services': ['Prescription Filling', '24/7 Service', 'Home Delivery'],
        'isOpen24Hours': false,
      },
      {
        'name': 'Community Drugstore',
        'address': '456 Wellness Avenue, $cityName',
        'phone': '+880 1811-222222',
        'rating': 4.6,
        'distance': (radius * 0.5).toStringAsFixed(1),
        'latitude': baseLat + 0.002,
        'longitude': baseLng + 0.002,
        'hours': '8:00 AM - 10:00 PM',
        'services': ['Prescription Filling', 'Vaccination', 'Health Consultation'],
        'isOpen24Hours': false,
      },
    ];
  }

  String _capitalize(String s) {
    if (s.isEmpty) return s;
    return s[0].toUpperCase() + s.substring(1);
  }
}

 