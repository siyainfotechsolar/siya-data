import 'package:flutter/material.dart';
import '../services/supabase_service.dart';
import '../services/record_service.dart';
import 'login_screen.dart';
import '../services/activity_log_service.dart';

class StaffProfileScreen extends StatefulWidget {
  const StaffProfileScreen({super.key});

  @override
  State<StaffProfileScreen> createState() => _StaffProfileScreenState();
}

class _StaffProfileScreenState extends State<StaffProfileScreen> {
  bool _isLoading = true;
  Map<String, dynamic>? _profile;
  Map<String, int> _workStats = {
    'today': 0,
    'weekly': 0,
    'completed': 0,
    'pending': 0,
    'followups': 0,
    'installations': 0,
    'payments': 0,
  };

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    setState(() => _isLoading = true);
    final data = await MobileRecordService.getCurrentStaffProfile();
    await _loadStaffWorkStats(data);
    if (mounted) {
      setState(() {
        _profile = data;
        _isLoading = false;
      });
    }
  }

  Future<void> _loadStaffWorkStats(Map<String, dynamic>? profile) async {
    try {
      final user = SupabaseService.currentUser;
      final staffName = profile?['full_name'] ?? user?.email?.split('@').first;
      if (staffName == null) return;

      final now = DateTime.now();
      final todayStart = DateTime(now.year, now.month, now.day);
      final weekStart = todayStart.subtract(Duration(days: now.weekday - 1));

      final todayRes = await ActivityLogService.fetchActivityLogs(
        pageSize: 100,
        startDate: todayStart,
        staffFilter: staffName,
      );

      final weekRes = await ActivityLogService.fetchActivityLogs(
        pageSize: 200,
        startDate: weekStart,
        staffFilter: staffName,
      );

      int completed = 0;
      int pending = 0;
      int followups = 0;
      int installations = 0;
      int payments = 0;

      for (final item in weekRes.items) {
        final act = item.action.toLowerCase();
        final mod = item.module.toLowerCase();
        final newVal = (item.newValue ?? '').toLowerCase();

        if (act.contains('complete') || newVal.contains('complete') || newVal.contains('done')) {
          completed++;
        } else if (act.contains('pending') || newVal.contains('pending') || newVal.contains('hold')) {
          pending++;
        }

        if (mod.contains('follow') || act.contains('follow')) followups++;
        if (mod.contains('install') || act.contains('install')) installations++;
        if (mod.contains('payment') || act.contains('payment')) payments++;
      }

      _workStats = {
        'today': todayRes.totalCount,
        'weekly': weekRes.totalCount,
        'completed': completed,
        'pending': pending,
        'followups': followups,
        'installations': installations,
        'payments': payments,
      };
    } catch (_) {}
  }

  Future<void> _handleSignOut() async {
    await SupabaseService.signOut();
    if (mounted) {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const MobileLoginScreen()),
        (route) => false,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final user = SupabaseService.currentUser;
    final email = _profile?['email'] ?? user?.email ?? 'Field Staff';
    final role = (_profile?['role'] as String? ?? 'staff').toUpperCase();
    final canDelete = _profile?['can_delete'] == true;
    final fullName = _profile?['full_name'] ?? 'Solar Field Technician';

    return Scaffold(
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  // Profile Header Card
                  Card(
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                      side: BorderSide(
                        color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5),
                      ),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(20.0),
                      child: Stack(
                        children: [
                          Positioned(
                            top: 0,
                            right: 0,
                            child: IconButton(
                              icon: Icon(Icons.logout_rounded, color: theme.colorScheme.error, size: 20),
                              tooltip: 'Sign Out',
                              onPressed: _handleSignOut,
                            ),
                          ),
                          Center(
                            child: Column(
                              children: [
                                CircleAvatar(
                                  radius: 36,
                                  backgroundColor: theme.colorScheme.primaryContainer,
                                  child: Icon(Icons.account_circle_rounded, size: 44, color: theme.colorScheme.primary),
                                ),
                                const SizedBox(height: 12),
                                Text(
                                  fullName,
                                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  email,
                                  style: TextStyle(color: theme.colorScheme.onSurfaceVariant, fontSize: 13),
                                ),
                                const SizedBox(height: 12),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: theme.colorScheme.primary.withValues(alpha: 0.12),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    'ROLE: $role',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                      color: theme.colorScheme.primary,
                                    ),
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

                  // Today's & Weekly Work Summary (Who Worked Log Integration)
                  Card(
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                      side: BorderSide(
                        color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5),
                      ),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.work_history_rounded, color: theme.colorScheme.primary, size: 20),
                              const SizedBox(width: 8),
                              Text('My Activity & Work Summary', style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold)),
                            ],
                          ),
                          const Divider(height: 18),
                          Row(
                            children: [
                              Expanded(
                                child: _buildWorkCounter('Today\'s Actions', '${_workStats['today'] ?? 0}', theme.colorScheme.primary),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: _buildWorkCounter('Weekly Actions', '${_workStats['weekly'] ?? 0}', theme.colorScheme.secondary),
                              ),
                            ],
                          ),
                          const SizedBox(height: 14),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceAround,
                            children: [
                              _buildMiniStat('Completed', '${_workStats['completed'] ?? 0}', theme.colorScheme.primary),
                              _buildMiniStat('Pending', '${_workStats['pending'] ?? 0}', theme.colorScheme.error),
                              _buildMiniStat('Follow-ups', '${_workStats['followups'] ?? 0}', theme.colorScheme.secondary),
                              _buildMiniStat('Installations', '${_workStats['installations'] ?? 0}', theme.colorScheme.tertiary),
                              _buildMiniStat('Payments', '${_workStats['payments'] ?? 0}', const Color(0xFF7C3AED)),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Permissions Card
                  Card(
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                      side: BorderSide(
                        color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5),
                      ),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Account Permissions', style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold)),
                          const Divider(height: 18),
                          _buildPermissionTile(
                            icon: Icons.visibility_outlined,
                            title: 'View Active Records',
                            subtitle: 'Allowed to search & inspect consumer profiles',
                            isAllowed: true,
                          ),
                          _buildPermissionTile(
                            icon: Icons.edit_outlined,
                            title: 'Update Installation Status',
                            subtitle: 'Allowed to change stage and log site notes',
                            isAllowed: true,
                          ),
                          _buildPermissionTile(
                            icon: Icons.delete_outline,
                            title: 'Delete Records',
                            subtitle: canDelete
                                ? 'Permission granted by Administrator'
                                : 'Restricted to Admin / Permitted Staff',
                            isAllowed: canDelete,
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Sign Out Button
                  OutlinedButton.icon(
                    onPressed: _handleSignOut,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: theme.colorScheme.error,
                      side: BorderSide(color: theme.colorScheme.error),
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    icon: const Icon(Icons.logout),
                    label: const Text('Sign Out', style: TextStyle(fontWeight: FontWeight.w600)),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildPermissionTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required bool isAllowed,
  }) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        children: [
          Icon(icon, size: 22, color: isAllowed ? cs.primary : cs.onSurfaceVariant),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                Text(subtitle, style: TextStyle(color: cs.onSurfaceVariant, fontSize: 11)),
              ],
            ),
          ),
          Icon(
            isAllowed ? Icons.check_circle : Icons.cancel_outlined,
            size: 18,
            color: isAllowed ? cs.primary : cs.onSurfaceVariant,
          ),
        ],
      ),
    );
  }

  Widget _buildWorkCounter(String label, String count, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            count,
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: color),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Theme.of(context).colorScheme.onSurfaceVariant),
          ),
        ],
      ),
    );
  }

  Widget _buildMiniStat(String label, String value, Color color) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: color),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: TextStyle(fontSize: 10, color: Theme.of(context).colorScheme.onSurfaceVariant),
        ),
      ],
    );
  }
}
