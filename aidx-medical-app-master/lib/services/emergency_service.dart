import 'dart:convert';
import 'package:http/http.dart' as http;

class EmergencyService {
  // Replace with your actual API endpoint when deployed to Firebase Functions
  // For now, using localhost for development
  static const String _baseUrl = 'http://10.0.2.2:3000'; // Android emulator localhost
  // For physical device, use your computer's IP: 'http://192.168.1.xxx:3000'

  static const String _apiPersonEndpoint = '/api/person';

  /// Fetch emergency information for a phone number
  Future<Map<String, dynamic>?> getEmergencyInfo(String phoneNumber) async {
    try {
      final url = Uri.parse('$_baseUrl$_apiPersonEndpoint');

      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'phoneNumber': phoneNumber,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data;
      } else if (response.statusCode == 404) {
        throw Exception('Phone number not found in emergency database');
      } else {
        throw Exception('Failed to fetch emergency information: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Network error: $e');
    }
  }

  /// Validate phone number format
  bool isValidPhoneNumber(String phoneNumber) {
    // Remove all non-digit characters
    final cleaned = phoneNumber.replaceAll(RegExp(r'[^\d]'), '');

    // Check if it has at least 8 digits (reasonable minimum for phone numbers)
    return cleaned.length >= 8;
  }

  /// Format phone number for display
  String formatPhoneNumber(String phoneNumber) {
    final cleaned = phoneNumber.replaceAll(RegExp(r'[^\d]'), '');

    if (cleaned.length >= 10) {
      // Format as +X (XXX) XXX-XXXX for US numbers
      if (cleaned.length == 10) {
        return '+1 (${cleaned.substring(0, 3)}) ${cleaned.substring(3, 6)}-${cleaned.substring(6)}';
      } else if (cleaned.length == 11 && cleaned.startsWith('1')) {
        final number = cleaned.substring(1);
        return '+1 (${number.substring(0, 3)}) ${number.substring(3, 6)}-${number.substring(6)}';
      }
    }

    // Return as-is with + prefix if it doesn't start with +
    return phoneNumber.startsWith('+') ? phoneNumber : '+$phoneNumber';
  }
}