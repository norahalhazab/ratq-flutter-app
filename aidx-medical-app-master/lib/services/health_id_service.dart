import 'dart:convert';
import 'dart:ui';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:http/http.dart' as http;
import '../models/health_id_model.dart';
import '../models/medication_model.dart';

class HealthIdService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  static const String _apiBaseUrl = 'http://localhost:3000'; // Change this to your API URL

  // Get current user's health ID
  Future<HealthIdModel?> getHealthId() async {
    try {
      final user = _auth.currentUser;
      if (user == null) return null;

      final doc = await _firestore
          .collection('health_ids')
          .where('userId', isEqualTo: user.uid)
          .limit(1)
          .get();

      if (doc.docs.isEmpty) return null;

      final healthId = HealthIdModel.fromFirestore(doc.docs.first);
      print('Retrieved Health ID - Age: ${healthId.age}');
      return healthId;
    } catch (e) {
      print('Error getting health ID: $e');
      return null;
    }
  }

  // Create or update health ID
  Future<HealthIdModel?> saveHealthId(HealthIdModel healthId) async {
    try {
      final user = _auth.currentUser;
      if (user == null) return null;

      print('Saving Health ID - Original Age: ${healthId.age}');

      // Update medications from medication collection
      final medications = await _getActiveMedications(user.uid);
      final updatedHealthId = healthId.copyWith(
        activeMedications: medications,
        updatedAt: DateTime.now(),
      );

      print('Saving Health ID - Updated Age: ${updatedHealthId.age}');

      if (healthId.id == null) {
        // Create new health ID
        final docRef = await _firestore
            .collection('health_ids')
            .add(updatedHealthId.toFirestore());

        final savedHealthId = updatedHealthId.copyWith(id: docRef.id);
        
        // Save emergency information to 'number' collection for API lookup
        if (savedHealthId.phoneNumber != null && savedHealthId.phoneNumber!.isNotEmpty) {
          await _saveEmergencyInfoToDatabase(savedHealthId);
        }
        
        print('Created new Health ID - Saved Age: ${savedHealthId.age}');
        return savedHealthId;
      } else {
        // Update existing health ID
        await _firestore
            .collection('health_ids')
            .doc(healthId.id)
            .update(updatedHealthId.toFirestore());

        // Update emergency information in 'number' collection
        if (updatedHealthId.phoneNumber != null && updatedHealthId.phoneNumber!.isNotEmpty) {
          await _saveEmergencyInfoToDatabase(updatedHealthId);
        }

        print('Updated existing Health ID - Saved Age: ${updatedHealthId.age}');
        return updatedHealthId;
      }
    } catch (e) {
      print('Error saving health ID: $e');
      return null;
    }
  }

  // Save emergency information to 'healthIds' collection for API lookup
  Future<void> _saveEmergencyInfoToDatabase(HealthIdModel healthId) async {
    try {
      if (healthId.phoneNumber == null || healthId.phoneNumber!.isEmpty) return;

      // Normalize phone number (remove non-digits and +88 prefix)
      final normalizedPhone = healthId.phoneNumber!
          .replaceAll(RegExp(r'[^\d]'), '')
          .replaceAll(RegExp(r'^\+?88'), '');

      print('🔄 Saving to healthIds collection for phone: $normalizedPhone');

      // Format emergency contacts for API
      final emergencyContacts = healthId.emergencyContacts.map((contact) => {
        'name': contact.name,
        'relationship': contact.relationship,
        'phone': contact.phone,
        'email': contact.email,
      }).toList();

      // Prepare data in the format expected by the API
      final apiHealthData = {
        'phoneNumber': normalizedPhone,
        'name': healthId.name,
        'age': healthId.age != null ? int.tryParse(healthId.age!) : null,
        'bloodGroup': healthId.bloodGroup ?? '',
        'address': healthId.address ?? '',
        'allergies': healthId.allergies,
        'emergencyContacts': emergencyContacts,
        'activeMedications': healthId.activeMedications,
        'medicalConditions': healthId.medicalConditions ?? '',
        'notes': healthId.notes ?? '',
        'isActive': true,
        'userId': healthId.userId,
        'healthIdRef': healthId.id, // Reference back to health_ids collection
        'updatedAt': FieldValue.serverTimestamp(),
      };

      // Save to 'healthIds' collection (API uses this collection)
      await _firestore
          .collection('healthIds')
          .doc(normalizedPhone)
          .set(apiHealthData, SetOptions(merge: true));

      print('✅ Health ID saved to healthIds collection for phone: $normalizedPhone');
    } catch (e) {
      print('⚠️ Error saving to healthIds collection: $e');
      // Don't throw - allow health ID save to continue even if API sync fails
    }
  }

  // Get active medications for the user
  Future<List<String>> _getActiveMedications(String userId) async {
    try {
      final querySnapshot = await _firestore
          .collection('medications')
          .where('userId', isEqualTo: userId)
          .where('isActive', isEqualTo: true)
          .get();

      return querySnapshot.docs
          .map((doc) => MedicationModel.fromFirestore(doc))
          .where((med) => med.isActiveAndNotExpired)
          .map((med) => '${med.name} - ${med.dosage}')
          .toList();
    } catch (e) {
      print('Error getting active medications: $e');
      return [];
    }
  }

  // Generate QR code data string
  String generateQRCodeData(HealthIdModel healthId) {
    return jsonEncode(healthId.toQRData());
  }

  // Generate QR code widget
  QrImageView generateQRCode(HealthIdModel healthId, {double size = 200}) {
    final qrData = jsonEncode(healthId.toQRData());
    
    return QrImageView(
      data: qrData,
      version: QrVersions.auto,
      size: size,
      backgroundColor: Colors.white,
      foregroundColor: Colors.black,
    );
  }

  // Save QR code to gallery
  Future<bool> saveQRCodeToGallery(HealthIdModel healthId) async {
    try {
      // For now, we'll just share the QR code instead of saving to gallery
      await shareQRCode(healthId);
      return true;
    } catch (e) {
      print('Error saving QR code: $e');
      return false;
    }
  }

  // Share health ID summary
  Future<void> shareHealthId(HealthIdModel healthId) async {
    try {
      final summary = healthId.generateSummary();
      await Share.share(summary, subject: 'Digital Health ID - ${healthId.name}');
    } catch (e) {
      print('Error sharing health ID: $e');
    }
  }

  // Share QR code
  Future<void> shareQRCode(HealthIdModel healthId) async {
    try {
      final qrData = jsonEncode(healthId.toQRData());
      final qrPainter = QrPainter(
        data: qrData,
        version: QrVersions.auto,
        color: Colors.black,
        emptyColor: Colors.white,
        gapless: true,
      );

      final directory = await getTemporaryDirectory();
      final path = '${directory.path}/health_id_qr.png';
      
      final recorder = PictureRecorder();
      final canvas = Canvas(recorder);
      
      qrPainter.paint(canvas, Size(400, 400));
      
      final picture = recorder.endRecording();
      final image = await picture.toImage(400, 400);
      final byteData = await image.toByteData(format: ImageByteFormat.png);
      final bytes = byteData!.buffer.asUint8List();
      
      await Share.shareXFiles([XFile.fromData(bytes, name: 'health_id_qr.png')], 
          subject: 'Digital Health ID QR Code - ${healthId.name}');
    } catch (e) {
      print('Error sharing QR code: $e');
    }
  }

  // Get blood group options
  List<String> getBloodGroupOptions() {
    return [
      'A+', 'A-', 'B+', 'B-', 'AB+', 'AB-', 'O+', 'O-'
    ];
  }

  // Get common allergies
  List<String> getCommonAllergies() {
    return [
      'Penicillin',
      'Sulfa drugs',
      'Aspirin',
      'Ibuprofen',
      'Codeine',
      'Morphine',
      'Latex',
      'Peanuts',
      'Tree nuts',
      'Milk',
      'Eggs',
      'Soy',
      'Wheat',
      'Fish',
      'Shellfish',
      'Dust',
      'Pollen',
      'Pet dander',
      'Mold',
      'Bee stings',
    ];
  }

  // Fetch health information from API using phone number
  Future<HealthIdModel?> fetchHealthInfoFromAPI(String phoneNumber) async {
    try {
      if (phoneNumber.isEmpty) {
        throw Exception('Phone number is required');
      }

      print('📞 Fetching health info from API for: $phoneNumber');

      final response = await http.get(
        Uri.parse('$_apiBaseUrl/api/person?phoneNumber=$phoneNumber'),
      ).timeout(
        const Duration(seconds: 10),
        onTimeout: () => throw Exception('Request timeout'),
      );

      print('API Response Status: ${response.statusCode}');

      if (response.statusCode == 200) {
        final jsonData = jsonDecode(response.body);
        print('✅ Health info found: ${jsonData['name']}');

        // Convert API response to HealthIdModel
        final healthId = _convertAPIResponseToHealthIdModel(jsonData);
        return healthId;
      } else if (response.statusCode == 404) {
        print('❌ Health ID not found for phone: $phoneNumber');
        throw Exception('Health ID not found for this phone number');
      } else {
        print('❌ API Error: ${response.statusCode}');
        final errorData = jsonDecode(response.body);
        throw Exception(errorData['error'] ?? 'Unknown error occurred');
      }
    } on SocketException catch (e) {
      print('❌ Network error: $e');
      throw Exception('Network error. Make sure the API server is running.');
    } catch (e) {
      print('❌ Error fetching health info: $e');
      rethrow;
    }
  }

  // Convert API response to HealthIdModel
  HealthIdModel _convertAPIResponseToHealthIdModel(Map<String, dynamic> apiData) {
    // Parse emergency contacts
    List<EmergencyContact> emergencyContacts = [];
    if (apiData['emergencyContacts'] != null) {
      emergencyContacts = (apiData['emergencyContacts'] as List)
          .map((contact) => EmergencyContact(
            name: contact['name'] ?? '',
            relationship: contact['relationship'] ?? '',
            phone: contact['phone'] ?? '',
            email: contact['email'],
          ))
          .toList();
    }

    // Create HealthIdModel from API data
    return HealthIdModel(
      id: apiData['id'], // Use API document ID
      userId: _auth.currentUser?.uid ?? 'guest',
      name: apiData['name'] ?? 'Unknown',
      phoneNumber: apiData['phoneNumber'],
      age: apiData['age']?.toString(),
      bloodGroup: apiData['bloodGroup'],
      address: apiData['address'],
      allergies: List<String>.from(apiData['allergies'] ?? []),
      emergencyContacts: emergencyContacts,
      activeMedications: List<String>.from(apiData['activeMedications'] ?? []),
      medicalConditions: apiData['medicalConditions'],
      notes: apiData['notes'],
      createdAt: DateTime.now(),
      updatedAt: apiData['lastUpdated'] != null 
          ? DateTime.parse(apiData['lastUpdated']) 
          : DateTime.now(),
      isActive: true,
    );
  }
} 