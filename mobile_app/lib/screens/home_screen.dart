import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/supabase_service.dart';
import '../utils/back_navigation_helper.dart';
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
import 'my_tasks_screen.dart';
import '../widgets/sync_status_indicator.dart';
import '../services/connectivity_service.dart';
import '../services/app_intelligence_service.dart';
import 'action_center_screen.dart';

class MobileHomeScreen extends StatefulWidget {
  const MobileHomeScreen({super.key});

  @override
  State<MobileHomeScreen> createState() => _MobileHomeScreenState();
}

class _MobileHomeScreenState extends State<MobileHomeScreen> {
  int _currentIndex = 0;
  Map<String, int>? _summaryCounts;
  OperationalInsights? _operationalInsights;
  bool _isLoadingSummary = false;
  StreamSubscription<MobileRecordChangeEvent>? _metricsSub;
  Map<String, dynamic>? _userProfile;

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
          MaterialPageRoute(builder: (_) => CreateTaskScreen(document: pending)),
        );
      }
    });
  }

  void _initMetricsRealtime() {
    MobileRealtimeService.initialize();
    _metricsSub = MobileRealtimeService.recordEvents.listen((_) {
      if (mounted) _loadSummary();
    });
  }

  @override
  void dispose() {
    _metricsSub?.cancel();
    super.dispose();
  }

  Future<void> _loadSummary() async {
    setState(() => _isLoadingSummary = true);
    final summaryFuture = MobileRecordService.fetchDashboardSummary();
    final insightsFuture = AppIntelligenceService.computeInsights();
    final results = await Future.wait([summaryFuture, insightsFuture]);
    if (mounted) {
      setState(() {
        _summaryCounts = results[0] as Map<String, int>?;
        _operationalInsights = results[1] as OperationalInsights?;
        _isLoadingSummary = false;
      });
    }
  }

  Future<void> _loadUserProfile() async {
    final profile = await MobileRecordService.getCurrentStaffProfile();
    if (mounted) setState(() => _userProfile = profile);
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

  Future<void> _showExitDialog() async {
    final shouldExit = await BackNavigationHelper.showExitAppDialog(
      context,
      title: 'Exit App?',
      message: 'Do you want to exit Siya Solar?',
      cancelLabel: 'Cancel',
      exitLabel: 'Exit',
    );
    if (shouldExit) SystemNavigator.pop();
  }

  void _showLogoutDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Sign Out'),
        content: const Text('Are you sure you want to sign out?'),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red.shade600),
            onPressed: () {
              Navigator.of(ctx).pop();
              _handleSignOut();
            },
            child: const Text('Sign Out'),
          ),
        ],
      ),
    );
  }

  bool _canAccessModule(String module) {
    if (_userProfile == null) return true;
    final role = (_userProfile?['role'] as String? ?? 'staff').toLowerCase();
    if (role == 'admin' || role == 'super_admin' || role == 'owner') return true;
    final permissions = _userProfile?['permissions'];
    if (permissions != null && permissions is Map) {
      final modActions = permissions[module.toLowerCase()];
      if (modActions is List && modActions.isNotEmpty) return true;
    }
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

  String _getAppBarTitle() {
    const titles = ['Siya Solar', 'Action Center', 'Records', 'Search', 'Profile'];
    return titles[_currentIndex.clamp(0, titles.length - 1)];
  }

  String _greeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good morning';
    if (hour < 17) return 'Good afternoon';
    return 'Good evening';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        BackNavigationHelper.handleDoubleBackPress(
          context: context,
          lastBackPressTime: _lastBackPressTime,
          onTimeUpdated: (t) => _lastBackPressTime = t,
        );
      },
      child: Scaffold(
        backgroundColor: colorScheme.surface,
        appBar: AppBar(
          elevation: 0,
          scrolledUnderElevation: 1,
          title: Text(_getAppBarTitle(), style: const TextStyle(fontWeight: FontWeight.w700, letterSpacing: -0.3)),
          leading: IconButton(
            icon: const Icon(Icons.exit_to_app_rounded),
            tooltip: 'Exit App',
            onPressed: _showExitDialog,
          ),
          actions: [
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: SyncStatusIndicator(compact: true),
            ),
            const SizedBox(width: 4),
            PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert),
              tooltip: 'More options',
              onSelected: (value) {
                switch (value) {
                  case 'sync':
                    Navigator.push(context, MaterialPageRoute(builder: (_) => const SyncCenterScreen()));
                    break;
                  case 'settings':
                    Navigator.push(context, MaterialPageRoute(builder: (_) => const MobileSettingsScreen()));
                    break;
                  case 'signout':
                    _showLogoutDialog();
                    break;
                }
              },
              itemBuilder: (_) => [
                const PopupMenuItem(value: 'sync', child: ListTile(leading: Icon(Icons.sync_rounded), title: Text('Sync Center'), dense: true, contentPadding: EdgeInsets.zero)),
                const PopupMenuItem(value: 'settings', child: ListTile(leading: Icon(Icons.settings_outlined), title: Text('Settings'), dense: true, contentPadding: EdgeInsets.zero)),
                const PopupMenuDivider(),
                const PopupMenuItem(value: 'signout', child: ListTile(leading: Icon(Icons.logout, color: Colors.red), title: Text('Sign Out', style: TextStyle(color: Colors.red)), dense: true, contentPadding: EdgeInsets.zero)),
              ],
            ),
          ],
        ),
        body: _buildBody(),
        bottomNavigationBar: NavigationBar(
          selectedIndex: _currentIndex,
          elevation: 0,
          onDestinationSelected: (idx) {
            setState(() => _currentIndex = idx);
            if (idx == 0) _loadSummary();
          },
          destinations: const [
            NavigationDestination(icon: Icon(Icons.home_outlined), selectedIcon: Icon(Icons.home), label: 'Home'),
            NavigationDestination(icon: Icon(Icons.bolt_outlined), selectedIcon: Icon(Icons.bolt), label: 'Actions'),
            NavigationDestination(icon: Icon(Icons.assignment_outlined), selectedIcon: Icon(Icons.assignment), label: 'Records'),
            NavigationDestination(icon: Icon(Icons.search), label: 'Search'),
            NavigationDestination(icon: Icon(Icons.person_outline), selectedIcon: Icon(Icons.person), label: 'Profile'),
          ],
        ),
      ),
    );
  }

  Widget _buildBody() {
    switch (_currentIndex) {
      case 0: return _buildHomeTab();
      case 1: return const ActionCenterScreen();
      case 2: return const ConsumerRecordsScreen();
      case 3: return const SearchRecordsScreen();
      case 4: return const StaffProfileScreen();
      default: return _buildHomeTab();
    }
  }

  Widget _buildHomeTab() {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final name = (_userProfile?['full_name'] as String?)?.split(' ').first ?? 'there';

    return RefreshIndicator(
      onRefresh: _loadSummary,
      child: ListView(
        padding: const EdgeInsets.only(bottom: 24),
        children: [
          // ── Hero greeting header ──────────────────────────────────────
          Container(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  cs.primary,
                  cs.primary.withValues(alpha: 0.82),
                  cs.primaryContainer.withValues(alpha: 0.9),
                ],
                stops: const [0.0, 0.6, 1.0],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Offline banner inside header when offline
                ValueListenableBuilder<SyncMode>(
                  valueListenable: ConnectivityService.modeNotifier,
                  builder: (context, mode, _) {
                    if (mode == SyncMode.online) return const SizedBox.shrink();
                    return Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            mode == SyncMode.offline ? Icons.cloud_off_rounded : Icons.warning_amber_rounded,
                            size: 14,
                            color: Colors.white,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            mode == SyncMode.offline ? 'Offline mode' : 'Sync issue',
                            style: const TextStyle(fontSize: 12, color: Colors.white, fontWeight: FontWeight.w500),
                          ),
                        ],
                      ),
                    );
                  },
                ),
                Text(
                  '${_greeting()}, $name 👋',
                  style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w700, letterSpacing: -0.4),
                ),
                const SizedBox(height: 4),
                Text(
                  'Here\'s your operational snapshot',
                  style: TextStyle(color: Colors.white.withValues(alpha: 0.8), fontSize: 13),
                ),
                const SizedBox(height: 20),

                // Metric chips row
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text(
                    'YOUR PIPELINE',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.3,
                      color: Colors.white.withValues(alpha: 0.65),
                    ),
                  ),
                ),
                if (_isLoadingSummary)
                  const SizedBox(
                    height: 4,
                    child: LinearProgressIndicator(
                      backgroundColor: Colors.transparent,
                      color: Colors.white,
                    ),
                  )
                else if (_summaryCounts != null)
                  Row(
                    children: [
                      _buildHeroMetric('Active', '${_summaryCounts!['total'] ?? 0}'),
                      const SizedBox(width: 10),
                      _buildHeroMetric('Pending', '${_summaryCounts!['pending'] ?? 0}'),
                      const SizedBox(width: 10),
                      _buildHeroMetric('Actions', '${_summaryCounts!['action_center'] ?? 0}'),
                    ],
                  ),
              ],
            ),
          ),

          const SizedBox(height: 20),

          // ── Attention needed (only when items exist) ──────────────────
          if (_operationalInsights != null) _buildAttentionSection(theme),

          // ── Quick modules ─────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Text(
              'MODULES',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.2,
                color: cs.onSurfaceVariant,
              ),
            ),
          ),
          const SizedBox(height: 8),

          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Card(
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
                side: BorderSide(color: cs.outlineVariant.withValues(alpha: 0.6)),
              ),
              child: Column(
                children: [
                  if (_canAccessModule('leads'))
                    _buildModuleTile(
                      icon: Icons.leaderboard_rounded,
                      iconColor: const Color(0xFF3B82F6),
                      title: 'Leads & Prospects',
                      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const MobileLeadsScreen())),
                    ),
                  if (_canAccessModule('leads'))
                    Divider(height: 1, indent: 58, endIndent: 16, color: cs.outlineVariant.withValues(alpha: 0.5)),
                  _buildModuleTile(
                    icon: Icons.assignment_ind_rounded,
                    iconColor: const Color(0xFF6366F1),
                    title: 'My Tasks',
                    onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const MyTasksScreen())),
                  ),
                  Divider(height: 1, indent: 58, endIndent: 16, color: cs.outlineVariant.withValues(alpha: 0.5)),
                  _buildModuleTile(
                    icon: Icons.share_rounded,
                    iconColor: const Color(0xFF25D366),
                    title: 'WhatsApp Tasks',
                    trailing: OfflineTaskSyncService.hasPendingTasks
                        ? _buildBadge('${OfflineTaskSyncService.pendingCount}', cs.error)
                        : null,
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const TasksListScreen(initialSourceFilter: 'WhatsApp Share')),
                    ),
                  ),
                  Divider(height: 1, indent: 58, endIndent: 16, color: cs.outlineVariant.withValues(alpha: 0.5)),
                  _buildModuleTile(
                    icon: Icons.currency_rupee_rounded,
                    iconColor: cs.primary,
                    title: 'Payments',
                    onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const PaymentDashboardScreen())),
                  ),
                ],
              ),
            ),
          ),

          // ── Today's work grid ─────────────────────────────────────────
          if (_canAccessModule('customer') ||
              _canAccessModule('loan') ||
              _canAccessModule('installation') ||
              _canAccessModule('rts') ||
              _canAccessModule('subsidy')) ...[
            const SizedBox(height: 20),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Text(
                'TODAY\'S WORK',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.2,
                  color: cs.onSurfaceVariant,
                ),
              ),
            ),
            const SizedBox(height: 10),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  if (_canAccessModule('customer'))
                    _buildWorkTile(Icons.draw_rounded, 'Agreement', const Color(0xFF2563EB), () => _openStage('Agreement Pending')),
                  if (_canAccessModule('loan'))
                    _buildWorkTile(Icons.account_balance_rounded, 'Loan', const Color(0xFFD97706), () => _openStage('Loan Pending')),
                  if (_canAccessModule('installation'))
                    _buildWorkTile(Icons.construction_rounded, 'Installation', const Color(0xFF059669), () => _openStage('Installation Pending')),
                  if (_canAccessModule('rts'))
                    _buildWorkTile(Icons.electric_meter_rounded, 'RTS', const Color(0xFF7C3AED), () => _openStage('RTS Pending')),
                  if (_canAccessModule('subsidy'))
                    _buildWorkTile(Icons.currency_rupee_rounded, 'Subsidy', const Color(0xFF0F766E), () => _openStage('Subsidy Processing')),
                ],
              ),
            ),
          ],
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  void _openStage(String stage) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => ActionCenterScreen(initialStageFilter: stage)));
  }

  Widget _buildHeroMetric(String label, String value) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(value, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: Colors.white)),
            Text(label, style: TextStyle(fontSize: 11, color: Colors.white.withValues(alpha: 0.8), fontWeight: FontWeight.w500)),
          ],
        ),
      ),
    );
  }

  Widget _buildAttentionSection(ThemeData theme) {
    final cs = theme.colorScheme;
    final ins = _operationalInsights!;

    final items = <_Chip>[];
    if (ins.stalledCount > 0) {
      items.add(_Chip('${ins.stalledCount} Stalled', Icons.timer_outlined, cs.error, () {
        Navigator.push(context, MaterialPageRoute(
          builder: (_) => SearchRecordsScreen(initialFilter: 'Stalled (>10d)', initialRecords: ins.stalledRecords),
        ));
      }));
    }
    if (ins.paymentActionCount > 0) {
      items.add(_Chip('${ins.paymentActionCount} Payments', Icons.payments_outlined, cs.primary, () {
        Navigator.push(context, MaterialPageRoute(
          builder: (_) => SearchRecordsScreen(initialFilter: 'Pending Payment', initialRecords: ins.paymentOpportunityRecords),
        ));
      }));
    }
    if (ins.loanAttentionCount > 0) {
      items.add(_Chip('${ins.loanAttentionCount} Loans', Icons.account_balance_outlined, cs.secondary, () {
        Navigator.push(context, MaterialPageRoute(
          builder: (_) => SearchRecordsScreen(initialFilter: 'Loan Attention', initialRecords: ins.loanAttentionRecords),
        ));
      }));
    }
    if (ins.followupDueCount > 0) {
      items.add(_Chip('${ins.followupDueCount} Follow-ups', Icons.phone_callback_rounded, cs.tertiary, () {
        Navigator.push(context, MaterialPageRoute(builder: (_) => const ActionCenterScreen()));
      }));
    }

    if (items.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(left: 16, right: 16, bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 8),
            child: Row(
              children: [
                Icon(Icons.radar_rounded, size: 14, color: cs.onSurfaceVariant),
                const SizedBox(width: 5),
                Text(
                  'NEEDS ATTENTION',
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 1.2, color: cs.onSurfaceVariant),
                ),
              ],
            ),
          ),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: items.map((chip) => _buildAttentionChip(chip)).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildAttentionChip(_Chip chip) {
    return InkWell(
      onTap: chip.onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: chip.color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: chip.color.withValues(alpha: 0.25)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(chip.icon, size: 13, color: chip.color),
            const SizedBox(width: 5),
            Text(chip.label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: chip.color)),
            const SizedBox(width: 4),
            Icon(Icons.chevron_right_rounded, size: 13, color: chip.color.withValues(alpha: 0.7)),
          ],
        ),
      ),
    );
  }

  Widget _buildBadge(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(10)),
      child: Text(text, style: const TextStyle(fontSize: 10, color: Colors.white, fontWeight: FontWeight.bold)),
    );
  }

  Widget _buildModuleTile({
    required IconData icon,
    required Color iconColor,
    required String title,
    required VoidCallback onTap,
    Widget? trailing,
  }) {
    return ListTile(
      leading: Container(
        width: 38,
        height: 38,
        decoration: BoxDecoration(
          color: iconColor.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, color: iconColor, size: 19),
      ),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14, letterSpacing: -0.1)),
      trailing: trailing ?? Icon(Icons.chevron_right, size: 18, color: Theme.of(context).colorScheme.onSurfaceVariant),
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
      visualDensity: VisualDensity.compact,
    );
  }

  Widget _buildWorkTile(IconData icon, String label, Color color, VoidCallback onTap) {
    final width = (MediaQuery.of(context).size.width - 40) / 2;
    return SizedBox(
      width: width,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 14),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.06),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: color.withValues(alpha: 0.2)),
          ),
          child: Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, size: 16, color: color),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: color),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Chip {
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  _Chip(this.label, this.icon, this.color, this.onTap);
}
