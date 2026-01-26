import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:aidx/services/auth_service.dart';
import 'package:aidx/services/firebase_service.dart';
import 'package:aidx/utils/theme.dart';
import 'package:aidx/utils/constants.dart';
import 'package:aidx/widgets/glass_container.dart';
import 'package:flutter_feather_icons/flutter_feather_icons.dart';
import 'package:geolocator/geolocator.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:android_intent_plus/android_intent.dart';
import 'package:aidx/services/telegram_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:just_audio/just_audio.dart';
import 'package:aidx/services/sos_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SosScreen extends StatefulWidget {
  const SosScreen({super.key});

  @override
  State<SosScreen> createState() => _SosScreenState();
}

class _SosScreenState extends State<SosScreen> {
  final bool _isLoading = false;
  bool _autoSosEnabled = false;
  bool _sosActive = false;
  late SosService _sosService;
  bool _isInitializing = false;
  bool _isDisposed = false;
  int _countdownSeconds = 30;
  Timer? _countdownTimer;
  bool _autoDialed = false;
  
  // Firebase services
  late FirebaseService _firebaseService;
  String? _currentUserId;
  
  // Emergency contacts
  final TextEditingController _emergencyContactController = TextEditingController();
  final TextEditingController _emergencyNumberController = TextEditingController();
  List<Map<String, dynamic>> _emergencyContacts = [];
  
  // Location
  Position? _currentPosition;
  bool _locationPermissionGranted = false;
  
  // Auto SOS monitoring
  Timer? _monitoringTimer;
  bool _abnormalVitalsDetected = false;
  DateTime? _abnormalVitalsStartTime;
  
  // Vitals (would come from wearable in real app)
  int _heartRate = 75;
  int _spo2 = 98;
  
  // SOS Settings
  Map<String, dynamic>? _sosSettings;
  
  final AudioPlayer _audioPlayer = AudioPlayer();
  bool _isAlarmPlaying = false;
  late final StreamSubscription<User?> _authSubscription;
  
  @override
  void initState() {
    super.initState();
    _firebaseService = FirebaseService();
    _sosService = SosService();
    _currentUserId = FirebaseAuth.instance.currentUser?.uid;
    _initializeData();

    // Listen for auth changes
    _authSubscription = FirebaseAuth.instance.authStateChanges().listen((user) {
      if (!_isDisposed && user?.uid != _currentUserId) {
        setState(() {
          _currentUserId = user?.uid;
        });
        // Only reinitialize if we have a new user and not disposed and not already initializing
        if (user?.uid != null && !_isDisposed && !_isInitializing) {
          _initializeData();
        }
      }
    });

    // Check global SOS status periodically and keep UI in sync
    Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted || _isDisposed) {
        timer.cancel();
        return;
      }

