import 'package:shared_preferences/shared_preferences.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class PremiumService {
  static const String _subscriptionKey = 'is_premium_subscribed';
  static const String _symptomCountKey = 'daily_symptom_count';
  static const String _symptomDateKey = 'last_symptom_date';
  static const String _drugCountKey = 'daily_drug_count';
  static const String _drugDateKey = 'last_drug_date';
  
  // Check if user has premium subscription
  static Future<bool> isPremium() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_subscriptionKey) ?? false;
  }
  
  // Set premium status
  static Future<void> setPremiumStatus(bool status) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_subscriptionKey, status);
    
    // Also update Firestore if user is logged in
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      try {
        await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
          'profile': {
            'isPremium': status,
            'subscriptionUpdatedAt': FieldValue.serverTimestamp(),
          }
        }, SetOptions(merge: true));
      } catch (e) {
        print('Error updating premium status in Firestore: $e');
      }
    }
  }
  
  // Subscribe user (Disabled Applink)
  static Future<bool> subscribe(String phoneNumber) async {
    // Applink subscription removed
    return false;
  }

  // Unsubscribe user (Disabled Applink)
  static Future<bool> unsubscribe(String phoneNumber) async {
    // Applink subscription removed
    return false;
  }

  // Sync subscription status from Firestore/Backend
  static Future<void> syncSubscriptionStatus(String userId) async {
    try {
      // 1. Check Firestore first
      final doc = await FirebaseFirestore.instance.collection('users').doc(userId).get();
      if (doc.exists && doc.data() != null) {
        final data = doc.data()!;
        final profile = data['profile'] as Map<String, dynamic>?;
        final usage = data['usage'] as Map<String, dynamic>?;
        
        // Sync usage counts
        if (usage != null) {
          final prefs = await SharedPreferences.getInstance();
          final today = DateTime.now().toString().split(' ')[0];
          
          if (usage['last_symptom_date'] == today) {
            await prefs.setString(_symptomDateKey, today);
            await prefs.setInt(_symptomCountKey, usage['symptom_count'] ?? 0);
          }
          
          if (usage['last_drug_date'] == today) {
            await prefs.setString(_drugDateKey, today);
            await prefs.setInt(_drugCountKey, usage['drug_count'] ?? 0);
          }
        }
        
        if (profile != null) {
          // Fallback to stored status if no phone verification possible
          if (profile['isPremium'] == true) {
            await setPremiumStatus(true);
          }
        }
      }
    } catch (e) {
      print('Error syncing subscription status: $e');
    }
  }
  
  // Check subscription from backend (Disabled Applink)
  static Future<bool> checkSubscriptionStatus(String phoneNumber) async {
    // Applink check removed
    return false;
  }
  
  // ============ USAGE LIMITS ============
  
  // Check if can use symptom analysis (Unlimited for now)
  static Future<bool> canUseSymptomAnalysis() async {
    return true;
  }
  
  // Increment symptom usage
  static Future<void> incrementSymptomUsage() async {
    final prefs = await SharedPreferences.getInstance();
    final count = prefs.getInt(_symptomCountKey) ?? 0;
    await prefs.setInt(_symptomCountKey, count + 1);
    
    // Sync to Firestore if logged in
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      final today = DateTime.now().toString().split(' ')[0];
      try {
        await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
          'usage': {
            'symptom_count': count + 1,
            'last_symptom_date': today,
          }
        }, SetOptions(merge: true));
      } catch (e) {
        print('Error syncing symptom usage: $e');
      }
    }
  }
  
  // Get remaining symptom analyses
  static Future<int> getRemainingSymptomAnalyses() async {
    return 999;
  }
  
  // Check if can use drug info (Unlimited for now)
  static Future<bool> canUseDrugInfo() async {
    return true;
  }
  
  // Increment drug info usage
  static Future<void> incrementDrugUsage() async {
    final prefs = await SharedPreferences.getInstance();
    final count = prefs.getInt(_drugCountKey) ?? 0;
    await prefs.setInt(_drugCountKey, count + 1);
    
    // Sync to Firestore if logged in
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      final today = DateTime.now().toString().split(' ')[0];
      try {
        await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
          'usage': {
            'drug_count': count + 1,
            'last_drug_date': today,
          }
        }, SetOptions(merge: true));
      } catch (e) {
        print('Error syncing drug usage: $e');
      }
    }
  }
  
  // Get remaining drug info requests
  static Future<int> getRemainingDrugRequests() async {
    return 999;
  }
}
