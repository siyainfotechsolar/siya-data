import 'package:flutter/material.dart';
import '../models/user_profile.dart';
import '../models/app_module_permission.dart';
import '../services/user_management_service.dart';

class AddEditUserDialog extends StatefulWidget {
  final UserProfile? user;
  final VoidCallback onSaved;

  const AddEditUserDialog({
    super.key,
    this.user,
    required this.onSaved,
  });

  @override
  State<AddEditUserDialog> createState() => _AddEditUserDialogState();
}

class _AddEditUserDialogState extends State<AddEditUserDialog> with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  late TabController _tabController;

  late TextEditingController _nameCtrl;
  late TextEditingController _mobileCtrl;
  late TextEditingController _emailCtrl;
  late TextEditingController _employeeIdCtrl;
  late TextEditingController _departmentCtrl;
  late TextEditingController _remarksCtrl;
  late TextEditingController _tempPasswordCtrl;

  late String _selectedRole;
  late String _selectedStatus;
  late Map<String, List<String>> _permissions;
  bool _isSaving = false;
  String? _errorMessage;

  final List<String> _departments = [
    'General Operations',
    'Sales & Marketing',
    'Loan & Finance',
    'Technical & Installation',
    'MSEDCL & RTS Liaison',
    'Subsidy & Compliance',
    'Accounts & Billing',
    'Customer Support',
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);

    final u = widget.user;
    _nameCtrl = TextEditingController(text: u?.fullName ?? '');
    _mobileCtrl = TextEditingController(text: u?.mobile ?? '');
    _emailCtrl = TextEditingController(text: u?.email ?? '');
    _employeeIdCtrl = TextEditingController(text: u?.employeeId ?? '');
    _departmentCtrl = TextEditingController(text: u?.department ?? '');
    _remarksCtrl = TextEditingController(text: u?.remarks ?? '');
    _tempPasswordCtrl = TextEditingController();

    _selectedRole = u?.role ?? UserRole.officeStaff;
    _selectedStatus = u?.status ?? 'Active';
    _permissions = u != null
        ? Map<String, List<String>>.from(u.permissions.map((k, v) => MapEntry(k, List<String>.from(v))))
        : UserRole.defaultPermissions(_selectedRole);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _nameCtrl.dispose();
    _mobileCtrl.dispose();
    _emailCtrl.dispose();
    _employeeIdCtrl.dispose();
    _departmentCtrl.dispose();
    _remarksCtrl.dispose();
    _tempPasswordCtrl.dispose();
    super.dispose();
  }

  void _onRoleChanged(String? newRole) {
    if (newRole == null) return;
    setState(() {
      _selectedRole = newRole;
      _permissions = UserRole.defaultPermissions(newRole);
    });
  }

  bool _hasPerm(String module, String action) {
    final list = _permissions[module.toLowerCase()];
    return list != null && list.contains(action.toLowerCase());
  }

  void _togglePerm(String module, String action, bool enable) {
    final m = module.toLowerCase();
    final a = action.toLowerCase();
    setState(() {
      final current = List<String>.from(_permissions[m] ?? []);
      if (enable) {
        if (!current.contains(a)) current.add(a);
      } else {
        current.remove(a);
      }
      _permissions[m] = current;
    });
  }

  Future<void> _handleSave() async {
    if (!_formKey.currentState!.validate()) {
      _tabController.animateTo(0);
      return;
    }

    setState(() {
      _isSaving = true;
      _errorMessage = null;
    });

    try {
      if (widget.user == null) {
        // Create new user
        await UserManagementService.createUser(
          fullName: _nameCtrl.text.trim(),
          mobile: _mobileCtrl.text.trim(),
          email: _emailCtrl.text.trim(),
          role: _selectedRole,
          employeeId: _employeeIdCtrl.text.trim(),
          department: _departmentCtrl.text.trim(),
          status: _selectedStatus,
          permissions: _permissions,
          remarks: _remarksCtrl.text.trim(),
          temporaryPassword: _tempPasswordCtrl.text.trim().isNotEmpty ? _tempPasswordCtrl.text.trim() : null,
        );
      } else {
        // Update user
        await UserManagementService.updateUser(
          userId: widget.user!.id,
          fullName: _nameCtrl.text.trim(),
          mobile: _mobileCtrl.text.trim(),
          email: _emailCtrl.text.trim(),
          role: _selectedRole,
          employeeId: _employeeIdCtrl.text.trim(),
          department: _departmentCtrl.text.trim(),
          status: _selectedStatus,
          permissions: _permissions,
          remarks: _remarksCtrl.text.trim(),
        );
      }

      if (mounted) {
        widget.onSaved();
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(widget.user == null ? 'User added successfully' : 'User updated successfully'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        String msg = e.toString().replaceAll('Exception: ', '');
        if (msg.contains('email_address_invalid') || msg.contains('is invalid')) {
          msg = 'Invalid email address or domain. Please check the email format.';
        } else if (msg.contains('already exists')) {
          msg = 'A user with this email address already exists.';
        } else if (msg.contains('Password must be')) {
          msg = 'Initial password must be at least 6 characters long.';
        }
        setState(() {
          _isSaving = false;
          _errorMessage = msg;
        });
      }
    }
  }

  Future<void> _handleSendResetLink() async {
    final email = _emailCtrl.text.trim();
    if (email.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a valid email first'), backgroundColor: Colors.red),
      );
      return;
    }

    try {
      await UserManagementService.sendPasswordResetEmail(email);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Password recovery link sent to '),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed: '), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isNew = widget.user == null;

    final screenHeight = MediaQuery.of(context).size.height;
    final screenWidth = MediaQuery.of(context).size.width;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        constraints: BoxConstraints(
          maxWidth: 820,
          maxHeight: screenHeight * 0.9,
          minWidth: screenWidth < 850 ? screenWidth * 0.95 : 600,
        ),
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            // Header
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: theme.colorScheme.primaryContainer,
                  radius: 22,
                  child: Icon(
                    isNew ? Icons.person_add_rounded : Icons.manage_accounts_rounded,
                    color: theme.colorScheme.onPrimaryContainer,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        isNew ? 'Add Staff Member' : 'Edit Staff & Permissions',
                        style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      Text(
                        isNew
                            ? 'Create staff credentials and configure operational permissions.'
                            : 'Update profile details, access rights, and staff status.',
                        style: TextStyle(fontSize: 12, color: theme.colorScheme.onSurfaceVariant),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
            const SizedBox(height: 14),

            // Tab bar for General info vs Granular permissions
            TabBar(
              controller: _tabController,
              tabs: const [
                Tab(icon: Icon(Icons.badge_outlined), text: 'Profile & Role'),
                Tab(icon: Icon(Icons.security_outlined), text: 'Granular Permissions'),
              ],
            ),
            const SizedBox(height: 14),

            if (_errorMessage != null)
              Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.red.shade200),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.error_outline, color: Colors.red, size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _errorMessage!,
                        style: const TextStyle(color: Colors.red, fontSize: 13),
                      ),
                    ),
                  ],
                ),
              ),

            // Tab View Body
            Expanded(
              child: Form(
                key: _formKey,
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    _buildGeneralTab(theme, isNew),
                    _buildPermissionsTab(theme),
                  ],
                ),
              ),
            ),
            const Divider(height: 24),

            // Footer Actions
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                if (!isNew)
                  OutlinedButton.icon(
                    onPressed: _handleSendResetLink,
                    icon: const Icon(Icons.lock_reset, size: 16),
                    label: const Text('Send Password Reset Link'),
                  )
                else
                  const SizedBox(),
                Row(
                  children: [
                    TextButton(
                      onPressed: _isSaving ? null : () => Navigator.of(context).pop(),
                      child: const Text('Cancel'),
                    ),
                    const SizedBox(width: 12),
                    FilledButton.icon(
                      onPressed: _isSaving ? null : _handleSave,
                      icon: _isSaving
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                            )
                          : const Icon(Icons.check, size: 18),
                      label: Text(isNew ? 'Create User' : 'Save Changes'),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGeneralTab(ThemeData theme, bool isNew) {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Full Name
              Expanded(
                child: TextFormField(
                  controller: _nameCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Full Name *',
                    hintText: 'e.g. Rushikesh Jadhav',
                    prefixIcon: Icon(Icons.person_outline),
                    border: OutlineInputBorder(),
                  ),
                  validator: (v) => (v == null || v.trim().isEmpty) ? 'Full Name is required' : null,
                ),
              ),
              const SizedBox(width: 16),
              // Mobile Number
              Expanded(
                child: TextFormField(
                  controller: _mobileCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Mobile Number *',
                    hintText: '10 digit mobile number',
                    prefixIcon: Icon(Icons.phone_outlined),
                    border: OutlineInputBorder(),
                  ),
                  keyboardType: TextInputType.phone,
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) return 'Mobile is required';
                    if (v.replaceAll(RegExp(r'\D'), '').length < 10) return 'Enter 10-digit mobile';
                    return null;
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Email
              Expanded(
                child: TextFormField(
                  controller: _emailCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Email Address *',
                    hintText: 'staff@siyasolar.com',
                    prefixIcon: Icon(Icons.email_outlined),
                    border: OutlineInputBorder(),
                  ),
                  keyboardType: TextInputType.emailAddress,
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) return 'Email is required';
                    if (!v.contains('@') || !v.contains('.')) return 'Enter valid email';
                    return null;
                  },
                ),
              ),
              const SizedBox(width: 16),
              // Role Dropdown
              Expanded(
                child: DropdownButtonFormField<String>(
                  value: _selectedRole,
                  decoration: const InputDecoration(
                    labelText: 'System Role *',
                    prefixIcon: Icon(Icons.shield_outlined),
                    border: OutlineInputBorder(),
                  ),
                  items: UserRole.allRoles.map((r) {
                    return DropdownMenuItem(
                      value: r,
                      child: Text(UserRole.displayName(r)),
                    );
                  }).toList(),
                  onChanged: _onRoleChanged,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Employee / Staff ID
              Expanded(
                child: TextFormField(
                  controller: _employeeIdCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Employee / Staff ID',
                    hintText: 'e.g. SIYA-104',
                    prefixIcon: Icon(Icons.badge_outlined),
                    border: OutlineInputBorder(),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              // Department Autocomplete / Dropdown
              Expanded(
                child: DropdownButtonFormField<String>(
                  value: _departments.contains(_departmentCtrl.text) ? _departmentCtrl.text : null,
                  decoration: const InputDecoration(
                    labelText: 'Department',
                    prefixIcon: Icon(Icons.business_outlined),
                    border: OutlineInputBorder(),
                  ),
                  items: _departments.map((d) {
                    return DropdownMenuItem(value: d, child: Text(d));
                  }).toList(),
                  onChanged: (val) {
                    if (val != null) {
                      setState(() => _departmentCtrl.text = val);
                    }
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Status Dropdown
              Expanded(
                child: DropdownButtonFormField<String>(
                  value: _selectedStatus,
                  decoration: const InputDecoration(
                    labelText: 'User Status',
                    prefixIcon: Icon(Icons.toggle_on_outlined),
                    border: OutlineInputBorder(),
                  ),
                  items: const [
                    DropdownMenuItem(value: 'Active', child: Text('Active (Can Login & Work)')),
                    DropdownMenuItem(value: 'Inactive', child: Text('Inactive (Disabled)')),
                    DropdownMenuItem(value: 'Suspended', child: Text('Suspended (Restricted)')),
                  ],
                  onChanged: (val) {
                    if (val != null) setState(() => _selectedStatus = val);
                  },
                ),
              ),
              const SizedBox(width: 16),
              // Temporary Password (Only on Create)
              if (isNew)
                Expanded(
                  child: TextFormField(
                    controller: _tempPasswordCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Initial Password (Optional)',
                      hintText: 'Default: Siya@Last4Digits',
                      prefixIcon: Icon(Icons.lock_outline),
                      border: OutlineInputBorder(),
                    ),
                    obscureText: true,
                  ),
                )
              else
                const Expanded(child: SizedBox()),
            ],
          ),
          const SizedBox(height: 16),

          // Remarks
          TextFormField(
            controller: _remarksCtrl,
            maxLines: 2,
            decoration: const InputDecoration(
              labelText: 'Remarks / Notes',
              hintText: 'Staff background, specialized skills, territories, etc.',
              border: OutlineInputBorder(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPermissionsTab(ThemeData theme) {
    final modules = AppModuleRegistry.allModules;

    return Column(
      children: [
        // Presets toolbar
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            children: [
              const Text('Presets:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
              const SizedBox(width: 8),
              TextButton.icon(
                onPressed: () {
                  setState(() {
                    _permissions = AppModuleRegistry.fullAccessPermissions();
                  });
                },
                icon: const Icon(Icons.check_circle_outline, size: 14, color: Colors.green),
                label: const Text('Full Access', style: TextStyle(fontSize: 12)),
              ),
              const SizedBox(width: 4),
              TextButton.icon(
                onPressed: () {
                  setState(() {
                    _permissions = AppModuleRegistry.readOnlyPermissions();
                  });
                },
                icon: const Icon(Icons.visibility_outlined, size: 14, color: Colors.blue),
                label: const Text('Read Only', style: TextStyle(fontSize: 12)),
              ),
              const SizedBox(width: 4),
              TextButton.icon(
                onPressed: () {
                  setState(() {
                    _permissions = UserRole.defaultPermissions(_selectedRole);
                  });
                },
                icon: const Icon(Icons.refresh, size: 14, color: Colors.orange),
                label: const Text('Reset to Role Default', style: TextStyle(fontSize: 12)),
              ),
              const Spacer(),
              TextButton.icon(
                onPressed: () {
                  setState(() {
                    _permissions.clear();
                  });
                },
                icon: const Icon(Icons.clear_all, size: 14, color: Colors.red),
                label: const Text('Clear All', style: TextStyle(fontSize: 12, color: Colors.red)),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),

        // Modules List
        Expanded(
          child: ListView.builder(
            itemCount: modules.length,
            itemBuilder: (ctx, i) {
              final mod = modules[i];
              final hasView = AppModuleRegistry.hasView(_permissions, mod.key);
              final hasEdit = AppModuleRegistry.hasEdit(_permissions, mod.key);
              final hasDelete = AppModuleRegistry.hasDelete(_permissions, mod.key);

              return Card(
                margin: const EdgeInsets.only(bottom: 8),
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                  side: BorderSide(
                    color: hasView
                        ? theme.colorScheme.primary.withValues(alpha: 0.4)
                        : theme.colorScheme.outlineVariant,
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  child: Row(
                    children: [
                      Icon(mod.icon, size: 20, color: theme.colorScheme.primary),
                      const SizedBox(width: 10),
                      Expanded(
                        flex: 4,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              mod.nameMr,
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                            ),
                            Text(
                              '${mod.nameEn} (${mod.category})',
                              style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                            ),
                          ],
                        ),
                      ),
                      Expanded(
                        flex: 5,
                        child: Wrap(
                          spacing: 8,
                          alignment: WrapAlignment.end,
                          children: [
                            FilterChip(
                              selected: hasView,
                              avatar: Icon(Icons.visibility, size: 14, color: hasView ? Colors.green.shade900 : null),
                              label: const Text('View (पाहणे)', style: TextStyle(fontSize: 11)),
                              selectedColor: Colors.green.shade100,
                              onSelected: (val) {
                                setState(() {
                                  _permissions = AppModuleRegistry.setModulePermission(
                                    currentPerms: _permissions,
                                    moduleKey: mod.key,
                                    action: 'view',
                                    enabled: val,
                                  );
                                });
                              },
                            ),
                            FilterChip(
                              selected: hasEdit,
                              avatar: Icon(Icons.edit, size: 14, color: hasEdit ? Colors.blue.shade900 : null),
                              label: const Text('Edit (बदलणे)', style: TextStyle(fontSize: 11)),
                              selectedColor: Colors.blue.shade100,
                              onSelected: (val) {
                                setState(() {
                                  _permissions = AppModuleRegistry.setModulePermission(
                                    currentPerms: _permissions,
                                    moduleKey: mod.key,
                                    action: 'edit',
                                    enabled: val,
                                  );
                                });
                              },
                            ),
                            FilterChip(
                              selected: hasDelete,
                              avatar: Icon(Icons.delete_outline, size: 14, color: hasDelete ? Colors.red.shade900 : null),
                              label: const Text('Delete (हटवणे)', style: TextStyle(fontSize: 11)),
                              selectedColor: Colors.red.shade100,
                              onSelected: (val) {
                                setState(() {
                                  _permissions = AppModuleRegistry.setModulePermission(
                                    currentPerms: _permissions,
                                    moduleKey: mod.key,
                                    action: 'delete',
                                    enabled: val,
                                  );
                                });
                              },
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
