import 'dart:async' show unawaited;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

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
import 'package:aidx/screens/case_details_screen.dart';

import 'package:aidx/utils/theme.dart';
import 'package:aidx/utils/constants.dart';

import 'firebase_options.dart';

// ✅ Global navigator key (used for notification navigation)
final GlobalKey<NavigatorState> rootNavigatorKey = GlobalKey<NavigatorState>();

final RouteObserver<ModalRoute<void>> routeObserver =
RouteObserver<ModalRoute<void>>();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      systemNavigationBarColor: Colors.transparent,
      systemNavigationBarIconBrightness: Brightness.light,
    ),
  );

  //SystemChrome.setEnabledSystemUIMode(
  //  SystemUiMode.edgeToEdge,
  //  overlays: [SystemUiOverlay.top, SystemUiOverlay.bottom],
  //);

  try {
    if (Firebase.apps.isEmpty) {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
    }

    unawaited(_initializeHeavyServices());

    runApp(const MyApp());
  } catch (e) {
    runApp(const AppErrorState());
  }
}

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  try {
    if (Firebase.apps.isEmpty) {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
    }
  } catch (_) {
    return;
  }

  try {
    final notificationService = NotificationService();
    await notificationService.init();

    final title =
        message.notification?.title ?? (message.data['title'] ?? 'AidX');
    final body = message.notification?.body ?? (message.data['body'] ?? '');

    await notificationService.showNotification(
      title: title,
      body: body,
      payload: message.data['payload'] as String?,
    );
  } catch (_) {}
}

Future<void> _initializeHeavyServices() async {
  try {
    // ✅ Notification service init + inject navigator key
    final notificationService = NotificationService();
    await notificationService.init();
    notificationService.setNavigatorKey(rootNavigatorKey);

    // Preferred orientations
    await SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);

    // Database init
    try {
      final databaseService = DatabaseService();
      await databaseService.initializeDatabase();
    } catch (_) {}
  } catch (_) {}
}

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
    final name = settings.name ?? '';

    if (name == AppConstants.routeSos) {
      return MaterialPageRoute(
        settings: settings,
        builder: (_) => const _PlaceholderRouteScreen(
          title: 'SOS',
          subtitle: 'Route exists now. Replace with your SOS screen.',
        ),
      );
    }

    if (name == '/inbox') {
      return MaterialPageRoute(
        settings: settings,
        builder: (_) => const _PlaceholderRouteScreen(
          title: 'Inbox',
          subtitle: 'Route exists now. Replace with your Inbox screen.',
        ),
      );
    }

    return MaterialPageRoute(
      settings: settings,
      builder: (_) => _UnknownRouteScreen(routeName: name),
    );
  }

  @override
  Widget build(BuildContext context) {
    final authService = AuthService();
    final firebaseService = FirebaseService();

    return FutureBuilder<SharedPreferences>(
      future: SharedPreferences.getInstance(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const MaterialApp(
            home: Scaffold(body: Center(child: CircularProgressIndicator())),
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

            // ✅ IMPORTANT
            navigatorKey: rootNavigatorKey,

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
              '/': (_) => const SplashScreen(),
              AppConstants.routeLogin: (_) => const LoginScreen(),
              AppConstants.routeDashboard: (_) => const Homepage(),
              AppConstants.routeCases: (_) => const CasesScreen(),
              '/cases': (_) => const CasesScreen(),
            },
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
    WidgetsBinding.instance.addPostFrameCallback((_) => _checkPendingNavigation());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _checkPendingNavigation();
    }
  }

  Future<void> _checkPendingNavigation() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      // ✅ open case from notification tap
      final openCase = prefs.getBool('pending_open_case') ?? false;
      final caseId = prefs.getString('pending_open_caseId');

      if (openCase && caseId != null && caseId.isNotEmpty) {
        await prefs.setBool('pending_open_case', false);
        await prefs.remove('pending_open_caseId');

        if (!mounted) return;

        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => CaseDetailsScreen(caseId: caseId),
          ),
        );
        return;
      }

      // existing sos
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

      // existing inbox
      final String? pendingChat = prefs.getString('pending_open_chat');
      if (pendingChat != null && pendingChat.isNotEmpty) {
        await prefs.remove('pending_open_chat');
        if (!mounted) return;

        Navigator.of(context).pushNamedAndRemoveUntil(
          '/inbox',
              (route) => false,
        );
      }
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

class _UnknownRouteScreen extends StatelessWidget {
  final String routeName;
  const _UnknownRouteScreen({required this.routeName});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Route not found')),
      body: Center(child: Text('No route defined for: $routeName')),
    );
  }
}

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
          child: Text(subtitle, textAlign: TextAlign.center),
        ),
      ),
    );
  }
}