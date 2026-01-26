import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import '../services/health_habit_service.dart';
import '../services/notification_service.dart';
import 'package:flutter_feather_icons/flutter_feather_icons.dart';
import '../utils/theme.dart';
import 'inbox_screen.dart';

class HealthHabitsScreen extends StatefulWidget {
  const HealthHabitsScreen({super.key});

  @override
  State<HealthHabitsScreen> createState() => _HealthHabitsScreenState();
}

class _HealthHabitsScreenState extends State<HealthHabitsScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FlutterLocalNotificationsPlugin _notifications = FlutterLocalNotificationsPlugin();
  final HealthHabitService _habitService = HealthHabitService();
  final NotificationService _notificationService = NotificationService();
  
  final List<Map<String, dynamic>> _habits = [];
  List<Map<String, dynamic>> _completedHabits = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _initializeNotifications();
    _habitService.initializeTTS();
    _loadHabits();
  }

  Future<void> _initializeNotifications() async {
    const AndroidInitializationSettings initializationSettingsAndroid = AndroidInitializationSettings('@mipmap/ic_launcher');
    const InitializationSettings initializationSettings = InitializationSettings(android: initializationSettingsAndroid);
    await _notifications.initialize(initializationSettings);
  }

  Future<void> _loadHabits() async {
    setState(() => _isLoading = true);
    try {
      final userId = _auth.currentUser?.uid;
      if (userId == null) return;
      final today = DateTime.now();
      final todayStart = DateTime(today.year, today.month, today.day);
      final completedSnapshot = await _firestore
          .collection('health_habits')
          .where('userId', isEqualTo: userId)
          .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(todayStart))
          .where('date', isLessThan: Timestamp.fromDate(todayStart.add(const Duration(days: 1))))
          .get();
      _completedHabits = completedSnapshot.docs.map((doc) => doc.data()).toList();
      setState(() => _isLoading = false);
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _markHabitCompleted(String habitType, String habitName) async {
    final ok = await _habitService.markHabitCompleted(habitType);
    if (ok) {
      await _loadHabits();
      _showSnackBar('Habit completed! 🎉');
    } else {
      _showSnackBar('Already completed today');
    }
  }

  Future<void> scheduleDailyReminder(TimeOfDay time) async {
    final now = DateTime.now();
    final scheduled = DateTime(now.year, now.month, now.day, time.hour, time.minute);
    await _notificationService.scheduleRecurringNotification(
      title: 'Daily Habit Reminder',
      body: 'Complete your habits today!',
      scheduledTime: scheduled.isAfter(now) ? scheduled : scheduled.add(const Duration(days: 1)),
      frequency: 'daily',
    );
    _showSnackBar('Reminder set for ${time.format(context)}');
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message), backgroundColor: AppTheme.primaryColor));
  }

  bool _isHabitCompleted(String habitType) => _completedHabits.any((habit) => habit['habitType'] == habitType);

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
            leading: IconButton(icon: const Icon(FeatherIcons.arrowLeft, color: Colors.white), onPressed: () => Navigator.pop(context)),
            actions: [
              IconButton(icon: const Icon(FeatherIcons.inbox, color: Colors.white), onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const InboxScreen()))),
              IconButton(
                icon: const Icon(FeatherIcons.bell, color: Colors.white),
                onPressed: () async {
                  final picked = await showTimePicker(context: context, initialTime: const TimeOfDay(hour: 9, minute: 0));
                  if (picked != null) await scheduleDailyReminder(picked);
                },
              ),
              IconButton(icon: const Icon(FeatherIcons.refreshCw, color: Colors.white), onPressed: _loadHabits),
            ],
            flexibleSpace: FlexibleSpaceBar(
              title: const Text('Health Habits', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
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
                  Container(
                    padding: const EdgeInsets.all(20),
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
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(color: AppTheme.primaryColor.withOpacity(0.2), borderRadius: BorderRadius.circular(12)),
                              child: Icon(FeatherIcons.trendingUp, color: AppTheme.primaryColor, size: 20),
                            ),
                            const SizedBox(width: 12),
                            const Expanded(child: Text("Today's Progress", style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold))),
                            Text('${((_completedHabits.length / 8) * 100).round()}%', style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                          ],
                        ),
                        const SizedBox(height: 12),
                        LinearProgressIndicator(
                          value: _completedHabits.length / 8,
                          backgroundColor: Colors.white.withOpacity(0.1),
                          valueColor: AlwaysStoppedAnimation<Color>(AppTheme.primaryColor),
                        ),
                        const SizedBox(height: 8),
                        Text('${_completedHabits.length} of 8 habits completed', style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 12)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  _isLoading
                      ? const Center(child: CircularProgressIndicator())
                      : GridView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 2,
                            crossAxisSpacing: 12,
                            mainAxisSpacing: 12,
                            childAspectRatio: 1.1,
                          ),
                          itemCount: _getHabitsList().length,
                          itemBuilder: (context, index) {
                            final habit = _getHabitsList()[index];
                            final isCompleted = _isHabitCompleted(habit['type']);
                            return _buildHabitCard(habit: habit, isCompleted: isCompleted, onTap: () => _markHabitCompleted(habit['type'], habit['name']));
                          },
                        ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  List<Map<String, dynamic>> _getHabitsList() {
    return [
      {'type': 'walk', 'name': 'Walk', 'icon': FeatherIcons.activity, 'color': Colors.blue},
      {'type': 'water', 'name': 'Hydrate', 'icon': FeatherIcons.droplet, 'color': Colors.cyan},
      {'type': 'medication', 'name': 'Medication', 'icon': FeatherIcons.plus, 'color': Colors.red},
      {'type': 'exercise', 'name': 'Exercise', 'icon': FeatherIcons.zap, 'color': Colors.orange},
      {'type': 'social', 'name': 'Social', 'icon': FeatherIcons.users, 'color': Colors.purple},
      {'type': 'eating', 'name': 'Healthy Meal', 'icon': FeatherIcons.heart, 'color': Colors.green},
      {'type': 'sleep', 'name': 'Sleep', 'icon': FeatherIcons.moon, 'color': Colors.indigo},
      {'type': 'mental', 'name': 'Mindfulness', 'icon': FeatherIcons.smile, 'color': Colors.pink},
    ];
  }

  Widget _buildHabitCard({required Map<String, dynamic> habit, required bool isCompleted, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: isCompleted ? habit['color'].withOpacity(0.2) : AppTheme.bgGlassMedium,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: isCompleted ? habit['color'].withOpacity(0.5) : Colors.white.withOpacity(0.1)),
        ),
        child: Stack(
          children: [
            if (isCompleted)
              Positioned(
                top: 8, right: 8,
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: const BoxDecoration(color: Colors.green, shape: BoxShape.circle),
                  child: const Icon(Icons.check, size: 12, color: Colors.white),
                ),
              ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: isCompleted ? habit['color'].withOpacity(0.3) : Colors.white.withOpacity(0.05),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(habit['icon'], size: 24, color: isCompleted ? habit['color'] : Colors.white70),
                  ),
                  const SizedBox(height: 8),
                  Text(habit['name'], textAlign: TextAlign.center, style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}