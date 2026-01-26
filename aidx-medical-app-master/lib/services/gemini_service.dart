import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'dart:math';
import 'dart:async';
import 'package:flutter/foundation.dart';
import '../utils/constants.dart';
import '../utils/toon_converter.dart';

class GeminiService {
  // Groq API configuration
  static String get _apiKey {
    // Try to get from environment variable first
    final envKey = Platform.environment['GROQ_API_KEY'];
    if (envKey != null && envKey.isNotEmpty) {
      return envKey;
    }
    // Fallback to AppConstants
    return AppConstants.groqApiKey;
  }
  static const String _model = 'llama-3.3-70b-versatile';
  static const String _visionModel = 'meta-llama/llama-4-scout-17b-16e-instruct'; 
  static const String _userSpecifiedVisionModel = 'meta-llama/llama-4-scout-17b-16e-instruct';
  
  static const String _endpoint = 'https://api.groq.com/openai/v1/chat/completions';

  final List<Function(String)> _listeners = [];

  void addListener(Function(String) listener) => _listeners.add(listener);
  void removeListener(Function(String) listener) => _listeners.remove(listener);
  void _notify(String message) {
    for (final listener in _listeners) {
      listener(message);
    }
  }

  void _logError(String message, [Object? error, StackTrace? stackTrace]) {
    debugPrint('[GeminiService] $message');
    if (error != null) debugPrint('Error: $error');
    if (stackTrace != null) debugPrint('StackTrace: $stackTrace');
  }

