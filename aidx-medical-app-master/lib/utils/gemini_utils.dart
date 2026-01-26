import 'package:aidx/services/gemini_service.dart';

/// Gemini V2 Utilities
/// Common patterns and helpers for Gemini 2.0 Flash integration

class GeminiUtils {
  static final GeminiService _service = GeminiService();

  /// Analyze medical report with error handling
  /// Analyze medical report with error handling
  static Future<Map<String, dynamic>?> safeAnalyzeReport({
    required String description,
    required String reportType,
    int? age,
    String? gender,
    Function(String)? onError,
  }) async {
    try {
      final response = await _service.analyzeMedicalReport(
        description: description,
        reportType: reportType,
        age: age,
        gender: gender,
      );
      return _service.parseReportResponse(response);
    } catch (e) {
      onError?.call(e.toString());
      return null;
    }
  }

  /// Process voice chat with context
  static Future<String?> safeProcessVoiceChat({
    required String message,
    String contextType = 'general',
    List<Map<String, String>>? history,
    Function(String)? onError,
  }) async {
    try {
      return await _service.processVoiceChat(
        userMessage: message,
        contextType: contextType,
        conversationHistory: history,
      );
    } catch (e) {
      onError?.call(e.toString());
      return null;
    }
  }

  /// Get emergency first aid with quick response
  static Future<String?> getQuickEmergencyAid({
    required String situation,
    String severity = 'Critical',
    Function(String)? onError,
  }) async {
    try {
      return await _service.getEmergencyFirstAid(
        situation,
        additionalInfo: 'Severity: $severity',
      );
    } catch (e) {
      onError?.call(e.toString());
      return null;
    }
  }

  /// Get health insights with focus area
  static Future<String?> getQuickHealthInsights({
    required Map<String, dynamic> healthData,
    String focusArea = 'general',
    Function(String)? onError,
  }) async {
    try {
      return await _service.getHealthInsights(
        healthData: healthData,
        focusArea: focusArea,
      );
    } catch (e) {
      onError?.call(e.toString());
      return null;
    }
  }

  /// Format medical analysis result for display
  static String formatAnalysisResult(Map<String, dynamic> result) {
    StringBuffer sb = StringBuffer();

    if (result['severity'] != null) {
      sb.writeln('🏥 Severity: ${result['severity']}');
      sb.writeln('');
    }

    if (result['summary'] != null) {
      sb.writeln('📋 Summary:');
      sb.writeln(result['summary']);
      sb.writeln('');
    }

    if (result['findings'] != null) {
      sb.writeln('🔍 Findings:');
      _formatList(result['findings']).forEach((item) => sb.writeln('  • $item'));
      sb.writeln('');
    }

    if (result['recommendations'] != null) {
      sb.writeln('✅ Recommendations:');
      _formatList(result['recommendations'])
          .forEach((item) => sb.writeln('  • $item'));
      sb.writeln('');
    }

    if (result['next_steps'] != null) {
      sb.writeln('➡️ Next Steps:');
      _formatList(result['next_steps']).forEach((item) => sb.writeln('  • $item'));
      sb.writeln('');
    }

    if (result['alerts'] != null && (_formatList(result['alerts']).isNotEmpty)) {
      sb.writeln('⚠️ Alerts:');
      _formatList(result['alerts']).forEach((item) => sb.writeln('  ⛔ $item'));
    }

    return sb.toString();
  }

  /// Format insights for display
  static String formatHealthInsights(String insights) {
    // Try to parse JSON if available
    try {
      if (insights.contains('{')) {
        final jsonStr = insights.substring(
          insights.indexOf('{'),
          insights.lastIndexOf('}') + 1,
        );
        // Return formatted JSON insights
        return jsonStr;
      }
    } catch (e) {
      // Return as-is if not JSON
    }
    return insights;
  }

  /// Format emergency aid response
  static String formatEmergencyResponse(String response) {
    StringBuffer sb = StringBuffer();
    sb.writeln('🚨 EMERGENCY RESPONSE 🚨');
    sb.writeln('');
    sb.writeln(response);
    sb.writeln('');
    sb.writeln('⚠️ If this is life-threatening, CALL EMERGENCY SERVICES NOW');
    return sb.toString();
  }

