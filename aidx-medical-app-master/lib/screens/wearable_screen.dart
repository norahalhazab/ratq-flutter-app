import 'dart:async';
import 'package:flutter/material.dart';
import 'package:aidx/utils/theme.dart';
import 'package:aidx/services/database_init.dart';
import 'package:aidx/services/android_wearable_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter_feather_icons/flutter_feather_icons.dart';
import 'inbox_screen.dart';

class WearableScreen extends StatefulWidget {
  const WearableScreen({super.key});

  @override
  State<WearableScreen> createState() => _WearableScreenState();
}

class _WearableScreenState extends State<WearableScreen> {
  final AndroidWearableService _androidService = AndroidWearableService();
  final DatabaseService _databaseService = DatabaseService();
  final FirebaseAuth _auth = FirebaseAuth.instance;
  
  List<Map<String, dynamic>> _connectedDevices = [];
  Timer? _simulationTimer;
  
  @override
  void initState() {
    super.initState();
    _checkPermissions();
    _initializeAndroidService();
    _loadConnectedDevices();
  }
  
  @override
  void dispose() {
    _simulationTimer?.cancel();
    super.dispose();
  }
  
  Future<void> _checkPermissions() async {
    Map<Permission, PermissionStatus> statuses = await [
      Permission.bluetooth,
      Permission.bluetoothScan,
      Permission.bluetoothConnect,
      Permission.location,
    ].request();
    
    if (statuses.values.any((s) => !s.isGranted)) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Bluetooth and location permissions are required'), backgroundColor: AppTheme.dangerColor),
        );
      }
    }
  }
  
  Future<void> _initializeAndroidService() async {
    await _androidService.initialize();
    _androidService.addListener(() {
      if (mounted) setState(() {});
    });
  }
  
  Future<void> _loadConnectedDevices() async {
    try {
      final user = _auth.currentUser;
      if (user != null) {
        final devices = await _databaseService.getWearableDevices(user.uid);
        setState(() => _connectedDevices = devices);
      }
    } catch (e) {
      debugPrint('Error loading devices: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bgDark,
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 100,
            floating: true,
            pinned: true,
            backgroundColor: AppTheme.bgDark,
            leading: IconButton(
              icon: const Icon(FeatherIcons.arrowLeft, color: Colors.white),
              onPressed: () => Navigator.pop(context),
            ),
            actions: [
              IconButton(
                icon: const Icon(FeatherIcons.inbox, color: Colors.white),
                onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const InboxScreen())),
              ),
            ],
            flexibleSpace: FlexibleSpaceBar(
              title: const Text('Smartwatch Connect', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
              centerTitle: true,
              background: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [AppTheme.primaryColor.withOpacity(0.2), AppTheme.bgDark],
                  ),
                ),
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildVitalsDashboard(),
                  const SizedBox(height: 20),
                  _buildConnectionStatus(),
                  const SizedBox(height: 20),
                  if (_androidService.isScanning || _androidService.getScanResults().isNotEmpty) _buildScanResults(),
                  if (_connectedDevices.isNotEmpty) _buildSavedDevices(),
                  const SizedBox(height: 20),
                  _buildInstructions(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVitalsDashboard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.bgGlassMedium,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(FeatherIcons.activity, color: AppTheme.primaryColor, size: 20),
              const SizedBox(width: 8),
              const Text("Live Vitals", style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(child: _buildMetricCard(FeatherIcons.heart, "${_androidService.heartRate}", "BPM", Colors.red)),
              const SizedBox(width: 12),
              Expanded(child: _buildMetricCard(FeatherIcons.droplet, "${_androidService.spo2}", "% SpO2", Colors.blue)),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(child: _buildMetricCard(Icons.directions_walk, "${_androidService.steps}", "Steps", Colors.green)),
              const SizedBox(width: 12),
              Expanded(child: _buildMetricCard(FeatherIcons.battery, "${_androidService.batteryLevel.round()}%", "Battery", Colors.orange)),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(child: _buildMetricCard(FeatherIcons.activity, "${_androidService.bloodPressureSystolic}/${_androidService.bloodPressureDiastolic}", "mmHg", Colors.purple)),
              const SizedBox(width: 12),
              Expanded(child: _buildMetricCard(FeatherIcons.thermometer, "${_androidService.temperature}°C", "Temp", Colors.yellow)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMetricCard(IconData icon, String value, String unit, Color color) {
    final isActive = _androidService.isConnected;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isActive ? color.withOpacity(0.1) : Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isActive ? color.withOpacity(0.3) : Colors.white.withOpacity(0.1)),
      ),
      child: Column(
        children: [
          Icon(icon, color: isActive ? color : Colors.white54, size: 24),
          const SizedBox(height: 8),
          Text(value, style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: isActive ? color : Colors.white54)),
          Text(unit, style: TextStyle(fontSize: 12, color: isActive ? color.withOpacity(0.8) : Colors.white38)),
        ],
      ),
    );
  }

  Widget _buildConnectionStatus() {
    final isConnected = _androidService.isConnected;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.bgGlassMedium,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: isConnected ? Colors.green.withOpacity(0.2) : Colors.red.withOpacity(0.2),
                  shape: BoxShape.circle,
                ),
                child: Icon(isConnected ? FeatherIcons.bluetooth : FeatherIcons.bluetooth, color: isConnected ? Colors.green : Colors.red, size: 16),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(isConnected ? "Connected" : "Disconnected", style: TextStyle(color: isConnected ? Colors.green : Colors.red, fontWeight: FontWeight.bold)),
                    if (isConnected) Text(_androidService.connectedDevice?.name ?? "Unknown Device", style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 12)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (isConnected) ...[
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () => _androidService.forceSensorReading(),
                icon: const Icon(FeatherIcons.refreshCw, size: 16),
                label: const Text("Refresh Sensors"),
                style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryColor, foregroundColor: Colors.white),
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () => _androidService.disconnect(),
                icon: const Icon(FeatherIcons.x, size: 16),
                label: const Text("Disconnect"),
                style: OutlinedButton.styleFrom(foregroundColor: Colors.red, side: const BorderSide(color: Colors.red)),
              ),
            ),
          ] else
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _androidService.isScanning ? null : () => _androidService.startScan(),
                icon: _androidService.isScanning ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Icon(FeatherIcons.search, size: 16),
                label: Text(_androidService.isScanning ? "Scanning..." : "Scan for Devices"),
                style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryColor, foregroundColor: Colors.white),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildScanResults() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text("Available Devices", style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
        const SizedBox(height: 12),
        ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: _androidService.getScanResults().length,
          itemBuilder: (context, index) {
            final result = _androidService.getScanResults()[index];
            final device = result.device;
            final isAndroidWatch = _androidService.isAndroidSmartwatch(device);
            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              decoration: BoxDecoration(
                color: AppTheme.bgGlassMedium,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white.withOpacity(0.05)),
              ),
              child: ListTile(
                leading: Icon(Icons.watch, color: isAndroidWatch ? AppTheme.primaryColor : Colors.grey),
                title: Text(device.name.isNotEmpty ? device.name : "Unknown Device", style: const TextStyle(color: Colors.white)),
                subtitle: Text(device.id.id, style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 12)),
                trailing: ElevatedButton(
                  onPressed: _androidService.isConnecting ? null : () => _androidService.connectToDevice(device),
                  style: ElevatedButton.styleFrom(backgroundColor: isAndroidWatch ? AppTheme.primaryColor : Colors.grey, padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8)),
                  child: const Text("Connect", style: TextStyle(color: Colors.white)),
                ),
              ),
            );
          },
        ),
        const SizedBox(height: 20),
      ],
    );
  }

  Widget _buildSavedDevices() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text("Saved Devices", style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
        const SizedBox(height: 12),
        ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: _connectedDevices.length,
          itemBuilder: (context, index) {
            final device = _connectedDevices[index];
            final isConnected = device['isConnected'] ?? false;
            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              decoration: BoxDecoration(
                color: AppTheme.bgGlassMedium,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white.withOpacity(0.05)),
              ),
              child: ListTile(
                leading: Icon(Icons.watch, color: isConnected ? Colors.green : Colors.grey),
                title: Text(device['deviceName'] ?? 'Unknown', style: const TextStyle(color: Colors.white)),
                subtitle: Text(isConnected ? 'Connected' : 'Last seen: ${_formatLastConnected(device['lastConnected'])}', style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 12)),
                trailing: IconButton(
                  icon: const Icon(FeatherIcons.trash2, color: Colors.red, size: 18),
                  onPressed: () => _removeDevice(device['id']),
                ),
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildInstructions() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.bgGlassMedium,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(FeatherIcons.info, color: AppTheme.primaryColor, size: 16),
              const SizedBox(width: 8),
              const Text("Instructions", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 12),
          _buildStep("1", "Pair watch in Android Bluetooth settings."),
          _buildStep("2", "Tap 'Scan' to find the device."),
          _buildStep("3", "Select your watch to connect."),
        ],
      ),
    );
  }

  Widget _buildStep(String num, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Container(
            width: 18, height: 18,
            decoration: BoxDecoration(color: AppTheme.primaryColor.withOpacity(0.2), shape: BoxShape.circle),
            child: Center(child: Text(num, style: TextStyle(color: AppTheme.primaryColor, fontSize: 10, fontWeight: FontWeight.bold))),
          ),
          const SizedBox(width: 8),
          Expanded(child: Text(text, style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 12))),
        ],
      ),
    );
  }

  String _formatLastConnected(dynamic timestamp) {
    if (timestamp == null) return 'Never';
    try {
      final date = timestamp is Timestamp ? timestamp.toDate() : DateTime.parse(timestamp.toString());
      final diff = DateTime.now().difference(date);
      if (diff.inDays > 0) return '${diff.inDays}d ago';
      if (diff.inHours > 0) return '${diff.inHours}h ago';
      return '${diff.inMinutes}m ago';
    } catch (e) {
      return 'Unknown';
    }
  }

  Future<void> _removeDevice(String deviceId) async {
    try {
      await _databaseService.deleteWearableDevice(deviceId);
      await _loadConnectedDevices();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }
}