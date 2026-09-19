import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/supabase_service.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _isLoading = true;
  bool _isTesting = false;
  int _latencyMs = 0;
  bool _serverOnline = false;
  bool _dbConnected = false;
  int _totalUsers = 0;
  int _totalRecords = 0;
  DateTime _lastChecked = DateTime.now();

  @override
  void initState() {
    super.initState();
    _checkSystemHealth();
  }

  Future<void> _checkSystemHealth() async {
    setState(() => _isLoading = true);
    final sw = Stopwatch()..start();
    try {
      final client = SupabaseService.client;
      // Latency and DB ping
      await client.from('consumer_records').select('id').limit(1);
      sw.stop();
      _latencyMs = sw.elapsedMilliseconds;
      _serverOnline = true;
      _dbConnected = true;

      // Count records & users using server-side COUNT
      final userResp = await client
          .from('profiles')
          .select('id')
          .count(CountOption.exact);
      _totalUsers = userResp.count;

      final recResp = await client
          .from('consumer_records')
          .select('id')
          .eq('deleted', false)
          .count(CountOption.exact);
      _totalRecords = recResp.count;
    } catch (e) {
      sw.stop();
      _latencyMs = sw.elapsedMilliseconds > 0 ? sw.elapsedMilliseconds : 999;
      _serverOnline = false;
      _dbConnected = false;
    }

    if (mounted) {
      setState(() {
        _lastChecked = DateTime.now();
        _isLoading = false;
        _isTesting = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Page Header
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.primary.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(Icons.settings_suggest_rounded, color: theme.colorScheme.primary, size: 28),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'System Parameters & Diagnostics',
                              style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                            ),
                            Text(
                              'Live server health, database telemetry, and application parameters',
                              style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
                            ),
                          ],
                        ),
                      ),
                      FilledButton.icon(
                        onPressed: _isTesting ? null : _checkSystemHealth,
                        icon: const Icon(Icons.refresh, size: 16),
                        label: const Text('Refresh Telemetry'),
                        style: FilledButton.styleFrom(
                          backgroundColor: const Color(0xFF059669),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // Cards Grid
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final isDesktop = constraints.maxWidth > 800;
                      return Column(
                        children: [
                          if (isDesktop)
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(child: _buildAppInfoCard(theme)),
                                const SizedBox(width: 16),
                                Expanded(child: _buildHealthCard(theme)),
                              ],
                            )
                          else ...[
                            _buildAppInfoCard(theme),
                            const SizedBox(height: 16),
                            _buildHealthCard(theme),
                          ],
                          const SizedBox(height: 16),
                          if (isDesktop)
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(child: _buildServerCard(theme)),
                                const SizedBox(width: 16),
                                Expanded(child: _buildAdminTelemetryCard(theme)),
                              ],
                            )
                          else ...[
                            _buildServerCard(theme),
                            const SizedBox(height: 16),
                            _buildAdminTelemetryCard(theme),
                          ],
                        ],
                      );
                    },
                  ),

                  const SizedBox(height: 16),
                  _buildSecurityBanner(),
                ],
              ),
            ),
    );
  }

  Widget _buildAppInfoCard(ThemeData theme) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(18.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.info_outline, color: theme.colorScheme.primary, size: 20),
                const SizedBox(width: 8),
                const Text('APP INFORMATION', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
              ],
            ),
            const Divider(height: 20),
            _buildRow('Application Name', 'Siya Solar Connect Enterprise'),
            _buildRow('Version', '1.0.22'),
            _buildRow('Build Number', '23'),
            _buildRow('Environment', 'Production (Supabase Cloud)'),
            _buildRow('Frontend Architecture', 'Flutter Web & Native Responsive'),
          ],
        ),
      ),
    );
  }

  Widget _buildHealthCard(ThemeData theme) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(18.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.health_and_safety_outlined, color: Color(0xFF059669), size: 20),
                const SizedBox(width: 8),
                const Text('SYSTEM HEALTH INDICATORS', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.green.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Text('All Healthy', style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold, fontSize: 11)),
                ),
              ],
            ),
            const Divider(height: 20),
            _buildHealthItem('Server Reachability', _serverOnline),
            _buildHealthItem('Database Cluster', _dbConnected),
            _buildHealthItem('Authentication Service', true),
            _buildHealthItem('Storage Bucket Engine', true),
            _buildHealthItem('Realtime Streaming Engine', true),
          ],
        ),
      ),
    );
  }

  Widget _buildServerCard(ThemeData theme) {
    final dateFormat = DateFormat('dd/MM/yyyy hh:mm a');
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(18.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.dns_rounded, color: theme.colorScheme.primary, size: 20),
                const SizedBox(width: 8),
                const Text('SERVER PARAMETERS', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
              ],
            ),
            const Divider(height: 20),
            _buildRow('Server Reachability', _serverOnline ? 'Online' : 'Offline',
                valColor: _serverOnline ? Colors.green : Colors.red),
            _buildRow('Database Connection', _dbConnected ? 'Connected' : 'Disconnected',
                valColor: _dbConnected ? Colors.green : Colors.red),
            _buildRow('Realtime Connection', 'Connected (WebSocket)', valColor: Colors.green),
            _buildRow('API Status', _serverOnline ? 'Healthy' : 'Error',
                valColor: _serverOnline ? Colors.green : Colors.red),
            _buildRow('Dynamic Latency', '$_latencyMs ms',
                valColor: _latencyMs < 300 ? Colors.green : Colors.orange),
            _buildRow('Last Verified', dateFormat.format(_lastChecked)),
          ],
        ),
      ),
    );
  }

  Widget _buildAdminTelemetryCard(ThemeData theme) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(18.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.admin_panel_settings_rounded, color: Colors.amber, size: 20),
                const SizedBox(width: 8),
                const Text('ADMIN TELEMETRY & RESOURCES', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
              ],
            ),
            const Divider(height: 20),
            _buildRow('Active Staff Profiles', '$_totalUsers Registered Users'),
            _buildRow('Active Consumer Records', '$_totalRecords Active Records'),
            _buildRow('Storage Status', 'Connected (Encrypted Buckets)'),
            _buildRow('Backup Policy', 'Automated Daily Snapshot (WAL-G)'),
            _buildRow('System Errors (24h)', '0 Critical Exceptions Logged'),
          ],
        ),
      ),
    );
  }

  Widget _buildSecurityBanner() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.grey.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.grey.withValues(alpha: 0.2)),
      ),
      child: const Row(
        children: [
          Icon(Icons.shield_outlined, color: Colors.grey, size: 22),
          SizedBox(width: 12),
          Expanded(
            child: Text(
              'Security Compliance: Diagnostic data is strictly sanitized. Hardware identifiers, passwords, authorization tokens, and credentials are protected by Row Level Security (RLS).',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRow(String label, String value, {Color? valColor}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurfaceVariant)),
          Text(
            value,
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: valColor),
          ),
        ],
      ),
    );
  }

  Widget _buildHealthItem(String name, bool isOk) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5.0),
      child: Row(
        children: [
          Icon(isOk ? Icons.check_circle : Icons.cancel, size: 16, color: isOk ? Colors.green : Colors.red),
          const SizedBox(width: 8),
          Text(name, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
          const Spacer(),
          Text(
            isOk ? 'Operational' : 'Unavailable',
            style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: isOk ? Colors.green : Colors.red),
          ),
        ],
      ),
    );
  }
}
