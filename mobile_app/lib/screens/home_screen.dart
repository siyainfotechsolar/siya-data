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
    _initMetricsRealtime();
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
            if (_currentIndex == 1)
              IconButton(
                icon: const Icon(Icons.refresh),
                tooltip: 'Refresh',
                onPressed: () {
                  setState(() {});
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

  Widget _buildHomeTab() {
    final theme = Theme.of(context);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
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

          // Action Queues Summary Grid
          Row(
            children: [
              Expanded(
                child: _buildActionTile(
                  icon: Icons.draw_rounded,
                  label: 'My Agreement Work',
                  onTap: () => _openActionCenterStage('Agreement Pending'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _buildActionTile(
                  icon: Icons.account_balance_rounded,
                  label: 'My Loan Work',
                  onTap: () => _openActionCenterStage('Loan Pending'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _buildActionTile(
                  icon: Icons.construction_rounded,
                  label: 'My Installation Work',
                  onTap: () => _openActionCenterStage('Installation Pending'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _buildActionTile(
                  icon: Icons.electric_meter_rounded,
                  label: 'My RTS Work',
                  onTap: () => _openActionCenterStage('RTS Pending'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _buildActionTile(
                  icon: Icons.currency_rupee_rounded,
                  label: 'My Subsidy Work',
                  onTap: () => _openActionCenterStage('Subsidy Processing'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
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