  /// Severity to color mapping
  static int getSeverityColor(String? severity) {
    switch (severity?.toLowerCase()) {
      case 'critical':
        return 0xFFD32F2F; // Red 700
      case 'high':
      case 'severe':
        return 0xFFF57C00; // Orange 700
      case 'moderate':
        return 0xFFFBC02D; // Amber
      case 'low':
      case 'minor':
        return 0xFF388E3C; // Green
      default:
        return 0xFF9E9E9E; // Grey
    }
  }

  /// Helper to convert lists to formatted strings
  static List<String> _formatList(dynamic items) {
    if (items is List) {
      return items.map((e) => e.toString().trim()).toList();
    } else if (items is String) {
      return items
          .split('\n')
          .map((e) => e.trim())
          .where((e) => e.isNotEmpty)
          .toList();
    }
    return [];
  }

  /// Validate medical report inputs
  static Map<String, String> validateReportInputs({
    required String description,
    required String reportType,
  }) {
    Map<String, String> errors = {};

    if (description.trim().isEmpty) {
      errors['description'] = 'Please enter report details';
    }

    if (reportType.trim().isEmpty) {
      errors['reportType'] = 'Please select report type';
    }

    if (description.length < 10) {
      errors['description'] =
          'Please provide more details (at least 10 characters)';
    }

    return errors;
  }

  /// Validate voice chat inputs
  static String? validateVoiceMessage(String message) {
    if (message.trim().isEmpty) {
      return 'Please enter a message';
    }
    if (message.length < 3) {
      return 'Message too short';
    }
    if (message.length > 1000) {
      return 'Message too long (max 1000 characters)';
    }
    return null;
  }

  /// Create emergency context message
  static String createEmergencyContext(String situation) {
    return '''
EMERGENCY SITUATION: $situation

RESPOND WITH:
1. IMMEDIATE ACTIONS (numbered steps)
2. DO NOT (critical don't-do items)
3. CALL EMERGENCY: yes/no
4. RECOVERY TIME: estimate

Be URGENT and CLEAR. Save lives.
''';
  }

  /// Create consultation context message
  static String createConsultationContext(String topic) {
    return '''
HEALTH CONSULTATION: $topic

RESPOND WITH:
1. What you need to know
2. Questions to ask your doctor
3. When to seek professional help
4. Preventive measures

Be thorough, empathetic, and professional.
''';
  }

  /// Parse medical severity
  static String parseSeverity(String response) {
    final severities = ['critical', 'high', 'moderate', 'low', 'minor', 'severe'];
    for (final sev in severities) {
      if (response.toLowerCase().contains(sev)) {
        return sev[0].toUpperCase() + sev.substring(1);
      }
    }
    return 'Unknown';
  }

  /// Check if response requires emergency
  static bool requiresEmergency(String response) {
    final emergencyKeywords = [
      'emergency',
      'call 911',
      'call ambulance',
      'immediate',
      'critical',
      'life-threatening',
      'unconscious',
      'severe bleeding',
      'chest pain',
      'difficulty breathing'
    ];

    final lower = response.toLowerCase();
    return emergencyKeywords.any((keyword) => lower.contains(keyword));
  }

  /// Generate report summary for export
  static String generateReportSummary({
    required String reportType,
    required int? age,
    required String? gender,
    required Map<String, dynamic> analysis,
    required DateTime timestamp,
  }) {
    StringBuffer sb = StringBuffer();
    sb.writeln('═══════════════════════════════════');
    sb.writeln('MEDICAL REPORT ANALYSIS SUMMARY');
    sb.writeln('═══════════════════════════════════');
    sb.writeln('');
    sb.writeln('Report Type: $reportType');
    sb.writeln('Patient Age: ${age ?? "Not specified"}');
    sb.writeln('Patient Gender: ${gender ?? "Not specified"}');
    sb.writeln('Analysis Date: ${timestamp.toString()}');
    sb.writeln('');
    sb.writeln(formatAnalysisResult(analysis));
    sb.writeln('');
    sb.writeln('═══════════════════════════════════');
    sb.writeln('Medical Disclaimer: This analysis is AI-generated for');
    sb.writeln('informational purposes only. Always consult a healthcare');
    sb.writeln('professional for medical advice.');
    sb.writeln('═══════════════════════════════════');

    return sb.toString();
  }
}