      final bool serviceActive = _sosService.isSOSActive;
      if (serviceActive) {
        // Ensure UI is active and keep seconds updated every tick
        if (!_sosActive || _countdownSeconds != _sosService.countdownSeconds) {
          setState(() {
            _sosActive = true;
            _countdownSeconds = _sosService.countdownSeconds;
          });
        }
        // Auto-dial once when countdown reaches 0
        if (_countdownSeconds == 0 && !_autoDialed) {
          _autoDialed = true;
          // Trigger the full emergency response
          unawaited(_dispatchEmergency());
        }
      } else if (_sosActive) {
        // Service ended or cancelled; reset UI
        setState(() {
          _sosActive = false;
          _countdownSeconds = 30;
          _autoDialed = false;
        });
      }
    });

    // Auto-start countdown if launched due to background fall detection
    _autoStartCountdownIfPending();
  }

  Future<void> _autoStartCountdownIfPending() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final bool openSos = prefs.getBool('pending_open_sos') ?? false;
      if (openSos && !_sosService.isSOSActive) {
        await prefs.setBool('pending_open_sos', false);
        await _sosService.startSOSCountdown();
        setState(() {
          _sosActive = true;
          _countdownSeconds = _sosService.countdownSeconds;
        });
      }
    } catch (e) {
      debugPrint('Error auto-starting SOS countdown: $e');
    }
  }
  
  Future<void> _initializeData() async {
    if (_isInitializing || _isDisposed) {
      debugPrint('Already initializing or disposed, skipping...');
      return;
    }
    
    _isInitializing = true;
    
    try {
      // Load settings first
      await _loadSettings();
      
      // Check if still mounted and not disposed
      if (!mounted || _isDisposed) return;
      
      // Then load emergency contacts
      await _loadEmergencyContacts();
      
      // Check if still mounted and not disposed
      if (!mounted || _isDisposed) return;
      
      // Finally check location permission
      await _checkLocationPermission();
    } catch (e) {
      debugPrint('Error initializing SOS screen: $e');
      // Don't crash the app, just show error
      if (mounted && !_isDisposed) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading SOS data: $e'),
            backgroundColor: AppTheme.dangerColor,
          ),
        );
      }
    } finally {
      if (!_isDisposed) {
        _isInitializing = false;
      }
    }
  }
  
  @override
  void dispose() {
    _isDisposed = true;
    _authSubscription.cancel();
    _countdownTimer?.cancel();
    _monitoringTimer?.cancel();
    _stopAlarm();
    _audioPlayer.dispose();
    _emergencyContactController.dispose();
    _emergencyNumberController.dispose();
    super.dispose();
  }
  
  Future<void> _loadSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      setState(() {
        _autoSosEnabled = prefs.getBool('auto_sos_enabled') ?? false;
        _emergencyNumberController.text = prefs.getString('emergency_number') ?? '';
        _sosSettings = {
          'heartRateThreshold': prefs.getInt('heart_rate_threshold') ?? 100,
          'spo2Threshold': prefs.getInt('spo2_threshold') ?? 95,
          'abnormalDurationSeconds': prefs.getInt('abnormal_duration_seconds') ?? 30,
          'locationSharing': prefs.getBool('location_sharing') ?? true,
        };
      });
      
      debugPrint('✅ Settings loaded from local storage');
      debugPrint('Auto SOS: $_autoSosEnabled');
      debugPrint('Emergency Number: ${_emergencyNumberController.text}');
    } catch (e) {
      debugPrint('Error loading settings: $e');
    }
  }
  
  Future<void> _saveSettings() async {
    try {
      // Save to local SharedPreferences first for immediate persistence
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('auto_sos_enabled', _autoSosEnabled);
      await prefs.setString('emergency_number', _emergencyNumberController.text);
      await prefs.setInt('heart_rate_threshold', _sosSettings?['heartRateThreshold'] ?? 100);
      await prefs.setInt('spo2_threshold', _sosSettings?['spo2Threshold'] ?? 95);
      await prefs.setInt('abnormal_duration_seconds', _sosSettings?['abnormalDurationSeconds'] ?? 30);
      await prefs.setBool('location_sharing', _sosSettings?['locationSharing'] ?? true);
      
      debugPrint('✅ Settings saved to local storage');
      
      // Also save to Firebase if user is logged in
      if (_currentUserId != null) {
        final settings = {
          'autoSosEnabled': _autoSosEnabled,
          'emergencyNumber': _emergencyNumberController.text,
          'heartRateThreshold': _sosSettings?['heartRateThreshold'] ?? 100,
          'spo2Threshold': _sosSettings?['spo2Threshold'] ?? 95,
          'abnormalDurationSeconds': _sosSettings?['abnormalDurationSeconds'] ?? 30,
          'locationSharing': _sosSettings?['locationSharing'] ?? true,
        };
        
        await _firebaseService.saveSosSettings(_currentUserId!, settings);
        debugPrint('✅ Settings saved to Firebase');
      }
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('SOS settings saved successfully'),
            backgroundColor: AppTheme.successColor,
          ),
        );
      }
    } catch (e) {
      debugPrint('Error saving settings: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error saving settings: $e'),
            backgroundColor: AppTheme.dangerColor,
          ),
        );
      }
    }
  }
  
  Future<void> _loadEmergencyContacts() async {
    if (_currentUserId == null) {
      debugPrint('No user ID available for loading emergency contacts');
      return;
    }
    
    try {
      final contactsSnapshot = await _firebaseService.getEmergencyContactsStream(_currentUserId!).first;
      
      if (mounted) {
        setState(() {
          _emergencyContacts = contactsSnapshot.docs.map((doc) {
            final data = doc.data() as Map<String, dynamic>;
            return {
              'id': doc.id,
              ...data,
            };
          }).toList();
        });
        
        // Set primary contact if available
        final primaryContact = _emergencyContacts.firstWhere(
          (contact) => contact['isPrimary'] == true,
          orElse: () => {},
        );
        
        if (primaryContact.isNotEmpty) {
          _emergencyContactController.text = primaryContact['name'] ?? '';
          if (_emergencyNumberController.text.isEmpty) {
            _emergencyNumberController.text = primaryContact['phone'] ?? '';
          }
        }
      }
    } catch (e) {
      debugPrint('Error loading emergency contacts: $e');
    }
  }
  
  Future<void> _checkLocationPermission() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Location services are disabled. Please enable them.')),
          );
        }
        return;
      }
      
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Location permissions are denied')),
            );
          }
          return;
        }
      }
      
      if (permission == LocationPermission.deniedForever) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Location permissions are permanently denied, we cannot request permissions.'),
            ),
          );
        }
        return;
      }
      
      if (mounted) {
        setState(() {
          _locationPermissionGranted = true;
        });
      }
      
      await _getCurrentPosition();
    } catch (e) {
      debugPrint('Error checking location permission: $e');
      // Don't crash the app, just log the error
    }
  }
  
  Future<void> _getCurrentPosition() async {
    try {
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 10), // Add timeout
      );
      if (mounted) {
        setState(() {
          _currentPosition = position;
        });
      }
    } catch (e) {
      debugPrint('Error getting current position: $e');
      // Don't crash, just log the error
    }
  }
  
  void _toggleAutoSos(bool value) async {
    setState(() {
      _autoSosEnabled = value;
    });
    
    _saveSettings();
    
    if (value) {
      // Enable SOS with automatic fall detection
      await _sosService.enableSOS();
      _startMonitoring();
    } else {
      // Disable SOS and fall detection
      await _sosService.disableSOS();
      _stopMonitoring();
    }
  }
  
  Future<void> _saveEmergencyContact() async {
    if (_currentUserId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please log in to save emergency contacts'),
          backgroundColor: AppTheme.dangerColor,
        ),
      );
      return;
    }
    
    if (_emergencyContactController.text.isEmpty || _emergencyNumberController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please fill in both contact name and phone number'),
          backgroundColor: AppTheme.dangerColor,
        ),
      );
      return;
    }
    
    try {
      final contactData = {
        'name': _emergencyContactController.text,
        'phone': _emergencyNumberController.text,
        'relationship': 'Emergency Contact',
        'isPrimary': _emergencyContacts.isEmpty, // First contact becomes primary
      };
      
      await _firebaseService.addEmergencyContact(_currentUserId!, contactData);
      
      // Clear form
      _emergencyContactController.clear();
      _emergencyNumberController.clear();
      
      // Reload contacts
      await _loadEmergencyContacts();
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Emergency contact saved successfully'),
            backgroundColor: AppTheme.successColor,
          ),
        );
      }
    } catch (e) {
      debugPrint('Error saving emergency contact: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error saving contact: $e'),
            backgroundColor: AppTheme.dangerColor,
          ),
        );
      }
    }
  }
  
  Future<void> _deleteEmergencyContact(String contactId) async {
    try {
      await _firebaseService.deleteEmergencyContact(contactId);
      
      // Reload contacts
      await _loadEmergencyContacts();
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Emergency contact deleted successfully'),
          backgroundColor: AppTheme.successColor,
        ),
      );
    } catch (e) {
      debugPrint('Error deleting emergency contact: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error deleting contact: $e'),
          backgroundColor: AppTheme.dangerColor,
        ),
      );
    }
  }
  
  Future<void> _showDeleteContactDialog(Map<String, dynamic> contact) async {
    return showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: AppTheme.bgDarkSecondary,
          title: Text(
            'Delete Emergency Contact',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
          content: Text(
            'Are you sure you want to delete "${contact['name']}" from your emergency contacts?',
            style: TextStyle(
              color: Colors.white.withOpacity(0.8),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(
                'Cancel',
                style: TextStyle(color: AppTheme.textTeal),
              ),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                _deleteEmergencyContact(contact['id']);
              },
              child: Text(
                'Delete',
                style: TextStyle(color: AppTheme.dangerColor),
              ),
            ),
          ],
        );
      },
    );
  }
  
  void _startMonitoring() {
    // Stop existing monitoring first
    _stopMonitoring();
    
    _monitoringTimer = Timer.periodic(
      Duration(milliseconds: AppConstants.sosMonitoringIntervalMs),
      (_) => _checkVitals(),
    );
  }
  
  void _stopMonitoring() {
    _monitoringTimer?.cancel();
    _monitoringTimer = null;
    _abnormalVitalsDetected = false;
    _abnormalVitalsStartTime = null;
  }
  
  bool _isCheckingVitals = false;

  void _checkVitals() {
    // Prevent re-entrant calls that can eventually blow the stack if the
    // check itself throws and the Timer keeps scheduling new callbacks.
    if (_isCheckingVitals) return;
    _isCheckingVitals = true;
    // Prevent execution if disposed or not mounted
    if (_isDisposed || !mounted) {
      return;
    }
    
    // In a real app, these values would come from a connected wearable
    // For demo purposes, we'll simulate random fluctuations within normal ranges
    // to prevent accidental SOS triggers during testing
    if (!_sosActive) {
      // Simulate normal vital signs with slight variations
      _heartRate = 70 + (DateTime.now().millisecond % 10); // 70-79 BPM
      _spo2 = 97 + (DateTime.now().second % 3); // 97-99%
    }
    
    // Check if vitals are abnormal
    bool isAbnormal = _heartRate > AppConstants.hrThresholdHigh || 
                      _spo2 < AppConstants.spo2ThresholdLow;
    
    if (isAbnormal && !_abnormalVitalsDetected) {
      // First detection of abnormal vitals
      _abnormalVitalsDetected = true;
      _abnormalVitalsStartTime = DateTime.now();
      debugPrint('🚨 Abnormal vitals detected: HR=$_heartRate, SpO2=$_spo2');
    } else if (isAbnormal && _abnormalVitalsDetected) {
      // Continuing abnormal vitals
      final now = DateTime.now();
      final duration = now.difference(_abnormalVitalsStartTime!).inMilliseconds;
      
      if (duration >= AppConstants.sosAbnormalDurationMs && !_sosActive) {
        // Abnormal vitals for the threshold duration, trigger SOS
        debugPrint('⚠️ Triggering Auto SOS after ${duration}ms of abnormal vitals');
        _triggerAutoSos();
      }
    } else if (!isAbnormal && _abnormalVitalsDetected) {
      // Vitals returned to normal
      _abnormalVitalsDetected = false;
      _abnormalVitalsStartTime = null;
      debugPrint('✅ Vitals returned to normal');
    }
    _isCheckingVitals = false;
  }
  
  void _triggerAutoSos() {
    if (!mounted || _sosActive) return; // Prevent multiple triggers
    
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Abnormal vitals detected! Initiating emergency countdown.'),
        backgroundColor: AppTheme.dangerColor,
        duration: Duration(seconds: 5),
      ),
    );
    
    // Save auto SOS event
    _saveSosEvent('auto');
    
    _startSos();
  }
  
  void _startSos() {
    try {
      // Cancel any previous local timers
      _countdownTimer?.cancel();

      if (!mounted || _isDisposed) return;

      // Persist a record that user manually started SOS
      unawaited(_saveSosEvent('manual'));

      // Start the global SOS countdown via service (handles alarm + timer)
      unawaited(_sosService.startSOSCountdown());

      // Proactively request phone permission so the app can auto-dial when dispatching
      unawaited(() async {
        try {
          final status = await Permission.phone.status;
          if (!status.isGranted) {
            await Permission.phone.request();
          }
        } catch (_) {}
      }());

      // Update current location (safe)
      unawaited(_getCurrentPosition());

      // Immediately reflect active UI and seconds from service
      setState(() {
        _sosActive = true;
        _countdownSeconds = _sosService.countdownSeconds;
      });
    } catch (e) {
      debugPrint('❌ Unexpected error starting SOS: $e');
      if (mounted && !_isDisposed) {
        setState(() {
          _sosActive = false;
          _countdownSeconds = 30;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Unable to start SOS: $e'),
            backgroundColor: AppTheme.dangerColor,
          ),
        );
      }
    }
  }
  
  Future<void> _saveSosEvent(String type) async {
    try {
      if (_currentUserId != null) {
        final sosData = {
          'type': type,
          'location': _currentPosition != null 
              ? GeoPoint(_currentPosition!.latitude, _currentPosition!.longitude)
              : null,
          'vitals': {
            'heartRate': _heartRate,
            'spo2': _spo2,
          },
          'emergencyContacts': _emergencyContacts.map((contact) => contact['phone']).toList(),
          'status': 'triggered',
        };
        
        await _firebaseService.addSosEvent(_currentUserId!, sosData);
      }
    } catch (e) {
      debugPrint('Error saving SOS event: $e');
    }
  }
  
  void _cancelSos() {
    _countdownTimer?.cancel();
    
    setState(() {
      _sosActive = false;
      _countdownSeconds = 30;
    });
    
    // Stop alarm sound
    _stopAlarm();
    
    // Stop global SOS countdown if active
    _sosService.stopSOSCountdown();
    
    // Update SOS event status
    _updateSosEventStatus('cancelled');
    
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Emergency alert cancelled')),
    );
  }
  
  Future<void> _updateSosEventStatus(String status) async {
    try {
      if (_currentUserId != null) {
        final updates = {
          'status': status,
          if (status == 'cancelled') 'cancelledAt': FieldValue.serverTimestamp(),
          if (status == 'dispatched') 'dispatchedAt': FieldValue.serverTimestamp(),
        };
        
        // Get the latest SOS event and update it
        final sosEvents = await _firebaseService.getSosEventsStream(_currentUserId!).first;
        if (sosEvents.docs.isNotEmpty) {
          final latestEvent = sosEvents.docs.first;
          await _firebaseService.updateSosEvent(latestEvent.id, updates);
        }
      }
    } catch (e) {
      debugPrint('Error updating SOS event: $e');
    }
  }
  
  Future<void> _dispatchEmergency() async {
    if (!mounted) return;

    // Send Telegram SOS alert
    try {
      final authService = Provider.of<AuthService>(context, listen: false);
      final userName = authService.currentUser?.displayName ?? 'Unknown';
      final locationText = _formatLocation();
      final latitude = _currentPosition?.latitude;
      final longitude = _currentPosition?.longitude;

      // Send to default chat/group
      await TelegramService().sendSosAlert(
        userName: userName,
        heartRate: _heartRate,
        spo2: _spo2,
        locationText: locationText,
        latitude: latitude,
        longitude: longitude,
      );

      // Send to any globally configured extra IDs
      for (final id in AppConstants.extraTelegramChatIds) {
        if (id.isNotEmpty) {
          await TelegramService().sendSosAlert(
            userName: userName,
            heartRate: _heartRate,
            spo2: _spo2,
            locationText: locationText,
            latitude: latitude,
            longitude: longitude,
            chatId: id,
          );
        }
      }

      // Send directly to contacts that have telegramChatId
      for (final contact in _emergencyContacts) {
        if (contact.containsKey('telegramChatId') && contact['telegramChatId'].toString().isNotEmpty) {
          await TelegramService().sendSosAlert(
            userName: userName,
            heartRate: _heartRate,
            spo2: _spo2,
            locationText: locationText,
            latitude: latitude,
            longitude: longitude,
            chatId: contact['telegramChatId'].toString(),
          );
        }
      }
    } catch (e) {
      debugPrint('Error sending Telegram SOS: $e');
    }
    
    // Update SOS event status
    await _updateSosEventStatus('dispatched');
    
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Emergency services notified!'),
        backgroundColor: AppTheme.dangerColor,
        duration: Duration(seconds: 5),
      ),
    );
    
    // In a real app, this would send data to emergency services
    // For demo, we'll just simulate a call
    final emergencyNumber = _emergencyNumberController.text.isNotEmpty
        ? _emergencyNumberController.text
        : _getDefaultEmergencyNumber();
    
    if (emergencyNumber.isNotEmpty) {
      await _callNumber(emergencyNumber);
    }
    
    // Reset SOS state
    setState(() {
      _sosActive = false;
    });
    
    // Stop alarm after emergency is dispatched
    _stopAlarm();
  }
  
  String _getDefaultEmergencyNumber() {
    // In a real app, this would determine the appropriate emergency number
    // based on the user's current location
    return AppConstants.defaultEmergencyNumber;
  }
  
  String _formatLocation() {
    if (_currentPosition == null) {
      return 'Unknown location';
    }
    
    return 'Lat: ${_currentPosition!.latitude.toStringAsFixed(6)}, '
        'Long: ${_currentPosition!.longitude.toStringAsFixed(6)}';
  }

  // Auto-dial emergency number
  Future<void> _callNumber(String number) async {
    try {
      // First try to get phone permission
      final status = await Permission.phone.status;
      if (!status.isGranted) {
        final result = await Permission.phone.request();
        if (!result.isGranted) {
          debugPrint('⚠️ Phone permission denied, trying to open dialer');
          // Fallback to opening dialer
          final url = 'tel:$number';
          if (await canLaunchUrl(Uri.parse(url))) {
            await launchUrl(Uri.parse(url));
            debugPrint('✅ Opened dialer with number: $number');
            return;
          }
        }
      }
      
      // Try AndroidIntent first (direct call)
      try {
        final intent = AndroidIntent(
          action: 'android.intent.action.CALL',
          data: 'tel:$number',
        );
        await intent.launch();
        debugPrint('✅ Auto-dialing emergency number: $number');
      } catch (e) {
        debugPrint('⚠️ AndroidIntent failed, trying url_launcher: $e');
        // Fallback to url_launcher
        final url = 'tel:$number';
        if (await canLaunchUrl(Uri.parse(url))) {
          await launchUrl(Uri.parse(url));
          debugPrint('✅ Opened dialer with number: $number');
      } else {
          debugPrint('❌ Cannot launch dialer for number: $number');
        }
      }
    } catch (e) {
      debugPrint('❌ Error placing emergency call: $e');
      // Final fallback - try to open dialer anyway
      try {
        final url = 'tel:$number';
        if (await canLaunchUrl(Uri.parse(url))) {
          await launchUrl(Uri.parse(url));
          debugPrint('✅ Final fallback - opened dialer with number: $number');
        }
      } catch (fallbackError) {
        debugPrint('❌ Final fallback also failed: $fallbackError');
      }
    }
  }

  // Play loud alarm sound
  Future<void> _playAlarm() async {
    if (_isAlarmPlaying) return;
    
    try {
      // Use the bundled notification sound
      await _audioPlayer.setAsset('assets/sounds/notification_sound.mp3');
      await _audioPlayer.setLoopMode(LoopMode.one); // Loop continuously
      await _audioPlayer.setVolume(1.0); // Max volume
      await _audioPlayer.play();
      _isAlarmPlaying = true;
    } catch (e) {
      debugPrint('Error playing alarm sound: $e');
    }
  }
  
  // Stop alarm sound
  Future<void> _stopAlarm() async {
    if (!_isAlarmPlaying) return;
    
    try {
      await _audioPlayer.stop();
      _isAlarmPlaying = false;
    } catch (e) {
      debugPrint('Error stopping alarm sound: $e');
    }
  }

  @override
  void setState(VoidCallback fn) {
    if (!mounted || _isDisposed) return; // prevent setState after dispose
    super.setState(fn);
  }

  @override
  Widget build(BuildContext context) {
    final authService = Provider.of<AuthService>(context);
    final userName = authService.currentUser?.displayName ?? 'User';
    
    return Scaffold(
      backgroundColor: AppTheme.bgDark,
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 100,
            floating: true,
            pinned: true,
            backgroundColor: AppTheme.bgDark,
            leading: IconButton(icon: const Icon(Icons.arrow_back, color: Colors.white), onPressed: () => Navigator.pop(context)),
            flexibleSpace: FlexibleSpaceBar(
              title: const Text('Emergency SOS', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
              centerTitle: true,
              background: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [AppTheme.dangerColor.withOpacity(0.2), AppTheme.bgDark],
                  ),
                ),
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator(valueColor: AlwaysStoppedAnimation<Color>(AppTheme.primaryColor)))
                : _currentUserId == null
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.error_outline, size: 64, color: Colors.white.withOpacity(0.5)),
                            const SizedBox(height: 16),
                            Text('Please log in to access SOS features', style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 16)),
                          ],
                        ),
                      )
                    : SingleChildScrollView(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (_sosActive) _buildCountdownCard() else _buildSosButton(),
                    
                    const SizedBox(height: 24),
                    
                    // Auto SOS toggle
                    GlassContainer(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Auto SOS',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            'Automatically trigger SOS when abnormal vital signs are detected for an extended period.',
                            style: TextStyle(color: AppTheme.textSecondary),
                          ),
                          const SizedBox(height: 16),
                          
                          // Current vitals
                          Row(
                            children: [
                              Expanded(
                                child: _buildVitalCard(
                                  title: 'Heart Rate',
                                  value: '$_heartRate BPM',
                                  icon: FeatherIcons.heart,
                                  isAbnormal: _heartRate > AppConstants.hrThresholdHigh,
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: _buildVitalCard(
                                  title: 'SpO2',
                                  value: '$_spo2%',
                                  icon: FeatherIcons.droplet,
                                  isAbnormal: _spo2 < AppConstants.spo2ThresholdLow,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          
                          // Toggle switch
                          SwitchListTile(
                            title: const Text(
                              'Enable Auto SOS',
                              style: TextStyle(color: Colors.white),
                            ),
                            subtitle: Text(
                              _autoSosEnabled
                                  ? 'Monitoring vital signs'
                                  : 'Disabled',
                              style: TextStyle(
                                color: _autoSosEnabled
                                    ? AppTheme.successColor
                                    : AppTheme.textSecondary,
                              ),
                            ),
                            value: _autoSosEnabled,
                            onChanged: _toggleAutoSos,
                            activeThumbColor: AppTheme.primaryColor,
                          ),
                          
                          if (_autoSosEnabled) ...[
                            const Divider(height: 24),
                            const Text(
                              'Auto SOS will trigger when:',
                              style: TextStyle(
                                fontWeight: FontWeight.w500,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              '• Heart rate exceeds ${AppConstants.hrThresholdHigh} BPM',
                              style: const TextStyle(color: AppTheme.textSecondary),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '• SpO2 falls below ${AppConstants.spo2ThresholdLow}%',
                              style: const TextStyle(color: AppTheme.textSecondary),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '• Abnormal vitals persist for ${AppConstants.sosAbnormalDurationMs ~/ 1000} seconds',
                              style: const TextStyle(color: AppTheme.textSecondary),
                            ),
                          ],
                        ],
                      ),
                    ),
                    
                    const SizedBox(height: 24),
                    
                    // Emergency contacts
                    GlassContainer(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Emergency Contact',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 16),
                          
                          // Contact name
                          TextFormField(
                            controller: _emergencyContactController,
                            decoration: const InputDecoration(
                              labelText: 'Contact Name',
                              prefixIcon: Icon(FeatherIcons.user),
                            ),
                          ),
                          const SizedBox(height: 16),
                          
                          // Contact number
                          TextFormField(
                            controller: _emergencyNumberController,
                            decoration: const InputDecoration(
                              labelText: 'Phone Number',
                              prefixIcon: Icon(FeatherIcons.phone),
                              hintText: 'e.g., 911 or +1234567890',
                            ),
                            keyboardType: TextInputType.phone,
                          ),
                          const SizedBox(height: 16),
                          
                          // Save button
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton(
                              onPressed: _saveEmergencyContact,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppTheme.primaryColor,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(vertical: 16),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                              child: const Text(
                                'Save Emergency Contact',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    
                    // Emergency Contacts List
                    if (_emergencyContacts.isNotEmpty) ...[
                      const SizedBox(height: 16),
                      const Divider(height: 24),
                      const Text(
                        'Saved Emergency Contacts',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 12),
                      ...(_emergencyContacts.map((contact) => Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppTheme.bgGlassMedium,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: contact['isPrimary'] == true 
                                ? AppTheme.primaryColor 
                                : Colors.white.withOpacity(0.1),
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              contact['isPrimary'] == true 
                                  ? FeatherIcons.star 
                                  : FeatherIcons.user,
                              color: contact['isPrimary'] == true 
                                  ? AppTheme.primaryColor 
                                  : Colors.white,
                              size: 16,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    contact['name'] ?? 'Unknown',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  Text(
                                    contact['phone'] ?? '',
                                    style: TextStyle(
                                      color: Colors.white.withOpacity(0.7),
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            if (contact['isPrimary'] == true)
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: AppTheme.primaryColor,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: const Text(
                                  'Primary',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 10,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            const SizedBox(width: 8),
                            IconButton(
                              onPressed: () => _showDeleteContactDialog(contact),
                              icon: Icon(
                                FeatherIcons.trash2,
                                color: AppTheme.dangerColor,
                                size: 16,
                              ),
                              tooltip: 'Delete Contact',
                            ),
                          ],
                        ),
                      )).toList()),
                    ],
                    
                    const SizedBox(height: 24),
                    
                    // Location info
                    GlassContainer(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Your Location',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 16),
                          
                          Row(
                            children: [
                              const Icon(
                                FeatherIcons.mapPin,
                                color: AppTheme.dangerColor,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  _formatLocation(),
                                  style: const TextStyle(color: Colors.white),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          
                          // Update location button
                          SizedBox(
                            width: double.infinity,
                            child: OutlinedButton.icon(
                              onPressed: _locationPermissionGranted
                                  ? _getCurrentPosition
                                  : _checkLocationPermission,
                              icon: const Icon(FeatherIcons.refreshCw),
                              label: const Text('Update Location'),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildSosButton() {
    return Center(
      child: GestureDetector(
        onTap: _startSos,
        child: Container(
          width: 200,
          height: 200,
          decoration: BoxDecoration(
            color: AppTheme.dangerColor.withOpacity(0.2),
            shape: BoxShape.circle,
            border: Border.all(
              color: AppTheme.dangerColor,
              width: 2,
            ),
          ),
          child: Center(
            child: Container(
              width: 160,
              height: 160,
              decoration: BoxDecoration(
                color: AppTheme.dangerColor.withOpacity(0.3),
                shape: BoxShape.circle,
                border: Border.all(
                  color: AppTheme.dangerColor,
                  width: 2,
                ),
              ),
              child: Center(
                child: Container(
                  width: 120,
                  height: 120,
                  decoration: BoxDecoration(
                    color: AppTheme.dangerColor,
                    shape: BoxShape.circle,
                  ),
                  child: const Center(
                    child: Text(
                      'SOS',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 36,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
  
  Widget _buildCountdownCard() {
    return GlassContainer(
      backgroundColor: AppTheme.dangerColor.withOpacity(0.2),
      child: Column(
        children: [
          const Text(
            'EMERGENCY SOS ACTIVATED',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 16),
          
          Text(
            'Dispatching in $_countdownSeconds seconds',
            style: const TextStyle(
              fontSize: 16,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 24),
          
          // Progress indicator
          LinearProgressIndicator(
            value: _countdownSeconds / 30,
            backgroundColor: Colors.white.withOpacity(0.3),
            valueColor: const AlwaysStoppedAnimation<Color>(AppTheme.dangerColor),
          ),
          const SizedBox(height: 24),
          
          // Cancel button
          SizedBox(
            width: double.infinity,
            height: 60,
            child: ElevatedButton(
              onPressed: _cancelSos,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: AppTheme.dangerColor,
              ),
              child: const Text(
                'I\'M OK - CANCEL',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildVitalCard({
    required String title,
    required String value,
    required IconData icon,
    required bool isAbnormal,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isAbnormal
            ? AppTheme.dangerColor.withOpacity(0.2)
            : AppTheme.bgGlassMedium,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isAbnormal
              ? AppTheme.dangerColor
              : Colors.transparent,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                icon,
                color: isAbnormal ? AppTheme.dangerColor : Colors.white,
                size: 16,
              ),
              const SizedBox(width: 8),
              Text(
                title,
                style: TextStyle(
                  fontSize: 14,
                  color: isAbnormal ? AppTheme.dangerColor : AppTheme.textSecondary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: isAbnormal ? AppTheme.dangerColor : Colors.white,
            ),
          ),
          if (isAbnormal) ...[
            const SizedBox(height: 4),
            Text(
              'Abnormal',
              style: TextStyle(
                fontSize: 12,
                color: AppTheme.dangerColor,
              ),
            ),
          ],
        ],
      ),
    );
  }
}