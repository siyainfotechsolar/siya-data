import 'dart:async';
import 'package:flutter/material.dart';
import '../services/supabase_service.dart';
import 'login_screen.dart';

import 'consumer_records_screen.dart';
import 'search_records_screen.dart';
import 'profile_screen.dart';
import 'priority_screen.dart';
import '../services/record_service.dart';
import '../services/realtime_service.dart';
import 'leads_screen.dart';
import 'settings_screen.dart';
import '../services/share_intent_service.dart';
import '../services/offline_task_sync_service.dart';
import 'create_task_screen.dart';
import 'tasks_list_screen.dart';
import 'sync_center_screen.dart';
import 'payment_dashboard_screen.dart';
import '../widgets/sync_status_indicator.dart';
import '../services/connectivity_service.dart';

class MobileHomeScreen extends StatefulWidget {
  const MobileHomeScreen({super.key});

  @override
  State<MobileHomeScreen> createState() => _MobileHomeScreenState();
}

class _MobileHomeScreenState extends State<MobileHomeScreen> {
  int _currentIndex = 0;
  Map<String, int>? _summaryCounts;
  bool _isLoadingSummary = false;
  StreamSubscription<MobileRecordChangeEvent>? _metricsSub;

  @override
  void initState() {
    super.initState();
    _loadSummary();
    _loadUserProfile();
    _initMetricsRealtime();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final pending = ShareIntentService.consumePendingDocument();
      if (pending != null && mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => CreateTaskScreen(document: pending),
          ),
        );
      }
    });
  }

  void _initMetricsRealtime() {
    MobileRealtimeService.initialize();
    _metricsSub = MobileRealtimeService.recordEvents.listen((_) {
      if (mounted) {
        _loadSummary();
      }
    });
  }

  @override
  void dispose() {
    _metricsSub?.cancel();
    super.dispose();
  }

  Future<void> _loadSummary() async {
    setState(() => _isLoadingSummary = true);
    final summary = await MobileRecordService.fetchDashboardSummary();
    if (mounted) {
      setState(() {
        _summaryCounts = summary;
        _isLoadingSummary = false;
      });
    }
  }

  Future<void> _handleSignOut() async {
    await SupabaseService.signOut();
    if (mounted) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const MobileLoginScreen()),
      );
    }
  }

  DateTime? _lastBackPressTime;

  Future<bool> _onWillPop() async {
    final now = DateTime.now();
    if (_lastBackPressTime == null || now.difference(_lastBackPressTime!) > const Duration(seconds: 2)) {
      _lastBackPressTime = now;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Press back again to exit app'),
          duration: Duration(seconds: 2),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return false;
    }
    return true;
  }

  void _showExitDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Exit App'),
        content: const Text('Are you sure you want to sign out and exit?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              _handleSignOut();
            },
            child: const Text('Log Out & Exit'),
          ),
        ],
      ),
    );
  }

  String _getAppBarTitle() {
    switch (_currentIndex) {
      case 0:
        return 'Siya Solar';
      case 1:
        return 'Action Center';
      case 2:
        return 'Consumer Records';
      case 3:
        return 'Search Consumers';
      case 4:
        return 'Staff Profile';
      default:
        return 'Siya Solar';
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        final shouldPop = await _onWillPop();
        if (shouldPop && context.mounted) {
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (_) => const MobileLoginScreen()),
          );
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(
            _getAppBarTitle(),
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            tooltip: 'Exit to Login',
            onPressed: _showExitDialog,
          ),
          actions: [
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: SyncStatusIndicator(compact: true),
            ),
            IconButton(
              icon: const Icon(Icons.sync_rounded),
              tooltip: 'Sync Center',
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const SyncCenterScreen()),
                );
              },
            ),
            if (_currentIndex == 1)
              IconButton(
                icon: const Icon(Icons.refresh),
                tooltip: 'Refresh',
                onPressed: () {
                  setState(() {});
                },
              ),
            IconButton(
              icon: const Icon(Icons.settings_outlined),
              tooltip: 'Settings & App Info',
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const MobileSettingsScreen()),
                );
              },
            ),
            IconButton(
              icon: const Icon(Icons.logout),
              tooltip: 'Logout / Exit',
              onPressed: _showExitDialog,
            ),
          ],
        ),
        body: _buildBody(),
        bottomNavigationBar: NavigationBar(
          selectedIndex: _currentIndex,
          onDestinationSelected: (idx) {
            setState(() => _currentIndex = idx);
            if (idx == 0) {
              _loadSummary();
            }
          },
          destinations: const [
            NavigationDestination(
              icon: Icon(Icons.home_outlined),
              selectedIcon: Icon(Icons.home),
              label: 'Home',
            ),
            NavigationDestination(
              icon: Icon(Icons.bolt_outlined),
              selectedIcon: Icon(Icons.bolt),
              label: 'Action Center',
            ),
            NavigationDestination(
              icon: Icon(Icons.assignment_outlined),
              selectedIcon: Icon(Icons.assignment),
              label: 'Records',
            ),
            NavigationDestination(
              icon: Icon(Icons.search),
              label: 'Search',
            ),
            NavigationDestination(
              icon: Icon(Icons.person_outline),
              selectedIcon: Icon(Icons.person),
              label: 'Profile',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBody() {
    switch (_currentIndex) {
      case 0:
        return _buildHomeTab();
      case 1:
        return const ActionCenterScreen();
      case 2:
        return const ConsumerRecordsScreen();
      case 3:
        return const SearchRecordsScreen();
      case 4:
        return const StaffProfileScreen();
      default:
        return _buildHomeTab();
    }
  }

  Map<String, dynamic>? _userProfile;

  Future<void> _loadUserProfile() async {
    final profile = await MobileRecordService.getCurrentStaffProfile();
    if (mounted) {
      setState(() => _userProfile = profile);
    }
  }

  bool _canAccessModule(String module) {
    if (_userProfile == null) return true; // Fallback while loading
    final role = (_userProfile?['role'] as String? ?? 'staff').toLowerCase();
    if (role == 'admin' || role == 'super_admin' || role == 'owner') return true;

    final permissions = _userProfile?['permissions'];
    if (permissions != null && permissions is Map) {
      final modActions = permissions[module.toLowerCase()];
      if (modActions is List && modActions.isNotEmpty) return true;
    }

    // Role-specific defaults
    switch (role) {
      case 'installation_staff':
        return module == 'installation' || module == 'customer';
      case 'loan_staff':
        return module == 'loan' || module == 'customer' || module == 'followup';
      case 'sales':
        return module == 'leads' || module == 'customer' || module == 'followup';
      case 'accounts':
        return module == 'payment' || module == 'subsidy' || module == 'customer';
      default:
        return true;
    }
  }

  Widget _buildHomeTab() {
    final theme = Theme.of(context);

    final showLeads = _canAccessModule('leads');
    final showAgreement = _canAccessModule('customer');
    final showLoan = _canAccessModule('loan');
    final showInstallation = _canAccessModule('installation');
    final showRts = _canAccessModule('rts');
    final showSubsidy = _canAccessModule('subsidy');

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Offline Status Banner
          ValueListenableBuilder<SyncMode>(
            valueListenable: ConnectivityService.modeNotifier,
            builder: (context, mode, _) {
              if (mode == SyncMode.online) return const SizedBox.shrink();
              final isOff = mode == SyncMode.offline;
              return Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                decoration: BoxDecoration(
                  color: isOff ? const Color(0xFFFEE2E2) : const Color(0xFFFEF3C7),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: isOff ? const Color(0xFFEF4444).withValues(alpha: 0.3) : const Color(0xFFF59E0B).withValues(alpha: 0.3),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      isOff ? Icons.cloud_off_rounded : Icons.warning_amber_rounded,
                      size: 16,
                      color: isOff ? const Color(0xFF991B1B) : const Color(0xFF92400E),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        isOff
                            ? 'LOCAL DATA (Offline) • All field actions will sync when internet returns.'
                            : 'Sync Issue Detected • Tap top sync button to view details.',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: isOff ? const Color(0xFF991B1B) : const Color(0xFF92400E),
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
          // Banner Card
          Card(
            color: theme.colorScheme.primaryContainer,
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                children: [
                  Icon(
                    Icons.bolt_rounded,
                    size: 38,
                    color: theme.colorScheme.onPrimaryContainer,
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'ACTION CENTER MOBILE PORTAL',
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: theme.colorScheme.onPrimaryContainer,
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'What work do I need to do today?',
                          style: TextStyle(
                            color: theme.colorScheme.onPrimaryContainer.withValues(alpha: 0.85),
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),

          // Quick Metrics Row
          if (_isLoadingSummary)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: LinearProgressIndicator(),
            )
          else if (_summaryCounts != null)
            Row(
              children: [
                Expanded(
                  child: _buildMetricCard(
                    title: 'Total Active',
                    value: '${_summaryCounts!['total'] ?? 0}',
                    color: theme.colorScheme.primary,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildMetricCard(
                    title: 'Pending Action',
                    value: '${_summaryCounts!['pending'] ?? 0}',
                    color: Colors.orange.shade800,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildMetricCard(
                    title: 'Action Center',
                    value: '${_summaryCounts!['action_center'] ?? 0}',
                    color: Colors.blue.shade800,
                  ),
                ),
              ],
            ),
          const SizedBox(height: 14),

          // LEADS & PROSPECTS PORTAL
          if (showLeads) ...[
            InkWell(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const MobileLeadsScreen()),
                );
              },
              borderRadius: BorderRadius.circular(12),
              child: Card(
                elevation: 0,
                color: const Color(0xFFEFF6FF), // Soft sky blue
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: const BorderSide(color: Color(0xFFBFDBFE)),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(14.0),
                  child: Row(
                    children: [
                      const CircleAvatar(
                        radius: 20,
                        backgroundColor: Color(0xFF2563EB),
                        child: Icon(Icons.leaderboard_rounded, color: Colors.white, size: 20),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'LEADS & PROSPECTS',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                                color: Color(0xFF1E3A8A),
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Pre-application customer inquiries, follow-ups & conversion',
                              style: TextStyle(fontSize: 11, color: Colors.blue.shade900.withValues(alpha: 0.8)),
                            ),
                          ],
                        ),
                      ),
                      const Icon(Icons.chevron_right, color: Color(0xFF2563EB)),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
          ],

          // WHATSAPP DOCUMENT TASKS PORTAL
          InkWell(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const TasksListScreen(initialSourceFilter: 'WhatsApp Share'),
                ),
              );
            },
            borderRadius: BorderRadius.circular(12),
            child: Card(
              elevation: 0,
              color: const Color(0xFFECFDF5), // Soft emerald green
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: const BorderSide(color: Color(0xFFA7F3D0)),
              ),
              child: Padding(
                padding: const EdgeInsets.all(14.0),
                child: Row(
                  children: [
                    const CircleAvatar(
                      radius: 20,
                      backgroundColor: Color(0xFF25D366), // WhatsApp brand color
                      child: Icon(Icons.share_rounded, color: Colors.white, size: 20),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Text(
                                'WHATSAPP DOCUMENT TASKS',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                  color: Color(0xFF065F46),
                                ),
                              ),
                              const SizedBox(width: 6),
                              if (OfflineTaskSyncService.hasPendingTasks)
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                                  decoration: BoxDecoration(
                                    color: Colors.amber.shade700,
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Text(
                                    '${OfflineTaskSyncService.pendingCount} Pending',
                                    style: const TextStyle(fontSize: 9, color: Colors.white, fontWeight: FontWeight.bold),
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Incoming WhatsApp bills, receipts & task workflow reviews',
                            style: TextStyle(fontSize: 11, color: Colors.green.shade900.withValues(alpha: 0.8)),
                          ),
                        ],
                      ),
                    ),
                    const Icon(Icons.chevron_right, color: Color(0xFF059669)),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),

          // INTELLIGENT PAYMENT HUB
          InkWell(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const PaymentDashboardScreen()),
              );
            },
            borderRadius: BorderRadius.circular(12),
            child: Card(
              elevation: 0,
              color: const Color(0xFFF0FDF4), // Soft mint green
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: const BorderSide(color: Color(0xFFBBF7D0)),
              ),
              child: const Padding(
                padding: EdgeInsets.all(14.0),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 20,
                      backgroundColor: Color(0xFF059669),
                      child: Icon(Icons.currency_rupee_rounded, color: Colors.white, size: 20),
                    ),
                    SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'PAYMENT & FINANCIAL HUB',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                              color: Color(0xFF065F46),
                            ),
                          ),
                          SizedBox(height: 2),
                          Text(
                            'Collections, installation milestones, receipts, and offline sync',
                            style: TextStyle(fontSize: 11, color: Color(0xFF047857)),
                          ),
                        ],
                      ),
                    ),
                    Icon(Icons.chevron_right, color: Color(0xFF059669)),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),

          // TODAY'S WORK Summary Section Header
          Text(
            'TODAY\'S WORK',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Actionable work required today across operational stages',
            style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
          ),
          const SizedBox(height: 12),

          // Action Queues Summary Grid (Dynamically filtered by staff permissions)
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              if (showAgreement)
                SizedBox(
                  width: (MediaQuery.of(context).size.width - 42) / 2,
                  child: _buildActionTile(
                    icon: Icons.draw_rounded,
                    label: 'My Agreement Work',
                    onTap: () => _openActionCenterStage('Agreement Pending'),
                  ),
                ),
              if (showLoan)
                SizedBox(
                  width: (MediaQuery.of(context).size.width - 42) / 2,
                  child: _buildActionTile(
                    icon: Icons.account_balance_rounded,
                    label: 'My Loan Work',
                    onTap: () => _openActionCenterStage('Loan Pending'),
                  ),
                ),
              if (showInstallation)
                SizedBox(
                  width: (MediaQuery.of(context).size.width - 42) / 2,
                  child: _buildActionTile(
                    icon: Icons.construction_rounded,
                    label: 'My Installation Work',
                    onTap: () => _openActionCenterStage('Installation Pending'),
                  ),
                ),
              if (showRts)
                SizedBox(
                  width: (MediaQuery.of(context).size.width - 42) / 2,
                  child: _buildActionTile(
                    icon: Icons.electric_meter_rounded,
                    label: 'My RTS Work',
                    onTap: () => _openActionCenterStage('RTS Pending'),
                  ),
                ),
              if (showSubsidy)
                SizedBox(
                  width: (MediaQuery.of(context).size.width - 42) / 2,
                  child: _buildActionTile(
                    icon: Icons.currency_rupee_rounded,
                    label: 'My Subsidy Work',
                    onTap: () => _openActionCenterStage('Subsidy Processing'),
                  ),
                ),
              SizedBox(
                width: (MediaQuery.of(context).size.width - 42) / 2,
                child: _buildActionTile(
                  icon: Icons.search,
                  label: 'Search Consumers',
                  onTap: () => setState(() => _currentIndex = 3),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _openActionCenterStage(String stage) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ActionCenterScreen(initialStageFilter: stage),
      ),
    );
  }

  Widget _buildMetricCard({required String title, required String value, required Color color}) {
    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12.0, horizontal: 8.0),
        child: Column(
          children: [
            Text(
              value,
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: color),
            ),
            const SizedBox(height: 2),
            Text(
              title,
              style: const TextStyle(fontSize: 11, color: Colors.grey),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionTile({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return Card(
      elevation: 2,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 18.0, horizontal: 12.0),
          child: Column(
            children: [
              Icon(icon, size: 28, color: Theme.of(context).colorScheme.primary),
              const SizedBox(height: 8),
              Text(
                label,
                textAlign: TextAlign.center,
                style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
