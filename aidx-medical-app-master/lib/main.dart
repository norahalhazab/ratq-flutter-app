import 'dart:async' show unawaited;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:permission_handler/permission_handler.dart';

import 'package:aidx/services/auth_service.dart';
import 'package:aidx/services/firebase_service.dart';
import 'package:aidx/services/database_init.dart';
import 'package:aidx/services/notification_service.dart';
import 'package:aidx/services/app_state_service.dart';
import 'package:aidx/services/android_wearable_service.dart';
import 'package:aidx/screens/splash_screen.dart';
import 'package:aidx/screens/auth/login_screen.dart';
import 'package:aidx/screens/Homepage.dart';
import 'package:aidx/screens/cases_screen.dart';

import 'package:aidx/utils/theme.dart';
import 'package:aidx/utils/constants.dart';
import 'utils/permission_utils.dart';

import 'firebase_options.dart';

// Global RouteObserver for route aware widgets
final RouteObserver<ModalRoute<void>> routeObserver =
RouteObserver<ModalRoute<void>>();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

  debugPrint('🚀 Starting app initialization...');

  // Configure system UI
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      systemNavigationBarColor: Colors.transparent,
      systemNavigationBarIconBrightness: Brightness.light,
    ),
  );

  SystemChrome.setEnabledSystemUIMode(
    SystemUiMode.edgeToEdge,
    overlays: [SystemUiOverlay.top, SystemUiOverlay.bottom],
  );

  try {
    debugPrint('📱 Initializing Firebase...');

    // ✅ Safer + simpler than try/catch Firebase.app()
    if (Firebase.apps.isEmpty) {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
      debugPrint('✅ Firebase initialized successfully (cold start)');
    } else {
      debugPrint('ℹ️ Firebase already initialized, reusing existing instance');
    }

    // Start heavy services without blocking first frame
    unawaited(_initializeHeavyServices());

    debugPrint('🚀 Running app...');
    runApp(const MyApp());
  } catch (e) {
    debugPrint('❌ Error during app initialization: $e');
    runApp(const AppErrorState());
  }
}

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  debugPrint('📱 FCM Background message received: ${message.messageId}');

  // Ensure Firebase is initialized in background isolate
  try {
    if (Firebase.apps.isEmpty) {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
    }
    debugPrint('✅ Firebase initialized in background');
  } catch (e) {
    debugPrint('❌ Firebase initialization failed in background: $e');
    return;
  }

  try {
    final notificationService = NotificationService();
    await notificationService.init();
    debugPrint('✅ Notification service initialized in background');

    final title =
        message.notification?.title ?? (message.data['title'] ?? 'AidX');
    final body = message.notification?.body ?? (message.data['body'] ?? '');

    debugPrint('🔔 Showing notification - Title: $title, Body: $body');

    await notificationService.showNotification(
      title: title,
      body: body,
      payload: message.data['payload'] as String?,
    );

    debugPrint('✅ Background notification shown successfully');
  } catch (e) {
    debugPrint('❌ Error handling background message: $e');
  }
}

// Initialize Firestore sample data without blocking UI startup
Future<void> _initializeSampleData() async {
  try {
    debugPrint('📱 Initializing sample data in background...');
    final dbInit = DatabaseService();
    // Don’t double-initialize here if DatabaseService() already does it elsewhere
    debugPrint('✅ Sample data initialization complete');
  } catch (e) {
    debugPrint('⚠️ Error initializing sample data: $e');
  }
}

// Initializes services that can run in the background after the first frame.
Future<void> _initializeHeavyServices() async {
  try {
    debugPrint('🛠️ Background initializing services...');

    // Notification service
    try {
      final notificationService = NotificationService();
      await notificationService.init();
      debugPrint('✅ Notification service initialized successfully');
    } catch (e) {
      debugPrint('❌ Error initializing notification service: $e');
      // Retry after delay
      try {
        await Future.delayed(const Duration(seconds: 2));
        final notificationService = NotificationService();
        await notificationService.init();
        debugPrint('✅ Notification service initialized on retry');
      } catch (retryError) {
        debugPrint('❌ Notification service retry failed: $retryError');
      }
    }

    // Preferred orientations
    try {
      await SystemChrome.setPreferredOrientations([
        DeviceOrientation.portraitUp,
        DeviceOrientation.portraitDown,
      ]);
      debugPrint('✅ Preferred orientations set');
    } catch (e) {
      debugPrint('⚠️ Error setting orientations: $e');
    }

    // Database initialization
    try {
      final databaseService = DatabaseService();
      await databaseService.initializeDatabase();
      debugPrint('✅ Database structure initialized');
    } catch (e) {
      debugPrint('⚠️ Error initializing database structure in background: $e');
    }

    // Initialize sample data
    unawaited(_initializeSampleData());
  } catch (e) {
    debugPrint('⚠️ Background service initialization error: $e');
  }
}

