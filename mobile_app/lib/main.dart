import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'screens/login_screen.dart';
import 'screens/home_screen.dart';
import 'screens/create_task_screen.dart';
import 'services/supabase_service.dart';
import 'services/share_intent_service.dart';
import 'services/offline_task_sync_service.dart';
import 'services/app_database.dart';
import 'services/connectivity_service.dart';
import 'services/sync_engine.dart';
import 'package:sqflite/sqflite.dart';

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

  // 7. Clean up stale WhatsApp shared docs from disk (files older than 30 days)
  // NOTE: onDirectNavigate callback is registered later in _SiyaMobileAppState.initState()
  // AFTER the widget tree is built and navigatorKey.currentState is ready.
  _cleanupStaleSharedDocs();

  runApp(const SiyaMobileApp());
}

/// Delete WhatsApp-shared files from local storage that are older than 30 days.
/// Prevents unbounded disk growth from accumulated shared PDFs/images.
void _cleanupStaleSharedDocs() {
  try {
    // Run fully asynchronous — do not await to avoid blocking app startup.
    Future.microtask(() async {
      try {
        // Resolve the app's filesDir equivalent on Flutter (path_provider not
        // available here; use the known subdirectory path derived from the
        // SQLite DB path which shares the same documents root).
        final dbPath = await getDatabasesPath();
        // filesDir is typically the parent of the databases directory.
        final filesDir = Directory(dbPath).parent;
        final sharedDocsDir = Directory('${filesDir.path}/whatsapp_shared_docs');

        if (!sharedDocsDir.existsSync()) return;

        final cutoff = DateTime.now().subtract(const Duration(days: 30));
        int deletedCount = 0;
        await for (final entity in sharedDocsDir.list()) {
          if (entity is File) {
            try {
              final stat = await entity.stat();
              if (stat.modified.isBefore(cutoff)) {
                await entity.delete();
                deletedCount++;
              }
            } catch (_) {}
          }
        }
        if (deletedCount > 0) {
          debugPrint('[Cleanup] Deleted $deletedCount stale WhatsApp shared docs (>30 days old).');
        }
      } catch (e) {
        debugPrint('[Cleanup] WhatsApp shared docs cleanup error: $e');
      }
    });
  } catch (e) {
    debugPrint('[Cleanup] Could not schedule cleanup: $e');
  }
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

    // Register onDirectNavigate HERE — after the widget tree is built and
    // navigatorKey.currentState is guaranteed to be non-null.
    // Previously set in main() before runApp() which caused a timing race
    // where cold-launch shared docs were silently dropped.
    ShareIntentService.onDirectNavigate = (sharedDoc) {
      final nav = navigatorKey.currentState;
      if (nav != null) {
        nav.push(
          MaterialPageRoute(
            builder: (_) => CreateTaskScreen(document: sharedDoc),
          ),
        );
      } else {
        // Navigator not yet available — re-queue via post-frame callback
        WidgetsBinding.instance.addPostFrameCallback((_) {
          navigatorKey.currentState?.push(
            MaterialPageRoute(
              builder: (_) => CreateTaskScreen(document: sharedDoc),
            ),
          );
        });
      }
    };

    // Check if a document was received during cold launch and deliver it
    // now that the navigator is ready.
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
        textTheme: GoogleFonts.interTextTheme(),
        cardTheme: const CardThemeData(elevation: 0),
        appBarTheme: const AppBarTheme(centerTitle: false),
        navigationBarTheme: const NavigationBarThemeData(labelBehavior: NavigationDestinationLabelBehavior.alwaysShow),
      ),
      darkTheme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF059669),
          brightness: Brightness.dark,
        ),
        textTheme: GoogleFonts.interTextTheme(ThemeData.dark().textTheme),
        cardTheme: const CardThemeData(elevation: 0),
        appBarTheme: const AppBarTheme(centerTitle: false),
      ),
      themeMode: ThemeMode.system,
      home: SupabaseService.isAuthenticated
          ? const MobileHomeScreen()
          : const MobileLoginScreen(),
    );
  }
}
