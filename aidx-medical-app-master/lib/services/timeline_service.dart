import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';

class TimelineService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  Future<String> getTimelineSummary() async {
    try {
      final user = _auth.currentUser;
      if (user == null) return "No user logged in.";

      final uid = user.uid;
      final StringBuffer summary = StringBuffer();
      summary.writeln("--- RECENT MEDICAL TIMELINE (Last 30 days) ---");

      // Helper to format date
      String formatDate(DateTime date) => DateFormat('MMM d, yyyy').format(date);

      // 1. Medications
      final meds = await _firestore
          .collection('medications')
          .where('userId', isEqualTo: uid)
          .limit(10)
          .get();
      
      if (meds.docs.isNotEmpty) {
        summary.writeln("\nActive Medications:");
        for (var doc in meds.docs) {
          final data = doc.data();
          summary.writeln("- ${data['name']} (${data['dosage']}): ${data['frequency']}");
        }
      }

      // 2. Appointments
      final appointments = await _firestore
          .collection('appointments')
          .where('userId', isEqualTo: uid)
          .orderBy('date', descending: true)
          .limit(5)
          .get();

      if (appointments.docs.isNotEmpty) {
        summary.writeln("\nRecent/Upcoming Appointments:");
        for (var doc in appointments.docs) {
          final data = doc.data();
          final date = (data['date'] as Timestamp).toDate();
          summary.writeln("- ${data['doctorName']} (${data['specialty']}) on ${formatDate(date)}");
        }
      }

      // 3. Reports
      final reports = await _firestore
          .collection('reports')
          .where('userId', isEqualTo: uid)
          .orderBy('date', descending: true)
          .limit(5)
          .get();

      if (reports.docs.isNotEmpty) {
        summary.writeln("\nRecent Lab Reports:");
        for (var doc in reports.docs) {
          final data = doc.data();
          final date = (data['date'] as Timestamp).toDate();
          summary.writeln("- ${data['title']} (${data['type']}) on ${formatDate(date)}: ${data['summary'] ?? 'No summary'}");
        }
      }

      // 4. Symptoms
      final symptoms = await _firestore
          .collection('symptoms')
          .where('userId', isEqualTo: uid)
          .orderBy('timestamp', descending: true)
          .limit(5)
          .get();

      if (symptoms.docs.isNotEmpty) {
        summary.writeln("\nRecent Symptoms:");
        for (var doc in symptoms.docs) {
          final data = doc.data();
          final date = (data['timestamp'] as Timestamp).toDate();
          summary.writeln("- ${data['symptom']} (${data['intensity']}) on ${formatDate(date)}");
        }
      }

      summary.writeln("\n--- END TIMELINE ---");
      return summary.toString();
    } catch (e) {
      return "Error fetching timeline: $e";
    }
  }
}
