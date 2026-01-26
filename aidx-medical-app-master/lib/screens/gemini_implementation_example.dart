import 'package:flutter/material.dart';
import 'package:aidx/screens/voice_chat_screen.dart';
import 'package:aidx/screens/report_analyzer_screen.dart';
import 'package:aidx/services/gemini_service.dart';

/// Quick Implementation Example
/// Shows how to integrate Gemini 2.0 Flash services into your app

class GeminiImplementationExample extends StatefulWidget {
  const GeminiImplementationExample({super.key});

  @override
  State<GeminiImplementationExample> createState() =>
      _GeminiImplementationExampleState();
}

class _GeminiImplementationExampleState
    extends State<GeminiImplementationExample> {
  final GeminiService _geminiService = GeminiService();
  String _connectionStatus = 'Checking...';
  Color _statusColor = Colors.grey;

  @override
  void initState() {
    super.initState();
    _checkConnection();
  }

  void _checkConnection() async {
    final isConnected = await _geminiService.checkConnectivity();
    setState(() {
      _connectionStatus = isConnected ? 'API Connected ✓' : 'API Disconnected ✗';
      _statusColor = isConnected ? Colors.green : Colors.red;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Gemini 2.0 Features'),
        backgroundColor: Colors.blue.shade700,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Connection Status
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: _statusColor.withOpacity(0.1),
                border: Border.all(color: _statusColor),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Container(
                    width: 12,
                    height: 12,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: _statusColor,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    _connectionStatus,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: _statusColor,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),

            // Section: Main Features
            const Text(
              'AI-Powered Features',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),

            // Feature 1: Voice Chat
            _buildFeatureCard(
              icon: Icons.chat_bubble,
              title: 'Live Voice Chat',
              description: 'Talk to AI for health consultations',
              onTap: () => _navigateToVoiceChat('consultation'),
            ),
            const SizedBox(height: 12),

            // Feature 2: Emergency Chat
            _buildFeatureCard(
              icon: Icons.warning,
              title: 'Emergency First Aid',
              description: 'Get instant emergency guidance',
              onTap: () => _navigateToVoiceChat('emergency'),
              color: Colors.red.shade700,
            ),
            const SizedBox(height: 12),

            // Feature 3: Report Analysis
            _buildFeatureCard(
              icon: Icons.description,
              title: 'Medical Report Analyzer',
              description: 'AI analysis of medical reports with images',
              onTap: () => _navigateToReportAnalyzer(),
              color: Colors.blue.shade700,
            ),
            const SizedBox(height: 32),

            // Section: Quick Actions
            const Text(
              'Quick Test Actions',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),

            // Test Health Insights
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _testHealthInsights,
                icon: const Icon(Icons.fitness_center),
                label: const Text('Test Health Insights'),
              ),
            ),
            const SizedBox(height: 12),

            // Test Emergency Response
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _testEmergencyResponse,
                icon: const Icon(Icons.emergency),
                label: const Text('Test Emergency Response'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                ),
              ),
            ),
            const SizedBox(height: 32),

            // Section: Implementation Guide
            const Text(
              'Integration Steps',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            _buildStepTile('1. Add screens to your dashboard'),
            _buildStepTile('2. Import GeminiV2Service in your providers'),
            _buildStepTile('3. Replace API key with your own'),
            _buildStepTile('4. Test connectivity with checkConnectivity()'),
            _buildStepTile('5. Deploy and monitor usage'),
          ],
        ),
      ),
    );
  }

  Widget _buildFeatureCard({
    required IconData icon,
    required String title,
    required String description,
    required VoidCallback onTap,
    Color? color,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: (color ?? Colors.blue).withOpacity(0.1),
          border: Border.all(color: (color ?? Colors.blue)),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Icon(icon, color: color ?? Colors.blue, size: 32),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    description,
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                  ),
                ],
              ),
            ),
            Icon(Icons.arrow_forward, color: color ?? Colors.blue),
          ],
        ),
      ),
    );
  }

  Widget _buildStepTile(String step) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Container(
            width: 24,
            height: 24,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.blue.shade700,
            ),
            child: const Center(
              child: Text(
                '✓',
                style: TextStyle(color: Colors.white, fontSize: 16),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(child: Text(step)),
        ],
      ),
    );
  }

  void _navigateToVoiceChat(String chatType) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => VoiceChatScreen(chatType: chatType),
      ),
    );
  }

  void _navigateToReportAnalyzer() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const ReportAnalyzerScreen(),
      ),
    );
  }

  void _testHealthInsights() async {
    _showLoadingDialog('Testing Health Insights...');
    try {
      final insights = await _geminiService.getHealthInsights(
        healthData: {
          'heart_rate': 72,
          'steps': 8500,
          'sleep_hours': 7.5,
          'water_intake_ml': 2000,
          'exercise_minutes': 45,
        },
        focusArea: 'fitness',
      );
      Navigator.pop(context);
      _showResultDialog('Health Insights', insights);
    } catch (e) {
      Navigator.pop(context);
      _showError('Test Failed: $e');
    }
  }

  void _testEmergencyResponse() async {
    _showLoadingDialog('Testing Emergency Response...');
    try {
      final response = await _geminiService.getEmergencyFirstAid(
        situation: 'Person collapsed, unconscious, not breathing normally',
        severity: 'Critical',
      );
      Navigator.pop(context);
      _showResultDialog('Emergency First Aid', response);
    } catch (e) {
      Navigator.pop(context);
      _showError('Test Failed: $e');
    }
  }

  void _showLoadingDialog(String message) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        content: Row(
          children: [
            const CircularProgressIndicator(),
            const SizedBox(width: 16),
            Expanded(child: Text(message)),
          ],
        ),
      ),
    );
  }

  void _showResultDialog(String title, String content) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: SingleChildScrollView(
          child: Text(content),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
      ),
    );
  }
}
