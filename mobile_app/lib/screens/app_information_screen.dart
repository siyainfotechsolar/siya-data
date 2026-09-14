import 'package:flutter/material.dart';
import '../services/system_info_service.dart';

class AppInformationScreen extends StatefulWidget {
  const AppInformationScreen({super.key});

  @override
  State<AppInformationScreen> createState() => _AppInformationScreenState();
}

class _AppInformationScreenState extends State<AppInformationScreen> {
  bool _isLoading = true;
  bool _isSyncing = false;
  SystemDiagnosticsData? _diagnostics;

  @override
  void initState() {
    super.initState();
    _loadDiagnostics();
  }

  Future<void> _loadDiagnostics() async {
    setState(() => _isLoading = true);
    final data = await SystemInfoService.fetchDiagnostics();
    if (mounted) {
      setState(() {
        _diagnostics = data;
        _isLoading = false;
      });
    }
  }

  Future<void> _handleSyncNow() async {
    setState(() => _isSyncing = true);
    final data = await SystemInfoService.syncNow();
    if (mounted) {
      setState(() {
        _diagnostics = data;
        _isSyncing = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.check_circle, color: Colors.white, size: 20),
              const SizedBox(width: 8),
              Text(
                'Sync completed successfully! Latency: ${data.latencyMs} ms',
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ],
          ),
          backgroundColor: const Color(0xFF059669),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'App Information',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Refresh System Telemetry',
            onPressed: _isLoading || _isSyncing ? null : _loadDiagnostics,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('Loading system parameters...', style: TextStyle(color: Colors.grey)),
                ],
              ),
            )
          : RefreshIndicator(
              onRefresh: _loadDiagnostics,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Brand Header Card
                    _buildAppHeaderCard(theme, isDark),
                    const SizedBox(height: 14),

                    // System Health Card
                    _buildSystemHealthCard(theme, isDark),
                    const SizedBox(height: 14),

                    // Server Parameters Card
                    _buildServerParametersCard(theme, isDark),
                    const SizedBox(height: 14),

                    // Device Parameters Card
                    _buildDeviceParametersCard(theme, isDark),
                    const SizedBox(height: 14),

                    // Sync Information Card
                    _buildSyncInformationCard(theme, isDark),
                    const SizedBox(height: 14),

                    // Admin Only Diagnostics (if user is Admin / Owner)
                    if (_diagnostics?.isAdmin == true) ...[
                      _buildAdminDiagnosticsCard(theme, isDark),
                      const SizedBox(height: 14),
                    ],

                    // Security Compliance Note
                    _buildSecurityNote(theme, isDark),
                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ),
    );
  }

  /// App Information & Branding Header
  Widget _buildAppHeaderCard(ThemeData theme, bool isDark) {
    final d = _diagnostics!;
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: LinearGradient(
            colors: isDark
                ? [const Color(0xFF064E3B), const Color(0xFF065F46)]
                : [const Color(0xFF059669), const Color(0xFF10B981)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.solar_power_rounded, color: Colors.white, size: 30),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        d.appName,
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                          letterSpacing: 0.3,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Siya Infotech Solar Enterprise Portal',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.white.withValues(alpha: 0.9),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            const Divider(color: Colors.white24, height: 1),
            const SizedBox(height: 14),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildHeaderStatItem('Version', d.version),
                _buildHeaderStatItem('Build Number', d.buildNumber),
                _buildHeaderStatItem('Environment', d.environment),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeaderStatItem(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label.toUpperCase(),
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.75),
            fontSize: 10,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 2),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.2),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 12,
            ),
          ),
        ),
      ],
    );
  }

  /// System Health Section with Simple Indicators and Retry logic
  Widget _buildSystemHealthCard(ThemeData theme, bool isDark) {
    final d = _diagnostics!;
    final failedItems = d.healthItems.where((h) => !h.isHealthy).toList();

    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.health_and_safety_outlined, color: theme.colorScheme.primary, size: 20),
                const SizedBox(width: 8),
                Text(
                  'SYSTEM HEALTH',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.5,
                  ),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: failedItems.isEmpty
                        ? Colors.green.withValues(alpha: 0.12)
                        : Colors.orange.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    failedItems.isEmpty ? 'All Operational' : '${failedItems.length} Issues Detected',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: failedItems.isEmpty ? Colors.green.shade700 : Colors.orange.shade800,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            const Divider(height: 1),
            const SizedBox(height: 12),

            // Health Indicators Grid
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: d.healthItems.map((item) {
                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: item.isHealthy
                        ? (isDark ? Colors.green.withValues(alpha: 0.15) : Colors.green.shade50)
                        : (isDark ? Colors.red.withValues(alpha: 0.2) : Colors.red.shade50),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: item.isHealthy
                          ? Colors.green.withValues(alpha: 0.3)
                          : Colors.red.withValues(alpha: 0.4),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        item.isHealthy ? Icons.check_circle : Icons.warning_amber_rounded,
                        size: 15,
                        color: item.isHealthy ? Colors.green.shade700 : Colors.red.shade700,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        item.name,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: item.isHealthy
                              ? (isDark ? Colors.green.shade200 : Colors.green.shade900)
                              : (isDark ? Colors.red.shade200 : Colors.red.shade900),
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),

            // Display failure details & retry if any
            if (failedItems.isNotEmpty) ...[
              const SizedBox(height: 14),
              ...failedItems.map((failed) {
                return Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.red.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.red.withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.error_outline, color: Colors.red, size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              failed.name,
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                            ),
                            Text(
                              failed.failureReason ?? 'Check network connection',
                              style: TextStyle(fontSize: 11, color: Colors.grey.shade700),
                            ),
                          ],
                        ),
                      ),
                      TextButton.icon(
                        onPressed: _loadDiagnostics,
                        icon: const Icon(Icons.refresh, size: 14),
                        label: const Text('Retry', style: TextStyle(fontSize: 12)),
                        style: TextButton.styleFrom(
                          visualDensity: VisualDensity.compact,
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                        ),
                      ),
                    ],
                  ),
                );
              }),
            ],
          ],
        ),
      ),
    );
  }

  /// Server Parameters Card
  Widget _buildServerParametersCard(ThemeData theme, bool isDark) {
    final d = _diagnostics!;
    final isOnline = d.serverReachability == 'Online';

    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.dns_outlined, color: theme.colorScheme.primary, size: 20),
                const SizedBox(width: 8),
                Text(
                  'SERVER PARAMETERS',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.5,
                  ),
                ),
                const Spacer(),
                _buildStatusPill(
                  isOnline ? 'Online' : 'Offline',
                  isOnline ? Colors.green : Colors.red,
                ),
              ],
            ),
            const SizedBox(height: 12),
            const Divider(height: 1),
            const SizedBox(height: 8),

            _buildParamRow(
              'Server Reachability',
              d.serverReachability,
              icon: Icons.cloud_done_outlined,
              valueColor: isOnline ? Colors.green.shade700 : Colors.red,
            ),
            _buildParamRow(
              'Database',
              d.databaseStatus,
              icon: Icons.storage_rounded,
              valueColor: d.databaseStatus == 'Connected' ? Colors.green.shade700 : Colors.red,
            ),
            _buildParamRow(
              'Realtime Connection',
              d.realtimeStatus,
              icon: Icons.sync_alt_rounded,
              valueColor: d.realtimeStatus == 'Connected' ? Colors.green.shade700 : Colors.orange,
            ),
            _buildParamRow(
              'API Status',
              d.apiStatus,
              icon: Icons.api_rounded,
              valueColor: d.apiStatus == 'Healthy' ? Colors.green.shade700 : Colors.red,
            ),
            _buildParamRow(
              'Latency',
              '${d.latencyMs} ms',
              icon: Icons.speed_rounded,
              badge: _buildLatencyBadge(d.latencyMs),
            ),
            _buildParamRow(
              'Last Sync',
              d.formattedLastSync,
              icon: Icons.access_time_rounded,
            ),
          ],
        ),
      ),
    );
  }

  /// Device Parameters — Mobile
  Widget _buildDeviceParametersCard(ThemeData theme, bool isDark) {
    final d = _diagnostics!;

    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.phone_android_rounded, color: theme.colorScheme.primary, size: 20),
                const SizedBox(width: 8),
                Text(
                  'DEVICE PARAMETERS — MOBILE',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.5,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            const Divider(height: 1),
            const SizedBox(height: 8),

            _buildParamRow('Platform', d.platform, icon: Icons.devices_rounded),
            _buildParamRow('OS Version', d.osVersion, icon: Icons.info_outline_rounded),
            _buildParamRow('Device Manufacturer', d.deviceManufacturer, icon: Icons.business_rounded),
            _buildParamRow('Device Model', d.deviceModel, icon: Icons.smartphone_rounded),
            _buildParamRow('App Storage', d.appStorage, icon: Icons.sd_storage_rounded),
            _buildParamRow('Network', d.networkType, icon: Icons.wifi_rounded),
            _buildParamRow('GPS', d.gpsStatus, icon: Icons.location_on_rounded),
            _buildParamRow('Notification Permission', d.notificationPermission, icon: Icons.notifications_active_outlined),
            _buildParamRow('Camera Permission', d.cameraPermission, icon: Icons.camera_alt_outlined),
            _buildParamRow('Location Permission', d.locationPermission, icon: Icons.my_location_rounded),
          ],
        ),
      ),
    );
  }

  /// Sync Information Card with [Sync Now] button
  Widget _buildSyncInformationCard(ThemeData theme, bool isDark) {
    final d = _diagnostics!;

    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.cloud_sync_outlined, color: theme.colorScheme.primary, size: 20),
                const SizedBox(width: 8),
                Text(
                  'SYNC INFORMATION',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.5,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            const Divider(height: 1),
            const SizedBox(height: 8),

            _buildParamRow('Last Successful Sync', d.formattedLastSuccessfulSync, icon: Icons.check_circle_outline),
            _buildParamRow('Pending Sync Records', '${d.pendingSyncRecords}', icon: Icons.hourglass_top_rounded),
            _buildParamRow(
              'Failed Sync Records',
              '${d.failedSyncRecords}',
              icon: Icons.error_outline,
              valueColor: d.failedSyncRecords > 0 ? Colors.red : Colors.green.shade700,
            ),
            const SizedBox(height: 14),

            // Sync Now action button
            SizedBox(
              width: double.infinity,
              height: 46,
              child: FilledButton.icon(
                onPressed: _isSyncing ? null : _handleSyncNow,
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF059669),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                icon: _isSyncing
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Icon(Icons.sync_rounded),
                label: Text(
                  _isSyncing ? 'Synchronizing Data...' : 'Sync Now',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Admin Only Diagnostics Card
  Widget _buildAdminDiagnosticsCard(ThemeData theme, bool isDark) {
    final d = _diagnostics!;

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: Colors.amber.shade700.withValues(alpha: 0.4)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.admin_panel_settings_rounded, color: Colors.amber, size: 20),
                const SizedBox(width: 8),
                Text(
                  'ADMIN ONLY TELEMETRY',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.5,
                    color: isDark ? Colors.amber.shade300 : Colors.amber.shade900,
                  ),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.amber.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Text(
                    'RESTRICTED',
                    style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.amber),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            const Divider(height: 1),
            const SizedBox(height: 8),

            _buildParamRow('Database Status', 'Active PostgreSQL Connection Pool', icon: Icons.storage),
            _buildParamRow('Realtime Status', 'Supabase WebSocket Broadcast Active', icon: Icons.radar_rounded),
            _buildParamRow('Storage Status', d.storageStatus, icon: Icons.cloud_done_rounded),
            _buildParamRow('API Health', 'HTTP 200 OK Gateway', icon: Icons.health_and_safety),
            _buildParamRow('Last Backup', d.lastBackup, icon: Icons.backup_rounded),
            _buildParamRow('Active Users', '${d.activeUsersCount} Profiles Registered', icon: Icons.people_alt_rounded),

            if (d.recentSystemErrors.isNotEmpty) ...[
              const SizedBox(height: 12),
              const Text('Recent Diagnostics Logs:', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: d.recentSystemErrors.take(3).map((err) {
                    return Text(
                      err,
                      style: const TextStyle(fontSize: 10, fontFamily: 'monospace', color: Colors.red),
                    );
                  }).toList(),
                ),
              ),
            ] else ...[
              _buildParamRow('System Errors', 'No critical system errors in past 24h', icon: Icons.check_circle),
            ],
          ],
        ),
      ),
    );
  }

  /// Security Card Note
  Widget _buildSecurityNote(ThemeData theme, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? Colors.grey.shade900 : Colors.grey.shade100,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.security_rounded, size: 20, color: Colors.grey.shade700),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'SECURITY & PRIVACY GUARANTEE',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey.shade800,
                    letterSpacing: 0.3,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'For your protection, hardware IMEI, MAC addresses, authentication tokens, passwords, and private session keys are never displayed or transmitted in diagnostic telemetry.',
                  style: TextStyle(fontSize: 11, color: Colors.grey.shade600, height: 1.3),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildParamRow(
    String label,
    String value, {
    required IconData icon,
    Color? valueColor,
    Widget? badge,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0),
      child: Row(
        children: [
          Icon(icon, size: 16, color: Colors.grey.shade600),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              label,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
            ),
          ),
          if (badge != null)
            badge
          else
            Text(
              value,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: valueColor,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildStatusPill(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: color),
          ),
        ],
      ),
    );
  }

  Widget _buildLatencyBadge(int ms) {
    Color color = Colors.green;
    if (ms > 300) {
      color = Colors.orange;
    }
    if (ms > 800) {
      color = Colors.red;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        '$ms ms',
        style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: color),
      ),
    );
  }
}
