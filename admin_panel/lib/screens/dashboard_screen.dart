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

  final List<_NavItem> _navItems = [
    _NavItem('Dashboard',     Icons.dashboard_outlined,       Icons.dashboard),
    _NavItem('Action Center', Icons.bolt_outlined,            Icons.bolt),
    _NavItem('Office Tasks',  Icons.assignment_ind_outlined,  Icons.assignment_ind),
    _NavItem('WhatsApp',      Icons.share_rounded,            Icons.share),
    _NavItem('Leads',         Icons.leaderboard_outlined,     Icons.leaderboard),
    _NavItem('Records',       Icons.table_chart_outlined,     Icons.table_chart),
    _NavItem('Payments',      Icons.payments_outlined,        Icons.payments),
    _NavItem('Import',        Icons.upload_file_outlined,     Icons.upload_file),
    _NavItem('Reports',       Icons.bar_chart_outlined,       Icons.bar_chart),
    _NavItem('History',       Icons.history_outlined,         Icons.history),
    _NavItem('Duplicates',    Icons.find_in_page_outlined,    Icons.find_in_page),
    _NavItem('Recycle Bin',   Icons.delete_sweep_outlined,    Icons.delete_sweep),
    _NavItem('Users',         Icons.people_outline,           Icons.people),
    _NavItem('Settings',      Icons.settings_outlined,        Icons.settings),
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

  void _openActionCenter(String stage) {
    setState(() {
      _selectedStageFilter = stage;
      _selectedIndex = 1;
    });
  }

  void _openImportDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => ImportDialog(onImportSuccess: _loadMetrics),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDesktop = MediaQuery.of(context).size.width >= 900;
    final isExtended = MediaQuery.of(context).size.width >= 1100;

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
          if (isDesktop)
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
            )
          else
            NavigationRail(
              extended: false,
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
          const VerticalDivider(thickness: 1, width: 1),
          Expanded(child: _buildBodyContent()),
        ],
      ),
    );
  }

  Widget _buildBodyContent() {
    switch (_selectedIndex) {
      case 0: return _buildDashboardView();
      case 1: return ActionCenterScreen(key: ValueKey(_selectedStageFilter), initialStageFilter: _selectedStageFilter);
      case 2: return const OfficeTasksScreen();
      case 3: return const WhatsAppTasksScreen();
      case 4: return const LeadsScreen();
      case 5: return RecordsScreen(key: ValueKey(_selectedQueueFilter), initialWorkflowQueue: _selectedQueueFilter);
      case 6: return const PaymentsScreen();
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

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Top metrics bar ───────────────────────────────────────────
          Container(
            padding: const EdgeInsets.fromLTRB(28, 24, 28, 24),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [cs.primary, cs.primary.withValues(alpha: 0.78)],
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'System Overview',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.5,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Live metrics · updated in real-time',
                        style: TextStyle(color: Colors.white.withValues(alpha: 0.75), fontSize: 13),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 24),
                Row(
                  children: [
                    SizedBox(width: 140, child: _buildHeroStat('Total Records', '${_metrics?.totalRecords ?? 0}')),
                    const SizedBox(width: 12),
                    SizedBox(width: 140, child: _buildHeroStat('Recent Updates', '${_metrics?.recentlyUpdated ?? 0}')),
                    const SizedBox(width: 12),
                    SizedBox(width: 140, child: _buildHeroStat('Active Users', '${_metrics?.activeUsers ?? 1}')),
                    const SizedBox(width: 16),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          '${DateTime.now().day.toString().padLeft(2,'0')} ${['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'][DateTime.now().month - 1]} ${DateTime.now().year}',
                          style: TextStyle(color: Colors.white.withValues(alpha: 0.9), fontSize: 13, fontWeight: FontWeight.w600),
                        ),
                        Text(
                          '${DateTime.now().hour.toString().padLeft(2,'0')}:${DateTime.now().minute.toString().padLeft(2,'0')}',
                          style: TextStyle(color: Colors.white.withValues(alpha: 0.6), fontSize: 11),
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),

          // ── Body content ──────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(28, 28, 28, 28),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final isWide = constraints.maxWidth > 800;
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Action queues
                    _sectionHeader('ACTION QUEUES', 'Customers requiring immediate follow-up'),
                    const SizedBox(height: 14),
                    isWide
                        ? Row(children: _actionQueueCards().map((w) => Expanded(child: Padding(padding: const EdgeInsets.only(right: 12), child: w))).toList())
                        : Wrap(spacing: 12, runSpacing: 12, children: _actionQueueCards().map((w) => SizedBox(width: 175, child: w)).toList()),
                    const SizedBox(height: 32),

                    // Status
                    _sectionHeader('STATUS', 'Hold and completed pipeline'),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        _buildStatusCard('Hold / No Action', _metrics?.noActionCount, Icons.pause_circle_outline_rounded, const Color(0xFFD97706)),
                        const SizedBox(width: 12),
                        _buildStatusCard('Completed', _metrics?.completedCount, Icons.verified_rounded, const Color(0xFF059669)),
                      ],
                    ),
                    const SizedBox(height: 32),

                    // Recent records table
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        _sectionHeader('RECENT RECORDS', 'Last updated consumer records'),
                        TextButton.icon(
                          onPressed: () => setState(() => _selectedIndex = 5),
                          icon: const Icon(Icons.arrow_forward, size: 14),
                          label: const Text('View All'),
                          style: TextButton.styleFrom(visualDensity: VisualDensity.compact),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    _buildRecentTable(theme),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeroStat(String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label.toUpperCase(),
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.8),
              fontSize: 10,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.8,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            _isLoadingMetrics ? '…' : value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
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
            letterSpacing: 1.2,
            color: theme.colorScheme.primary,
          ),
        ),
        const SizedBox(height: 2),
        Text(subtitle, style: TextStyle(fontSize: 12, color: theme.colorScheme.onSurfaceVariant)),
      ],
    );
  }

  List<Widget> _actionQueueCards() {
    return [
      _buildQueueCard('Agreement Pending', _metrics?.agreementPendingCount,   Icons.history_edu_rounded,      const Color(0xFF2563EB)),
      _buildQueueCard('Loan Pending',      _metrics?.loanPendingCount,        Icons.account_balance_rounded,  const Color(0xFFD97706)),
      _buildQueueCard('Installation',      _metrics?.installationPendingCount, Icons.build_circle_outlined,   const Color(0xFF0F766E)),
      _buildQueueCard('RTS Pending',       _metrics?.rtsPendingCount,         Icons.electric_meter_rounded,   const Color(0xFF7C3AED)),
      _buildQueueCard('Subsidy',           _metrics?.subsidyPendingCount,     Icons.currency_rupee_rounded,   const Color(0xFF059669)),
    ];
  }

  Widget _buildQueueCard(String title, int? count, IconData icon, Color color) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: () => _openActionCenter(title),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          color: theme.colorScheme.surface,
          border: Border.all(color: color.withValues(alpha: 0.2)),
          boxShadow: [
            BoxShadow(color: color.withValues(alpha: 0.06), blurRadius: 8, offset: const Offset(0, 2)),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(9),
                  ),
                  child: Icon(icon, size: 17, color: color),
                ),
                Icon(Icons.north_east_rounded, size: 14, color: color.withValues(alpha: 0.6)),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              _isLoadingMetrics ? '…' : '${count ?? 0}',
              style: TextStyle(fontSize: 26, fontWeight: FontWeight.w800, color: color, letterSpacing: -0.5),
            ),
            const SizedBox(height: 2),
            Text(
              title,
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: theme.colorScheme.onSurface),
              overflow: TextOverflow.ellipsis,
              maxLines: 1,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusCard(String title, int? count, IconData icon, Color color) {
    final theme = Theme.of(context);
    return Expanded(
      child: InkWell(
        onTap: () => _openActionCenter(title),
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            color: color.withValues(alpha: 0.06),
            border: Border.all(color: color.withValues(alpha: 0.2)),
          ),
          child: Row(
            children: [
              Icon(icon, color: color, size: 28),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _isLoadingMetrics ? '…' : '${count ?? 0}',
                      style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: color),
                    ),
                    Text(
                      title,
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: theme.colorScheme.onSurface),
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

  Widget _buildRecentTable(ThemeData theme) {
    final cs = theme.colorScheme;

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
          // Header row
          TableRow(
            decoration: BoxDecoration(color: cs.surfaceContainerHighest),
            children: const [
              _TH('Consumer No'),
              _TH('Name'),
              _TH('Status'),
              _TH('Updated'),
            ],
          ),
          // Data rows
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

  // ── Import view ──────────────────────────────────────────────────────────────

  Widget _buildImportView() {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    return Center(
      child: Container(
        constraints: const BoxConstraints(maxWidth: 480),
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: cs.primaryContainer,
                borderRadius: BorderRadius.circular(18),
              ),
              child: Icon(Icons.cloud_upload_outlined, size: 36, color: cs.primary),
            ),
            const SizedBox(height: 20),
            Text('Import Center', style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800, letterSpacing: -0.4)),
            const SizedBox(height: 8),
            Text(
              'Import consumer records from .xlsx, .xls, or .csv files with automatic header mapping.',
              textAlign: TextAlign.center,
              style: TextStyle(color: cs.onSurfaceVariant, fontSize: 14, height: 1.5),
            ),
            const SizedBox(height: 28),
            FilledButton.icon(
              onPressed: _openImportDialog,
              icon: const Icon(Icons.upload_file_rounded),
              label: const Text('Launch Import Wizard', style: TextStyle(fontWeight: FontWeight.w600)),
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Table helpers ────────────────────────────────────────────────────────────

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

// ── Nav model ────────────────────────────────────────────────────────────────

class _NavItem {
  final String label;
  final IconData icon;
  final IconData selectedIcon;
  _NavItem(this.label, this.icon, this.selectedIcon);
}
