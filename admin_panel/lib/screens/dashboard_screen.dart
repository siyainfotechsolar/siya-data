import 'dart:async';
import 'package:flutter/material.dart';
import '../services/supabase_service.dart';
import '../services/record_service.dart';
import '../services/realtime_service.dart';
import '../widgets/import_dialog.dart';
import 'login_screen.dart';
import 'records_screen.dart';
import 'history_screen.dart';
import 'recycle_bin_screen.dart';
import 'users_screen.dart';
import 'priority_list_screen.dart';
import 'duplicate_finder_screen.dart';
import 'reports_screen.dart';
import 'leads_screen.dart';

class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  int _selectedIndex = 0;
  bool _isLoadingMetrics = false;
  DashboardMetrics? _metrics;
  StreamSubscription<ConsumerRecordChangeEvent>? _metricsRealtimeSub;
  String? _selectedQueueFilter;
  String? _selectedPriorityFilter;

  final List<_NavDestination> _destinations = [
    _NavDestination('Dashboard', Icons.dashboard_outlined, Icons.dashboard),
    _NavDestination('Action Center', Icons.bolt_outlined, Icons.bolt),
    _NavDestination('Leads', Icons.leaderboard_outlined, Icons.leaderboard),
    _NavDestination('Duplicate Finder', Icons.find_in_page_outlined, Icons.find_in_page),
    _NavDestination('Records', Icons.table_chart_outlined, Icons.table_chart),
    _NavDestination('Import Data', Icons.upload_file_outlined, Icons.upload_file),
    _NavDestination('Import History', Icons.history_outlined, Icons.history),
    _NavDestination('Recycle Bin', Icons.delete_sweep_outlined, Icons.delete_sweep),
    _NavDestination('Users', Icons.people_outline, Icons.people),
    _NavDestination('Reports', Icons.bar_chart_outlined, Icons.bar_chart),
    _NavDestination('Settings', Icons.settings_outlined, Icons.settings),
  ];

  @override
  void initState() {
    super.initState();
    _loadMetrics();
    _initMetricsRealtime();
  }

  void _initMetricsRealtime() {
    RealtimeSyncService.initialize();
    _metricsRealtimeSub = RealtimeSyncService.recordEvents.listen((_) {
      if (mounted) {
        _loadMetrics();
      }
    });
  }

  @override
  void dispose() {
    _metricsRealtimeSub?.cancel();
    super.dispose();
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
        return PriorityListScreen(
          key: ValueKey(_selectedPriorityFilter),
          initialPriorityFilter: _selectedPriorityFilter,
        );
      case 2:
        return const LeadsScreen();
      case 3:
        return const DuplicateFinderScreen();
      case 4:
        return RecordsScreen(
          key: ValueKey(_selectedQueueFilter),
          initialWorkflowQueue: _selectedQueueFilter,
        );
      case 5:
        return _buildImportLandingView();
      case 6:
        return const HistoryScreen();
      case 7:
        return const RecycleBinScreen();
      case 8:
        return const UsersScreen();
      case 9:
        return const ReportsScreen();
      case 10:
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
                _isLoadingMetrics ? '...' : '${_metrics?.totalImportBatches ?? 0}',
                Icons.cloud_upload_outlined,
                Colors.purple,
              ),
            ],
          ),
          const SizedBox(height: 24),

          // PROSPECTIVE LEADS SECTION
          Card(
            elevation: 0,
            color: const Color(0xFFEFF6FF), // Soft sky blue
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: const BorderSide(color: Color(0xFFBFDBFE)),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 22,
                    backgroundColor: const Color(0xFF2563EB),
                    child: const Icon(Icons.leaderboard_rounded, color: Colors.white),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'PROSPECTIVE LEADS & INQUIRIES',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                            color: Color(0xFF1E3A8A),
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Manage pre-conversion customer inquiries, track follow-ups, and convert leads into applications.',
                          style: TextStyle(fontSize: 12, color: Colors.blue.shade900.withValues(alpha: 0.8)),
                        ),
                      ],
                    ),
                  ),
                  FilledButton.icon(
                    style: FilledButton.styleFrom(backgroundColor: const Color(0xFF2563EB)),
                    icon: const Icon(Icons.arrow_forward_rounded, size: 16),
                    label: const Text('Go to Leads'),
                    onPressed: () => setState(() => _selectedIndex = 2),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 28),

          // ACTION CENTER SECTION
          Text(
            'ACTION CENTER',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color: const Color(0xFF1E293B),
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Operational queues for customers currently requiring action',
            style: TextStyle(color: theme.colorScheme.onSurfaceVariant, fontSize: 13),
          ),
          const SizedBox(height: 14),

          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              _buildQueueCard(
                title: 'Agreement Pending',
                count: _isLoadingMetrics ? '...' : '${_metrics?.agreementPendingCount ?? 0}',
                icon: Icons.history_edu_rounded,
                color: const Color(0xFF2563EB),
                onTap: () => _openActionCenter('Agreement Pending'),
              ),
              _buildQueueCard(
                title: 'Loan Pending',
                count: _isLoadingMetrics ? '...' : '${_metrics?.loanPendingCount ?? 0}',
                icon: Icons.account_balance_rounded,
                color: const Color(0xFFD97706),
                onTap: () => _openActionCenter('Loan Pending'),
              ),
              _buildQueueCard(
                title: 'Installation Pending',
                count: _isLoadingMetrics ? '...' : '${_metrics?.installationPendingCount ?? 0}',
                icon: Icons.build_circle_outlined,
                color: const Color(0xFF0F766E),
                onTap: () => _openActionCenter('Installation Pending'),
              ),
              _buildQueueCard(
                title: 'RTS Pending',
                count: _isLoadingMetrics ? '...' : '${_metrics?.rtsPendingCount ?? 0}',
                icon: Icons.electric_meter_rounded,
                color: const Color(0xFF7C3AED),
                onTap: () => _openActionCenter('RTS Pending'),
              ),
              _buildQueueCard(
                title: 'Subsidy Processing',
                count: _isLoadingMetrics ? '...' : '${_metrics?.subsidyPendingCount ?? 0}',
                icon: Icons.currency_rupee_rounded,
                color: const Color(0xFF059669),
                onTap: () => _openActionCenter('Subsidy Processing'),
              ),
              _buildQueueCard(
                title: 'Hold / No Action',
                count: _isLoadingMetrics ? '...' : '${_metrics?.noActionCount ?? 0}',
                icon: Icons.pause_circle_filled_rounded,
                color: const Color(0xFFD97706),
                onTap: () => _openActionCenter('Hold'),
              ),
            ],
          ),
          const SizedBox(height: 28),

          // TODAY'S WORK SECTION
          Text(
            'TODAY\'S WORK',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color: const Color(0xFF1E293B),
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Summary of actionable work calculated automatically from current workflow state',
            style: TextStyle(color: theme.colorScheme.onSurfaceVariant, fontSize: 13),
          ),
          const SizedBox(height: 14),

          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              _buildQueueCard(
                title: 'Loan Follow-ups',
                count: _isLoadingMetrics ? '...' : '${_metrics?.loanFollowupsCount ?? 0}',
                icon: Icons.phone_callback_rounded,
                color: const Color(0xFFD97706),
                onTap: () => _openActionCenter('Loan Pending'),
              ),
              _buildQueueCard(
                title: 'Installations',
                count: _isLoadingMetrics ? '...' : '${_metrics?.installationsCount ?? 0}',
                icon: Icons.construction_rounded,
                color: const Color(0xFF0F766E),
                onTap: () => _openActionCenter('Installation Pending'),
              ),
              _buildQueueCard(
                title: 'RTS Work',
                count: _isLoadingMetrics ? '...' : '${_metrics?.rtsWorkCount ?? 0}',
                icon: Icons.bolt_rounded,
                color: const Color(0xFF7C3AED),
                onTap: () => _openActionCenter('RTS Pending'),
              ),
              _buildQueueCard(
                title: 'Agreements',
                count: _isLoadingMetrics ? '...' : '${_metrics?.agreementsCount ?? 0}',
                icon: Icons.draw_rounded,
                color: const Color(0xFF2563EB),
                onTap: () => _openActionCenter('Agreement Pending'),
              ),
              _buildQueueCard(
                title: 'Subsidy Processing',
                count: _isLoadingMetrics ? '...' : '${_metrics?.subsidyProcessingCount ?? 0}',
                icon: Icons.payments_rounded,
                color: const Color(0xFF059669),
                onTap: () => _openActionCenter('Subsidy Processing'),
              ),
            ],
          ),
          const SizedBox(height: 28),

          // INACTIVE QUEUES (HOLD & COMPLETED)
          Text(
            'INACTIVE QUEUES (HOLD & COMPLETED)',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color: const Color(0xFF1E293B),
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Customers excluded from active queues (Hold / Paused or Fully Completed)',
            style: TextStyle(color: theme.colorScheme.onSurfaceVariant, fontSize: 13),
          ),
          const SizedBox(height: 14),

          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              _buildQueueCard(
                title: 'Hold / No Action',
                count: _isLoadingMetrics ? '...' : '${_metrics?.noActionCount ?? 0}',
                icon: Icons.pause_circle_filled_rounded,
                color: const Color(0xFFD97706),
                onTap: () => _openActionCenter('Hold'),
              ),
              _buildQueueCard(
                title: 'Completed',
                count: _isLoadingMetrics ? '...' : '${_metrics?.completedCount ?? 0}',
                icon: Icons.verified_rounded,
                color: Colors.green.shade800,
                onTap: () => _openActionCenter('Completed'),
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

  void _openActionCenter(String stage) {
    setState(() {
      _selectedPriorityFilter = stage;
      _selectedIndex = 1; // Switch to Action Center tab
    });
  }


  Widget _buildQueueCard({
    required String title,
    required String count,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        width: 175,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withValues(alpha: 0.3)),
          boxShadow: [
            BoxShadow(
              color: color.withValues(alpha: 0.05),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                CircleAvatar(
                  radius: 14,
                  backgroundColor: color.withValues(alpha: 0.12),
                  child: Icon(icon, size: 16, color: color),
                ),
                Icon(Icons.arrow_forward_ios_rounded, size: 12, color: Colors.grey.shade400),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              count,
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: color),
            ),
            const SizedBox(height: 2),
            Text(
              title,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF475569)),
            ),
          ],
        ),
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
