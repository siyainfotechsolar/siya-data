/// Application configuration loaded from environment or compile-time constants.
class AppConfig {
  static const String supabaseUrl = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: 'https://unueboqvasadiuvgcvvh.supabase.co',
  );

  static const String supabaseAnonKey = String.fromEnvironment(
    'SUPABASE_ANON_KEY',
    defaultValue:
        'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InVudWVib3F2YXNhZGl1dmdjdnZoIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODgxOTIyNDUsImV4cCI6MjEwMzc2ODI0NX0.hMTMoNDivYTP1i1fd86zoFPChSvQcjzBNRkd07iB6zk',
  );

  static const String appName = 'Siya Data Admin Panel';
}
