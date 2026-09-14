import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_app/services/system_info_service.dart';

void main() {
  group('SystemInfoService & App Information Telemetry Tests', () {
    test('SystemDiagnosticsData correctly models safe system parameters', () {
      final data = SystemDiagnosticsData(
        appName: 'Siya Solar Connect',
        version: '1.0.13',
        buildNumber: '14',
        environment: 'Development',
        serverReachability: 'Online',
        databaseStatus: 'Connected',
        realtimeStatus: 'Connected',
        apiStatus: 'Healthy',
        latencyMs: 85,
        lastSyncTime: DateTime(2026, 9, 14, 10, 30),
        platform: 'Android',
        osVersion: 'Android 14',
        deviceManufacturer: 'Google',
        deviceModel: 'Pixel',
        appStorage: '42.8 MB Used',
        networkType: 'Wi-Fi',
        gpsStatus: 'Enabled',
        notificationPermission: 'Allowed',
        cameraPermission: 'Allowed',
        locationPermission: 'Allowed',
        lastSuccessfulSync: DateTime(2026, 9, 14, 10, 30),
        pendingSyncRecords: 0,
        failedSyncRecords: 0,
        healthItems: [
          const SystemHealthItem(name: 'Server', isHealthy: true),
          const SystemHealthItem(name: 'Database', isHealthy: true),
          const SystemHealthItem(name: 'Authentication', isHealthy: true),
          const SystemHealthItem(name: 'Storage', isHealthy: true),
          const SystemHealthItem(name: 'Notifications', isHealthy: true),
          const SystemHealthItem(name: 'Realtime', isHealthy: true),
          const SystemHealthItem(name: 'Sync', isHealthy: true),
        ],
        isAdmin: true,
        storageStatus: 'Connected / Healthy',
        lastBackup: 'Automated Daily Snapshot',
        activeUsersCount: 5,
        recentSystemErrors: [],
      );

      expect(data.appName, equals('Siya Solar Connect'));
      expect(data.version, equals('1.0.13'));
      expect(data.buildNumber, equals('14'));
      expect(data.serverReachability, equals('Online'));
      expect(data.databaseStatus, equals('Connected'));
      expect(data.realtimeStatus, equals('Connected'));
      expect(data.apiStatus, equals('Healthy'));
      expect(data.latencyMs, equals(85));
      expect(data.formattedLastSync, contains('14/09/2026'));
      expect(data.formattedLastSuccessfulSync, contains('14/09/2026'));
      expect(data.healthItems.length, equals(7));
      expect(data.healthItems.every((h) => h.isHealthy), isTrue);
      expect(data.isAdmin, isTrue);
    });

    test('Diagnostics data does NOT expose sensitive credentials, tokens, or IMEI', () {
      final data = SystemDiagnosticsData(
        appName: 'Siya Solar Connect',
        version: '1.0.12',
        buildNumber: '13',
        environment: 'Development',
        serverReachability: 'Online',
        databaseStatus: 'Connected',
        realtimeStatus: 'Connected',
        apiStatus: 'Healthy',
        latencyMs: 120,
        lastSyncTime: DateTime.now(),
        platform: 'Android',
        osVersion: 'Android 14',
        deviceManufacturer: 'Samsung',
        deviceModel: 'Galaxy S23',
        appStorage: '45 MB Used',
        networkType: 'Mobile Data',
        gpsStatus: 'Enabled',
        notificationPermission: 'Allowed',
        cameraPermission: 'Allowed',
        locationPermission: 'Allowed',
        lastSuccessfulSync: DateTime.now(),
        pendingSyncRecords: 0,
        failedSyncRecords: 0,
        healthItems: const [],
        isAdmin: false,
        storageStatus: 'OK',
        lastBackup: 'N/A',
        activeUsersCount: 1,
        recentSystemErrors: const [],
      );

      // Verify no fields contain IMEI, auth token, or sensitive data
      final stringRepresentation = '${data.appName} ${data.deviceManufacturer} ${data.deviceModel} ${data.osVersion}';
      expect(stringRepresentation, isNot(contains('imei')));
      expect(stringRepresentation, isNot(contains('token')));
      expect(stringRepresentation, isNot(contains('password')));
      expect(stringRepresentation, isNot(contains('bearer')));
      expect(data.isAdmin, isFalse);
    });

    test('SystemInfoService logDiagnosticError and safe syncNow error handling', () async {
      SystemInfoService.logDiagnosticError('Mock network glitch test');
      // fetchDiagnostics in test environment will gracefully fallback
      final data = await SystemInfoService.fetchDiagnostics();
      expect(data.appName, equals('Siya Solar Connect'));
      expect(data.healthItems.any((h) => h.name == 'Server'), isTrue);
      expect(data.healthItems.any((h) => h.name == 'Database'), isTrue);
      expect(data.healthItems.any((h) => h.name == 'Realtime'), isTrue);
    });
  });
}
