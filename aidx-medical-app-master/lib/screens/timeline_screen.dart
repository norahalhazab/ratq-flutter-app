import 'package:flutter/material.dart';
import '../widgets/app_drawer.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:timeline_tile/timeline_tile.dart';
import 'package:aidx/utils/theme.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'dart:async';
import 'package:flutter_feather_icons/flutter_feather_icons.dart';
import 'inbox_screen.dart';

class TimelineScreen extends StatefulWidget {
  const TimelineScreen({super.key});

  @override
  State<TimelineScreen> createState() => _TimelineScreenState();
}

class _TimelineScreenState extends State<TimelineScreen> {
  List<Map<String, dynamic>> _timelineEvents = [];
  bool _isLoading = true;
  final bool _isOffline = false;
  String _selectedMood = '';
  final TextEditingController _moodNoteController = TextEditingController();
  bool _isDisposed = false;
  
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  
  @override
  void initState() {
    super.initState();
    _loadTimelineEvents();
  }
  
  @override
  void dispose() {
    _moodNoteController.dispose();
    _isDisposed = true;
    super.dispose();
  }

  Future<void> _loadTimelineEvents() async {
    if (!mounted) return;
    
    // 1. Load from cache first for instant display
    await _loadFromCache();
    
    // 2. Then fetch from network in background
    if (_timelineEvents.isEmpty) {
      setState(() => _isLoading = true);
    }
    
    try {
      final user = _auth.currentUser;
      if (user == null) {
        if (mounted) setState(() { _timelineEvents = []; _isLoading = false; });
        return;
      }

      final uid = user.uid;
      final collectionsToQuery = [
        {'name': 'medications', 'query': _firestore.collection('medications').where('userId', isEqualTo: uid).limit(50)},
        {'name': 'medical_records', 'query': _firestore.collection('medical_records').where('userId', isEqualTo: uid).limit(50)},
        {'name': 'appointments', 'query': _firestore.collection('appointments').where('userId', isEqualTo: uid).limit(50)},
        {'name': 'symptoms', 'query': _firestore.collection('symptoms').where('userId', isEqualTo: uid).limit(100)},
        {'name': 'symptomRecords', 'query': _firestore.collection('users').doc(uid).collection('symptomRecords').limit(100)},
        {'name': 'reports', 'query': _firestore.collection('reports').where('userId', isEqualTo: uid).limit(100)},
        {'name': 'health_data', 'query': _firestore.collection('health_data').where('userId', isEqualTo: uid).limit(100)},
        {'name': 'reminders', 'query': _firestore.collection('reminders').where('userId', isEqualTo: uid).limit(50)},
        {'name': 'mood_entries', 'query': _firestore.collection('mood_entries').where('userId', isEqualTo: uid).limit(50)},
        {'name': 'chat_history', 'query': _firestore.collection('chat_history').where('userId', isEqualTo: uid).limit(25)},
        {'name': 'direct_messages', 'query': _firestore.collection('direct_messages').where('senderId', isEqualTo: uid).limit(25)},
        {'name': 'drugs', 'query': _firestore.collection('users').doc(uid).collection('drugs').limit(50)},
        {'name': 'sleep_fall_detection', 'query': _firestore.collection('sleep_fall_detection').where('userId', isEqualTo: uid).limit(100)},
        {'name': 'health_habits', 'query': _firestore.collection('health_habits').where('userId', isEqualTo: uid).limit(100)},
        {'name': 'community_posts', 'query': _firestore.collection('community_posts').where('userId', isEqualTo: uid).limit(50)},
        {'name': 'wearable_data', 'query': _firestore.collection('wearable_data').where('userId', isEqualTo: uid).limit(200)},
        {'name': 'motion_monitoring', 'query': _firestore.collection('motion_monitoring').where('userId', isEqualTo: uid).limit(200)},
      ];

      final List<Map<String, dynamic>> events = [];

      for (var collection in collectionsToQuery) {
        try {
          final snap = await (collection['query'] as Query).get().timeout(const Duration(seconds: 5));
          debugPrint('📊 Collection ${collection['name']}: ${snap.docs.length} documents');
          for (var doc in snap.docs) {
            final data = doc.data() as Map<String, dynamic>;
            final event = _createEventFromData(collection['name'] as String, doc.id, data);
            if (event != null) {
              events.add(event);
            } else {
              debugPrint('⚠️ Null event from ${collection['name']}: ${doc.id}');
            }
          }
        } catch (e) {
          debugPrint('Error querying ${collection['name']}: $e');
        }
      }

      debugPrint('📋 Total events created: ${events.length}');
      events.sort((a, b) => (b['date'] as DateTime).compareTo(a['date'] as DateTime));
      
      if (mounted) {
        setState(() {
          _timelineEvents = events;
          _isLoading = false;
        });
        
        // 3. Save to cache for next time
        await _saveToCache(events);
      }
    } catch (e) {
      debugPrint('Error loading timeline: $e');
      if (mounted) setState(() { _isLoading = false; });
    }
  }

