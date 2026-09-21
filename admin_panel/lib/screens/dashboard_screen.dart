import 'dart:async';
import 'package:flutter/material.dart';
import '../services/supabase_service.dart';
import '../services/record_service.dart';
import '../services/realtime_service.dart';
import '../utils/responsive.dart';
import '../widgets/import_dialog.dart';
import 'login_screen.dart';
import 'records_screen.dart';
import 'history_screen.dart';
import 'recycle_bin_screen.dart';
import 'users_screen.dart';
import 'duplicate_finder_screen.dart';
import 'reports_screen.dart';
import 'leads_screen.dart';
import 'settings_screen.dart';
import 'whatsapp_tasks_screen.dart';
import 'payments_screen.dart';
import 'office_tasks_screen.dart';
import 'action_center_screen.dart';

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
  String? _selectedStageFilter;
  String? _selectedQueueFilter;
  String? _selectedPaymentFilter;
  String _selectedSiteType = 'Subsidy';

  final List<_NavItem> _navItems = [
    _NavItem('Dashboard', Icons.home_outlined, Icons.home, true), // 0
    _NavItem('Customers', Icons.people_alt_outlined, Icons.people_alt, true), // 1 (Records)
    _NavItem('Action Center', Icons.bolt_outlined, Icons.bolt, true), // 2
    _NavItem('Payments', Icons.payments_outlined, Icons.payments, true), // 3
    _NavItem('Office Tasks', Icons.assignment_ind_outlined, Icons.assignment_ind, false), // 4
    _NavItem('WhatsApp', Icons.share_rounded, Icons.share, false), // 5
    _NavItem('Leads', Icons.leaderboard_outlined, Icons.leaderboard, false), // 6
    _NavItem('Import', Icons.upload_file_outlined, Icons.upload_file, false), // 7
    _NavItem('Reports', Icons.bar_chart_outlined, Icons.bar_chart, false), // 8
    _NavItem('History', Icons.history_outlined, Icons.history, false), // 9
    _NavItem('Duplicates', Icons.find_in_page_outlined, Icons.find_in_page, false), // 10
    _NavItem('Recycle Bin', Icons.delete_sweep_outlined, Icons.delete_sweep, false), // 11
    _NavItem('Users', Icons.group_outlined, Icons.group, false), // 12
    _NavItem('Settings', Icons.settings_outlined, Icons.settings, false), // 13
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
      if (mounted) _loadMetrics();
    });
  }

  @override
  void dispose() {
    _metricsRealtimeSub?.cancel();
    super.dispose();
  }

  Future<void> _loadMetrics() async {
    setState(() => _isLoadingMetrics = true);
    final m = await RecordService.fetchDashboardMetrics(siteType: _selectedSiteType);
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

  void _openActionCenter(String stage) {
    setState(() {
      _selectedStageFilter = stage;
      _selectedIndex = 2; // Action Center
    });
  }

  void _openImportDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => ImportDialog(onImportSuccess: _loadMetrics),
    );
  }

  void _showMoreMenu() {
    final theme = Theme.of(context);
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: theme.colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade400,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 12),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                  child: Row(
                    children: [
                      Text(
                        'All Admin Modules',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),
                const Divider(),
                Flexible(
                  child: SingleChildScrollView(
                    child: Column(
                      children: _navItems.asMap().entries.map((entry) {
                        final idx = entry.key;
                        final item = entry.value;
                        final isSelected = _selectedIndex == idx;

                        return ListTile(
                          leading: Icon(
                            isSelected ? item.selectedIcon : item.icon,
                            color: isSelected ? theme.colorScheme.primary : null,
                          ),
                          title: Text(
                            item.label,
                            style: TextStyle(
                              fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                              color: isSelected ? theme.colorScheme.primary : null,
                            ),
                          ),
                          onTap: () {
                            Navigator.of(ctx).pop();
                            setState(() {
                              _selectedIndex = idx;
                            });
                            if (idx == 0) _loadMetrics();
                          },
                        );
                      }).toList(),
                    ),
                  ),
                ),
                const Divider(),
                ListTile(
                  leading: const Icon(Icons.logout, color: Colors.red),
                  title: const Text('Sign Out', style: TextStyle(color: Colors.red, fontWeight: FontWeight.w600)),
                  onTap: () {
                    Navigator.of(ctx).pop();
                    _handleSignOut();
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDesktop = Responsive.isDesktop(context);
    final isExtended = MediaQuery.of(context).size.width >= 1100;

    if (isDesktop) {
      return Scaffold(
        backgroundColor: theme.colorScheme.surface,
        appBar: AppBar(
          elevation: 0,
          scrolledUnderElevation: 1,
          title: Row(
            children: [
              Container(
                width: 26,
                height: 26,
                decoration: BoxDecoration(
                  color: theme.colorScheme.primaryContainer,
                  shape: BoxShape.circle,
                ),
                child: ClipOval(
                  child: Image.asset(
                    'assets/images/logo.png',
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Icon(
                      Icons.solar_power_rounded,
                      color: theme.colorScheme.primary,
                      size: 16,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              const Text('Siya Data', style: TextStyle(fontWeight: FontWeight.w700, letterSpacing: -0.3)),
            ],
          ),
          actions: [
            if (_isLoadingMetrics)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
                child: SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2, color: theme.colorScheme.primary),
                ),
              ),
            IconButton(icon: const Icon(Icons.refresh_rounded), tooltip: 'Refresh', onPressed: _loadMetrics),
            PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert),
              tooltip: 'More options',
              onSelected: (v) { if (v == 'signout') _handleSignOut(); },
              itemBuilder: (_) => [
                const PopupMenuItem(
                  value: 'signout',
                  child: ListTile(
                    leading: Icon(Icons.logout, color: Colors.red),
                    title: Text('Sign Out', style: TextStyle(color: Colors.red)),
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
              ],
            ),
            const SizedBox(width: 4),
          ],
        ),
        body: Row(
          children: [
            SizedBox(
              width: isExtended ? 200 : 72,
              child: SingleChildScrollView(
                child: IntrinsicHeight(
                  child: NavigationRail(
                    extended: isExtended,
                    selectedIndex: _selectedIndex,
                    useIndicator: true,
                    onDestinationSelected: (i) {
                      setState(() => _selectedIndex = i);
                      if (i == 0) _loadMetrics();
                    },
                    destinations: _navItems
                        .map((d) => NavigationRailDestination(
                              icon: Icon(d.icon),
                              selectedIcon: Icon(d.selectedIcon),
                              label: Text(d.label),
                            ))
                        .toList(),
                  ),
                ),
              ),
            ),
            const VerticalDivider(thickness: 1, width: 1),
            Expanded(child: _buildBodyContent()),
          ],
        ),
      );
    }

    // ── Mobile Scaffold ────────────────────────────────────────────────────────
    final int currentBottomNavIndex = _selectedIndex < 4 ? _selectedIndex : 4;

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      appBar: AppBar(
        elevation: 0,
        scrolledUnderElevation: 1,
        leading: IconButton(
          icon: const Icon(Icons.menu_rounded),
          tooltip: 'Menu',
          onPressed: _showMoreMenu,
        ),
        title: Row(
          children: [
            Container(
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                color: theme.colorScheme.primaryContainer,
                shape: BoxShape.circle,
              ),
              child: ClipOval(
                child: Image.asset(
                  'assets/images/logo.png',
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Icon(
                    Icons.solar_power_rounded,
                    color: theme.colorScheme.primary,
                    size: 14,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              _navItems[_selectedIndex].label,
              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
        actions: [
          if (_isLoadingMetrics)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2, color: theme.colorScheme.primary),
              ),
            ),
          IconButton(
            icon: const Icon(Icons.refresh_rounded, size: 20),
            tooltip: 'Refresh',
            onPressed: _loadMetrics,
          ),
        ],
      ),
      body: SafeArea(
        child: _buildBodyContent(),
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: currentBottomNavIndex,
        type: BottomNavigationBarType.fixed,
        selectedItemColor: theme.colorScheme.primary,
        unselectedItemColor: theme.colorScheme.onSurfaceVariant,
        selectedFontSize: 11,
        unselectedFontSize: 11,
        onTap: (index) {
          if (index == 4) {
            _showMoreMenu();
          } else {
            setState(() {
              _selectedIndex = index;
            });
            if (index == 0) _loadMetrics();
          }
        },
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.home_outlined),
            activeIcon: Icon(Icons.home),
            label: 'Home',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.people_alt_outlined),
            activeIcon: Icon(Icons.people_alt),
            label: 'Customers',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.bolt_outlined),
            activeIcon: Icon(Icons.bolt),
            label: 'Actions',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.payments_outlined),
            activeIcon: Icon(Icons.payments),
            label: 'Payments',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.grid_view_outlined),
            activeIcon: Icon(Icons.grid_view),
            label: 'More',
          ),
        ],
      ),
    );
  }

  Widget _buildBodyContent() {
    switch (_selectedIndex) {
      case 0: return _buildDashboardView();
      case 1: return RecordsScreen(
        key: ValueKey('$_selectedQueueFilter-$_selectedSiteType'),
        initialWorkflowQueue: _selectedQueueFilter,
        initialSiteType: _selectedSiteType,
      );
      case 2: return ActionCenterScreen(key: ValueKey(_selectedStageFilter), initialStageFilter: _selectedStageFilter);
      case 3: return PaymentsScreen(
        key: ValueKey(_selectedPaymentFilter),
        initialStatusFilter: _selectedPaymentFilter,
      );
      case 4: return const OfficeTasksScreen();
      case 5: return const WhatsAppTasksScreen();
      case 6: return const LeadsScreen();
      case 7: return _buildImportView();
      case 8: return const ReportsScreen();
      case 9: return const HistoryScreen();
      case 10: return const DuplicateFinderScreen();
      case 11: return const RecycleBinScreen();
      case 12: return const UsersScreen();
      case 13: return const SettingsScreen();
      default: return _buildDashboardView();
    }
  }

  // ── Dashboard view ───────────────────────────────────────────────────────────

  Widget _buildDashboardView() {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final isMobile = Responsive.isMobile(context);

    return SingleChildScrollView(
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Top metrics header bar ───────────────────────────────────────────
          Container(
            padding: EdgeInsets.fromLTRB(isMobile ? 16 : 28, 20, isMobile ? 16 : 28, 20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [cs.primary, cs.primary.withValues(alpha: 0.82)],
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '$_selectedSiteType Dashboard',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 20,
                              fontWeight: FontWeight.w800,
                              letterSpacing: -0.4,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Live $_selectedSiteType business data & operations',
                            style: TextStyle(color: Colors.white.withValues(alpha: 0.85), fontSize: 12),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.18),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: Colors.white.withValues(alpha: 0.3)),
                      ),
                      child: Text(
                        '${_selectedSiteType.toUpperCase()} ONLY',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),

                // ── Segmented Toggle: [ Non-Subsidy ] [ Subsidy ] ─────────
                Container(
                  constraints: const BoxConstraints(maxWidth: 360),
                  padding: const EdgeInsets.all(3),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: InkWell(
                          onTap: () {
                            if (_selectedSiteType != 'Non-Subsidy') {
                              setState(() => _selectedSiteType = 'Non-Subsidy');
                              _loadMetrics();
                            }
                          },
                          borderRadius: BorderRadius.circular(9),
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 7),
                            decoration: BoxDecoration(
                              color: _selectedSiteType == 'Non-Subsidy' ? Colors.white : Colors.transparent,
                              borderRadius: BorderRadius.circular(9),
                              boxShadow: _selectedSiteType == 'Non-Subsidy'
                                  ? [BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 4)]
                                  : null,
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.solar_power_rounded,
                                  size: 15,
                                  color: _selectedSiteType == 'Non-Subsidy' ? cs.primary : Colors.white,
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  'Non-Subsidy',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                    color: _selectedSiteType == 'Non-Subsidy' ? cs.primary : Colors.white,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: InkWell(
                          onTap: () {
                            if (_selectedSiteType != 'Subsidy') {
                              setState(() => _selectedSiteType = 'Subsidy');
                              _loadMetrics();
                            }
                          },
                          borderRadius: BorderRadius.circular(9),
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 7),
                            decoration: BoxDecoration(
                              color: _selectedSiteType == 'Subsidy' ? Colors.white : Colors.transparent,
                              borderRadius: BorderRadius.circular(9),
                              boxShadow: _selectedSiteType == 'Subsidy'
                                  ? [BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 4)]
                                  : null,
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.account_balance_rounded,
                                  size: 15,
                                  color: _selectedSiteType == 'Subsidy' ? cs.primary : Colors.white,
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  'Subsidy',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                    color: _selectedSiteType == 'Subsidy' ? cs.primary : Colors.white,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                // Stat chips
                if (isMobile)
                  Column(
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: _buildHeroStat(
                              'Total Customers',
                              '${_metrics?.totalRecords ?? 0}',
                              onTap: () {
                                setState(() {
                                  _selectedQueueFilter = 'All';
                                  _selectedIndex = 1;
                                });
                              },
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: _buildHeroStat(
                              'Completed Sites',
                              '${_metrics?.completedCount ?? 0}',
                              onTap: () {
                                setState(() {
                                  _selectedQueueFilter = 'Completed';
                                  _selectedIndex = 1;
                                });
                              },
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: _buildHeroStat(
                              'Pending Tasks',
                              '${_metrics?.pendingTasksCount ?? 0}',
                              onTap: () => setState(() => _selectedIndex = 4),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: _buildHeroStat(
                              'Completed Tasks',
                              '${_metrics?.completedTasksCount ?? 0}',
                              onTap: () => setState(() => _selectedIndex = 4),
                            ),
                          ),
                        ],
                      ),
                    ],
                  )
                else
                  Row(
                    children: [
                      Expanded(
                        child: _buildHeroStat(
                          'Total $_selectedSiteType Customers',
                          '${_metrics?.totalRecords ?? 0}',
                          onTap: () {
                            setState(() {
                              _selectedQueueFilter = 'All';
                              _selectedIndex = 1;
                            });
                          },
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _buildHeroStat(
                          'Completed Sites',
                          '${_metrics?.completedCount ?? 0}',
                          onTap: () {
                            setState(() {
                              _selectedQueueFilter = 'Completed';
                              _selectedIndex = 1;
                            });
                          },
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _buildHeroStat(
                          'Pending Tasks',
                          '${_metrics?.pendingTasksCount ?? 0}',
                          onTap: () => setState(() => _selectedIndex = 4),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _buildHeroStat(
                          'Completed Tasks',
                          '${_metrics?.completedTasksCount ?? 0}',
                          onTap: () => setState(() => _selectedIndex = 4),
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          ),

          // ── Body content ──────────────────────────────────────────────
          Padding(
            padding: EdgeInsets.all(isMobile ? 16 : 28),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Interactive Quick Action Cards ───────────────────────────────
                _sectionHeader('ACTION SUMMARY', 'Instant overview of pending tasks and payments'),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: _buildQuickActionCard(
                        title: 'Pending Tasks',
                        count: _metrics?.pendingTasksCount ?? 0,
                        icon: Icons.task_alt_rounded,
                        color: const Color(0xFF2563EB),
                        onTap: () => setState(() => _selectedIndex = 4), // Office Tasks
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _buildQuickActionCard(
                        title: 'Follow-ups',
                        count: _metrics?.noActionCount ?? 0,
                        icon: Icons.schedule_rounded,
                        color: const Color(0xFFD97706),
                        onTap: () => _openActionCenter('Hold / No Action'), // Action Center
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _buildQuickActionCard(
                        title: 'Pending Pay',
                        count: _metrics?.pendingPaymentsCount ?? 0,
                        icon: Icons.account_balance_wallet_outlined,
                        color: const Color(0xFFDC2626),
                        onTap: () => setState(() {
                          _selectedPaymentFilter = 'Pending';
                          _selectedIndex = 3; // Payments
                        }),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 28),

                // ── Payments Card ───────────────────────────────────────────
                _sectionHeader('${_selectedSiteType.toUpperCase()} PAYMENTS', 'Contract payments, received revenue and pending dues'),
                const SizedBox(height: 12),
                _buildPaymentSection(theme),
                const SizedBox(height: 28),

                // Action queues grid
                _sectionHeader('${_selectedSiteType.toUpperCase()} WORKFLOW QUEUES', 'Customers requiring stage-wise operations'),
                const SizedBox(height: 12),
                if (isMobile)
                  GridView.count(
                    crossAxisCount: 2,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    mainAxisSpacing: 10,
                    crossAxisSpacing: 10,
                    childAspectRatio: 1.45,
                    children: _actionQueueCards(),
                  )
                else
                  Row(
                    children: _actionQueueCards()
                        .map((w) => Expanded(child: Padding(padding: const EdgeInsets.only(right: 12), child: w)))
                        .toList(),
                  ),
                const SizedBox(height: 28),

                // Status
                _sectionHeader('STATUS', 'Hold and completed pipeline'),
                const SizedBox(height: 12),
                Row(
                  children: [
                    _buildStatusCard(
                      'Hold / No Action',
                      _metrics?.noActionCount,
                      Icons.pause_circle_outline_rounded,
                      const Color(0xFFD97706),
                      onTap: () => _openActionCenter('Hold / No Action'),
                    ),
                    const SizedBox(width: 12),
                    _buildStatusCard(
                      'Completed Sites',
                      _metrics?.completedCount,
                      Icons.verified_rounded,
                      const Color(0xFF059669),
                      onTap: () {
                        setState(() {
                          _selectedQueueFilter = 'Completed';
                          _selectedIndex = 1;
                        });
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 28),

                // Recent records table / card list
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _sectionHeader('RECENT ${_selectedSiteType.toUpperCase()} RECORDS', 'Last updated ${_selectedSiteType.toLowerCase()} records'),
                    TextButton.icon(
                      onPressed: () {
                        setState(() {
                          _selectedQueueFilter = 'All';
                          _selectedIndex = 1; // Records
                        });
                      },
                      icon: const Icon(Icons.arrow_forward, size: 14),
                      label: const Text('View All'),
                      style: TextButton.styleFrom(visualDensity: VisualDensity.compact),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                _buildRecentRecordsView(theme),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActionCard({
    required String title,
    required int count,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: 0.25)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 18, color: color),
                const Spacer(),
                Icon(Icons.chevron_right_rounded, size: 16, color: color),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              '$count',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: color),
            ),
            const SizedBox(height: 2),
            Text(
              title,
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: theme.colorScheme.onSurface),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeroStat(String label, String value, {VoidCallback? onTap}) {
    final card = Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label.toUpperCase(),
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.85),
              fontSize: 9,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.4,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 2),
          Text(
            _isLoadingMetrics ? '…' : value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 17,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );

    if (onTap != null) {
      return Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(10),
          child: card,
        ),
      );
    }
    return card;
  }

  Widget _sectionHeader(String title, String subtitle) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w800,
            letterSpacing: 1.1,
            color: theme.colorScheme.primary,
          ),
        ),
        const SizedBox(height: 2),
        Text(subtitle, style: TextStyle(fontSize: 12, color: theme.colorScheme.onSurfaceVariant)),
      ],
    );
  }

  List<Widget> _actionQueueCards() {
    final list = [
      _buildQueueCard('Agreement Pending', _metrics?.agreementPendingCount,   Icons.history_edu_rounded,      const Color(0xFF2563EB)),
      _buildQueueCard('Loan Pending',      _metrics?.loanPendingCount,        Icons.account_balance_rounded,  const Color(0xFFD97706)),
      _buildQueueCard('Installation',      _metrics?.installationPendingCount, Icons.build_circle_outlined,   const Color(0xFF0F766E)),
      _buildQueueCard('RTS Pending',       _metrics?.rtsPendingCount,         Icons.electric_meter_rounded,   const Color(0xFF7C3AED)),
    ];
    if (_selectedSiteType == 'Subsidy') {
      list.add(
        _buildQueueCard('Subsidy Pending', _metrics?.subsidyPendingCount,     Icons.price_check_rounded,      const Color(0xFF059669)),
      );
    }
    return list;
  }

  Widget _buildQueueCard(String title, int? count, IconData icon, Color color) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: () => _openActionCenter(title),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          color: theme.colorScheme.surface,
          border: Border.all(color: color.withValues(alpha: 0.2)),
          boxShadow: [
            BoxShadow(color: color.withValues(alpha: 0.05), blurRadius: 6, offset: const Offset(0, 2)),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  width: 30,
                  height: 30,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(icon, size: 16, color: color),
                ),
                Text(
                  _isLoadingMetrics ? '…' : '${count ?? 0}',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: color),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              title,
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: theme.colorScheme.onSurface),
              overflow: TextOverflow.ellipsis,
              maxLines: 1,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusCard(String title, int? count, IconData icon, Color color, {VoidCallback? onTap}) {
    final theme = Theme.of(context);
    return Expanded(
      child: InkWell(
        onTap: onTap ?? () => _openActionCenter(title),
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            color: color.withValues(alpha: 0.06),
            border: Border.all(color: color.withValues(alpha: 0.2)),
          ),
          child: Row(
            children: [
              Icon(icon, color: color, size: 24),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _isLoadingMetrics ? '…' : '${count ?? 0}',
                      style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: color),
                    ),
                    Text(
                      title,
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: theme.colorScheme.onSurface),
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatCurrency(num amount) {
    if (amount >= 10000000) {
      return '₹${(amount / 10000000).toStringAsFixed(2)} Cr';
    } else if (amount >= 100000) {
      return '₹${(amount / 100000).toStringAsFixed(2)} L';
    } else if (amount >= 1000) {
      return '₹${(amount / 1000).toStringAsFixed(1)} k';
    }
    return '₹${amount.toStringAsFixed(0)}';
  }

  Widget _buildPaymentSection(ThemeData theme) {
    final cs = theme.colorScheme;
    final isMobile = Responsive.isMobile(context);
    final total = _metrics?.totalPaymentAmount ?? 0.0;
    final paid = _metrics?.paidPaymentAmount ?? 0.0;
    final pending = _metrics?.pendingPaymentAmount ?? 0.0;
    final pendingCount = _metrics?.pendingPaymentsCount ?? 0;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: cs.surface,
        border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.5)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFF059669).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.account_balance_wallet_rounded, size: 20, color: Color(0xFF059669)),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '$_selectedSiteType Payment Summary',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: cs.onSurface,
                      ),
                    ),
                    Text(
                      'Total contract billing and received revenue',
                      style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant),
                    ),
                  ],
                ),
              ),
              InkWell(
                onTap: () {
                  setState(() {
                    _selectedPaymentFilter = 'Pending';
                    _selectedIndex = 3; // Open Payments
                  });
                },
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: const Color(0xFFDC2626).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFFDC2626).withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '$pendingCount Pending',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFFDC2626),
                        ),
                      ),
                      const SizedBox(width: 4),
                      const Icon(Icons.arrow_forward_ios_rounded, size: 10, color: Color(0xFFDC2626)),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (isMobile)
            Column(
              children: [
                _buildPaymentMetricCard('Total Payment', _formatCurrency(total), Icons.receipt_long_rounded, const Color(0xFF2563EB), onTap: () {
                  setState(() {
                    _selectedPaymentFilter = 'All';
                    _selectedIndex = 3;
                  });
                }),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: _buildPaymentMetricCard('Paid', _formatCurrency(paid), Icons.check_circle_rounded, const Color(0xFF059669), onTap: () {
                        setState(() {
                          _selectedPaymentFilter = 'Paid';
                          _selectedIndex = 3;
                        });
                      }),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _buildPaymentMetricCard('Pending', _formatCurrency(pending), Icons.pending_actions_rounded, const Color(0xFFDC2626), onTap: () {
                        setState(() {
                          _selectedPaymentFilter = 'Pending';
                          _selectedIndex = 3;
                        });
                      }),
                    ),
                  ],
                ),
              ],
            )
          else
            Row(
              children: [
                Expanded(
                  child: _buildPaymentMetricCard('Total Payment', _formatCurrency(total), Icons.receipt_long_rounded, const Color(0xFF2563EB), onTap: () {
                    setState(() {
                      _selectedPaymentFilter = 'All';
                      _selectedIndex = 3;
                    });
                  }),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildPaymentMetricCard('Paid', _formatCurrency(paid), Icons.check_circle_rounded, const Color(0xFF059669), onTap: () {
                    setState(() {
                      _selectedPaymentFilter = 'Paid';
                      _selectedIndex = 3;
                    });
                  }),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildPaymentMetricCard('Pending', _formatCurrency(pending), Icons.pending_actions_rounded, const Color(0xFFDC2626), onTap: () {
                    setState(() {
                      _selectedPaymentFilter = 'Pending';
                      _selectedIndex = 3;
                    });
                  }),
                ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildPaymentMetricCard(String label, String value, IconData icon, Color color, {VoidCallback? onTap}) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: 0.18)),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, size: 18, color: color),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label.toUpperCase(),
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.4,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    _isLoadingMetrics ? '…' : value,
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                      color: color,
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded, size: 16, color: color.withValues(alpha: 0.6)),
          ],
        ),
      ),
    );
  }

  Widget _buildRecentRecordsView(ThemeData theme) {
    final cs = theme.colorScheme;
    final isMobile = Responsive.isMobile(context);

    if (_isLoadingMetrics) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 32),
        child: Center(child: CircularProgressIndicator()),
      );
    }
    if (_metrics == null || _metrics!.recentRecords.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 24),
        child: Text('No records yet.', style: TextStyle(color: cs.onSurfaceVariant)),
      );
    }

    if (isMobile) {
      return Column(
        children: _metrics!.recentRecords.map((r) {
          return Card(
            margin: const EdgeInsets.only(bottom: 8),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
              side: BorderSide(color: cs.outlineVariant.withValues(alpha: 0.5)),
            ),
            child: ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
              title: Text(r.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
              subtitle: Text('No: ${r.consumerNo}', style: TextStyle(color: cs.onSurfaceVariant, fontSize: 12)),
              trailing: Chip(
                label: Text(r.status, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600)),
                padding: EdgeInsets.zero,
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
            ),
          );
        }).toList(),
      );
    }

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.6)),
      ),
      clipBehavior: Clip.antiAlias,
      child: Table(
        columnWidths: const {
          0: FlexColumnWidth(1.2),
          1: FlexColumnWidth(2.2),
          2: FlexColumnWidth(1.6),
          3: FlexColumnWidth(1.2),
        },
        children: [
          TableRow(
            decoration: BoxDecoration(color: cs.surfaceContainerHighest),
            children: const [
              _TH('Consumer No'),
              _TH('Name'),
              _TH('Status'),
              _TH('Updated'),
            ],
          ),
          ..._metrics!.recentRecords.asMap().entries.map((entry) {
            final isEven = entry.key.isEven;
            final r = entry.value;
            return TableRow(
              decoration: BoxDecoration(
                color: isEven ? cs.surface : cs.surfaceContainerLowest,
              ),
              children: [
                _TD(r.consumerNo, bold: true),
                _TD(r.name),
                _TD(r.status),
                _TD(r.updatedAt != null ? r.updatedAt!.toLocal().toString().split(' ')[0] : '—'),
              ],
            );
          }),
        ],
      ),
    );
  }

  Widget _buildImportView() {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    return Center(
      child: Container(
        constraints: const BoxConstraints(maxWidth: 480),
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: cs.primaryContainer,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(Icons.cloud_upload_outlined, size: 32, color: cs.primary),
            ),
            const SizedBox(height: 16),
            Text('Import Center', style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800, letterSpacing: -0.4)),
            const SizedBox(height: 8),
            Text(
              'Import consumer records from .xlsx, .xls, or .csv files with automatic header mapping.',
              textAlign: TextAlign.center,
              style: TextStyle(color: cs.onSurfaceVariant, fontSize: 13, height: 1.4),
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: _openImportDialog,
              icon: const Icon(Icons.upload_file_rounded),
              label: const Text('Launch Import Wizard', style: TextStyle(fontWeight: FontWeight.w600)),
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TH extends StatelessWidget {
  final String text;
  const _TH(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.5,
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }
}

class _TD extends StatelessWidget {
  final String text;
  final bool bold;
  const _TD(this.text, {this.bold = false});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
      child: Text(
        text,
        style: TextStyle(fontSize: 13, fontWeight: bold ? FontWeight.w600 : FontWeight.normal),
      ),
    );
  }
}

class _NavItem {
  final String label;
  final IconData icon;
  final IconData selectedIcon;
  final bool isMainBottomNav;
  _NavItem(this.label, this.icon, this.selectedIcon, this.isMainBottomNav);
}
