import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';

class OtpService {
  static const String _baseUrl = 'https://cbdirfispvyknwmfhwln.supabase.co/functions/v1/otp';

  // Request OTP
  static Future<Map<String, dynamic>> requestOtp(String phoneNumber) async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl?action=request'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'subscriberId': 'tel:$phoneNumber',
          'applicationHash': '', // Optional: Add hash if needed for auto-read
          'applicationMetaData': {
            'client': 'MOBILEAPP',
            'os': 'android',
          }
        }),
      );

      debugPrint('OTP Request Response: ${response.body}');
      
      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        throw Exception('Failed to request OTP: ${response.body}');
      }
    } catch (e) {
      debugPrint('Error requesting OTP: $e');
      rethrow;
    }
  }

  // Verify OTP
  static Future<Map<String, dynamic>> verifyOtp(String referenceNo, String otp) async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl?action=verify'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'referenceNo': referenceNo,
          'otp': otp,
        }),
      );

      debugPrint('OTP Verify Response: ${response.body}');

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        throw Exception('Failed to verify OTP: ${response.body}');
      }
    } catch (e) {
      debugPrint('Error verifying OTP: $e');
      rethrow;
    }
  }
}
