import 'package:flutter/material.dart';
import 'screens/login_screen.dart';
import 'screens/home_screen.dart';
import 'services/supabase_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await SupabaseService.initialize();
  } catch (e) {
    // Prevent app crash at startup if offline
    debugPrint('Supabase init error: $e');
  }
  runApp(const SiyaMobileApp());
}

class SiyaMobileApp extends StatelessWidget {
  const SiyaMobileApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
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
