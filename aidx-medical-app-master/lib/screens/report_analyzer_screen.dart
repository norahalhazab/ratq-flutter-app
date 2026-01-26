import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:aidx/services/gemini_service.dart';
import 'dart:io';

class ReportAnalyzerScreen extends StatefulWidget {
  const ReportAnalyzerScreen({super.key});

  @override
  State<ReportAnalyzerScreen> createState() => _ReportAnalyzerScreenState();
}

class _ReportAnalyzerScreenState extends State<ReportAnalyzerScreen> {
  final GeminiService _geminiService = GeminiService();
  final TextEditingController _descriptionController = TextEditingController();
  final ImagePicker _imagePicker = ImagePicker();

  File? _selectedImage;
  bool _isAnalyzing = false;
  Map<String, dynamic>? _analysisResult;
  String _selectedReportType = 'Blood Test';
  int? _age;
  String? _gender;

  final List<String> _reportTypes = [
    'Blood Test',
    'X-Ray',
    'CT Scan',
    'Ultrasound',
    'ECG',
    'General Checkup',
    'Other'
  ];

  void _pickImage() async {
    final image = await _imagePicker.pickImage(source: ImageSource.gallery);
    if (image != null) {
      setState(() => _selectedImage = File(image.path));
    }
  }

  void _captureImage() async {
    final image = await _imagePicker.pickImage(source: ImageSource.camera);
    if (image != null) {
      setState(() => _selectedImage = File(image.path));
    }
  }

  void _analyzeReport() async {
    if (_descriptionController.text.isEmpty && _selectedImage == null) {
      _showError('Please enter a description or upload an image');
      return;
    }

    setState(() => _isAnalyzing = true);

    try {
      final result = await _geminiService.analyzeMedicalReport(
        description: _descriptionController.text,
        reportType: _selectedReportType,
        age: _age,
        gender: _gender,
        imageFile: _selectedImage,
      );

      setState(() {
        _analysisResult = _geminiService.parseReportResponse(result);
      });
    } catch (e) {
      _showError('Analysis Error: $e');
    } finally {
      setState(() => _isAnalyzing = false);
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
      ),
    );
  }

  void _clearAll() {
    setState(() {
      _descriptionController.clear();
      _selectedImage = null;
      _analysisResult = null;
      _age = null;
      _gender = null;
      _selectedReportType = 'Blood Test';
    });
  }

  @override
  void dispose() {
    _descriptionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Medical Report Analyzer'),
        backgroundColor: Colors.blue.shade700,
        actions: [
          if (_analysisResult != null)
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: _clearAll,
              tooltip: 'Clear All',
            )
        ],
      ),
      body: _isAnalyzing
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('Analyzing your report...'),
                ],
              ),
            )
          : _analysisResult != null
              ? _buildResultView()
              : _buildInputView(),
    );
  }

  Widget _buildInputView() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Report Type
          const Text('Report Type', style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          DropdownButton<String>(
            value: _selectedReportType,
            isExpanded: true,
            onChanged: (value) {
              setState(() => _selectedReportType = value ?? 'Blood Test');
            },
            items: _reportTypes
                .map((type) => DropdownMenuItem(value: type, child: Text(type)))
                .toList(),
          ),
          const SizedBox(height: 24),

          // Patient Info
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Age (Optional)', style: TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    TextField(
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        hintText: 'Enter age',
                      ),
                      onChanged: (value) {
                        setState(() => _age = int.tryParse(value));
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Gender (Optional)', style: TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    DropdownButton<String>(
                      value: _gender,
                      isExpanded: true,
                      onChanged: (value) {
                        setState(() => _gender = value);
                      },
                      items: ['Male', 'Female', 'Other']
                          .map((g) => DropdownMenuItem(value: g, child: Text(g)))
                          .toList(),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // Description
          const Text('Report Details', style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          TextField(
            controller: _descriptionController,
            decoration: InputDecoration(
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              hintText: 'Describe your report findings...',
            ),
            minLines: 4,
            maxLines: 5,
          ),
          const SizedBox(height: 24),

          // Image Selection
          const Text('Report Image (Optional)', style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          if (_selectedImage != null)
            Stack(
              children: [
                Container(
                  height: 200,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                    image: DecorationImage(
                      image: FileImage(_selectedImage!),
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
                Positioned(
                  top: 8,
                  right: 8,
                  child: GestureDetector(
                    onTap: () => setState(() => _selectedImage = null),
                    child: Container(
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.red,
                      ),
                      padding: const EdgeInsets.all(8),
                      child: const Icon(Icons.close, color: Colors.white),
                    ),
                  ),
                ),
              ],
            )
          else
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _pickImage,
                    icon: const Icon(Icons.image),
                    label: const Text('Pick Image'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _captureImage,
                    icon: const Icon(Icons.camera_alt),
                    label: const Text('Capture'),
                  ),
                ),
              ],
            ),
          const SizedBox(height: 24),

          // Analyze Button
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton.icon(
              onPressed: _analyzeReport,
              icon: const Icon(Icons.analytics),
              label: const Text('Analyze Report'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue.shade700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildResultView() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Severity Badge
          if (_analysisResult?['severity'] != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: _getSeverityColor(_analysisResult!['severity']),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                'Severity: ${_analysisResult!['severity']}',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          const SizedBox(height: 16),

          // Summary
          if (_analysisResult?['summary'] != null) ...[
            const Text('Summary', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(_analysisResult!['summary']),
            ),
            const SizedBox(height: 16),
          ],

          // Findings
          if (_analysisResult?['findings'] != null) ...[
            const Text('Findings', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            ..._buildList(_analysisResult!['findings']),
            const SizedBox(height: 16),
          ],

          // Recommendations
          if (_analysisResult?['recommendations'] != null) ...[
            const Text('Recommendations', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            ..._buildList(_analysisResult!['recommendations']),
            const SizedBox(height: 16),
          ],

          // Next Steps
          if (_analysisResult?['next_steps'] != null) ...[
            const Text('Next Steps', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            ..._buildList(_analysisResult!['next_steps']),
            const SizedBox(height: 16),
          ],

          // Alerts
          if (_analysisResult?['alerts'] != null && (_analysisResult!['alerts'] as List).isNotEmpty) ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                border: Border.all(color: Colors.red),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('⚠️ Alerts', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.red)),
                  const SizedBox(height: 8),
                  ..._buildList(_analysisResult!['alerts']),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],

          // New Analysis Button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _clearAll,
              icon: const Icon(Icons.add),
              label: const Text('Analyze Another Report'),
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildList(dynamic items) {
    List<String> list = [];
    if (items is List) {
      list = items.map((e) => e.toString()).toList();
    } else if (items is String) {
      list = items.split('\n').where((e) => e.isNotEmpty).toList();
    }

    return list
        .map(
          (item) => Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('• ', style: TextStyle(fontWeight: FontWeight.bold)),
                Expanded(child: Text(item)),
              ],
            ),
          ),
        )
        .toList();
  }

  Color _getSeverityColor(String severity) {
    switch (severity.toLowerCase()) {
      case 'critical':
        return Colors.red.shade700;
      case 'high':
      case 'severe':
        return Colors.orange.shade700;
      case 'moderate':
        return Colors.amber;
      case 'low':
      case 'minor':
        return Colors.green;
      default:
        return Colors.grey;
    }
  }
}