  // Cache Management
  Future<void> _loadFromCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final String? cachedData = prefs.getString('timeline_cache');
      
      if (cachedData != null && cachedData.isNotEmpty) {
        final List<dynamic> decoded = json.decode(cachedData);
        final List<Map<String, dynamic>> cachedEvents = decoded.map((item) {
          final Map<String, dynamic> event = Map<String, dynamic>.from(item);
          // Restore DateTime objects
          if (event['date'] != null) {
            event['date'] = DateTime.parse(event['date']);
          }
          return event;
        }).where((event) => event['type'] != 'sos_events').toList(); // Filter out SOS events
        
        if (mounted && cachedEvents.isNotEmpty) {
          setState(() {
            _timelineEvents = cachedEvents;
            _isLoading = false;
          });
          debugPrint('✅ Loaded ${cachedEvents.length} events from cache (SOS events excluded)');
        }
      }
    } catch (e) {
      debugPrint('Error loading cache: $e');
    }
  }

  Future<void> _saveToCache(List<Map<String, dynamic>> events) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      // Convert DateTime to ISO string for JSON serialization
      final List<Map<String, dynamic>> serializableEvents = events.map((e) {
        final Map<String, dynamic> copy = Map.from(e);
        if (copy['date'] is DateTime) {
          copy['date'] = (copy['date'] as DateTime).toIso8601String();
        }
        return copy;
      }).toList();
      
      await prefs.setString('timeline_cache', json.encode(serializableEvents));
      debugPrint('✅ Saved ${events.length} events to cache');
    } catch (e) {
      debugPrint('Error saving cache: $e');
    }
  }

  Map<String, dynamic>? _createEventFromData(String collectionName, String docId, Map<String, dynamic> data) {
    try {
      DateTime eventDate = _toDate(data['timestamp'] ?? data['createdAt'] ?? data['date'] ?? DateTime.now());
      String title = data['title'] ?? data['name'] ?? _toTitleCase(collectionName.replaceAll('_', ' '));
      String description = data['description'] ?? data['notes'] ?? data['summary'] ?? '';
      
      if (collectionName == 'symptomRecords' || collectionName == 'symptoms') {
        final analysis = data['analysis'];
        if (analysis is Map) {
          description = analysis['summary'] ?? analysis['possible_conditions']?.toString() ?? '';
        } else if (analysis is String) description = analysis;
        title = 'Symptom Analysis: ${data['name'] ?? 'Unknown'}';
      } else if (collectionName == 'mood_entries') {
        title = 'Mood: ${data['mood'] ?? 'Recorded'}';
      }

      return {
        'id': docId,
        'title': title,
        'description': description,
        'date': eventDate,
        'type': collectionName,
        'mood': data['mood'],
        'doctor': data['doctor'],
      };
    } catch (e) {
      return null;
    }
  }

  DateTime _toDate(dynamic value) {
    if (value == null) return DateTime.now();
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    if (value is String) return DateTime.tryParse(value) ?? DateTime.now();
    if (value is int) return DateTime.fromMillisecondsSinceEpoch(value);
    return DateTime.now();
  }

  String _toTitleCase(String input) {
    if (input.isEmpty) return input;
    return input.split(' ').map((word) => word.isNotEmpty ? word[0].toUpperCase() + word.substring(1).toLowerCase() : '').join(' ');
  }

  void _showMoodDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.bgGlassMedium,
        title: const Text('How are you feeling?', style: TextStyle(color: Colors.white)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Wrap(
              spacing: 8,
              children: ['Excellent', 'Great', 'Good', 'Okay', 'Tired', 'Exhausted'].map((m) => _buildMoodChip(m)).toList(),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _moodNoteController,
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(
                hintText: 'Add a note (optional)',
                hintStyle: TextStyle(color: Colors.white70),
                enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: Colors.white24)),
                focusedBorder: OutlineInputBorder(borderSide: BorderSide(color: AppTheme.primaryColor)),
              ),
              maxLines: 2,
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () { Navigator.pop(context); _addMoodEntry(); },
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryColor),
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  Widget _buildMoodChip(String mood) {
    final emoji = _getMoodEmoji(mood);
    return ActionChip(
      label: Text('$emoji $mood', style: const TextStyle(color: Colors.white)),
      backgroundColor: _selectedMood == mood ? AppTheme.primaryColor.withOpacity(0.4) : Colors.white.withOpacity(0.1),
      onPressed: () => setState(() { _selectedMood = mood; _moodNoteController.clear(); }),
    );
  }

  Future<void> _addMoodEntry() async {
    final user = _auth.currentUser;
    if (user == null) return;
    try {
      await _firestore.collection('mood_entries').add({
        'userId': user.uid,
        'mood': _selectedMood,
        'notes': _moodNoteController.text.trim(),
        'timestamp': FieldValue.serverTimestamp(),
      });
      _loadTimelineEvents();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bgDark,
      drawer: const AppDrawer(),
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 100,
            floating: true,
            pinned: true,
            backgroundColor: AppTheme.bgDark,
            leading: Builder(builder: (context) => IconButton(icon: const Icon(FeatherIcons.menu, color: Colors.white), onPressed: () => Scaffold.of(context).openDrawer())),
            actions: [
              IconButton(icon: const Icon(FeatherIcons.inbox, color: Colors.white), onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const InboxScreen()))),
            ],
            flexibleSpace: FlexibleSpaceBar(
              title: const Text('Medical Timeline', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
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
                children: [
                  _buildHeaderActions(),
                  const SizedBox(height: 20),
                  _isLoading 
                      ? const Center(child: CircularProgressIndicator())
                      : _timelineEvents.isEmpty 
                          ? const Center(child: Text("No timeline events found", style: TextStyle(color: Colors.white54)))
                          : ListView.builder(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              itemCount: _timelineEvents.length,
                              itemBuilder: (context, index) => _buildTimelineItem(_timelineEvents[index], index == 0, index == _timelineEvents.length - 1),
                            ),
                ],
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: AppTheme.primaryColor,
        onPressed: _loadTimelineEvents,
        child: const Icon(FeatherIcons.refreshCw),
      ),
    );
  }

  Widget _buildHeaderActions() {
    return Row(
      children: [
        Expanded(
          child: ElevatedButton.icon(
            onPressed: _showMoodDialog,
            icon: const Icon(FeatherIcons.smile, size: 16),
            label: const Text("Log Mood"),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.bgGlassMedium,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: Colors.white.withOpacity(0.1))),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: ElevatedButton.icon(
            onPressed: () {}, // Placeholder for adding other events manually if needed
            icon: const Icon(FeatherIcons.plus, size: 16),
            label: const Text("Add Event"),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.bgGlassMedium,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: Colors.white.withOpacity(0.1))),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTimelineItem(Map<String, dynamic> event, bool isFirst, bool isLast) {
    final color = _getEventColor(event['type']);
    final icon = _getEventIcon(event['type']);
    
    return TimelineTile(
      alignment: TimelineAlign.manual,
      lineXY: 0.15,
      isFirst: isFirst,
      isLast: isLast,
      indicatorStyle: IndicatorStyle(
        width: 32,
        height: 32,
        indicator: Container(
          decoration: BoxDecoration(color: color.withOpacity(0.2), shape: BoxShape.circle, border: Border.all(color: color, width: 2)),
          child: Icon(icon, color: color, size: 16),
        ),
      ),
      beforeLineStyle: LineStyle(color: Colors.white.withOpacity(0.1), thickness: 2),
      afterLineStyle: LineStyle(color: Colors.white.withOpacity(0.1), thickness: 2),
      endChild: Container(
        margin: const EdgeInsets.only(bottom: 16, left: 12),
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
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  DateFormat('MMM dd, h:mm a').format(event['date']),
                  style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 12),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(color: color.withOpacity(0.2), borderRadius: BorderRadius.circular(4)),
                  child: Text(event['type'].toString().toUpperCase(), style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.bold)),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(event['title'], style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
            if (event['description'].toString().isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(event['description'], style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 14)),
            ],
          ],
        ),
      ),
    );
  }

  Color _getEventColor(String type) {
    if (type.contains('symptom')) return AppTheme.warningColor;
    if (type.contains('medication')) return AppTheme.primaryColor;
    if (type.contains('appointment')) return AppTheme.accentColor;
    if (type.contains('mood')) return Colors.pinkAccent;
    return Colors.blueGrey;
  }

  IconData _getEventIcon(String type) {
    if (type.contains('symptom')) return FeatherIcons.activity;
    if (type.contains('medication')) return Icons.medication;
    if (type.contains('appointment')) return FeatherIcons.calendar;
    if (type.contains('mood')) return FeatherIcons.smile;
    return FeatherIcons.circle;
  }

  String _getMoodEmoji(String mood) {
    switch (mood.toLowerCase()) {
      case 'excellent': return '😊';
      case 'great': return '😃';
      case 'good': return '🙂';
      case 'okay': return '😐';
      case 'tired': return '😴';
      case 'exhausted': return '😫';
      default: return '😐';
    }
  }
}