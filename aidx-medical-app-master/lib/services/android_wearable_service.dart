import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AndroidWearableService extends ChangeNotifier {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  
  // Device state
  BluetoothDevice? _connectedDevice;
  bool _isConnected = false;
  bool _isScanning = false;
  bool _isConnecting = false;
  List<ScanResult> _scanResults = [];
  
  // Health data
  int _heartRate = 0;
  int _spo2 = 0;
  int _steps = 0;
  double _batteryLevel = 0.0;
  int _temperature = 0;
  int _bloodPressureSystolic = 0;
  int _bloodPressureDiastolic = 0;
  
  // Stream subscriptions
  StreamSubscription<List<ScanResult>>? _scanSubscription;
  StreamSubscription<BluetoothConnectionState>? _connectionSubscription;
  List<StreamSubscription<List<int>>>? _characteristicSubscriptions;
  
  // Data saving
  Timer? _dataSaveTimer;
  Timer? _healthCheckTimer;
  Timer? _autoReconnectTimer;
  Timer? _keepAliveTimer;
  Timer? _sensorActivationTimer;
  
  // Getters
  BluetoothDevice? get connectedDevice => _connectedDevice;
  bool get isConnected => _isConnected;
  bool get isScanning => _isScanning;
  bool get isConnecting => _isConnecting;
  int get heartRate => _heartRate;
  int get spo2 => _spo2;
  int get steps => _steps;
  double get batteryLevel => _batteryLevel;
  int get temperature => _temperature;
  int get bloodPressureSystolic => _bloodPressureSystolic;
  int get bloodPressureDiastolic => _bloodPressureDiastolic;
  
  // Android Smartwatch specific service UUIDs
  static const Map<String, String> androidWatchServices = {
    'heartRate': '0000180d-0000-1000-8000-00805f9b34fb',
    'healthThermometer': '00001809-0000-1000-8000-00805f9b34fb',
    'pulseOximeter': '00001822-0000-1000-8000-00805f9b34fb',
    'bloodPressure': '00001810-0000-1000-8000-00805f9b34fb',
    'fitnessTracker': '00001826-0000-1000-8000-00805f9b34fb',
    'battery': '0000180f-0000-1000-8000-00805f9b34fb',
    'deviceInfo': '0000180a-0000-1000-8000-00805f9b34fb',
  };

  // Persistence key
  static const String _lastDevicePrefKey = 'last_wearable_device_id';
  static const String _connectionStatePrefKey = 'wearable_connection_state';
  
  static const Map<String, String> androidWatchCharacteristics = {
    'heartRateMeasurement': '00002a37-0000-1000-8000-00805f9b34fb',
    'heartRateControl': '00002a39-0000-1000-8000-00805f9b34fb',
    'temperatureMeasurement': '00002a1c-0000-1000-8000-00805f9b34fb',
    'spo2Measurement': '00002a5f-0000-1000-8000-00805f9b34fb',
    'bloodPressureMeasurement': '00002a35-0000-1000-8000-00805f9b34fb',
    'fitnessActivity': '00002a6d-0000-1000-8000-00805f9b34fb',
    'batteryLevel': '00002a19-0000-1000-8000-00805f9b34fb',
    'manufacturerName': '00002a29-0000-1000-8000-00805f9b34fb',
    'modelNumber': '00002a24-0000-1000-8000-00805f9b34fb',
  };
  
  // Initialize the service
  Future<void> initialize() async {
    try {
      // Check if Bluetooth is supported
      if (await FlutterBluePlus.isSupported == false) {
        debugPrint('❌ Bluetooth not supported on this device');
        return;
      }
      
      // Listen for Bluetooth state changes
      FlutterBluePlus.adapterState.listen((state) {
        debugPrint('🔵 Bluetooth adapter state: $state');
        if (state == BluetoothAdapterState.off) {
          _handleDisconnect();
        }
      });
      
      debugPrint('✅ Android Wearable Service initialized');
      
      // Load persistent connection state
      await _loadConnectionState();
    } catch (e) {
      debugPrint('❌ Error initializing Android Wearable Service: $e');
    }
  }

  // Load persistent connection state
  Future<void> _loadConnectionState() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final wasConnected = prefs.getBool(_connectionStatePrefKey) ?? false;
      final lastDeviceId = prefs.getString(_lastDevicePrefKey);
      
      if (wasConnected && lastDeviceId != null) {
        debugPrint('🔄 Restoring previous connection to: $lastDeviceId');
        // Attempt to reconnect in background
        // ignore: unawaited_futures
        autoReconnect();
      }
    } catch (e) {
      debugPrint('❌ Error loading connection state: $e');
    }
  }

  // Try to auto-reconnect to last known device
  Future<void> autoReconnect({Duration timeout = const Duration(seconds: 20)}) async {
    try {
      if (_isConnected) return;
      final prefs = await SharedPreferences.getInstance();
      final lastId = prefs.getString(_lastDevicePrefKey);
      if (lastId == null || lastId.isEmpty) return;

      // Start scan if not already scanning
      if (!_isScanning) {
        // Fire and forget
        // ignore: unawaited_futures
        startScan();
      }

      // Set a longer timeout for auto-reconnect
      timeout = const Duration(seconds: 30);

      final StreamSubscription<List<ScanResult>> tempSub = FlutterBluePlus.scanResults.listen((results) {
        try {
          for (final r in results) {
                      if (r.device.id.id == lastId) {
            stopScan();
            // ignore: unawaited_futures
            connectToDevice(r.device);
            break;
          }
        }
      } catch (_) {}
      
      // Also try to connect to any Android smartwatch if exact match fails
      final androidWatches = results.where((r) => isAndroidSmartwatch(r.device)).toList();
      if (androidWatches.isNotEmpty && !_isConnected) {
        final firstWatch = androidWatches.first;
        stopScan();
        // ignore: unawaited_futures
        connectToDevice(firstWatch.device);
      }
      });

      // Stop attempt after timeout
      _autoReconnectTimer?.cancel();
      _autoReconnectTimer = Timer(timeout, () async {
        await tempSub.cancel();
        if (_isScanning) stopScan();
      });
    } catch (e) {
      debugPrint('❌ Auto-reconnect error: $e');
    }
  }
  
  // Start scanning for paired Android smartwatches
  Future<void> startScan() async {
    if (_isScanning) return;
    
    setState(() {
      _isScanning = true;
    });
    
    try {
      // First check for already paired devices
      await _checkPairedDevices();
      
      // Then scan for discoverable devices
      _scanSubscription = FlutterBluePlus.scanResults.listen((results) {
        _scanResults = results.where((result) {
          final device = result.device;
          final name = device.name.toLowerCase();
          final manufacturerData = result.advertisementData.manufacturerData;
          
          // Common Android smartwatch names and identifiers
          return name.contains('watch') ||
                 name.contains('smart') ||
                 name.contains('fitness') ||
                 name.contains('band') ||
                 name.contains('mi') ||
                 name.contains('huawei') ||
                 name.contains('samsung') ||
                 name.contains('amazfit') ||
                 name.contains('garmin') ||
                 name.contains('fitbit') ||
                 name.contains('ultra') ||
                 name.contains('pro') ||
                 manufacturerData.isNotEmpty;
        }).toList();
        
        debugPrint('📱 Found ${_scanResults.length} Android smartwatches');
        notifyListeners();
      });
      
      await FlutterBluePlus.startScan(timeout: const Duration(seconds: 20));
      
      // Stop scanning after timeout
      Future.delayed(const Duration(seconds: 20), () {
        stopScan();
      });
    } catch (e) {
      debugPrint('❌ Scan failed: $e');
      setState(() => _isScanning = false);
    }
  }

  // Check for already paired devices
  Future<void> _checkPairedDevices() async {
    try {
      // Get bonded devices (already paired through system Bluetooth)
      final bondedDevices = await FlutterBluePlus.bondedDevices;
      
      for (final device in bondedDevices) {
        if (isAndroidSmartwatch(device)) {
          debugPrint('🔗 Found paired smartwatch: ${device.name} (${device.id.id})');
          // Try to connect directly to paired device
          // ignore: unawaited_futures
          connectToDevice(device);
          break; // Connect to first paired smartwatch found
        }
      }
    } catch (e) {
      debugPrint('⚠️ Error checking paired devices: $e');
    }
  }
  
  void stopScan() {
    _scanSubscription?.cancel();
    FlutterBluePlus.stopScan();
    setState(() => _isScanning = false);
  }
  
  // Connect to Android smartwatch
  Future<void> connectToDevice(BluetoothDevice device) async {
    if (_isConnecting) return;
    
    setState(() {
      _isConnecting = true;
      _connectedDevice = device;
    });
    
    try {
      await device.connect(timeout: const Duration(seconds: 15));
      
      // Listen for connection state changes
      _connectionSubscription = device.connectionState.listen((state) {
        debugPrint('🔗 Connection state: $state');
        if (state == BluetoothConnectionState.disconnected) {
          // Don't immediately disconnect, try to reconnect first
          _handleConnectionLoss();
        }
      });
      
      // Discover services
      List<BluetoothService> services = await device.discoverServices();
      await _setupAndroidWatchServices(services);
      
      // Save device to database
      await _saveDeviceToDatabase(device);

      // Persist last connected device id
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(_lastDevicePrefKey, device.id.id);
        await prefs.setBool(_connectionStatePrefKey, true);
      } catch (e) {
        debugPrint('⚠️ Failed to persist last wearable id: $e');
      }
      
      setState(() {
        _isConnecting = false;
        _isConnected = true;
      });
      
      // Start data saving
      _startDataSaving();
      
      // Start keep-alive mechanism
      _startKeepAlive();
      
      // Activate sensors on the watch
      _activateWatchSensors();
      
      debugPrint('✅ Connected to Android smartwatch: ${device.name}');
      notifyListeners();
    } catch (e) {
      debugPrint('❌ Connection failed: $e');
      setState(() => _isConnecting = false);
      _handleDisconnect();
    }
  }
  
  // Handle connection loss with reconnection attempt
  void _handleConnectionLoss() {
    debugPrint('🔌 Connection lost, attempting reconnection...');
    _isConnected = false;
    notifyListeners();
    
    // Try to reconnect after a short delay
    Timer(const Duration(seconds: 3), () {
      if (!_isConnected) {
        // ignore: unawaited_futures
        autoReconnect();
      }
    });
  }

  // Keep connection alive
  void _startKeepAlive() {
    _keepAliveTimer?.cancel();
    _keepAliveTimer = Timer.periodic(const Duration(seconds: 10), (timer) {
      if (_isConnected && _connectedDevice != null) {
        try {
          // Send a ping to keep connection alive by reading battery level
          // ignore: unawaited_futures
          _sendSensorActivationCommands();
        } catch (e) {
          debugPrint('⚠️ Keep-alive ping failed: $e');
        }
      }
    });
  }

  // Activate sensors on the watch
  Future<void> _activateWatchSensors() async {
    if (_connectedDevice == null) return;
    
    try {
      // Send commands to activate sensors
      await _sendSensorActivationCommands();
      
      // Start periodic sensor activation
      _sensorActivationTimer?.cancel();
      _sensorActivationTimer = Timer.periodic(const Duration(seconds: 30), (timer) {
        // ignore: unawaited_futures
        _sendSensorActivationCommands();
      });
      
      debugPrint('🔬 Watch sensors activated');
    } catch (e) {
      debugPrint('❌ Failed to activate sensors: $e');
    }
  }

  // Send commands to activate watch sensors
  Future<void> _sendSensorActivationCommands() async {
    if (_connectedDevice == null) return;
    
    try {
      final services = await _connectedDevice!.discoverServices();
      
      for (var service in services) {
        for (var characteristic in service.characteristics) {
          // Heart Rate Control Point
          if (characteristic.uuid.toString().toLowerCase() == 
              androidWatchCharacteristics['heartRateControl']!.toLowerCase()) {
            // Enable heart rate sensor
            await characteristic.write([0x01]);
            debugPrint('💓 Heart rate sensor activated');
          }
          
          // Fitness Activity Control
          if (characteristic.uuid.toString().toLowerCase() == 
              '00002a6e-0000-1000-8000-00805f9b34fb') {
            // Enable fitness tracking
            await characteristic.write([0x01]);
            debugPrint('👟 Fitness sensor activated');
          }
        }
      }
    } catch (e) {
      debugPrint('⚠️ Sensor activation command failed: $e');
    }
  }
  
  // Setup Android smartwatch specific services
  Future<void> _setupAndroidWatchServices(List<BluetoothService> services) async {
    _characteristicSubscriptions?.forEach((sub) => sub.cancel());
    _characteristicSubscriptions = [];
    
    for (var service in services) {
      final serviceUuid = service.uuid.toString().toLowerCase();
      debugPrint('🔍 Found service: $serviceUuid');
      
      // Heart Rate Service
      if (serviceUuid == androidWatchServices['heartRate']!.toLowerCase()) {
        await _setupHeartRateService(service);
      }
      
      // Pulse Oximeter Service
      if (serviceUuid == androidWatchServices['pulseOximeter']!.toLowerCase()) {
        await _setupPulseOximeterService(service);
      }
      
      // Blood Pressure Service
      if (serviceUuid == androidWatchServices['bloodPressure']!.toLowerCase()) {
        await _setupBloodPressureService(service);
      }
      
      // Fitness Tracker Service
      if (serviceUuid == androidWatchServices['fitnessTracker']!.toLowerCase()) {
        await _setupFitnessTrackerService(service);
      }
      
      // Battery Service
      if (serviceUuid == androidWatchServices['battery']!.toLowerCase()) {
        await _setupBatteryService(service);
      }
      
      // Health Thermometer Service
      if (serviceUuid == androidWatchServices['healthThermometer']!.toLowerCase()) {
        await _setupTemperatureService(service);
      }
    }
    
    debugPrint('✅ Setup ${_characteristicSubscriptions?.length ?? 0} characteristics');
  }
  
  Future<void> _setupHeartRateService(BluetoothService service) async {
    for (var characteristic in service.characteristics) {
      final charUuid = characteristic.uuid.toString().toLowerCase();
      
      if (charUuid == androidWatchCharacteristics['heartRateMeasurement']!.toLowerCase()) {
        await characteristic.setNotifyValue(true);
        
        final subscription = characteristic.value.listen((value) {
          _parseHeartRateData(value);
        });
        
        _characteristicSubscriptions?.add(subscription);
        debugPrint('💓 Heart rate monitoring enabled');
      }
    }
  }
  
  Future<void> _setupPulseOximeterService(BluetoothService service) async {
    for (var characteristic in service.characteristics) {
      final charUuid = characteristic.uuid.toString().toLowerCase();
      
      if (charUuid == androidWatchCharacteristics['spo2Measurement']!.toLowerCase()) {
        await characteristic.setNotifyValue(true);
        
        final subscription = characteristic.value.listen((value) {
          _parseSpO2Data(value);
        });
        
        _characteristicSubscriptions?.add(subscription);
        debugPrint('🩸 SpO2 monitoring enabled');
      }
    }
  }
  
  Future<void> _setupBloodPressureService(BluetoothService service) async {
    for (var characteristic in service.characteristics) {
      final charUuid = characteristic.uuid.toString().toLowerCase();
      
      if (charUuid == androidWatchCharacteristics['bloodPressureMeasurement']!.toLowerCase()) {
        await characteristic.setNotifyValue(true);
        
        final subscription = characteristic.value.listen((value) {
          _parseBloodPressureData(value);
        });
        
        _characteristicSubscriptions?.add(subscription);
        debugPrint('🩺 Blood pressure monitoring enabled');
      }
    }
  }
  
  Future<void> _setupFitnessTrackerService(BluetoothService service) async {
    for (var characteristic in service.characteristics) {
      final charUuid = characteristic.uuid.toString().toLowerCase();
      
      if (charUuid == androidWatchCharacteristics['fitnessActivity']!.toLowerCase()) {
        await characteristic.setNotifyValue(true);
        
        final subscription = characteristic.value.listen((value) {
          _parseFitnessData(value);
        });
        
        _characteristicSubscriptions?.add(subscription);
        debugPrint('👟 Fitness tracking enabled');
      }
    }
  }
  
  Future<void> _setupBatteryService(BluetoothService service) async {
    for (var characteristic in service.characteristics) {
      final charUuid = characteristic.uuid.toString().toLowerCase();
      
      if (charUuid == androidWatchCharacteristics['batteryLevel']!.toLowerCase()) {
        await characteristic.setNotifyValue(true);
        
        final subscription = characteristic.value.listen((value) {
          _parseBatteryData(value);
        });
        
        _characteristicSubscriptions?.add(subscription);
        debugPrint('🔋 Battery monitoring enabled');
      }
    }
  }
  
  Future<void> _setupTemperatureService(BluetoothService service) async {
    for (var characteristic in service.characteristics) {
      final charUuid = characteristic.uuid.toString().toLowerCase();
      
      if (charUuid == androidWatchCharacteristics['temperatureMeasurement']!.toLowerCase()) {
        await characteristic.setNotifyValue(true);
        
        final subscription = characteristic.value.listen((value) {
          _parseTemperatureData(value);
        });
        
        _characteristicSubscriptions?.add(subscription);
        debugPrint('🌡️ Temperature monitoring enabled');
      }
    }
  }
  
  // Parse health data from Android smartwatch
  void _parseHeartRateData(List<int> data) {
    if (data.length < 2) return;
    
    int flags = data[0];
    int heartRate = 0;
    
    if ((flags & 0x01) == 0) {
      // UINT8 format
      heartRate = data[1];
    } else {
      // UINT16 format
      if (data.length >= 3) {
        heartRate = (data[2] << 8) | data[1];
      }
    }
    
    if (heartRate > 0 && heartRate < 300) {
      setState(() => _heartRate = heartRate);
      debugPrint('💓 Heart Rate: $heartRate BPM');
    }
  }
  
  void _parseSpO2Data(List<int> data) {
    if (data.isNotEmpty) {
      int spo2 = data[0];
      if (spo2 >= 0 && spo2 <= 100) {
        setState(() => _spo2 = spo2);
        debugPrint('🩸 SpO2: $spo2%');
      }
    }
  }
  
  void _parseBloodPressureData(List<int> data) {
    if (data.length >= 4) {
      int systolic = (data[2] << 8) | data[1];
      int diastolic = (data[4] << 8) | data[3];
      
      if (systolic > 0 && diastolic > 0) {
        setState(() {
          _bloodPressureSystolic = systolic;
          _bloodPressureDiastolic = diastolic;
        });
        debugPrint('🩺 BP: $systolic/$diastolic mmHg');
      }
    }
  }
  
  void _parseFitnessData(List<int> data) {
    if (data.length >= 4) {
      int steps = (data[3] << 24) | (data[2] << 16) | (data[1] << 8) | data[0];
      setState(() => _steps = steps);
      debugPrint('👟 Steps: $steps');
    }
  }
  
  void _parseBatteryData(List<int> data) {
    if (data.isNotEmpty) {
      int battery = data[0];
      if (battery >= 0 && battery <= 100) {
        setState(() => _batteryLevel = battery.toDouble());
        debugPrint('🔋 Battery: $battery%');
      }
    }
  }
  
  void _parseTemperatureData(List<int> data) {
    if (data.length >= 2) {
      // Temperature in Celsius (standard format)
      int tempRaw = (data[2] << 8) | data[1];
      double tempCelsius = tempRaw / 100.0;
      int tempRounded = tempCelsius.round();
      
      setState(() => _temperature = tempRounded);
      debugPrint('🌡️ Temperature: $tempRounded°C');
    }
  }
  
  // Save device to database
  Future<void> _saveDeviceToDatabase(BluetoothDevice device) async {
    try {
      final user = _auth.currentUser;
      if (user != null) {
        final deviceData = {
          'deviceId': device.id.id,
          'deviceName': device.name.isNotEmpty ? device.name : 'Android Smartwatch',
          'deviceType': 'android_smartwatch',
          'manufacturer': 'Android',
          'model': device.name,
          'isConnected': true,
          'lastConnected': FieldValue.serverTimestamp(),
          'capabilities': [
            'heart_rate',
            'spo2',
            'blood_pressure',
            'temperature',
            'steps',
            'battery'
          ],
          'androidWatchFeatures': true,
        };
        
        await _firestore
            .collection('users')
            .doc(user.uid)
            .collection('wearable_devices')
            .doc(device.id.id)
            .set(deviceData, SetOptions(merge: true));
        
        debugPrint('✅ Device saved to database');
      }
    } catch (e) {
      debugPrint('❌ Error saving device: $e');
    }
  }
  
  // Save health data to Firebase
  Future<void> _saveHealthData() async {
    try {
      final user = _auth.currentUser;
      if (user != null && _isConnected) {
        final healthData = {
          'userId': user.uid,
          'deviceId': _connectedDevice?.id.id,
          'deviceType': 'android_smartwatch',
          'heartRate': _heartRate,
          'spo2': _spo2,
          'steps': _steps,
          'batteryLevel': _batteryLevel,
          'temperature': _temperature,
          'bloodPressureSystolic': _bloodPressureSystolic,
          'bloodPressureDiastolic': _bloodPressureDiastolic,
          'timestamp': FieldValue.serverTimestamp(),
          'source': 'android_wearable',
        };
        
        await _firestore
            .collection('health_data')
            .add(healthData);
        
        debugPrint('✅ Health data saved to Firebase');
      }
    } catch (e) {
      debugPrint('❌ Error saving health data: $e');
    }
  }
  
  // Start periodic data saving
  void _startDataSaving() {
    _dataSaveTimer?.cancel();
    _dataSaveTimer = Timer.periodic(const Duration(seconds: 30), (timer) {
      if (_isConnected) {
        _saveHealthData();
      }
    });
  }
  
  // Disconnect from device
  Future<void> disconnect() async {
    _dataSaveTimer?.cancel();
    _autoReconnectTimer?.cancel();
    _keepAliveTimer?.cancel();
    _sensorActivationTimer?.cancel();
    _characteristicSubscriptions?.forEach((sub) => sub.cancel());
    _connectionSubscription?.cancel();
    
    if (_connectedDevice != null) {
      try {
        await _connectedDevice!.disconnect();
      } catch (e) {
        debugPrint('❌ Disconnect error: $e');
      }
    }
    
    _handleDisconnect();
  }
  
  void _handleDisconnect() {
    _dataSaveTimer?.cancel();
    _keepAliveTimer?.cancel();
    _sensorActivationTimer?.cancel();
    
    setState(() {
      _connectedDevice = null;
      _isConnecting = false;
      _isConnected = false;
      _heartRate = 0;
      _spo2 = 0;
      _steps = 0;
      _batteryLevel = 0.0;
      _temperature = 0;
      _bloodPressureSystolic = 0;
      _bloodPressureDiastolic = 0;
    });
    
    // Clear persistent connection state
    try {
      SharedPreferences.getInstance().then((prefs) {
        prefs.setBool(_connectionStatePrefKey, false);
      });
    } catch (e) {
      debugPrint('⚠️ Failed to clear connection state: $e');
    }
    
    debugPrint('🔌 Device disconnected');
    notifyListeners();
  }
  
  void setState(VoidCallback fn) {
    fn();
    notifyListeners();
  }
  
  // Get scan results
  List<ScanResult> getScanResults() {
    return _scanResults;
  }
  
  // Check if device is Android smartwatch
  bool isAndroidSmartwatch(BluetoothDevice device) {
    final name = device.name.toLowerCase();
    return name.contains('watch') ||
           name.contains('smart') ||
           name.contains('fitness') ||
           name.contains('band') ||
           name.contains('mi') ||
           name.contains('huawei') ||
           name.contains('samsung') ||
           name.contains('amazfit') ||
           name.contains('garmin') ||
           name.contains('fitbit') ||
           name.contains('ultra') ||
           name.contains('pro');
  }
  
  // Get device info
  Map<String, dynamic> getDeviceInfo() {
    return {
      'name': _connectedDevice?.name ?? 'Unknown',
      'id': _connectedDevice?.id.id ?? '',
      'isConnected': _isConnected,
      'heartRate': _heartRate,
      'spo2': _spo2,
      'steps': _steps,
      'batteryLevel': _batteryLevel,
      'temperature': _temperature,
      'bloodPressure': '$_bloodPressureSystolic/$_bloodPressureDiastolic',
    };
  }

  // Force sensor reading
  Future<void> forceSensorReading() async {
    if (_connectedDevice == null || !_isConnected) return;
    
    try {
      await _sendSensorActivationCommands();
      debugPrint('🔬 Forced sensor reading');
    } catch (e) {
      debugPrint('❌ Force sensor reading failed: $e');
    }
  }
} 