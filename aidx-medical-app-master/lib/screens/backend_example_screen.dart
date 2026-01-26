import 'package:flutter/material.dart';
import '../services/supabase_backend_service.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// EXAMPLE: How to use the Supabase backend in your app
class BackendExampleScreen extends StatefulWidget {
  const BackendExampleScreen({super.key});

  @override
  State<BackendExampleScreen> createState() => _BackendExampleScreenState();
}

class _BackendExampleScreenState extends State<BackendExampleScreen> {
  bool _loading = false;
  String _result = '';

  String get userId => FirebaseAuth.instance.currentUser?.uid ?? 'test_user';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Backend Test'),
        backgroundColor: const Color(0xFF1a1a2e),
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF0a0e27), Color(0xFF16213e)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // EXAMPLE 1: Save Health Data
            _buildCard(
              title: '💓 Save Health Data',
              description: 'Save heart rate, BP, steps, etc.',
              onTap: _saveHealthData,
            ),
            
            // EXAMPLE 2: Get Health Data
            _buildCard(
              title: '📊 Get Health Data',
              description: 'Fetch last 10 health records',
              onTap: _getHealthData,
            ),
            
            // EXAMPLE 3: Get Health Stats
            _buildCard(
              title: '📈 Get Health Stats',
              description: 'Get 7-day averages and totals',
              onTap: _getHealthStats,
            ),
            
            // EXAMPLE 4: Create Profile
            _buildCard(
              title: '👤 Create User Profile',
              description: 'Save user info to backend',
              onTap: _createProfile,
            ),
            
            // EXAMPLE 5: Get Profile
            _buildCard(
              title: '🔍 Get User Profile',
              description: 'Fetch user details',
              onTap: _getProfile,
            ),
            
            const SizedBox(height: 20),
            
            // Result Display
            if (_result.isNotEmpty)
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.white.withOpacity(0.2)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Result:',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.7),
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _result,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontFamily: 'monospace',
                      ),
                    ),
                  ],
                ),
              ),
            
            if (_loading)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(20),
                  child: CircularProgressIndicator(color: Color(0xFF4CAF50)),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildCard({
    required String title,
    required String description,
    required VoidCallback onTap,
  }) {
    return Card(
      color: Colors.white.withOpacity(0.1),
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        onTap: _loading ? null : onTap,
        title: Text(
          title,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        subtitle: Text(
          description,
          style: TextStyle(color: Colors.white.withOpacity(0.7)),
        ),
        trailing: Icon(Icons.arrow_forward_ios, color: Colors.white.withOpacity(0.5), size: 16),
      ),
    );
  }

  // EXAMPLE IMPLEMENTATIONS

  Future<void> _saveHealthData() async {
    setState(() {
      _loading = true;
      _result = '';
    });

    final success = await SupabaseBackendService.addHealthData(
      userId: userId,
      heartRate: 72,
      bloodPressureSystolic: 120,
      bloodPressureDiastolic: 80,
      bloodOxygen: 98,
      steps: 5000,
      calories: 250,
      distance: 3.5,
      temperature: 36.5,
    );

    setState(() {
      _loading = false;
      _result = success
          ? '✅ Health data saved successfully!\n\nData: HR=72, BP=120/80, SpO2=98%, Steps=5000'
          : '❌ Failed to save health data';
    });
  }

  Future<void> _getHealthData() async {
    setState(() {
      _loading = true;
      _result = '';
    });

    final data = await SupabaseBackendService.getHealthData(
      userId: userId,
      limit: 10,
    );

    setState(() {
      _loading = false;
      _result = data.isNotEmpty
          ? '✅ Found ${data.length} records:\n\n${data.take(3).map((e) => 'HR: ${e['heart_rate']}, Steps: ${e['steps']}').join('\n')}'
          : '📭 No health data found';
    });
  }

  Future<void> _getHealthStats() async {
    setState(() {
      _loading = true;
      _result = '';
    });

    final stats = await SupabaseBackendService.getHealthStats(
      userId: userId,
      days: 7,
    );

    if (stats != null) {
      setState(() {
        _loading = false;
        _result = '''✅ 7-Day Statistics:

Avg Heart Rate: ${stats['averageHeartRate']} bpm
Avg BP: ${stats['averageBloodPressure']['systolic']}/${stats['averageBloodPressure']['diastolic']}
Total Steps: ${stats['totalSteps']}
Total Calories: ${stats['totalCalories']}
Avg Sleep: ${stats['averageSleep']} hours''';
      });
    } else {
      setState(() {
        _loading = false;
        _result = '❌ Failed to get stats';
      });
    }
  }

  Future<void> _createProfile() async {
    setState(() {
      _loading = true;
      _result = '';
    });

    final success = await SupabaseBackendService.createUserProfile(
      userId: userId,
      phoneNumber: '8801712345678',
      firstName: 'John',
      lastName: 'Doe',
      email: 'john@example.com',
      bloodType: 'O+',
    );

    setState(() {
      _loading = false;
      _result = success
          ? '✅ Profile created!\n\nName: John Doe\nPhone: 8801712345678\nBlood: O+'
          : '❌ Failed to create profile (may already exist)';
    });
  }

  Future<void> _getProfile() async {
    setState(() {
      _loading = true;
      _result = '';
    });

    final profile = await SupabaseBackendService.getUserProfile(
      userId: userId,
    );

    if (profile != null) {
      setState(() {
        _loading = false;
        _result = '''✅ Profile Found:

Name: ${profile['first_name']} ${profile['last_name']}
Phone: ${profile['phone_number']}
Email: ${profile['email'] ?? 'Not set'}
Blood Type: ${profile['blood_type'] ?? 'Not set'}''';
      });
    } else {
      setState(() {
        _loading = false;
        _result = '❌ Profile not found';
      });
    }
  }
}
