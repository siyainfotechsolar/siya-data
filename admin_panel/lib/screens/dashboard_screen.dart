import 'package:flutter/material.dart';
import '../services/supabase_service.dart';
import '../services/record_service.dart';
import '../widgets/import_dialog.dart';
import 'login_screen.dart';
import 'records_screen.dart';

class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  int _selectedIndex = 0;
  bool _isLoadingMetrics = false;
  DashboardMetrics? _metrics;

  final List<_NavDestination> _destinations = [
    _NavDestination('Dashboard', Icons.dashboard_outlined, Icons.dashboard),
    _NavDestination('Records', Icons.table_chart_outlined, Icons.table_chart),
    _NavDestination('Import Data', Icons.upload_file_outlined, Icons.upload_file),
    _NavDestination('Import History', Icons.history_outlined, Icons.history),
    _NavDestination('Users', Icons.people_outline, Icons.people),
    _NavDestination('Reports', Icons.bar_chart_outlined, Icons.bar_chart),
    _NavDestination('Settings', Icons.settings_outlined, Icons.settings),
  ];

  @override
  void initState() {
    super.initState();
    _loadMetrics();
  }

  Future<void> _loadMetrics() async {
    setState(() => _isLoadingMetrics = true);
    final m = await RecordService.fetchDashboardMetrics();
    if (mounted) {
      setState(() {
        _metrics = m;
        _isLoadingMetrics = false;
      });
    }
  }

  Future<void> _handleSignOut() async {
    await SupabaseService.signOut();
    if (mounted) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const AdminLoginScreen()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDesktop = MediaQuery.of(context).size.width >= 900;

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Icon(Icons.solar_power_rounded, color: theme.colorScheme.primary),
            const SizedBox(width: 10),
            const Text(
              'Siya Data Management',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications_none_outlined),
            tooltip: 'Notifications',
            onPressed: () {},
          ),
          const SizedBox(width: 8),
          CircleAvatar(
            backgroundColor: theme.colorScheme.primaryContainer,
            child: Text(
              'A',
              style: TextStyle(
                color: theme.colorScheme.onPrimaryContainer,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(width: 8),
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Sign Out',
            onPressed: _handleSignOut,
          ),
          const SizedBox(width: 16),
        ],
      ),
      body: Row(
        children: [
          NavigationRail(
            extended: isDesktop,
            selectedIndex: _selectedIndex,
            onDestinationSelected: (index) {
              setState(() {
                _selectedIndex = index;
              });
              if (index == 0) {
                _loadMetrics();
              }
            },
            destinations: _destinations
                .map(
                  (d) => NavigationRailDestination(
                    icon: Icon(d.icon),
                    selectedIcon: Icon(d.selectedIcon),
                    label: Text(d.label),
                  ),
                )
                .toList(),
          ),
          const VerticalDivider(thickness: 1, width: 1),
          Expanded(
            child: _buildBodyContent(),
          ),
        ],
      ),
    );
  }

  void _openImportDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => ImportDialog(
        onImportSuccess: () {
          _loadMetrics();
        },
      ),
    );
  }

  Widget _buildBodyContent() {
    switch (_selectedIndex) {
      case 0:
        return _buildDashboardView();
      case 1:
        return const RecordsScreen();
      case 2:
        return _buildImportLandingView();
      case 3:
        return _buildPlaceholderView('Import History & Audit Log', 'Phase 6 Feature');
      case 4:
        return _buildPlaceholderView('User & Staff Management', 'Phase 9 Feature');
      case 5:
        return _buildPlaceholderView('Reports & Analytics', 'Upcoming Feature');
      case 6:
        return _buildPlaceholderView('Settings', 'System Configuration');
      default:
        return _buildDashboardView();
    }
  }

  Widget _buildImportLandingView() {
    final theme = Theme.of(context);

    return Center(
      child: Container(
        constraints: const BoxConstraints(maxWidth: 720),
        padding: const EdgeInsets.all(40.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: theme.colorScheme.primary.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.cloud_upload_outlined, size: 64, color: theme.colorScheme.primary),
            ),
            const SizedBox(height: 24),
            Text(
              'Excel & CSV Import Center',
              style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Text(
              'Easily batch-import hundreds or thousands of solar consumer records from .xlsx, .xls, or .csv files with automatic header mapping and data verification.',
              textAlign: TextAlign.center,
              style: TextStyle(color: theme.colorScheme.onSurfaceVariant, fontSize: 14, height: 1.5),
            ),
            const SizedBox(height: 32),
            FilledButton.icon(
              onPressed: _openImportDialog,
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              icon: const Icon(Icons.upload_file_rounded),
              label: const Text('Launch Import Wizard', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDashboardView() {
    final theme = Theme.of(context);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'System Overview',
                    style: theme.textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Live metrics and synchronized records',
                    style: TextStyle(color: theme.colorScheme.onSurfaceVariant),
                  ),
                ],
              ),
              IconButton.outlined(
                icon: const Icon(Icons.refresh),
                tooltip: 'Refresh Dashboard',
                onPressed: _loadMetrics,
              ),
            ],
          ),
          const SizedBox(height: 24),
          Wrap(
            spacing: 16,
            runSpacing: 16,
            children: [
              _buildStatCard(
                'Total Records',
                _isLoadingMetrics ? '...' : '${_metrics?.totalRecords ?? 0}',
                Icons.description_outlined,
                Colors.blue,
              ),
              _buildStatCard(
                'Active Users',
                _isLoadingMetrics ? '...' : '${_metrics?.activeUsers ?? 1}',
                Icons.person_outline,
                Colors.green,
              ),
              _buildStatCard(
                'Recently Updated',
                _isLoadingMetrics ? '...' : '${_metrics?.recentlyUpdated ?? 0}',
                Icons.update,
                Colors.orange,
              ),
              _buildStatCard(
                'Import Batches',
                '0',
                Icons.cloud_upload_outlined,
                Colors.purple,
              ),
            ],
          ),
          const SizedBox(height: 32),

          // Recent Records Table Card
          Card(
            elevation: 2,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Recently Updated Records',
                        style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      TextButton(
                        onPressed: () => setState(() => _selectedIndex = 1),
                        child: const Text('View All Records →'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  if (_isLoadingMetrics)
                    const Center(child: Padding(padding: EdgeInsets.all(20), child: CircularProgressIndicator()))
                  else if (_metrics == null || _metrics!.recentRecords.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 24.0),
                      child: Center(
                        child: Text(
                          'No records added yet. Head to "Records" tab to add your first solar consumer.',
                          style: TextStyle(color: theme.colorScheme.onSurfaceVariant),
                        ),
                      ),
                    )
                  else
                    Table(
                      columnWidths: const {
                        0: FlexColumnWidth(1.2),
                        1: FlexColumnWidth(2),
                        2: FlexColumnWidth(1.2),
                        3: FlexColumnWidth(1.2),
                      },
                      children: [
                        const TableRow(
                          decoration: BoxDecoration(border: Border(bottom: BorderSide(color: Colors.grey, width: 0.5))),
                          children: [
                            Padding(padding: EdgeInsets.symmetric(vertical: 8), child: Text('Consumer No', style: TextStyle(fontWeight: FontWeight.bold))),
                            Padding(padding: EdgeInsets.symmetric(vertical: 8), child: Text('Name', style: TextStyle(fontWeight: FontWeight.bold))),
                            Padding(padding: EdgeInsets.symmetric(vertical: 8), child: Text('Status', style: TextStyle(fontWeight: FontWeight.bold))),
                            Padding(padding: EdgeInsets.symmetric(vertical: 8), child: Text('Last Updated', style: TextStyle(fontWeight: FontWeight.bold))),
                          ],
                        ),
                        ..._metrics!.recentRecords.map((r) {
                          return TableRow(
                            children: [
                              Padding(padding: const EdgeInsets.symmetric(vertical: 10), child: Text(r.consumerNo, style: const TextStyle(fontWeight: FontWeight.w500))),
                              Padding(padding: const EdgeInsets.symmetric(vertical: 10), child: Text(r.name)),
                              Padding(padding: const EdgeInsets.symmetric(vertical: 10), child: Text(r.status)),
                              Padding(
                                padding: const EdgeInsets.symmetric(vertical: 10),
                                child: Text(r.updatedAt != null ? r.updatedAt!.toLocal().toString().split(' ')[0] : '—'),
                              ),
                            ],
                          );
                        }),
                      ],
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(String title, String value, IconData icon, Color color) {
    final theme = Theme.of(context);

    return SizedBox(
      width: 220,
      child: Card(
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    title,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  CircleAvatar(
                    radius: 18,
                    backgroundColor: color.withValues(alpha: 0.1),
                    child: Icon(icon, color: color, size: 20),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Text(
                value,
                style: theme.textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPlaceholderView(String title, String subtitle) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.construction_rounded, size: 64, color: Colors.grey.shade400),
          const SizedBox(height: 16),
          Text(title, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Text(subtitle, style: TextStyle(color: Colors.grey.shade600)),
        ],
      ),
    );
  }
}

class _NavDestination {
  final String label;
  final IconData icon;
  final IconData selectedIcon;

  _NavDestination(this.label, this.icon, this.selectedIcon);
}
