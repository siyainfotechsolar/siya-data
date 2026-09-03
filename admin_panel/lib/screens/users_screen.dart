import 'package:flutter/material.dart';
import '../models/user_profile.dart';
import '../services/user_management_service.dart';
import '../services/supabase_service.dart';

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

  List<UserProfile> get _filteredUsers {
    final query = _searchController.text.trim().toLowerCase();
    if (query.isEmpty) return _users;
    return _users.where((u) {
      final email = u.email.toLowerCase();
      final name = (u.fullName ?? '').toLowerCase();
      return email.contains(query) || name.contains(query);
    }).toList();
  }

  Future<void> _handleRoleChange(UserProfile user, String newRole) async {
    final currentUid = SupabaseService.currentUser?.id;
    if (user.id == currentUid && newRole != 'admin') {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Cannot demote your own admin account!'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    try {
      await UserManagementService.updateUserRole(user.id, newRole);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Updated ${user.email} to $newRole'),
          backgroundColor: Colors.green,
        ),
      );
      _loadUsers();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
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

  Future<void> _handleToggleDelete(UserProfile user, bool canDelete) async {
    try {
      await UserManagementService.toggleDeletePermission(user.id, canDelete);
      _loadUsers();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to update delete permission: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final currentUid = SupabaseService.currentUser?.id;

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'User & Permission Management',
                      style: theme.textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Manage staff roles, login authorization, and record deletion permissions.',
                      style: TextStyle(color: theme.colorScheme.onSurfaceVariant),
                    ),
                  ],
                ),
                FilledButton.icon(
                  onPressed: _loadUsers,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Refresh'),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Search Bar & Summary
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      hintText: 'Search user by email or name...',
                      prefixIcon: const Icon(Icons.search),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                    ),
                    onChanged: (_) => setState(() {}),
                  ),
                ),
                const SizedBox(width: 16),
                Chip(
                  avatar: const Icon(Icons.people, size: 16),
                  label: Text('Total Users: ${_users.length}'),
                ),
                const SizedBox(width: 8),
                Chip(
                  avatar: const Icon(Icons.shield, size: 16, color: Colors.blue),
                  label: Text('Admins: ${_users.where((u) => u.isAdmin).length}'),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Content Table
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
                              ? const Center(child: Text('No users match search criteria.'))
                              : SingleChildScrollView(
                                  scrollDirection: Axis.horizontal,
                                  child: SingleChildScrollView(
                                    child: DataTable(
                                      columns: const [
                                        DataColumn(label: Text('User')),
                                        DataColumn(label: Text('Email')),
                                        DataColumn(label: Text('Role')),
                                        DataColumn(label: Text('Active Status')),
                                        DataColumn(label: Text('Can Delete Records')),
                                        DataColumn(label: Text('Actions')),
                                      ],
                                      rows: _filteredUsers.map((u) {
                                        final isSelf = u.id == currentUid;

                                        return DataRow(
                                          cells: [
                                            DataCell(
                                              Row(
                                                children: [
                                                  CircleAvatar(
                                                    radius: 16,
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
                                                  Text(
                                                    u.fullName?.isNotEmpty == true
                                                        ? u.fullName!
                                                        : 'Staff Member',
                                                    style: const TextStyle(fontWeight: FontWeight.w600),
                                                  ),
                                                  if (isSelf) ...[
                                                    const SizedBox(width: 8),
                                                    Container(
                                                      padding: const EdgeInsets.symmetric(
                                                        horizontal: 6,
                                                        vertical: 2,
                                                      ),
                                                      decoration: BoxDecoration(
                                                        color: Colors.amber.shade100,
                                                        borderRadius: BorderRadius.circular(4),
                                                      ),
                                                      child: Text(
                                                        'YOU',
                                                        style: TextStyle(
                                                          fontSize: 10,
                                                          fontWeight: FontWeight.bold,
                                                          color: Colors.amber.shade900,
                                                        ),
                                                      ),
                                                    ),
                                                  ],
                                                ],
                                              ),
                                            ),
                                            DataCell(Text(u.email)),
                                            DataCell(
                                              DropdownButton<String>(
                                                value: u.role,
                                                underline: const SizedBox(),
                                                items: const [
                                                  DropdownMenuItem(
                                                    value: 'admin',
                                                    child: Text('Admin'),
                                                  ),
                                                  DropdownMenuItem(
                                                    value: 'staff',
                                                    child: Text('Staff'),
                                                  ),
                                                ],
                                                onChanged: isSelf
                                                    ? null
                                                    : (val) {
                                                        if (val != null && val != u.role) {
                                                          _handleRoleChange(u, val);
                                                        }
                                                      },
                                              ),
                                            ),
                                            DataCell(
                                              Switch(
                                                value: u.isActive,
                                                onChanged: isSelf
                                                    ? null
                                                    : (val) => _handleToggleActive(u, val),
                                              ),
                                            ),
                                            DataCell(
                                              Switch(
                                                value: u.isAdmin || u.canDelete,
                                                onChanged: (u.isAdmin)
                                                    ? null
                                                    : (val) => _handleToggleDelete(u, val),
                                              ),
                                            ),
                                            DataCell(
                                              Text(
                                                u.createdAt != null
                                                    ? '${u.createdAt!.year}-${u.createdAt!.month.toString().padLeft(2, '0')}-${u.createdAt!.day.toString().padLeft(2, '0')}'
                                                    : '-',
                                                style: TextStyle(
                                                  fontSize: 12,
                                                  color: theme.colorScheme.onSurfaceVariant,
                                                ),
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
