import 'package:flutter/material.dart';
import '../widgets/bottom_nav.dart';

import 'smart_watch_simulator_service.dart';

class SmartWatchSimulatorScreen extends StatefulWidget {
  const SmartWatchSimulatorScreen({super.key});

  @override
  State<SmartWatchSimulatorScreen> createState() =>
      _SmartWatchSimulatorScreenState();
}

class _SmartWatchSimulatorScreenState extends State<SmartWatchSimulatorScreen> {
  final service = SmartWatchSimulatorService.instance;

  @override
  void initState() {
    super.initState();
    service.vitalsStream.listen((_) {
      if (mounted) setState(() {});
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Watch Simulator'),
        leading: const BackButton(),
      ),

      // ✅ نفس الـ nav bar الثابت حقكم
      // بما إن صفحة الساعة جايه من Settings، نخلي Settings هو المحدد (index = 4)
      bottomNavigationBar: const AppBottomNav(currentIndex: 4),

      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            _card('Heart Rate', '${service.heartRate} bpm', Icons.favorite),
            _card('Temperature', '${service.temperature.toStringAsFixed(1)} °C',
                Icons.thermostat),
            _card('Blood Pressure', service.bloodPressure, Icons.monitor_heart),

            const Spacer(),

            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: service.isConnected ? null : service.connect,
                child: Text(service.isConnected ? 'Connected' : 'Connect'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _card(String title, String value, IconData icon) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: Icon(icon),
        title: Text(title),
        subtitle: Text(
          value,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }
}
