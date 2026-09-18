import 'package:flutter/material.dart';
import 'screens/login_screen.dart';
import 'screens/home_screen.dart';
import 'screens/create_task_screen.dart';
import 'services/supabase_service.dart';
import 'services/share_intent_service.dart';
import 'services/offline_task_sync_service.dart';
import 'services/app_database.dart';
import 'services/connectivity_service.dart';
import 'services/sync_engine.dart';

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 1. Initialize SQLite local database
  try {
    await AppDatabase.database;
  } catch (e) {
    debugPrint('AppDatabase init error: $e');
  }

  // 2. Initialize network & connectivity monitor
  try {
    await ConnectivityService.initialize();
  } catch (e) {
    debugPrint('ConnectivityService init error: $e');
  }

  // 3. Initialize sync engine
  try {
    SyncEngine.initialize();
  } catch (e) {
    debugPrint('SyncEngine init error: $e');
  }

  // 4. Initialize Supabase
  try {
    await SupabaseService.initialize();
  } catch (e) {
    debugPrint('Supabase init error: $e');
  }

  // 5. Load offline task queue
  try {
    await OfflineTaskSyncService.loadQueue();
  } catch (e) {
    debugPrint('Offline queue init error: $e');
  }

  // 6. Initialize Android Native Share Intent Service
  try {
    await ShareIntentService.initialize();
  } catch (e) {
    debugPrint('ShareIntentService init error: $e');
  }

  // Configure Direct Navigation from WhatsApp Share
  ShareIntentService.onDirectNavigate = (sharedDoc) {
    final nav = navigatorKey.currentState;
    if (nav != null) {
      nav.push(
        MaterialPageRoute(
          builder: (_) => CreateTaskScreen(document: sharedDoc),
        ),
      );
    }
  };

  runApp(const SiyaMobileApp());
}

class SiyaMobileApp extends StatefulWidget {
  const SiyaMobileApp({super.key});

  @override
  State<SiyaMobileApp> createState() => _SiyaMobileAppState();
}

class _SiyaMobileAppState extends State<SiyaMobileApp> {
  @override
  void initState() {
    super.initState();
    // Check if a document was received during cold launch
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final pendingDoc = ShareIntentService.consumePendingDocument();
      if (pendingDoc != null && navigatorKey.currentState != null) {
        navigatorKey.currentState!.push(
          MaterialPageRoute(
            builder: (_) => CreateTaskScreen(document: pendingDoc),
          ),
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: navigatorKey,
      title: 'Siya Solar',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF059669), // Emerald Solar Green
          brightness: Brightness.light,
        ),
      ),
      darkTheme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF059669),
          brightness: Brightness.dark,
        ),
      ),
      themeMode: ThemeMode.system,
      home: SupabaseService.isAuthenticated
          ? const MobileHomeScreen()
          : const MobileLoginScreen(),
    );
  }
}
