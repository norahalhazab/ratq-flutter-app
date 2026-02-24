import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/pdf_service.dart';
import '../widgets/bottom_nav.dart';
import '../utils/app_colors.dart';

class SummaryReportScreen extends StatelessWidget {
  final String caseId;

  const SummaryReportScreen({super.key, required this.caseId});

  Future<Map<String, dynamic>> _fetchReportData() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) throw Exception("User not logged in");

    // 1. Start with the Auth Display Name (used in Settings)
    String displayName = user.displayName ?? "";

    // 2. Try to get the name from Firestore (used in Homepage)
    try {
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();

      final userData = userDoc.data();
      if (userData != null) {
        // Check nested profile first (Database structure)
        if (userData['profile'] != null && userData['profile']['name'] != null) {
          displayName = userData['profile']['name'].toString();
        }
        // Check top level fields (Homepage logic)
        else {
          final firestoreName = userData['name'] ?? userData['username'] ?? userData['displayName'];
          if (firestoreName != null && firestoreName.toString().trim().isNotEmpty) {
            displayName = firestoreName.toString().trim();
          }
        }
      }
    } catch (e) {
      print("Firestore name fetch failed: $e");
    }

    // 3. Final Fallback if everything is empty
    if (displayName.isEmpty) {
      displayName = user.email ?? "Patient";
    }

    // --- Proceed with your existing WHQ and Vitals logic ---
    final responses = await FirebaseFirestore.instance
        .collection('users').doc(user.uid)
        .collection('cases').doc(caseId)
        .collection('whqResponses').get();

    String assessmentStatus = "No records found";

    if (responses.docs.isNotEmpty) {
      // Get the latest result from the "results" field in your image
      final latestData = responses.docs.first.data();
      final String rawResult = (latestData['results'] ?? 'low').toString().toLowerCase();

      // Map the database string to your UI display string
      if (rawResult == 'high') {
        assessmentStatus = "High sign of infection";
      } else {
        assessmentStatus = "No sign of infection";
      }
    }

    double totalTemp = 0;
    int totalHR = 0;
    int validVitalsCount = 0;
    Map<String, int> symptomFrequency = {};

    for (var doc in responses.docs) {
      final data = doc.data();
      final v = data['vitals'] as Map<String, dynamic>?;

      if (v != null) {
        totalTemp += (v['temperature'] as num? ?? 0).toDouble();
        totalHR += (v['heartRate'] as num? ?? 0).toInt();
        validVitalsCount++;
      }

      final answers = data['userResponse']?['answers'] as Map<String, dynamic>?;
      answers?.forEach((key, value) {
        if ((value as num? ?? 0) > 0) {
          symptomFrequency[key] = (symptomFrequency[key] ?? 0) + 1;
        }
      });
    }

    var sortedSymptoms = symptomFrequency.keys.toList()
      ..sort((a, b) => symptomFrequency[b]!.compareTo(symptomFrequency[a]!));
    List<String> top3 = sortedSymptoms.take(3).toList();

    return {
      "patientName": displayName,
      "assessmentStatus": assessmentStatus,// THIS IS THE KEY
      "avgVitals": {
        "temperature": validVitalsCount > 0 ? (totalTemp / validVitalsCount).toStringAsFixed(1) : "37.0",
        "heartRate": validVitalsCount > 0 ? (totalHR ~/ validVitalsCount).toString() : "80",
        "bloodPressure": "120/80",
      },
      "topSymptoms": top3,
      "totalRecords": responses.docs.length,
    };
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7FBFF),
      body: FutureBuilder<Map<String, dynamic>>(
        future: _fetchReportData(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
          if (snapshot.hasError) return const Center(child: Text("Error loading report data"));

          final reportData = snapshot.data!;
          return SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text("Case Summary", style: GoogleFonts.dmSans(fontSize: 32, fontWeight: FontWeight.w900)),
                  Text("Averaged from ${reportData['totalRecords']} entries.", style: GoogleFonts.inter(fontSize: 14, color: Colors.grey[600])),
                  const SizedBox(height: 30),
                  _buildSummaryCard(reportData),
                  const Spacer(),
                  _buildPdfButton(context, reportData),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          );
        },
      ),
      bottomNavigationBar: const AppBottomNav(currentIndex: 1),
    );
  }

  Widget _buildSummaryCard(Map<String, dynamic> data) {
    final vitals = data['avgVitals'];
    final List<String> symptoms = data['topSymptoms'];

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(24), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 20)]),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildStatRow("Patient", data['patientName']),
          const Divider(height: 30),
          _buildStatRow("Avg Temperature", "${vitals['temperature']}°C"),
          _buildStatRow("Avg Heart Rate", "${vitals['heartRate']} BPM"),
          const SizedBox(height: 20),
          Text("FREQUENT SYMPTOMS", style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w800, color: Colors.grey)),
          const SizedBox(height: 8),
          if (symptoms.isEmpty)
            Text("No significant symptoms reported.", style: GoogleFonts.inter(fontSize: 14, color: Colors.grey)),
          ...symptoms.map((s) => Text("• $s", style: GoogleFonts.inter(fontSize: 14, color: Colors.redAccent))),
        ],
      ),
    );
  }

  Widget _buildStatRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [Text(label), Text(value, style: const TextStyle(fontWeight: FontWeight.bold))],
      ),
    );
  }

  Widget _buildPdfButton(BuildContext context, Map<String, dynamic> data) {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: ElevatedButton.icon(
        onPressed: () => PdfReportGenerator.generateAndPrintReport(
          caseId: caseId,
          patientName: data['patientName'],
          vitals: data['avgVitals'],
          topSymptoms: data['topSymptoms'],
          assessmentStatus: data['assessmentStatus'],
        ),
        icon: const Icon(Icons.picture_as_pdf),
        label: const Text("Download Medical PDF"),
        style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF3B7691), foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
      ),
    );
  }
}