// Error state widget to show when app initialization fails
class AppErrorState extends StatelessWidget {
  const AppErrorState({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      home: Scaffold(
        body: Center(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.error_outline, size: 64, color: Colors.red),
                SizedBox(height: 16),
                Text(
                  'Failed to initialize app',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                SizedBox(height: 8),
                Text(
                  'Please check your internet connection and try again.',
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  Route<dynamic> _onGenerateRoute(RouteSettings settings) {
    // ✅ Fix for your runtime crash:
    // You navigate to AppConstants.routeSos and '/inbox' but they weren’t defined.
    // Here we handle them safely even if you haven’t created screens yet.
    final name = settings.name ?? '';

    if (name == AppConstants.routeSos) {
      return MaterialPageRoute(
        settings: settings,
        builder: (_) => const _PlaceholderRouteScreen(
          title: 'SOS',
          subtitle:
          'Route exists now. Replace this with your real SOS screen widget.',
        ),
      );
    }

    if (name == '/inbox') {
      return MaterialPageRoute(
        settings: settings,
        builder: (_) => const _PlaceholderRouteScreen(
          title: 'Inbox',
          subtitle:
          'Route exists now. Replace this with your real Inbox screen widget.',
        ),
      );
    }

    // fallback: null means Flutter will try `routes:` map, then `onUnknownRoute`.
    return MaterialPageRoute(
      settings: settings,
      builder: (_) => _UnknownRouteScreen(routeName: name),
    );
  }

  @override
  Widget build(BuildContext context) {
    debugPrint('📱 Building MyApp widget...');

    // Create services once and reuse them
    final authService = AuthService();
    final firebaseService = FirebaseService();

    debugPrint('📱 Auth service created, isLoggedIn: ${authService.isLoggedIn}');

    return FutureBuilder<SharedPreferences>(
      future: SharedPreferences.getInstance(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const MaterialApp(
            home: Scaffold(
              body: Center(child: CircularProgressIndicator()),
            ),
          );
        }

        final prefs = snapshot.data!;
        final appStateService = AppStateService(prefs);

        return MultiProvider(
          providers: [
            ChangeNotifierProvider<AuthService>.value(value: authService),
            ChangeNotifierProvider<FirebaseService>.value(value: firebaseService),
            ChangeNotifierProvider<AndroidWearableService>(
              create: (_) {
                final svc = AndroidWearableService();
                // ignore: unawaited_futures
                svc.initialize().then((_) => svc.autoReconnect());
                return svc;
              },
            ),
            Provider<DatabaseService>(create: (_) => DatabaseService()),
            ChangeNotifierProvider<AppStateService>.value(value: appStateService),
          ],
          child: MaterialApp(
            title: 'AidX',
            debugShowCheckedModeBanner: false,
            theme: AppTheme.lightTheme,
            darkTheme: AppTheme.darkTheme,
            themeMode: ThemeMode.light,
            navigatorObservers: [routeObserver],
            builder: (context, child) {
              return AppLifecycleWrapper(
                child: MediaQuery(
                  data: MediaQuery.of(context).copyWith(
                    alwaysUse24HourFormat: true,
                    textScaler: TextScaler.linear(1.0),
                  ),
                  child: child ?? const SizedBox.shrink(),
                ),
              );
            },
            initialRoute: '/',
            routes: {
              '/': (context) {
                debugPrint('📱 Loading SplashScreen...');
                return const SplashScreen();
              },
              AppConstants.routeLogin: (_) => const LoginScreen(),
              AppConstants.routeDashboard: (_) => const Homepage(),
              AppConstants.routeCases: (_) => const CasesScreen(),
              '/cases': (_) => const CasesScreen(),
            },

            // ✅ ensures routeSos + '/inbox' don’t crash even if not in routes map
            onGenerateRoute: _onGenerateRoute,
          ),
        );
      },
    );
  }
}

class AppLifecycleWrapper extends StatefulWidget {
  final Widget child;
  const AppLifecycleWrapper({super.key, required this.child});

  @override
  State<AppLifecycleWrapper> createState() => _AppLifecycleWrapperState();
}

class _AppLifecycleWrapperState extends State<AppLifecycleWrapper>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) => _checkPendingOpenSos());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _checkPendingOpenSos();
    }
  }

  Future<void> _checkPendingOpenSos() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      final bool openSos = prefs.getBool('pending_open_sos') ?? false;
      if (openSos) {
        await prefs.setBool('pending_open_sos', false);
        if (!mounted) return;

        Navigator.of(context).pushNamedAndRemoveUntil(
          AppConstants.routeSos,
              (route) => false,
        );
        return;
      }

      final String? pendingChat = prefs.getString('pending_open_chat');
      if (pendingChat != null && pendingChat.isNotEmpty) {
        await prefs.remove('pending_open_chat');
        if (!mounted) return;

        Navigator.of(context).pushNamedAndRemoveUntil(
          '/inbox',
              (route) => false,
        );
      }
    } catch (e) {
      // Ignore navigation errors
      debugPrint('⚠️ Pending navigation error: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return widget.child;
  }
}

/// Shown when something tries to navigate to an undefined route.
class _UnknownRouteScreen extends StatelessWidget {
  final String routeName;
  const _UnknownRouteScreen({required this.routeName});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Route not found')),
      body: Center(
        child: Text('No route defined for: $routeName'),
      ),
    );
  }
}

/// Temporary screen so `/inbox` and `AppConstants.routeSos` don’t crash.
/// Replace with your real screens later.
class _PlaceholderRouteScreen extends StatelessWidget {
  final String title;
  final String subtitle;

  const _PlaceholderRouteScreen({
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            subtitle,
            textAlign: TextAlign.center,
          ),
        ),
      ),
    );
  }
}