import 'package:flutter/material.dart';
import '../models/user_profile.dart';
import '../services/user_management_service.dart';
import '../services/supabase_service.dart';
import '../widgets/add_edit_user_dialog.dart';
import '../widgets/staff_workload_dialog.dart';
import '../utils/responsive.dart';

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
    final isMobile = Responsive.isMobile(context);

    final activeCount = _users.where((u) => u.isActive && u.status == 'Active').length;
    final adminCount = _users.where((u) => u.isAdmin).length;

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      body: Padding(
        padding: EdgeInsets.all(isMobile ? 12.0 : 24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header with Add User and Workload buttons
            if (isMobile)
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Staff Management',
                          style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Chip(
                        backgroundColor: Colors.green.shade50,
                        label: Text(
                          '$activeCount Active',
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.green.shade800),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _openWorkloadDialog,
                          icon: const Icon(Icons.speed_rounded, color: Colors.orange, size: 16),
                          label: const Text('Workload', style: TextStyle(fontSize: 13)),
                          style: OutlinedButton.styleFrom(
                            visualDensity: VisualDensity.compact,
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: FilledButton.icon(
                          onPressed: _openAddUserDialog,
                          icon: const Icon(Icons.person_add_rounded, size: 16),
                          label: const Text('Add User', style: TextStyle(fontSize: 13)),
                          style: FilledButton.styleFrom(
                            visualDensity: VisualDensity.compact,
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                          ),
                        ),
                      ),
                      IconButton(
                        onPressed: _loadUsers,
                        icon: const Icon(Icons.refresh, size: 20),
                        tooltip: 'Refresh',
                      ),
                    ],
                  ),
                ],
              )
            else
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
            if (isMobile)
              Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      hintText: 'Search by name, email...',
                      prefixIcon: const Icon(Icons.search),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    ),
                    onChanged: (_) => setState(() {}),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          value: _filterRole,
                          isExpanded: true,
                          decoration: InputDecoration(
                            labelText: 'Role',
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                            isDense: true,
                          ),
                          items: ['All', ...UserRole.allRoles].map((r) {
                            return DropdownMenuItem(
                              value: r,
                              child: Text(r == 'All' ? 'All Roles' : UserRole.displayName(r), overflow: TextOverflow.ellipsis),
                            );
                          }).toList(),
                          onChanged: (val) {
                            if (val != null) setState(() => _filterRole = val);
                          },
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          value: _filterStatus,
                          isExpanded: true,
                          decoration: InputDecoration(
                            labelText: 'Status',
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                            isDense: true,
                          ),
                          items: const [
                            DropdownMenuItem(value: 'All', child: Text('All')),
                            DropdownMenuItem(value: 'Active', child: Text('Active')),
                            DropdownMenuItem(value: 'Inactive', child: Text('Inactive')),
                          ],
                          onChanged: (val) {
                            if (val != null) setState(() => _filterStatus = val);
                          },
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
                      : isMobile
                          ? _buildMobileUserList(theme, currentUid)
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

  Widget _buildMobileUserList(ThemeData theme, String? currentUid) {
    final filtered = _filteredUsers;
    if (filtered.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.people_outline, size: 48, color: Colors.grey.shade400),
            const SizedBox(height: 12),
            const Text('No users found', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
            const SizedBox(height: 4),
            Text('Try adjusting your filters.', style: TextStyle(color: Colors.grey.shade600)),
          ],
        ),
      );
    }
    return ListView.separated(
      itemCount: filtered.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (context, idx) {
        final u = filtered[idx];
        final isCurrentUser = u.id == currentUid;
        final displayName = u.fullName ?? u.email;
        return Card(
          elevation: 1,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    CircleAvatar(
                      radius: 18,
                      backgroundColor: theme.colorScheme.primaryContainer,
                      child: Text(
                        displayName.isNotEmpty ? displayName[0].toUpperCase() : '?',
                        style: TextStyle(color: theme.colorScheme.onPrimaryContainer, fontWeight: FontWeight.bold),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  displayName + (isCurrentUser ? ' (You)' : ''),
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: u.status == 'Active' ? Colors.green.shade50 : Colors.grey.shade100,
                                  borderRadius: BorderRadius.circular(4),
                                  border: Border.all(color: u.status == 'Active' ? Colors.green.shade300 : Colors.grey.shade300),
                                ),
                                child: Text(
                                  u.status,
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color: u.status == 'Active' ? Colors.green.shade800 : Colors.grey.shade700,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          Text(u.email, style: TextStyle(fontSize: 12, color: Colors.grey.shade600), overflow: TextOverflow.ellipsis),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Chip(
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  visualDensity: VisualDensity.compact,
                  backgroundColor: theme.colorScheme.primaryContainer.withValues(alpha: 0.5),
                  label: Text(UserRole.displayName(u.role), style: TextStyle(fontSize: 10, color: theme.colorScheme.primary)),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: Row(
                        children: [
                          const Text('Active: ', style: TextStyle(fontSize: 12)),
                          Switch.adaptive(
                            value: u.isActive,
                            onChanged: isCurrentUser ? null : (val) => _handleToggleActive(u, val),
                            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                        ],
                      ),
                    ),
                    OutlinedButton.icon(
                      icon: const Icon(Icons.edit, size: 14),
                      label: const Text('Edit', style: TextStyle(fontSize: 12)),
                      style: OutlinedButton.styleFrom(
                        visualDensity: VisualDensity.compact,
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      ),
                      onPressed: () => _openEditUserDialog(u),
                    ),
                    if (!isCurrentUser && u.isActive) ...[
                      const SizedBox(width: 6),
                      OutlinedButton.icon(
                        icon: Icon(Icons.block_outlined, size: 14, color: Colors.red.shade700),
                        label: Text('Deactivate', style: TextStyle(fontSize: 12, color: Colors.red.shade700)),
                        style: OutlinedButton.styleFrom(
                          visualDensity: VisualDensity.compact,
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          side: BorderSide(color: Colors.red.shade300),
                        ),
                        onPressed: () => _handleSafeDeactivate(u),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}


