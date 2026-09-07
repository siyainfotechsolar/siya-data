import 'package:flutter/material.dart';
import '../models/user_profile.dart';
import '../services/user_management_service.dart';
import '../services/supabase_service.dart';
import '../widgets/add_edit_user_dialog.dart';
import '../widgets/staff_workload_dialog.dart';

class UsersScreen extends StatefulWidget {
  const UsersScreen({super.key});

  @override
  State<UsersScreen> createState() => _UsersScreenState();
}

class _UsersScreenState extends State<UsersScreen> {
  final TextEditingController _searchController = TextEditingController();
  List<UserProfile> _users = [];
  bool _isLoading = false;
  String? _errorMessage;

  String _filterRole = 'All';
  String _filterDepartment = 'All';
  String _filterStatus = 'All';

  @override
  void initState() {
    super.initState();
    _loadUsers();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadUsers() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final list = await UserManagementService.fetchAllUsers();
      if (mounted) {
        setState(() {
          _users = list;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = e.toString().replaceAll('Exception: ', '');
        });
      }
    }
  }

  List<String> get _departments {
    final set = <String>{'All'};
    for (final u in _users) {
      if (u.department != null && u.department!.trim().isNotEmpty) {
        set.add(u.department!.trim());
      }
    }
    return set.toList();
  }

  List<UserProfile> get _filteredUsers {
    final query = _searchController.text.trim().toLowerCase();

    return _users.where((u) {
      if (_filterRole != 'All' && u.role.toLowerCase() != _filterRole.toLowerCase()) {
        return false;
      }
      if (_filterDepartment != 'All' && (u.department ?? '') != _filterDepartment) {
        return false;
      }
      if (_filterStatus != 'All' && u.status.toLowerCase() != _filterStatus.toLowerCase()) {
        return false;
      }

      if (query.isNotEmpty) {
        final email = u.email.toLowerCase();
        final name = (u.fullName ?? '').toLowerCase();
        final mobile = (u.mobile ?? '').toLowerCase();
        final empId = (u.employeeId ?? '').toLowerCase();
        final matches = email.contains(query) ||
            name.contains(query) ||
            mobile.contains(query) ||
            empId.contains(query);
        if (!matches) return false;
      }

      return true;
    }).toList();
  }

  void _openAddUserDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AddEditUserDialog(
        onSaved: _loadUsers,
      ),
    );
  }

  void _openEditUserDialog(UserProfile user) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AddEditUserDialog(
        user: user,
        onSaved: _loadUsers,
      ),
    );
  }

  void _openWorkloadDialog() {
    showDialog(
      context: context,
      builder: (_) => StaffWorkloadDialog(users: _users),
    );
  }

  Future<void> _handleToggleActive(UserProfile user, bool isActive) async {
    final currentUid = SupabaseService.currentUser?.id;
    if (user.id == currentUid && !isActive) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Cannot deactivate your own account!'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    try {
      await UserManagementService.toggleUserActive(user.id, isActive);
      _loadUsers();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to update status: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _handleSafeDeactivate(UserProfile user) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Deactivate Staff Account'),
        content: Text(
          'Are you sure you want to deactivate ${user.fullName ?? user.email}?\n\n'
          '• User will not be able to log in.\n'
          '• Historical audit logs, completed jobs, and records remain completely intact.\n'
          '• Staff cannot receive new customer assignments.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Deactivate'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await _handleToggleActive(user, false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final currentUid = SupabaseService.currentUser?.id;

    final activeCount = _users.where((u) => u.isActive && u.status == 'Active').length;
    final adminCount = _users.where((u) => u.isAdmin).length;

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header with Add User and Workload buttons
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          'User & Staff Management',
                          style: theme.textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Chip(
                          backgroundColor: Colors.green.shade50,
                          label: Text(
                            '$activeCount Active',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: Colors.green.shade800,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Manage staff credentials, role-permission matrix, and balance operational workload.',
                      style: TextStyle(color: theme.colorScheme.onSurfaceVariant),
                    ),
                  ],
                ),
                Wrap(
                  spacing: 12,
                  children: [
                    OutlinedButton.icon(
                      onPressed: _openWorkloadDialog,
                      icon: const Icon(Icons.speed_rounded, color: Colors.orange),
                      label: const Text('Staff Workload'),
                    ),
                    FilledButton.icon(
                      onPressed: _openAddUserDialog,
                      icon: const Icon(Icons.person_add_rounded),
                      label: const Text('Add User'),
                    ),
                    IconButton(
                      onPressed: _loadUsers,
                      icon: const Icon(Icons.refresh),
                      tooltip: 'Refresh',
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Search & Filter Toolbar
            Row(
              children: [
                Expanded(
                  flex: 3,
                  child: TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      hintText: 'Search by name, email, mobile, or staff ID...',
                      prefixIcon: const Icon(Icons.search),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    ),
                    onChanged: (_) => setState(() {}),
                  ),
                ),
                const SizedBox(width: 12),
                // Role Filter
                Expanded(
                  flex: 2,
                  child: DropdownButtonFormField<String>(
                    value: _filterRole,
                    decoration: InputDecoration(
                      labelText: 'Role',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    ),
                    items: ['All', ...UserRole.allRoles].map((r) {
                      return DropdownMenuItem(
                        value: r,
                        child: Text(r == 'All' ? 'All Roles' : UserRole.displayName(r)),
                      );
                    }).toList(),
                    onChanged: (val) {
                      if (val != null) setState(() => _filterRole = val);
                    },
                  ),
                ),
                const SizedBox(width: 12),
                // Status Filter
                Expanded(
                  flex: 2,
                  child: DropdownButtonFormField<String>(
                    value: _filterStatus,
                    decoration: InputDecoration(
                      labelText: 'Status',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    ),
                    items: const [
                      DropdownMenuItem(value: 'All', child: Text('All Statuses')),
                      DropdownMenuItem(value: 'Active', child: Text('Active Only')),
                      DropdownMenuItem(value: 'Inactive', child: Text('Inactive Only')),
                      DropdownMenuItem(value: 'Suspended', child: Text('Suspended Only')),
                    ],
                    onChanged: (val) {
                      if (val != null) setState(() => _filterStatus = val);
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Table Content
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _errorMessage != null
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.error_outline, size: 48, color: Colors.red),
                              const SizedBox(height: 12),
                              Text(_errorMessage!),
                              const SizedBox(height: 12),
                              FilledButton(onPressed: _loadUsers, child: const Text('Retry')),
                            ],
                          ),
                        )
                      : Card(
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                            side: BorderSide(color: theme.colorScheme.outlineVariant),
                          ),
                          clipBehavior: Clip.antiAlias,
                          child: _filteredUsers.isEmpty
                              ? const Center(child: Text('No users match search or filter criteria.'))
                              : SingleChildScrollView(
                                  scrollDirection: Axis.horizontal,
                                  child: SingleChildScrollView(
                                    child: DataTable(
                                      headingRowColor: WidgetStateProperty.all(
                                        theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
                                      ),
                                      columns: const [
                                        DataColumn(label: Text('Staff Member', style: TextStyle(fontWeight: FontWeight.bold))),
                                        DataColumn(label: Text('Contact Info', style: TextStyle(fontWeight: FontWeight.bold))),
                                        DataColumn(label: Text('Role', style: TextStyle(fontWeight: FontWeight.bold))),
                                        DataColumn(label: Text('Department', style: TextStyle(fontWeight: FontWeight.bold))),
                                        DataColumn(label: Text('Status', style: TextStyle(fontWeight: FontWeight.bold))),
                                        DataColumn(label: Text('Active Toggle', style: TextStyle(fontWeight: FontWeight.bold))),
                                        DataColumn(label: Text('Can Delete', style: TextStyle(fontWeight: FontWeight.bold))),
                                        DataColumn(label: Text('Actions', style: TextStyle(fontWeight: FontWeight.bold))),
                                      ],
                                      rows: _filteredUsers.map((u) {
                                        final isSelf = u.id == currentUid;

                                        return DataRow(
                                          cells: [
                                            // Staff Member Cell
                                            DataCell(
                                              Row(
                                                children: [
                                                  CircleAvatar(
                                                    radius: 18,
                                                    backgroundColor: u.isAdmin
                                                        ? Colors.blue.shade100
                                                        : Colors.green.shade100,
                                                    child: Icon(
                                                      u.isAdmin ? Icons.shield : Icons.person,
                                                      size: 18,
                                                      color: u.isAdmin
                                                          ? Colors.blue.shade800
                                                          : Colors.green.shade800,
                                                    ),
                                                  ),
                                                  const SizedBox(width: 12),
                                                  Column(
                                                    mainAxisAlignment: MainAxisAlignment.center,
                                                    crossAxisAlignment: CrossAxisAlignment.start,
                                                    children: [
                                                      Row(
                                                        children: [
                                                          Text(
                                                            u.fullName?.isNotEmpty == true
                                                                ? u.fullName!
                                                                : 'Staff Member',
                                                            style: const TextStyle(fontWeight: FontWeight.w600),
                                                          ),
                                                          if (isSelf) ...[
                                                            const SizedBox(width: 6),
                                                            Container(
                                                              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                                                              decoration: BoxDecoration(
                                                                color: Colors.amber.shade100,
                                                                borderRadius: BorderRadius.circular(4),
                                                              ),
                                                              child: Text(
                                                                'YOU',
                                                                style: TextStyle(
                                                                  fontSize: 9,
                                                                  fontWeight: FontWeight.bold,
                                                                  color: Colors.amber.shade900,
                                                                ),
                                                              ),
                                                            ),
                                                          ],
                                                        ],
                                                      ),
                                                      if (u.employeeId != null && u.employeeId!.isNotEmpty)
                                                        Text(
                                                          'ID: ${u.employeeId}',
                                                          style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                                                        ),
                                                    ],
                                                  ),
                                                ],
                                              ),
                                            ),

                                            // Contact Info
                                            DataCell(
                                              Column(
                                                mainAxisAlignment: MainAxisAlignment.center,
                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                children: [
                                                  Text(u.email, style: const TextStyle(fontSize: 12)),
                                                  if (u.mobile != null && u.mobile!.isNotEmpty)
                                                    Text(
                                                      u.mobile!,
                                                      style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                                                    ),
                                                ],
                                              ),
                                            ),

                                            // Role Cell
                                            DataCell(
                                              Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                                decoration: BoxDecoration(
                                                  color: u.isAdmin ? Colors.blue.shade50 : Colors.grey.shade100,
                                                  borderRadius: BorderRadius.circular(6),
                                                  border: Border.all(
                                                    color: u.isAdmin ? Colors.blue.shade200 : Colors.grey.shade300,
                                                  ),
                                                ),
                                                child: Text(
                                                  UserRole.displayName(u.role),
                                                  style: TextStyle(
                                                    fontSize: 11,
                                                    fontWeight: FontWeight.w600,
                                                    color: u.isAdmin ? Colors.blue.shade900 : Colors.black87,
                                                  ),
                                                ),
                                              ),
                                            ),

                                            // Department Cell
                                            DataCell(
                                              Text(
                                                u.department?.isNotEmpty == true ? u.department! : '-',
                                                style: const TextStyle(fontSize: 12),
                                              ),
                                            ),

                                            // Status Badge Cell
                                            DataCell(
                                              Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                                decoration: BoxDecoration(
                                                  color: u.status == 'Active'
                                                      ? Colors.green.shade50
                                                      : u.status == 'Suspended'
                                                          ? Colors.red.shade50
                                                          : Colors.grey.shade100,
                                                  borderRadius: BorderRadius.circular(4),
                                                ),
                                                child: Text(
                                                  u.status,
                                                  style: TextStyle(
                                                    fontSize: 11,
                                                    fontWeight: FontWeight.bold,
                                                    color: u.status == 'Active'
                                                        ? Colors.green.shade800
                                                        : u.status == 'Suspended'
                                                            ? Colors.red.shade800
                                                            : Colors.grey.shade700,
                                                  ),
                                                ),
                                              ),
                                            ),

                                            // Active Switch
                                            DataCell(
                                              Switch(
                                                value: u.isActive,
                                                onChanged: isSelf
                                                    ? null
                                                    : (val) => _handleToggleActive(u, val),
                                              ),
                                            ),

                                            // Can Delete Switch
                                            DataCell(
                                              Switch(
                                                value: u.isAdmin || u.canDelete,
                                                onChanged: (u.isAdmin)
                                                    ? null
                                                    : (val) async {
                                                        await UserManagementService.toggleDeletePermission(u.id, val);
                                                        _loadUsers();
                                                      },
                                              ),
                                            ),

                                            // Actions Cell
                                            DataCell(
                                              Row(
                                                children: [
                                                  IconButton(
                                                    icon: const Icon(Icons.edit_outlined, size: 18),
                                                    tooltip: 'Edit User & Permissions',
                                                    onPressed: () => _openEditUserDialog(u),
                                                  ),
                                                  if (!isSelf && u.isActive)
                                                    IconButton(
                                                      icon: const Icon(Icons.block_outlined, size: 18, color: Colors.red),
                                                      tooltip: 'Deactivate Staff',
                                                      onPressed: () => _handleSafeDeactivate(u),
                                                    ),
                                                ],
                                              ),
                                            ),
                                          ],
                                        );
                                      }).toList(),
                                    ),
                                  ),
                                ),
                        ),
            ),
          ],
        ),
      ),
    );
  }
}

