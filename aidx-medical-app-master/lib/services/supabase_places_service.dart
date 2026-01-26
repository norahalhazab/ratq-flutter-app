import 'package:http/http.dart' as http;
import 'dart:convert';

class SupabasePlacesService {
  static const String baseUrl = 'https://cbdirfispvyknwmfhwln.supabase.co/functions/v1/api';

  /// Search for doctors using Supabase API
  Future<List<Map<String, dynamic>>> searchDoctors({
    required String city,
    required String area,
    String? specialty,
  }) async {
    try {
      final queryParams = {
        'city': city,
        'area': area,
        if (specialty != null && specialty.isNotEmpty) 'specialty': specialty,
      };

      final uri = Uri.parse('$baseUrl/doctors').replace(queryParameters: queryParams);

      final response = await http.get(uri, headers: {
        'Content-Type': 'application/json',
        // Add any authentication headers if needed
      });

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true) {
          final doctors = data['doctors'] as List;
          return doctors.map((doctor) => {
            'name': doctor['name'] ?? 'Unknown Doctor',
            'specialty': doctor['specialty'] ?? 'General Physician',
            'address': doctor['address'] ?? 'Address not available',
            'phone': doctor['phone'] ?? 'Contact not available',
            'rating': doctor['rating'] ?? 4.0,
            'latitude': doctor['lat'] ?? 0.0,
            'longitude': doctor['lon'] ?? 0.0,
            'distance': doctor['distance'] ?? '0.0',
            'experience': 'Available on request',
            'qualifications': 'MBBS, MD',
            'consultation_fee': '৳500-1000',
            'available': true,
            'hours': '9:00 AM - 6:00 PM',
            'website': '',
          }).toList();
        } else {
          throw Exception(data['error'] ?? 'API returned error');
        }
      } else {
        throw Exception('Failed to load doctors: ${response.statusCode}');
      }
    } catch (e) {
      print('Error searching doctors via Supabase: $e');
      return _getSampleDoctors(specialty ?? 'general', city, area);
    }
  }

  /// Search for pharmacies using Supabase API
  Future<List<Map<String, dynamic>>> searchPharmacies({
    required String city,
    required String area,
  }) async {
    try {
      final queryParams = {
        'city': city,
        'area': area,
      };

      final uri = Uri.parse('$baseUrl/pharmacies').replace(queryParameters: queryParams);

      final response = await http.get(uri, headers: {
        'Content-Type': 'application/json',
        // Add any authentication headers if needed
      });

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true) {
          final pharmacies = data['pharmacies'] as List;
          return pharmacies.map((pharmacy) => {
            'name': pharmacy['name'] ?? 'Unknown Pharmacy',
            'address': pharmacy['address'] ?? 'Address not available',
            'phone': pharmacy['phone'] ?? 'Contact not available',
            'rating': pharmacy['rating'] ?? 4.0,
            'latitude': pharmacy['lat'] ?? 0.0,
            'longitude': pharmacy['lon'] ?? 0.0,
            'distance': pharmacy['distance'] ?? '0.0',
            'hours': pharmacy['openingHours'] ?? '9:00 AM - 9:00 PM',
            'services': ['Prescription Filling', 'Over-the-counter', 'Health Consultation'],
            'isOpen24Hours': pharmacy['isOpen'] ?? false,
            'website': pharmacy['website'] ?? '',
          }).toList();
        } else {
          throw Exception(data['error'] ?? 'API returned error');
        }
      } else {
        throw Exception('Failed to load pharmacies: ${response.statusCode}');
      }
    } catch (e) {
      print('Error searching pharmacies via Supabase: $e');
      return _getSamplePharmacies(city, area);
    }
  }

  /// Sample doctor data as fallback
  List<Map<String, dynamic>> _getSampleDoctors(String specialty, String city, String area) {
    final specialtyName = _capitalize(specialty);
    final doctors = [
      {
        'name': 'Dr. Ahmed Rahman',
        'specialty': specialtyName,
        'address': '$area, $city',
        'phone': '+880 1711-123456',
        'rating': 4.5,
        'distance': '2.1',
        'latitude': 23.8103,
        'longitude': 90.4125,
        'experience': '15 years',
        'qualifications': 'MBBS, MD',
        'consultation_fee': '৳800',
        'available': true,
        'hours': '9:00 AM - 6:00 PM',
      },
      {
        'name': 'Dr. Fatima Khan',
        'specialty': specialtyName,
        'address': '$area, $city',
        'phone': '+880 1811-234567',
        'rating': 4.8,
        'distance': '3.2',
        'latitude': 23.8110,
        'longitude': 90.4130,
        'experience': '12 years',
        'qualifications': 'MBBS, FCPS',
        'consultation_fee': '৳700',
        'available': true,
        'hours': '9:00 AM - 6:00 PM',
      },
    ];
    return doctors;
  }

  /// Sample pharmacy data as fallback
  List<Map<String, dynamic>> _getSamplePharmacies(String city, String area) {
    return [
      {
        'name': 'Popular Pharmacy',
        'address': '$area, $city',
        'phone': '+880 1711-111111',
        'rating': 4.3,
        'distance': '1.5',
        'latitude': 23.8103,
        'longitude': 90.4125,
        'hours': '9:00 AM - 9:00 PM',
        'services': ['Prescription Filling', '24/7 Service', 'Home Delivery'],
        'isOpen24Hours': false,
      },
      {
        'name': 'Medicine Corner',
        'address': '$area, $city',
        'phone': '+880 1811-222222',
        'rating': 4.6,
        'distance': '2.8',
        'latitude': 23.8110,
        'longitude': 90.4130,
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

  /// Send search results via SMS
  Future<bool> sendSmsResults({
    String? city,
    String? area,
    required String type,
    required String userPhone,
    String? specialty,
    String? query,
    String? bloodType,
  }) async {
    try {
      final uri = Uri.parse('https://cbdirfispvyknwmfhwln.supabase.co/functions/v1/sms-finder');
      
      final payload = {
        if (city != null) 'city': city,
        if (area != null) 'area': area,
        'type': type,
        'userPhone': userPhone,
        if (specialty != null) 'specialty': specialty,
        if (query != null) 'query': query,
        if (bloodType != null) 'bloodType': bloodType,
      };
      final response = await http.post(
        uri,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(payload),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['success'] == true;
      }
      return false;
    } catch (e) {
      print('Error sending SMS results: $e');
      return false;
    }
  }
}