  Future<String> analyzeMedicalReport({
    required String description,
    required String reportType,
    int? age,
    String? gender,
    bool imageAttached = false,
    File? imageFile,
    Uint8List? imageBytes,
    String? imageMimeType,
  }) async {
    if (_apiKey.isEmpty) throw Exception('Groq API key not configured');

    final systemPrompt = '''Medical Report Analyzer. Return ONLY this TOON format:
reportSummary: brief overview
keyFindings:
  - finding1
  - finding2
medicalRecommendations:
  - advice1
  - advice2
nextSteps:
  - action1
  - action2
severity: normal|abnormal|critical
Rules: Concise, patient-friendly, valid TOON format only.''';

    final userPrompt = '''
Report Type: $reportType
Patient: Age: ${age ?? 'Not specified'}, Gender: ${gender ?? 'Not specified'}
Report Details:
${description.trim().isEmpty ? 'Please provide report details.' : description.trim()}''';

    List<Map<String, dynamic>> messages;
    String modelToUse = _model;

    if (imageAttached && (imageFile != null || imageBytes != null)) {
      modelToUse = _userSpecifiedVisionModel;
      String base64Image;
      if (imageBytes != null) {
        base64Image = base64Encode(imageBytes);
      } else {
        base64Image = base64Encode(await imageFile!.readAsBytes());
      }

      messages = [
        {
          'role': 'user',
          'content': [
            {'type': 'text', 'text': '$systemPrompt\n\n$userPrompt'},
            {
              'type': 'image_url',
              'image_url': {
                'url': 'data:${imageMimeType ?? "image/jpeg"};base64,$base64Image'
              }
            }
          ]
        }
      ];
    } else {
      messages = [
        {'role': 'user', 'content': '$systemPrompt\n\n$userPrompt'}
      ];
    }

    final body = {
      'model': modelToUse,
      'messages': messages,
      'temperature': 0.1,
      'max_tokens': 300,
    };

    final uri = Uri.parse(_endpoint);
    int retries = 0;
    const maxRetries = 3;

    while (retries < maxRetries) {
      try {
        final res = await http.post(
          uri,
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $_apiKey',
          },
          body: jsonEncode(body),
        ).timeout(const Duration(seconds: 30));

        if (res.statusCode != 200) {
          String msg = 'API error (${res.statusCode})';
          try {
            final err = jsonDecode(res.body);
            final em = err['error']?['message'];
            if (em is String && em.isNotEmpty) msg = 'API error: $em';
          } catch (_) {}
          throw Exception(msg);
        }

        final data = jsonDecode(res.body);
        String? text = data['choices']?[0]?['message']?['content'];
        if (text == null || text.trim().isEmpty) {
          throw Exception('Empty response from API');
        }
        return text.trim();
      } catch (e, st) {
        retries++;
        _logError('Attempt $retries failed', e, st);
        if (retries >= maxRetries) {
          return '{"summary":"Unable to analyze report","findings":"Error: $e","recommendations":"","next_steps":""}';
        }
        await Future.delayed(Duration(seconds: pow(2, retries).toInt()));
      }
    }
    return '{"summary":"Unable to analyze report","findings":"","recommendations":"","next_steps":""}';
  }

  Map<String, dynamic> parseReportResponse(String text) {
    print('🔍 Raw Report Response: $text');
    final result = <String, dynamic>{
      'summary': '',
      'findings': '',
      'recommendations': '',
      'next_steps': '',
    };

    try {
      final dynamic decoded = ToonConverter.decode(text);
      if (decoded is Map) {
        final Map<String, dynamic> parsed = Map<String, dynamic>.from(decoded);
        print('📋 Parsed Report Keys: ${parsed.keys.toList()}');

        // Helper to find value by key or common aliases
        dynamic getValue(List<String> keys) {
          for (final k in keys) {
            // Check exact match
            if (parsed.containsKey(k)) return parsed[k];
            // Check normalized match (lowercase, no markdown)
            for (final actualKey in parsed.keys) {
              final normalized = actualKey.toLowerCase().replaceAll('*', '').trim();
              if (normalized == k.toLowerCase()) return parsed[actualKey];
            }
          }
          return null;
        }

        result['summary'] = _formatReportField(getValue(['reportSummary', 'summary', 'overview', 'report_summary', 'analysis_summary']));
        result['findings'] = _formatReportField(getValue(['keyFindings', 'findings', 'key_findings', 'observations', 'results']));
        result['recommendations'] = _formatReportField(getValue(['medicalRecommendations', 'recommendations', 'advice', 'suggestions', 'medical_advice']));
        result['next_steps'] = _formatReportField(getValue(['nextSteps', 'next_steps', 'follow_up', 'actions', 'plan']));
        result['severity'] = (getValue(['severity']) ?? 'normal').toString().toLowerCase();
      }
    } catch (e) {
      _logError('Error parsing TOON response', e);
    }

    // Fallback: Regex parsing if fields are still empty
    if (result['summary']!.isEmpty) {
      result['summary'] = _extractWithRegex(text, r'(?:reportSummary|summary|overview|report summary):\s*(.*?)(?=\n\w+:|$)');
    }
    if (result['findings']!.isEmpty) {
      result['findings'] = _extractWithRegex(text, r'(?:keyFindings|findings|key findings|observations|results):\s*(.*?)(?=\n\w+:|$)');
    }
    if (result['recommendations']!.isEmpty) {
      result['recommendations'] = _extractWithRegex(text, r'(?:medicalRecommendations|recommendations|advice|suggestions):\s*(.*?)(?=\n\w+:|$)');
    }
    if (result['next_steps']!.isEmpty) {
      result['next_steps'] = _extractWithRegex(text, r'(?:nextSteps|next steps|follow up|actions|plan):\s*(.*?)(?=\n\w+:|$)');
    }
    if (result['severity'] == null || result['severity']!.isEmpty) {
      result['severity'] = _extractWithRegex(text, r'severity:\s*(normal|abnormal|critical)');
      if (result['severity']!.isEmpty) result['severity'] = 'normal';
    }

    // Final cleanup: if everything is empty, use the whole text as summary
    if (result.values.every((v) => v.toString().isEmpty)) {
      result['summary'] = text.trim();
    }

    return result;
  }

  String _extractWithRegex(String text, String pattern) {
    try {
      final reg = RegExp(pattern, caseSensitive: false, dotAll: true);
      final match = reg.firstMatch(text);
      if (match != null && match.groupCount >= 1) {
        final content = match.group(1)?.trim() ?? '';
        // If it looks like a list, format it
        if (content.contains('\n-') || content.contains('\n•')) {
           final lines = content.split('\n')
            .map((l) => l.trim())
            .where((l) => l.startsWith('-') || l.startsWith('•'))
            .map((l) => l.substring(1).trim())
            .toList();
           if (lines.isNotEmpty) return lines.map((l) => '• $l').join('\n');
        }
        return content;
      }
    } catch (_) {}
    return '';
  }

  String _formatReportField(dynamic value) {
    if (value == null) return '';
    if (value is List) {
      return value.map((e) => '• $e').join('\n');
    }
    return value.toString();
  }

  Future<String> sendMessage(String userInput, {String? conversationContext}) async {
    if (_apiKey.isEmpty) throw Exception('Groq API key not configured');

    String prompt = '''
You are Aidx, a direct medical assistant. Give brief, direct answers.

${conversationContext != null ? 'CONTEXT:\n$conversationContext\n' : ''}

User: $userInput

INSTRUCTIONS:
1. Maximum 50 words - be extremely concise
2. NO markdown, NO extra text
3. Answer medical questions directly
4. Skip pleasantries and chit-chat
5. Focus on facts and advice only
''';

    final body = {
      'model': _model,
      'messages': [
        {'role': 'user', 'content': prompt}
      ],
      'temperature': 0.3,
      'max_tokens': 50,
      'top_p': 0.7,
    };

    int retries = 0;
    const maxRetries = 3;

    while (retries < maxRetries) {
      try {
        final response = await http.post(
          Uri.parse(_endpoint),
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $_apiKey',
          },
          body: jsonEncode(body),
        ).timeout(const Duration(seconds: 30));

        if (response.statusCode != 200) {
          throw Exception('API error (${response.statusCode})');
        }

        final data = jsonDecode(response.body);
        final content = data['choices']?[0]?['message']?['content'];
        if (content == null || content.toString().trim().isEmpty) {
          throw Exception('Empty response');
        }
        return content.toString().trim();
      } catch (e, st) {
        retries++;
        _logError('sendMessage attempt $retries failed', e, st);
        if (retries >= maxRetries) {
          return "I'm having trouble connecting right now. Please try again.";
        }
        await Future.delayed(Duration(seconds: retries));
      }
    }
    return "Service temporarily unavailable.";
  }

  Stream<String> streamMessage(String userInput, {String? conversationContext}) async* {
    if (_apiKey.isEmpty) {
      yield "API key not configured";
      return;
    }

    String prompt = '''
You are Aidx, a medical assistant. Maximum 50 words.

${conversationContext != null ? 'CONTEXT:\n$conversationContext\n' : ''}

User: $userInput

Be brief and direct. No markdown. Max 50 words.
''';

    final body = {
      'model': _model,
      'messages': [
        {'role': 'user', 'content': prompt}
      ],
      'temperature': 0.3,
      'max_tokens': 50,
      'stream': true,
    };

    try {
      final request = http.Request('POST', Uri.parse(_endpoint));
      request.headers['Content-Type'] = 'application/json';
      request.headers['Authorization'] = 'Bearer $_apiKey';
      request.body = jsonEncode(body);

      final streamedResponse = await request.send().timeout(const Duration(seconds: 30));

      if (streamedResponse.statusCode != 200) {
        yield "Error: Unable to connect to chat service";
        return;
      }

      String buffer = '';
      await for (final chunk in streamedResponse.stream.transform(utf8.decoder)) {
        buffer += chunk;
        final lines = buffer.split('\n');
        buffer = lines.removeLast();

        for (final line in lines) {
          if (line.startsWith('data: ')) {
            final data = line.substring(6).trim();
            if (data == '[DONE]') continue;
            try {
              final json = jsonDecode(data);
              final content = json['choices']?[0]?['delta']?['content'];
              if (content != null && content.toString().isNotEmpty) {
                yield content.toString();
              }
            } catch (_) {}
          }
        }
      }
    } catch (e, st) {
      _logError('streamMessage failed', e, st);
      yield "\n\nConnection error. Please try again.";
    }
  }

  Future<String> analyzeSymptoms({
    required List<String> symptoms,
    required String? age,
    required String? gender,
    required String? duration,
    required String? intensity,
    String? medicalHistory,
    bool imageAttached = false,
    File? imageFile,
    Uint8List? imageBytes,
    String? imageMimeType,
  }) async {
    if (_apiKey.isEmpty) throw Exception('Groq API key not configured');

    final systemPrompt = '''Medical Symptom Analyzer. Return ONLY this TOON format:
possibleConditions:
  - condition: Name of condition, probability: XX%
  - condition: Name of condition, probability: XX%
severity: minor|moderate|severe|critical
immediateActions:
  - action1
  - action2
recommendations:
  - rec1
  - rec2
otcMedicines:
  - "Medicine Name: Dosage"
  - "Medicine Name: Dosage"
homeRemedies:
  - remedy1
  - remedy2
whenToSeekHelp: guidance
Rules: 
1. Analyze the provided symptoms AND any attached image carefully.
2. Provide 2-3 possible conditions with estimated probability percentages based on the visual and textual evidence.
3. If an image is provided, prioritize visual signs in your analysis.
4. For otcMedicines, return a LIST OF STRINGS in the format "Name: Dosage". Suggest only safe over-the-counter medications.
5. For homeRemedies, return a LIST OF STRINGS. Suggest practical and safe home treatments.
6. Return ONLY valid TOON format.
7. Be medically accurate but patient-friendly.''';

    final userPrompt = '''
Symptoms: ${symptoms.join(', ')}
Age: ${age ?? 'Not specified'}
Gender: ${gender ?? 'Not specified'}
Duration: ${duration ?? 'Not specified'}
Intensity: ${intensity ?? 'Not specified'}
Medical History: ${medicalHistory ?? 'None'}
${imageAttached ? 'Note: An image of the symptoms is attached. Please analyze the visual appearance of the symptoms in the image.' : ''}

Analyze and provide possible conditions with probabilities.''';

    List<Map<String, dynamic>> messages;
    String modelToUse = _model;

    if (imageAttached && (imageFile != null || imageBytes != null)) {
      modelToUse = _userSpecifiedVisionModel;
      String base64Image;
      if (imageBytes != null) {
        base64Image = base64Encode(imageBytes);
      } else {
        base64Image = base64Encode(await imageFile!.readAsBytes());
      }

      messages = [
        {
          'role': 'user',
          'content': [
            {'type': 'text', 'text': '$systemPrompt\n\n$userPrompt'},
            {
              'type': 'image_url',
              'image_url': {
                'url': 'data:${imageMimeType ?? "image/jpeg"};base64,$base64Image'
              }
            }
          ]
        }
      ];
    } else {
      messages = [
        {'role': 'user', 'content': '$systemPrompt\n\n$userPrompt'}
      ];
    }
    
    final body = {
      'model': modelToUse,
      'messages': messages,
      'temperature': 0.1,
      'max_tokens': 400,
    };

    final uri = Uri.parse(_endpoint);
    int retries = 0;
    const maxRetries = 3;

    while (retries < maxRetries) {
      try {
        final res = await http.post(
          uri,
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $_apiKey',
          },
          body: jsonEncode(body),
        ).timeout(const Duration(seconds: 30));

        if (res.statusCode != 200) {
           throw Exception('API error (${res.statusCode})');
        }

        final data = jsonDecode(res.body);
        String? text = data['choices']?[0]?['message']?['content'];
        if (text == null || text.trim().isEmpty) {
          throw Exception('Empty response from API');
        }
        return text.trim();
      } catch (e, st) {
        retries++;
        _logError('analyzeSymptoms attempt $retries failed', e, st);
        if (retries >= maxRetries) {
             // Return generic error fallback so user knows analysis failed
             return '''possibleConditions:
  - condition: Analysis Failed, probability: 0%
severity: unknown
immediateActions:
  - Check internet connection
  - Try again later
recommendations:
  - Ensure image is clear
whenToSeekHelp: If symptoms persist, see a doctor.''';
        }
        await Future.delayed(Duration(seconds: pow(2, retries).toInt()));
      }
    }
    return ''; 
  }

  Future<String> analyzePrescription({
    required Uint8List imageBytes,
    String? imageMimeType,
  }) async {
    if (_apiKey.isEmpty) throw Exception('Groq API key not configured');

    final systemPrompt = '''Prescription Analyzer. Return ONLY this TOON format:
medications:
- name: Medicine Name
  dosage: dosage (e.g. 500mg)
  frequency: frequency (e.g. 2 times daily)
  timing: timing (e.g. after meals)
  duration: duration (e.g. 5 days)
  type: tablet|syrup|injection|other
notes: any special instructions
Rules:
1. Extract ALL medications visible in the prescription.
2. Be precise with dosages and frequencies.
3. If a field is not visible, use "Not specified".
4. Return ONLY valid TOON format.''';

    final userPrompt = 'Analyze this prescription image and extract medication details.';

    String base64Image = base64Encode(imageBytes);
    
    final messages = [
      {
        'role': 'user',
        'content': [
          {'type': 'text', 'text': '$systemPrompt\n\n$userPrompt'},
          {
            'type': 'image_url',
            'image_url': {
              'url': 'data:${imageMimeType ?? "image/jpeg"};base64,$base64Image'
            }
          }
        ]
      }
    ];

    final body = {
      'model': _userSpecifiedVisionModel,
      'messages': messages,
      'temperature': 0.1,
      'max_tokens': 1000,
    };

    try {
      final res = await http.post(
        Uri.parse(_endpoint),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $_apiKey',
        },
        body: jsonEncode(body),
      ).timeout(const Duration(seconds: 45));

      if (res.statusCode != 200) {
        throw Exception('API error (${res.statusCode})');
      }

      final data = jsonDecode(res.body);
      String? text = data['choices']?[0]?['message']?['content'];
      if (text == null || text.trim().isEmpty) {
        throw Exception('Empty response from API');
      }
      return text.trim();
    } catch (e, st) {
      _logError('analyzePrescription failed', e, st);
      rethrow;
    }
  }

  Map<String, dynamic> parseResponse(String text) {
    try {
      final dynamic parsed = ToonConverter.decode(text);
      if (parsed is Map<String, dynamic>) {
        // Handle possibleConditions which might be a list of strings or maps
        var conditions = parsed['possibleConditions'] ?? [];
        if (conditions is List && conditions.isNotEmpty) {
           conditions = conditions.map((c) {
             if (c is Map) return c;
             if (c is String) {
               // Try to extract condition and probability from string
               // Format: "condition: Name, probability: 60%"
               String name = c;
               String prob = '?';
               
               final condMatch = RegExp(r'condition:\s*([^,]+)').firstMatch(c);
               if (condMatch != null) {
                 name = condMatch.group(1)?.trim() ?? c;
               }
               
               final probMatch = RegExp(r'probability:\s*([^%]+%?)').firstMatch(c);
               if (probMatch != null) {
                 prob = probMatch.group(1)?.trim() ?? '?';
               }
               
               // Cleanup name if it still has labels
               name = name.replaceAll(RegExp(r'probability:.*'), '').trim();
               if (name.endsWith(',')) name = name.substring(0, name.length - 1).trim();
               
               return {'condition': name, 'probability': prob};
             }
             return {'condition': c.toString(), 'probability': '?'};
           }).toList();
        }

        return {
          'possibleConditions': conditions,
          'severity': (parsed['severity'] ?? 'unknown').toString(),
          'immediateActions': _parseList(parsed['immediateActions']),
          'recommendations': _parseList(parsed['recommendations']),
          'otcMedicines': _parseList(parsed['otcMedicines']),
          'homeRemedies': _parseList(parsed['homeRemedies']),
          'whenToSeekHelp': (parsed['whenToSeekHelp'] ?? '').toString(),
        };
      }
    } catch (e) {
      _logError('Error parsing TOON response', e);
    }

    return {
      'possibleConditions': [],
    };
  }

  Map<String, dynamic> parsePrescriptionResponse(String text) {
    try {
      final dynamic parsed = ToonConverter.decode(text);
      if (parsed is Map<String, dynamic>) {
        var medications = parsed['medications'] ?? [];
        if (medications is List) {
          medications = medications.map((m) {
            if (m is Map) {
              return {
                'name': m['name']?.toString() ?? 'Unknown',
                'dosage': m['dosage']?.toString() ?? '',
                'frequency': m['frequency']?.toString() ?? '',
                'timing': m['timing']?.toString() ?? '',
                'duration': m['duration']?.toString() ?? '',
                'type': m['type']?.toString() ?? 'tablet',
              };
            }
            return {'name': m.toString()};
          }).toList();
        }

        return {
          'medications': medications,
          'notes': parsed['notes']?.toString() ?? '',
        };
      }
    } catch (e) {
      _logError('Error parsing prescription TOON', e);
    }

    return {'medications': [], 'notes': ''};
  }

  Future<String> getEmergencyFirstAid({
    required String situation,
    String? additionalInfo,
    Uint8List? imageBytes,
    String? imageMimeType,
  }) async {
    if (_apiKey.isEmpty) throw Exception('Groq API key not configured');

    final systemPrompt = '''Emergency First Aid Guide. Return ONLY this TOON format:
severity: minor|moderate|severe|critical
condition: diagnosis
immediateActions:
- step1
- step2
warnings:
- warning1
whenToSeekHelp: guidance
additionalTips:
- tip1
Rules:
1. Analyze the situation AND any provided image.
2. Prioritize life-saving actions.
3. Be clear, concise, and safety-focused.
4. Return ONLY valid TOON format.''';

    final userPrompt = '''
Emergency Situation: $situation
${additionalInfo != null ? 'Additional Info: $additionalInfo' : ''}

Provide first aid guidance.''';

    List<Map<String, dynamic>> messages;
    String modelToUse = _model;

    if (imageBytes != null) {
      modelToUse = _userSpecifiedVisionModel;
      String base64Image = base64Encode(imageBytes);
      messages = [
        {
          'role': 'user',
          'content': [
            {'type': 'text', 'text': '$systemPrompt\n\n$userPrompt'},
            {
              'type': 'image_url',
              'image_url': {
                'url': 'data:${imageMimeType ?? "image/jpeg"};base64,$base64Image'
              }
            }
          ]
        }
      ];
    } else {
      messages = [
        {'role': 'user', 'content': '$systemPrompt\n\n$userPrompt'}
      ];
    }

    final body = {
      'model': modelToUse,
      'messages': messages,
      'temperature': 0.1,
      'max_tokens': 500,
    };

    try {
      final res = await http.post(
        Uri.parse(_endpoint),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $_apiKey',
        },
        body: jsonEncode(body),
      ).timeout(const Duration(seconds: 45));

      if (res.statusCode != 200) {
        throw Exception('API error (${res.statusCode})');
      }

      final data = jsonDecode(res.body);
      String? text = data['choices']?[0]?['message']?['content'];
      if (text == null || text.trim().isEmpty) {
        throw Exception('Empty response');
      }
      return text.trim();
    } catch (e, st) {
      _logError('getEmergencyFirstAid failed', e, st);
      rethrow;
    }
  }

  Map<String, dynamic> parseFirstAidResponse(String text) {
    try {
      final dynamic parsed = ToonConverter.decode(text);
      if (parsed is Map<String, dynamic>) {
        return {
          'severity': parsed['severity']?.toString() ?? 'unknown',
          'condition': parsed['condition']?.toString() ?? 'Unknown Condition',
          'immediateActions': _parseList(parsed['immediateActions']),
          'warnings': _parseList(parsed['warnings']),
          'whenToSeekHelp': parsed['whenToSeekHelp']?.toString() ?? '',
          'additionalTips': _parseList(parsed['additionalTips']),
        };
      }
    } catch (e) {
      _logError('Error parsing first aid TOON', e);
    }

    return {
      'severity': 'unknown',
      'condition': 'Analysis Failed',
      'immediateActions': <String>[],
      'warnings': <String>[],
      'whenToSeekHelp': '',
      'additionalTips': <String>[],
    };
  }

  Future<Map<String, dynamic>> searchDrug(String drugName, {bool brief = true}) async {
    if (_apiKey.isEmpty) throw Exception('Groq API key not configured');

    final systemPrompt = brief
        ? '''Drug Information (Brief). Return ONLY this TOON format:
name: brand name
genericName: generic name
uses: primary use
dosage: typical dose
sideEffects:
  - effect1
  - effect2'''
        : '''Drug Information (Detailed). Return ONLY this TOON format:
name: brand name
genericName: generic name
uses: detailed uses
dosage: dosage info
sideEffects:
  - effect1
  - effect2
warnings:
  - warning1
interactions:
  - interaction1
precautions: precautions''';

    final userPrompt = 'Drug: $drugName\n\nProvide ${brief ? "brief" : "detailed"} information.';

    final body = {
      'model': _model,
      'messages': [
        {'role': 'user', 'content': '$systemPrompt\n\n$userPrompt'}
      ],
      'temperature': 0.1,
      'max_tokens': brief ? 200 : 400,
    };

    int retries = 0;
    const maxRetries = 3;

    while (retries < maxRetries) {
      try {
        final res = await http.post(
          Uri.parse(_endpoint),
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $_apiKey',
          },
          body: jsonEncode(body),
        ).timeout(const Duration(seconds: 30));

        if (res.statusCode != 200) {
          throw Exception('API error (${res.statusCode})');
        }

        final data = jsonDecode(res.body);
        String? text = data['choices']?[0]?['message']?['content'];
        if (text == null || text.trim().isEmpty) {
          throw Exception('Empty response');
        }

        final Map<String, dynamic>? parsed = ToonConverter.decode(text.trim()) as Map<String, dynamic>?;
        if (parsed != null) {
          return {
            'name': (parsed['name'] ?? drugName).toString(),
            'generic_formula': (parsed['genericName'] ?? '').toString(),
            'uses': (parsed['uses'] ?? '').toString(),
            'dosage': (parsed['dosage'] ?? '').toString(),
            'side_effects': _parseList(parsed['sideEffects']).join('\n• '),
            'warnings': _parseList(parsed['warnings']).join('\n• '),
            'interactions': _parseList(parsed['interactions']).join('\n• '),
            'precautions': (parsed['precautions'] ?? '').toString(),
          };
        }

        return {
          'name': drugName,
          'generic_formula': '',
          'uses': text.trim(),
          'dosage': '',
          'side_effects': '',
          'warnings': '',
          'interactions': '',
          'precautions': '',
        };
      } catch (e, st) {
        retries++;
        _logError('searchDrug attempt $retries failed', e, st);
        if (retries >= maxRetries) {
          return {
            'name': drugName,
            'generic_formula': '',
            'uses': 'Unable to fetch information',
            'dosage': '',
            'side_effects': '',
            'warnings': '',
            'interactions': '',
            'precautions': '',
          };
        }
        await Future.delayed(Duration(seconds: retries));
      }
    }
    return {
      'name': drugName,
      'generic_formula': '',
      'uses': 'Service error',
      'dosage': '',
      'side_effects': '',
      'warnings': '',
      'interactions': '',
      'precautions': '',
    };
  }

  Future<String> generateDrugInsight(String drugName, String question) async {
    if (_apiKey.isEmpty) throw Exception('Groq API key not configured');

    final prompt = 'Drug: $drugName\nQuestion: $question\n\nProvide a concise, accurate answer.';

    final body = {
      'model': _model,
      'messages': [
        {'role': 'user', 'content': prompt}
      ],
      'temperature': 0.3,
      'max_tokens': 150,
    };

    try {
      final res = await http.post(
        Uri.parse(_endpoint),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $_apiKey',
        },
        body: jsonEncode(body),
      ).timeout(const Duration(seconds: 30));

      if (res.statusCode != 200) {
        throw Exception('API error');
      }

      final data = jsonDecode(res.body);
      String? text = data['choices']?[0]?['message']?['content'];
      return text?.trim() ?? 'Unable to generate insight';
    } catch (e, st) {
      _logError('generateDrugInsight failed', e, st);
      return 'Unable to generate insight. Please try again.';
    }
  }

  Future<String> askWithImage({
    required String question,
    Uint8List? imageBytes,
    File? imageFile,
    String? imageMimeType,
  }) async {
    if (_apiKey.isEmpty) throw Exception('Groq API key not configured');

    List<Map<String, dynamic>> messages;
    String modelToUse = _model;

    if (imageBytes != null || imageFile != null) {
      modelToUse = _userSpecifiedVisionModel;
      String base64Image;
      if (imageBytes != null) {
        base64Image = base64Encode(imageBytes);
      } else {
        base64Image = base64Encode(await imageFile!.readAsBytes());
      }

      messages = [
        {
          'role': 'user',
          'content': [
            {'type': 'text', 'text': question},
            {
              'type': 'image_url',
              'image_url': {
                'url': 'data:${imageMimeType ?? "image/jpeg"};base64,$base64Image'
              }
            }
          ]
        }
      ];
    } else {
      messages = [
        {'role': 'user', 'content': question}
      ];
    }

    final body = {
      'model': modelToUse,
      'messages': messages,
      'temperature': 0.3,
      'max_tokens': 300,
    };

    try {
      final res = await http.post(
        Uri.parse(_endpoint),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $_apiKey',
        },
        body: jsonEncode(body),
      ).timeout(const Duration(seconds: 30));

      if (res.statusCode != 200) {
        throw Exception('API error (${res.statusCode})');
      }

      final data = jsonDecode(res.body);
      String? text = data['choices']?[0]?['message']?['content'];
      if (text == null || text.trim().isEmpty) {
        throw Exception('Empty response');
      }
      return text.trim();
    } catch (e, st) {
      _logError('askWithImage failed', e, st);
      rethrow;
    }
  }



  List<String> _parseList(dynamic value) {
    if (value is List) {
      return value.map((e) => e.toString()).toList();
    } else if (value is String) {
      return value.split('\n').where((s) => s.trim().isNotEmpty).toList();
    }
    return <String>[];
  }

  Future<String> processVoiceChat({
    required String userMessage,
    String contextType = 'general',
    List<Map<String, String>>? conversationHistory,
  }) async {
    StringBuffer context = StringBuffer();
    context.writeln('Context Type: $contextType');
    if (conversationHistory != null) {
      for (var msg in conversationHistory) {
        context.writeln('${msg['role']}: ${msg['content']}');
      }
    }
    return sendMessage(userMessage, conversationContext: context.toString());
  }

  Future<String> getHealthInsights({
    required Map<String, dynamic> healthData,
    String focusArea = 'general',
  }) async {
    if (_apiKey.isEmpty) throw Exception('Groq API key not configured');

    final systemPrompt = '''Health Data Analyst. Return ONLY this TOON format:
summary: brief summary
insights:
  - insight1
  - insight2
recommendations:
  - rec1
  - rec2
Rules: Valid TOON only.''';

    final userPrompt = '''
Focus Area: $focusArea
Health Data: $healthData
Analyze and provide insights.''';

    final body = {
      'model': _model,
      'messages': [
        {'role': 'user', 'content': '$systemPrompt\n\n$userPrompt'}
      ],
      'temperature': 0.3,
      'max_tokens': 300,
    };

    try {
      final res = await http.post(
        Uri.parse(_endpoint),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $_apiKey',
        },
        body: jsonEncode(body),
      ).timeout(const Duration(seconds: 30));

      if (res.statusCode != 200) throw Exception('API error');
      final data = jsonDecode(res.body);
      return data['choices']?[0]?['message']?['content']?.trim() ?? '';
    } catch (e) {
      return 'summary: Unable to analyze\ninsights: []\nrecommendations: []';
    }
  }
}
