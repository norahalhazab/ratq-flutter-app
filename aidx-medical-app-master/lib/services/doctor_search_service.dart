import 'package:http/http.dart' as http;
import 'package:html/parser.dart' as parser;
import 'package:html/dom.dart';
import '../data/health_data.dart';

class Doctor {
  final String name;
  final String qualifications;
  final String position;
  final String profileUrl;
  final String? chamber;
  final String? address;
  final String? visitingHours;
  final String? appointmentPhone;
  String? phone;
  String? fee;

  Doctor({
    required this.name,
    required this.qualifications,
    required this.position,
    required this.profileUrl,
    this.chamber,
    this.address,
    this.visitingHours,
    this.appointmentPhone,
    this.phone,
    this.fee,
  });
}

class DoctorSearchService {
  static const String baseUrl = 'https://www.doctorbangladesh.com';

  Future<List<Doctor>> searchDoctors({
    required String specialtySlug,
    required String locationSlug,
  }) async {
    // Try hardcoded data first
    final locationData = HealthData.doctors[locationSlug] ?? HealthData.doctors['Dhaka'];
    final doctorList = locationData?[specialtySlug];

    if (doctorList != null && doctorList.isNotEmpty) {
      print('Returning hardcoded doctors for $specialtySlug in $locationSlug');
      return doctorList.map((d) => Doctor(
        name: d['name']!,
        qualifications: d['qualifications']!,
        position: d['position']!,
        profileUrl: d['profileUrl']!,
        chamber: d['chamber'],
        address: d['address'],
        visitingHours: d['visitingHours'],
        appointmentPhone: d['appointmentPhone'],
      )).toList();
    }

    // Fallback to scraping
    print('No hardcoded data found, falling back to scraping for $specialtySlug in $locationSlug');
    final url = '$baseUrl/$specialtySlug-$locationSlug/';
    
    try {
      final response = await http.get(Uri.parse(url));
      if (response.statusCode != 200) return [];

      final document = parser.parse(response.body);
      final List<Doctor> doctors = [];

      final doctorElements = document.querySelectorAll('div.entry-content p');
      
      for (var element in doctorElements) {
        final links = element.querySelectorAll('a');
        Element? nameLink;
        Element? chamberLink;
        
        for (var link in links) {
          final text = link.text.trim();
          if (text.contains('Dr.')) {
            nameLink = link;
          } else if (text.contains('See Chambers') || link.classes.contains('call-now')) {
            chamberLink = link;
          }
        }

        if (nameLink != null) {
          final name = nameLink.text.trim();
          final profileUrl = nameLink.attributes['href'] ?? '';
          final chamber = chamberLink?.attributes['title']?.replaceAll('Chamber: ', '').trim();
          
          final text = element.text;
          final parts = text.split('\n').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
          
          String qualifications = '';
          String position = '';
          
          if (parts.length > 1) qualifications = parts[1];
          if (parts.length > 2 && !parts[2].contains('See Chambers')) position = parts[2];

          doctors.add(Doctor(
            name: name,
            qualifications: qualifications,
            position: position,
            profileUrl: profileUrl,
            chamber: chamber,
          ));
        }
      }
      return doctors;
    } catch (e) {
      print('Error searching doctors: $e');
      return [];
    }
  }

  Future<void> fetchDoctorDetails(Doctor doctor) async {
    try {
      final response = await http.get(Uri.parse(doctor.profileUrl));
      if (response.statusCode != 200) return;

      final document = parser.parse(response.body);
      final text = document.body?.text ?? '';
      
      // Phone number regex
      final phoneMatch = RegExp(r'(\+8801[3-9]\d{8}|01[3-9]\d{8})').firstMatch(text);
      if (phoneMatch != null) {
        doctor.phone = phoneMatch.group(0);
      }

      // Fee regex
      final feeMatch = RegExp(r'Fee:\s*(\d+)').firstMatch(text);
      if (feeMatch != null) {
        doctor.fee = feeMatch.group(1);
      }
    } catch (e) {
      // Ignore
    }
  }
}
