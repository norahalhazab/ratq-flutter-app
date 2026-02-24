import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

class PdfReportGenerator {
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