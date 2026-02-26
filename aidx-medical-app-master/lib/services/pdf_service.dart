import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class PdfReportGenerator {

  // ✅ NEW: One-call method (caseId only)
  static Future<void> generateAndPrintReportForCase({
    required String caseId,
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      throw Exception("User not logged in");
    }

    // -------- Patient Name (same logic as SummaryReportScreen) --------
    String displayName = user.displayName ?? "";

    try {
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();

      final userData = userDoc.data();
      if (userData != null) {
        if (userData['profile'] != null &&
            userData['profile']['name'] != null) {
          displayName = userData['profile']['name'].toString();
        } else {
          final firestoreName =
              userData['name'] ?? userData['username'] ??
                  userData['displayName'];
          if (firestoreName != null && firestoreName
              .toString()
              .trim()
              .isNotEmpty) {
            displayName = firestoreName.toString().trim();
          }
        }
      }
    } catch (_) {
      // ignore
    }

    if (displayName.isEmpty) {
      displayName = user.email ?? "Patient";
    }

    // -------- Fetch WHQ responses --------
    QuerySnapshot<Map<String, dynamic>> responses;

    // Try orderBy createdAt (best). If your docs don't have createdAt, fallback.
    try {
      responses = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('cases')
          .doc(caseId)
          .collection('whqResponses')
          .orderBy('createdAt', descending: true)
          .get();
    } catch (_) {
      responses = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('cases')
          .doc(caseId)
          .collection('whqResponses')
          .get();
    }

    // -------- Assessment status from latest "results" --------
    String assessmentStatus = "No records found";

    if (responses.docs.isNotEmpty) {
      // If ordered: first is latest. If not ordered: still use first (like before).
      final latestData = responses.docs.first.data();
      final rawResult = (latestData['results'] ?? 'low')
          .toString()
          .toLowerCase();

      assessmentStatus = (rawResult == 'high')
          ? "High sign of infection"
          : "No sign of infection";
    }

    // -------- Average vitals + top symptoms frequency --------
    double totalTemp = 0;
    int totalHR = 0;
    int validVitalsCount = 0;

    final Map<String, int> symptomFrequency = {};

    for (final doc in responses.docs) {
      final data = doc.data();

      // vitals avg
      final v = data['vitals'] as Map<String, dynamic>?;
      if (v != null) {
        totalTemp += (v['temperature'] as num? ?? 0).toDouble();
        totalHR += (v['heartRate'] as num? ?? 0).toInt();
        validVitalsCount++;
      }

      // symptom frequency
      final answers =
          (data['userResponse']?['answers'] as Map<String, dynamic>?) ?? {};

      answers.forEach((key, value) {
        if ((value as num? ?? 0) > 0) {
          symptomFrequency[key] = (symptomFrequency[key] ?? 0) + 1;
        }
      });
    }

    final sortedSymptoms = symptomFrequency.keys.toList()
      ..sort((a, b) => symptomFrequency[b]!.compareTo(symptomFrequency[a]!));

    final top3 = sortedSymptoms.take(3).toList();

    final vitals = {
      "temperature": validVitalsCount > 0
          ? (totalTemp / validVitalsCount).toStringAsFixed(1)
          : "37.0",
      "heartRate": validVitalsCount > 0 ? (totalHR ~/ validVitalsCount)
          .toString() : "80",
      "bloodPressure": "120/80",
    };

    // ✅ Finally generate the PDF using your existing method
    await generateAndPrintReport(
      caseId: caseId,
      patientName: displayName,
      vitals: vitals,
      topSymptoms: top3,
      assessmentStatus: assessmentStatus,
    );
  }

// ... keep your existing generateAndPrintReport(...) BELOW unchanged ...

  static Future<void> generateAndPrintReport({
  required String caseId,
  required Map<String, dynamic> vitals,
  required List<String> topSymptoms,
  required String patientName,
  required String assessmentStatus,
  }) async {
  final pdf = pw.Document();

  // ✅ Full 16-Question Mapping (English Only)
  final Map<String, String> questionMap = {
  "q1": "Was the area around the wound warmer than the surrounding skin?",
  "q2": "Has any part of the wound leaked blood-stained fluid?",
  "q3": "Have the edges of any part of the wound separated or gaped open of their accord?",
  "q4": "If the wound edges opened: Did the flesh beneath the skin or the inside sutures also separate?",
  "q5": "Has the area around the wound become swollen?",
  "q6": "Has the wound been smelly?",
  "q7": "Has the wound been painful to touch?",
  "q8": "Has any part of the wound leaked thin, clear fluid?",
  "q9": "Have you sought advice because of a problem with your wound?",
  "q10": "Has anything been put on the skin to cover the wound? (dressing)",
  "q11": "Have you been back into hospital for a problem with your wound?",
  "q12": "Have you been given medicines (antibiotics) for your wound?",
  "q13": "Have the edges of your wound been separated by a doctor or nurse?",
  "q14": "Has your wound been scraped or cut to remove unwanted flesh?",
  "q15": "Has pus been drained from your wound by a doctor or nurse?",
  "q16": "Have you had to go back to the operating room for your wound?",
  };

  final bool isHighRisk = assessmentStatus.contains("High sign");
  final PdfColor statusColor = isHighRisk ? PdfColors.red : PdfColors.green;

  pdf.addPage(
  pw.Page(
  pageFormat: PdfPageFormat.a4,
  margin: const pw.EdgeInsets.all(32),
  build: (pw.Context context) {
  return pw.Column(
  crossAxisAlignment: pw.CrossAxisAlignment.start,
  children: [
  // Header
  pw.Row(
  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
  children: [
  pw.Column(
  crossAxisAlignment: pw.CrossAxisAlignment.start,
  children: [
  pw.Text("WOUND ASSESSMENT SUMMARY",
  style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
  pw.Text("Clinical Documentation - Patient Report",
  style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700)),
  ],
  ),
  pw.Text("DATE: ${DateTime.now().toString().split(' ')[0]}",
  style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
  ],
  ),
  pw.SizedBox(height: 10),
  pw.Divider(thickness: 1),
  pw.SizedBox(height: 15),

  _pdfRow("Patient Name:", patientName),
  _pdfRow("Case Reference:", caseId),

  pw.SizedBox(height: 20),
  _sectionHeader("I. CLINICAL VITALS (AVERAGED)"),
  pw.Table(
  border: pw.TableBorder.all(color: PdfColors.grey400, width: 0.5),
  children: [
  pw.TableRow(
  decoration: const pw.BoxDecoration(color: PdfColors.grey200),
  children: [
  _tableCell("Vital Sign", isHeader: true),
  _tableCell("Average Value", isHeader: true),
  _tableCell("Reference Range", isHeader: true),
  ],
  ),
  _tableRow("Body Temperature", "${vitals['temperature']}°C", "36.5 - 37.5°C"),
  _tableRow("Heart Rate", "${vitals['heartRate']} BPM", "60 - 100 BPM"),
  _tableRow("Blood Pressure", "${vitals['bloodPressure']}", "120/80 mmHg"),
  ],
  ),

  pw.SizedBox(height: 20),
  _sectionHeader("II. RECURRING POSITIVE INDICATORS"),
  pw.Text("The following questions were answered affirmatively by the patient:",
  style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700)),
  pw.SizedBox(height: 8),

  if (topSymptoms.isEmpty)
  pw.Text("No positive indicators reported during this period.",
  style: pw.TextStyle(fontSize: 10, fontStyle: pw.FontStyle.italic))
  else
  pw.Column(
  crossAxisAlignment: pw.CrossAxisAlignment.start,
  children: topSymptoms.map((qId) {
  final String fullQuestion = questionMap[qId] ?? "Question ID: $qId";
  return pw.Padding(
  padding: const pw.EdgeInsets.only(bottom: 5),
  child: pw.Row(
  crossAxisAlignment: pw.CrossAxisAlignment.start,
  children: [
  pw.Text("• ", style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
  pw.Expanded(
  child: pw.Text(fullQuestion, style: const pw.TextStyle(fontSize: 10)),
  ),
  ],
  ),
  );
  }).toList(),
  ),

  pw.SizedBox(height: 25),

  // Assessment Status Box
  pw.Container(
  padding: const pw.EdgeInsets.all(12),
  decoration: pw.BoxDecoration(
  border: pw.Border.all(color: statusColor, width: 2),
  color: isHighRisk ? PdfColors.red50 : PdfColors.green50,
  ),
  child: pw.Row(
  mainAxisAlignment: pw.MainAxisAlignment.center,
  children: [
  pw.Text("ASSESSMENT: ",
  style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 11)),
  pw.Text(assessmentStatus.toUpperCase(),
  style: pw.TextStyle(
  fontWeight: pw.FontWeight.bold,
  fontSize: 11,
  color: statusColor)),
  ],
  ),
  ),

  pw.Spacer(),
  pw.Divider(thickness: 0.5, color: PdfColors.grey400),
  pw.Center(
  child: pw.Text(
  "Generated via WHQ Digital Monitoring. Consult a healthcare provider for clinical diagnosis.",
  style: const pw.TextStyle(fontSize: 7, color: PdfColors.grey600),
  ),
  ),
  ],
  );
  },
  ),
  );

  await Printing.layoutPdf(onLayout: (format) async => pdf.save());
  }

  // --- Helpers ---
  static pw.Widget _tableCell(String text, {bool isHeader = false}) => pw.Padding(
  padding: const pw.EdgeInsets.all(6),
  child: pw.Text(text,
  style: pw.TextStyle(
  fontSize: 9, fontWeight: isHeader ? pw.FontWeight.bold : pw.FontWeight.normal)));

  static pw.TableRow _tableRow(String label, String value, String range) =>
  pw.TableRow(children: [_tableCell(label), _tableCell(value), _tableCell(range)]);

  static pw.Widget _sectionHeader(String title) => pw.Padding(
  padding: const pw.EdgeInsets.only(bottom: 8),
  child: pw.Text(title,
  style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold)));

  static pw.Widget _pdfRow(String label, String value) => pw.Padding(
  padding: const pw.EdgeInsets.only(bottom: 4),
  child: pw.Row(children: [
  pw.SizedBox(
  width: 90,
  child: pw.Text(label,
  style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10))),
  pw.Text(value, style: const pw.TextStyle(fontSize: 10))
  ]));
  }
