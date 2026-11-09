import 'package:flutter/material.dart';
import '../models/user_profile.dart';
import '../models/app_module_permission.dart';
import '../services/user_management_service.dart';
import '../services/supabase_service.dart';
import '../widgets/add_edit_user_dialog.dart';
import '../widgets/staff_workload_dialog.dart';
import '../utils/responsive.dart';

class UsersScreen extends StatefulWidget {
  final int initialTabIndex;
  const UsersScreen({super.key, this.initialTabIndex = 0});

  @override
  State<UsersScreen> createState() => _UsersScreenState();
}

class _UsersScreenState extends State<UsersScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _matrixSearchCtrl = TextEditingController();

  List<UserProfile> _users = [];
  bool _isLoading = false;
  String? _errorMessage;

  String _filterRole = 'All';
  String _filterDepartment = 'All';
  String _filterStatus = 'All';

  // Permission Matrix State
  UserProfile? _selectedMatrixUser;
  Map<String, List<String>> _matrixPerms = {};
  bool _isSavingMatrix = false;
  String _matrixCategoryFilter = 'All';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: 2,
      vsync: this,
      initialIndex: widget.initialTabIndex,
    );
    _loadUsers();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    _matrixSearchCtrl.dispose();
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
          if (list.isNotEmpty) {
            if (_selectedMatrixUser == null) {
              _selectedMatrixUser = list.first;
              _matrixPerms = Map<String, List<String>>.from(
                _selectedMatrixUser!.permissions.map((k, v) => MapEntry(k, List<String>.from(v))),
              );
            } else {
              final updated = list.firstWhere(
                (u) => u.id == _selectedMatrixUser!.id,
                orElse: () => list.first,
              );
              _selectedMatrixUser = updated;
              _matrixPerms = Map<String, List<String>>.from(
                updated.permissions.map((k, v) => MapEntry(k, List<String>.from(v))),
              );
            }
          }
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

  void _openPermissionsMatrixForUser(UserProfile user) {
    setState(() {
      _selectedMatrixUser = user;
      _matrixPerms = Map<String, List<String>>.from(
        user.permissions.map((k, v) => MapEntry(k, List<String>.from(v))),
      );
      _tabController.animateTo(1);
    });
  }

  Future<void> _saveMatrixPermissions() async {
    if (_selectedMatrixUser == null) return;
    setState(() => _isSavingMatrix = true);

    try {
      await UserManagementService.updateUserPermissions(
        userId: _selectedMatrixUser!.id,
        permissions: _matrixPerms,
        targetUserName: _selectedMatrixUser!.fullName ?? _selectedMatrixUser!.email,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '${_selectedMatrixUser!.fullName ?? _selectedMatrixUser!.email} च्या परवानग्या यशस्वीरित्या सेव्ह केल्या!',
            ),
            backgroundColor: Colors.green,
          ),
        );
      }
      await _loadUsers();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('परवानग्या सेव्ह करताना त्रुटी: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSavingMatrix = false);
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
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to update status: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
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
    final isMobile = Responsive.isMobile(context);
    final activeCount = _users.where((u) => u.isActive && u.status == 'Active').length;

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      body: Padding(
        padding: EdgeInsets.all(isMobile ? 12.0 : 20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top Navigation Bar with Tabs
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.admin_panel_settings_rounded, size: 28, color: theme.colorScheme.primary),
                          const SizedBox(width: 10),
                          Text(
                            isMobile ? 'Staff & Permissions' : 'User Management & Permissions Matrix',
                            style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(width: 12),
                          Chip(
                            backgroundColor: Colors.green.shade50,
                            side: BorderSide(color: Colors.green.shade200),
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
                      if (!isMobile) ...[
                        const SizedBox(height: 4),
                        Text(
                          'कर्मचारी खाती व्यवस्थापन आणि सिस्टीम मॉड्युल्सवर पाहणे (View), बदलणे (Edit), व हटवणे (Delete) अधिकार.',
                          style: TextStyle(color: theme.colorScheme.onSurfaceVariant, fontSize: 13),
                        ),
                      ],
                    ],
                  ),
                ),
                Wrap(
                  spacing: 8,
                  children: [
                    OutlinedButton.icon(
                      onPressed: _openWorkloadDialog,
                      icon: const Icon(Icons.speed_rounded, color: Colors.orange, size: 16),
                      label: Text(isMobile ? 'Workload' : 'Staff Workload', style: const TextStyle(fontSize: 12)),
                    ),
                    FilledButton.icon(
                      onPressed: _openAddUserDialog,
                      icon: const Icon(Icons.person_add_rounded, size: 16),
                      label: Text(isMobile ? 'Add' : 'Add Staff User', style: const TextStyle(fontSize: 12)),
                    ),
                    IconButton(
                      onPressed: _loadUsers,
                      icon: const Icon(Icons.refresh, size: 20),
                      tooltip: 'Refresh',
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 14),

            // Tab Bar
            Container(
              decoration: BoxDecoration(
                border: Border(bottom: BorderSide(color: theme.colorScheme.outlineVariant)),
              ),
              child: TabBar(
                controller: _tabController,
                indicatorColor: theme.colorScheme.primary,
                indicatorWeight: 3,
                labelColor: theme.colorScheme.primary,
                unselectedLabelColor: theme.colorScheme.onSurfaceVariant,
                labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                tabs: const [
                  Tab(
                    icon: Icon(Icons.people_alt_outlined, size: 18),
                    text: 'Staff Directory (कर्मचारी यादी)',
                  ),
                  Tab(
                    icon: Icon(Icons.security_outlined, size: 18),
                    text: 'Role & Permissions Matrix (मॉड्यूल अधिकार व परवानग्या)',
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),

            // Tab Views
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
                      : TabBarView(
                          controller: _tabController,
                          children: [
                            // Tab 1: Staff Directory
                            _buildStaffDirectoryTab(theme, isMobile),

                            // Tab 2: User Permissions Matrix
                            _buildPermissionsMatrixTab(theme, isMobile),
                          ],
                        ),
            ),
          ],
        ),
      ),
    );
  }

  // ==========================================
  // TAB 1: STAFF DIRECTORY
  // ==========================================
  Widget _buildStaffDirectoryTab(ThemeData theme, bool isMobile) {
    final currentUid = SupabaseService.currentUser?.id;

    return Column(
      children: [
        // Search & Filter Toolbar
        if (isMobile)
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  hintText: 'Search by name, email, mobile...',
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
        const SizedBox(height: 14),

        // User Directory List or Table
        Expanded(
          child: isMobile
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
                                DataColumn(label: Text('Active', style: TextStyle(fontWeight: FontWeight.bold))),
                                DataColumn(label: Text('Permissions Matrix', style: TextStyle(fontWeight: FontWeight.bold))),
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

                                    // Permissions Matrix Shortcut Cell
                                    DataCell(
                                      ActionChip(
                                        avatar: Icon(
                                          Icons.security_rounded,
                                          size: 14,
                                          color: u.isAdmin ? Colors.blue.shade800 : Colors.indigo.shade700,
                                        ),
                                        backgroundColor: u.isAdmin ? Colors.blue.shade50 : Colors.indigo.shade50,
                                        label: Text(
                                          u.isAdmin ? 'Full Control' : '${u.allowedModulesCount} / 20 Modules',
                                          style: TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.bold,
                                            color: u.isAdmin ? Colors.blue.shade900 : Colors.indigo.shade900,
                                          ),
                                        ),
                                        tooltip: 'अधिकार व परवानग्या व्यवस्थापन करा (View, Edit, Delete)',
                                        onPressed: () => _openPermissionsMatrixForUser(u),
                                      ),
                                    ),

                                    // Actions Cell
                                    DataCell(
                                      Row(
                                        children: [
                                          IconButton(
                                            icon: const Icon(Icons.edit_outlined, size: 18),
                                            tooltip: 'Edit Profile & Details',
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
                Row(
                  children: [
                    Chip(
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      visualDensity: VisualDensity.compact,
                      backgroundColor: theme.colorScheme.primaryContainer.withValues(alpha: 0.5),
                      label: Text(UserRole.displayName(u.role), style: TextStyle(fontSize: 10, color: theme.colorScheme.primary)),
                    ),
                    const SizedBox(width: 6),
                    ActionChip(
                      avatar: const Icon(Icons.security, size: 12, color: Colors.indigo),
                      backgroundColor: Colors.indigo.shade50,
                      label: Text(
                        u.isAdmin ? 'Full Access' : '${u.allowedModulesCount}/20 Modules',
                        style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.indigo.shade900),
                      ),
                      onPressed: () => _openPermissionsMatrixForUser(u),
                    ),
                  ],
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
                      icon: const Icon(Icons.security, size: 14, color: Colors.indigo),
                      label: const Text('Permissions', style: TextStyle(fontSize: 11)),
                      style: OutlinedButton.styleFrom(
                        visualDensity: VisualDensity.compact,
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      ),
                      onPressed: () => _openPermissionsMatrixForUser(u),
                    ),
                    const SizedBox(width: 6),
                    OutlinedButton.icon(
                      icon: const Icon(Icons.edit, size: 14),
                      label: const Text('Edit', style: TextStyle(fontSize: 11)),
                      style: OutlinedButton.styleFrom(
                        visualDensity: VisualDensity.compact,
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      ),
                      onPressed: () => _openEditUserDialog(u),
                    ),
                    if (!isCurrentUser && u.isActive) ...[
                      const SizedBox(width: 6),
                      IconButton(
                        icon: Icon(Icons.block_outlined, size: 16, color: Colors.red.shade700),
                        tooltip: 'Deactivate',
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

  // ==========================================
  // TAB 2: GRANULAR ROLE & PERMISSIONS MATRIX
  // ==========================================
  Widget _buildPermissionsMatrixTab(ThemeData theme, bool isMobile) {
    if (_users.isEmpty) {
      return const Center(child: Text('कोणतेही युझर्स उपलब्ध नाहीत. कृपया प्रथम युझर जोडा.'));
    }

    final selectedUser = _selectedMatrixUser ?? _users.first;
    final allModules = AppModuleRegistry.allModules;

    // Filter modules by search & category
    final query = _matrixSearchCtrl.text.trim().toLowerCase();
    final displayedModules = allModules.where((mod) {
      if (_matrixCategoryFilter != 'All' && mod.category != _matrixCategoryFilter) {
        return false;
      }
      if (query.isNotEmpty) {
        final matches = mod.key.toLowerCase().contains(query) ||
            mod.nameEn.toLowerCase().contains(query) ||
            mod.nameMr.toLowerCase().contains(query) ||
            mod.descriptionEn.toLowerCase().contains(query) ||
            mod.descriptionMr.toLowerCase().contains(query);
        if (!matches) return false;
      }
      return true;
    }).toList();

    // Calculate live counters
    final viewCount = allModules.where((m) => AppModuleRegistry.hasView(_matrixPerms, m.key)).length;
    final editCount = allModules.where((m) => AppModuleRegistry.hasEdit(_matrixPerms, m.key)).length;
    final deleteCount = allModules.where((m) => AppModuleRegistry.hasDelete(_matrixPerms, m.key)).length;

    return Column(
      children: [
        // Top Header: User Selector & Statistics Bar
        Card(
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(color: theme.colorScheme.outlineVariant),
          ),
          color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.35),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // User Selector Dropdown
                Row(
                  children: [
                    Expanded(
                      flex: 4,
                      child: DropdownButtonFormField<String>(
                        value: selectedUser.id,
                        isExpanded: true,
                        decoration: InputDecoration(
                          labelText: 'निवडलेला कर्मचारी / Staff Member',
                          prefixIcon: const Icon(Icons.person_pin_rounded, color: Colors.indigo),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          isDense: true,
                        ),
                        items: _users.map((u) {
                          return DropdownMenuItem<String>(
                            value: u.id,
                            child: Row(
                              children: [
                                Text(
                                  u.fullName?.isNotEmpty == true ? u.fullName! : u.email,
                                  style: const TextStyle(fontWeight: FontWeight.bold),
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: u.isAdmin ? Colors.blue.shade100 : Colors.grey.shade200,
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    UserRole.displayName(u.role),
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                      color: u.isAdmin ? Colors.blue.shade900 : Colors.black87,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          );
                        }).toList(),
                        onChanged: (val) {
                          if (val != null) {
                            final found = _users.firstWhere((u) => u.id == val);
                            setState(() {
                              _selectedMatrixUser = found;
                              _matrixPerms = Map<String, List<String>>.from(
                                found.permissions.map((k, v) => MapEntry(k, List<String>.from(v))),
                              );
                            });
                          }
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    // Quick Save Button on top
                    FilledButton.icon(
                      style: FilledButton.styleFrom(
                        backgroundColor: Colors.green.shade700,
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      ),
                      onPressed: _isSavingMatrix ? null : _saveMatrixPermissions,
                      icon: _isSavingMatrix
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                            )
                          : const Icon(Icons.save_rounded, size: 18),
                      label: const Text('परवानग्या सेव्ह करा', style: TextStyle(fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Live Stats Counter Badges
                Wrap(
                  spacing: 12,
                  runSpacing: 8,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.blue.shade50,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: Colors.blue.shade200),
                      ),
                      child: Text(
                        'एकूण मॉड्यूल्स: 20',
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.blue.shade900),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.green.shade50,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: Colors.green.shade300),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.visibility, size: 14, color: Colors.green),
                          const SizedBox(width: 4),
                          Text(
                            'पाहण्याची परवानगी (View): $viewCount / 20',
                            style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.green.shade900),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.indigo.shade50,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: Colors.indigo.shade200),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.edit, size: 14, color: Colors.indigo),
                          const SizedBox(width: 4),
                          Text(
                            'बदलण्याची परवानगी (Edit): $editCount / 20',
                            style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.indigo.shade900),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.red.shade50,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: Colors.red.shade200),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.delete_outline, size: 14, color: Colors.red),
                          const SizedBox(width: 4),
                          Text(
                            'हटवण्याची परवानगी (Delete): $deleteCount / 20',
                            style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.red.shade900),
                          ),
                        ],
                      ),
                    ),
                    if (selectedUser.isAdmin)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.amber.shade50,
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: Colors.amber.shade300),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.shield, size: 14, color: Colors.amber),
                            const SizedBox(width: 4),
                            Text(
                              'सूचना: Admin / Owner खात्याला सर्व मॉड्यूल्सवर पूर्ण अधिकार असतात.',
                              style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.amber.shade900),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 10),

                // Quick Action Presets
                Row(
                  children: [
                    const Text('क्विक प्रीसेट्स:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                    const SizedBox(width: 8),
                    OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        visualDensity: VisualDensity.compact,
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        side: BorderSide(color: Colors.green.shade400),
                      ),
                      onPressed: () {
                        setState(() {
                          _matrixPerms = AppModuleRegistry.fullAccessPermissions();
                        });
                      },
                      icon: const Icon(Icons.done_all, size: 14, color: Colors.green),
                      label: const Text('सर्व अधिकार द्या (Full Access)', style: TextStyle(fontSize: 11)),
                    ),
                    const SizedBox(width: 6),
                    OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        visualDensity: VisualDensity.compact,
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        side: BorderSide(color: Colors.blue.shade400),
                      ),
                      onPressed: () {
                        setState(() {
                          _matrixPerms = AppModuleRegistry.readOnlyPermissions();
                        });
                      },
                      icon: const Icon(Icons.visibility_outlined, size: 14, color: Colors.blue),
                      label: const Text('फक्त पाहणे (Read Only)', style: TextStyle(fontSize: 11)),
                    ),
                    const SizedBox(width: 6),
                    OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        visualDensity: VisualDensity.compact,
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        side: BorderSide(color: Colors.orange.shade400),
                      ),
                      onPressed: () {
                        setState(() {
                          _matrixPerms = UserRole.defaultPermissions(selectedUser.role);
                        });
                      },
                      icon: const Icon(Icons.restore, size: 14, color: Colors.orange),
                      label: const Text('रोलनुसार डिफॉल्ट (Role Default)', style: TextStyle(fontSize: 11)),
                    ),
                    const Spacer(),
                    TextButton.icon(
                      style: TextButton.styleFrom(visualDensity: VisualDensity.compact),
                      onPressed: () {
                        setState(() {
                          _matrixPerms = AppModuleRegistry.noAccessPermissions();
                        });
                      },
                      icon: const Icon(Icons.block, size: 14, color: Colors.red),
                      label: const Text('सर्व बंद करा (Clear All)', style: TextStyle(fontSize: 11, color: Colors.red)),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 10),

        // Search & Category Filters Toolbar
        Row(
          children: [
            Expanded(
              flex: 3,
              child: TextField(
                controller: _matrixSearchCtrl,
                decoration: InputDecoration(
                  hintText: 'मॉड्यूल शोधा (उदा. Customer, Loan, Sub-Vendor, Quotation, Payment)...',
                  prefixIcon: const Icon(Icons.search, size: 18),
                  suffixIcon: _matrixSearchCtrl.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear, size: 16),
                          onPressed: () {
                            _matrixSearchCtrl.clear();
                            setState(() {});
                          },
                        )
                      : null,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  isDense: true,
                ),
                onChanged: (_) => setState(() {}),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              flex: 4,
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: AppModuleRegistry.categories.map((cat) {
                    final isSelected = _matrixCategoryFilter == cat;
                    return Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: FilterChip(
                        selected: isSelected,
                        label: Text(cat == 'All' ? 'सर्व विभाग (All)' : cat, style: const TextStyle(fontSize: 11)),
                        visualDensity: VisualDensity.compact,
                        onSelected: (val) {
                          if (val) setState(() => _matrixCategoryFilter = cat);
                        },
                      ),
                    );
                  }).toList(),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),

        // Permissions Matrix Grid
        Expanded(
          child: Card(
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(color: theme.colorScheme.outlineVariant),
            ),
            clipBehavior: Clip.antiAlias,
            child: displayedModules.isEmpty
                ? const Center(child: Text('कोणतेही मॉड्युल्स सापडले नाहीत.'))
                : ListView.separated(
                    itemCount: displayedModules.length,
                    separatorBuilder: (_, __) => Divider(height: 1, color: Colors.grey.shade200),
                    itemBuilder: (context, index) {
                      final mod = displayedModules[index];
                      final hasView = AppModuleRegistry.hasView(_matrixPerms, mod.key);
                      final hasEdit = AppModuleRegistry.hasEdit(_matrixPerms, mod.key);
                      final hasDelete = AppModuleRegistry.hasDelete(_matrixPerms, mod.key);

                      final allActive = hasView && hasEdit && hasDelete;

                      return Container(
                        color: hasView ? Colors.white : Colors.grey.shade50,
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                        child: Row(
                          children: [
                            // Module Icon & Name
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: hasView ? theme.colorScheme.primaryContainer : Colors.grey.shade200,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Icon(
                                mod.icon,
                                size: 22,
                                color: hasView ? theme.colorScheme.primary : Colors.grey.shade600,
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              flex: 4,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Text(
                                        mod.nameMr,
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 13,
                                          color: hasView ? Colors.black87 : Colors.grey.shade600,
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: _getCategoryColor(mod.category).withValues(alpha: 0.15),
                                          borderRadius: BorderRadius.circular(4),
                                        ),
                                        child: Text(
                                          mod.category,
                                          style: TextStyle(
                                            fontSize: 10,
                                            fontWeight: FontWeight.bold,
                                            color: _getCategoryColor(mod.category),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    mod.nameEn,
                                    style: TextStyle(fontSize: 11, color: Colors.grey.shade700, fontWeight: FontWeight.w500),
                                  ),
                                  Text(
                                    mod.descriptionMr,
                                    style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
                                  ),
                                ],
                              ),
                            ),

                            // Switch 1: View (पाहणे)
                            Expanded(
                              flex: 2,
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Switch.adaptive(
                                    value: hasView,
                                    activeColor: Colors.green.shade700,
                                    onChanged: (val) {
                                      setState(() {
                                        _matrixPerms = AppModuleRegistry.setModulePermission(
                                          currentPerms: _matrixPerms,
                                          moduleKey: mod.key,
                                          action: 'view',
                                          enabled: val,
                                        );
                                      });
                                    },
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    'पाहणे\n(View)',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                      color: hasView ? Colors.green.shade900 : Colors.grey.shade500,
                                    ),
                                  ),
                                ],
                              ),
                            ),

                            // Switch 2: Edit / Add (बदलणे / जोडणे)
                            Expanded(
                              flex: 2,
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Switch.adaptive(
                                    value: hasEdit,
                                    activeColor: Colors.indigo.shade700,
                                    onChanged: (val) {
                                      setState(() {
                                        _matrixPerms = AppModuleRegistry.setModulePermission(
                                          currentPerms: _matrixPerms,
                                          moduleKey: mod.key,
                                          action: 'edit',
                                          enabled: val,
                                        );
                                      });
                                    },
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    'बदलणे\n(Edit)',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                      color: hasEdit ? Colors.indigo.shade900 : Colors.grey.shade500,
                                    ),
                                  ),
                                ],
                              ),
                            ),

                            // Switch 3: Delete (हटवणे / पुसणे)
                            Expanded(
                              flex: 2,
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Switch.adaptive(
                                    value: hasDelete,
                                    activeColor: Colors.red.shade700,
                                    onChanged: (val) {
                                      setState(() {
                                        _matrixPerms = AppModuleRegistry.setModulePermission(
                                          currentPerms: _matrixPerms,
                                          moduleKey: mod.key,
                                          action: 'delete',
                                          enabled: val,
                                        );
                                      });
                                    },
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    'हटवणे\n(Delete)',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                      color: hasDelete ? Colors.red.shade900 : Colors.grey.shade500,
                                    ),
                                  ),
                                ],
                              ),
                            ),

                            // Quick All Toggle
                            IconButton(
                              icon: Icon(
                                allActive ? Icons.check_circle : Icons.check_circle_outline,
                                color: allActive ? Colors.green.shade700 : Colors.grey.shade400,
                                size: 20,
                              ),
                              tooltip: allActive ? 'सर्व अधिकार काढा' : 'या मॉड्यूलचे सर्व अधिकार द्या',
                              onPressed: () {
                                setState(() {
                                  if (allActive) {
                                    _matrixPerms = AppModuleRegistry.setModulePermission(
                                      currentPerms: _matrixPerms,
                                      moduleKey: mod.key,
                                      action: 'view',
                                      enabled: false,
                                    );
                                  } else {
                                    var updated = AppModuleRegistry.setModulePermission(
                                      currentPerms: _matrixPerms,
                                      moduleKey: mod.key,
                                      action: 'view',
                                      enabled: true,
                                    );
                                    updated = AppModuleRegistry.setModulePermission(
                                      currentPerms: updated,
                                      moduleKey: mod.key,
                                      action: 'edit',
                                      enabled: true,
                                    );
                                    updated = AppModuleRegistry.setModulePermission(
                                      currentPerms: updated,
                                      moduleKey: mod.key,
                                      action: 'delete',
                                      enabled: true,
                                    );
                                    _matrixPerms = updated;
                                  }
                                });
                              },
                            ),
                          ],
                        ),
                      );
                    },
                  ),
          ),
        ),
      ],
    );
  }

  Color _getCategoryColor(String category) {
    switch (category) {
      case 'Operations':
        return Colors.blue.shade800;
      case 'Finance':
        return Colors.green.shade800;
      case 'Tools':
        return Colors.purple.shade800;
      case 'System':
        return Colors.amber.shade900;
      default:
        return Colors.grey.shade800;
    }
  }
}
