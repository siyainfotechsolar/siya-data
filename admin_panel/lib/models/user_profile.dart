class UserRole {
  static const String superAdmin = 'super_admin';
  static const String admin = 'admin';
  static const String officeStaff = 'office_staff';
  static const String sales = 'sales';
  static const String loanStaff = 'loan_staff';
  static const String installationStaff = 'installation_staff';
  static const String accounts = 'accounts';
  static const String viewer = 'viewer';
  static const String subVendor = 'sub_vendor';

  static const List<String> allRoles = [
    superAdmin,
    admin,
    officeStaff,
    sales,
    loanStaff,
    installationStaff,
    accounts,
    viewer,
    subVendor,
  ];

  static String displayName(String role) {
    switch (role.toLowerCase()) {
      case 'super_admin':
      case 'owner':
        return 'Owner / Super Admin';
      case 'admin':
        return 'Admin';
      case 'sub_vendor':
        return 'Sub-Vendor';
      case 'office_staff':
        return 'Office Staff';
      case 'sales':
        return 'Sales';
      case 'loan_staff':
        return 'Loan Staff';
      case 'installation_staff':
        return 'Installation Staff';
      case 'accounts':
        return 'Accounts';
      case 'viewer':
        return 'Viewer';
      case 'staff':
      default:
        return 'Staff';
    }
  }

  /// Default permission sets for each role
  static Map<String, List<String>> defaultPermissions(String role) {
    switch (role.toLowerCase()) {
      case 'super_admin':
      case 'owner':
      case 'admin':
        return {
          'customer': ['view', 'create', 'edit', 'delete'],
          'loan': ['view', 'create', 'edit', 'delete'],
          'installation': ['view', 'create', 'edit', 'delete'],
          'rts': ['view', 'create', 'edit', 'delete'],
          'subsidy': ['view', 'create', 'edit', 'delete'],
          'payment': ['view', 'create', 'edit', 'delete'],
          'invoices': ['view', 'create', 'edit', 'delete'],
          'customer_hishob': ['view', 'create', 'edit', 'delete'],
          'sub_vendor': ['view', 'create', 'edit', 'delete'],
          'commission': ['view', 'create', 'edit', 'delete', 'approve', 'pay'],
          'solar_quotation': ['view', 'create', 'edit', 'delete'],
          'solar_cost_calculator': ['view', 'create', 'edit', 'delete'],
          'followup': ['view', 'create', 'edit', 'complete'],
          'general_issue': ['view', 'create', 'edit', 'close'],
          'leads': ['view', 'create', 'edit', 'delete'],
          'whatsapp': ['view', 'create', 'edit', 'delete'],
          'misc': ['view', 'create', 'complete'],
          'import': ['view', 'create'],
          'export_excel': ['view'],
          'export_pdf': ['view'],
          'reports': ['view'],
          'user_management': ['view', 'create', 'edit', 'delete'],
          'settings': ['view', 'edit', 'delete'],
        };

      case 'office_staff':
        return {
          'customer': ['view', 'create', 'edit'],
          'loan': ['view', 'edit'],
          'installation': ['view'],
          'rts': ['view', 'edit'],
          'subsidy': ['view', 'edit'],
          'payment': ['view', 'create'],
          'invoices': ['view', 'create'],
          'customer_hishob': ['view'],
          'sub_vendor': ['view'],
          'commission': ['view', 'create'],
          'solar_quotation': ['view', 'create', 'edit'],
          'solar_cost_calculator': ['view'],
          'leads': ['view', 'create', 'edit'],
          'whatsapp': ['view', 'create', 'edit'],
          'followup': ['view', 'create', 'complete'],
          'general_issue': ['view', 'create', 'edit', 'close'],
          'misc': ['view', 'create', 'complete'],
          'export_excel': ['view'],
          'reports': ['view'],
        };

      case 'sales':
        return {
          'customer': ['view', 'create', 'edit'],
          'leads': ['view', 'create', 'edit'],
          'solar_quotation': ['view', 'create', 'edit'],
          'solar_cost_calculator': ['view', 'create', 'edit'],
          'whatsapp': ['view', 'create', 'edit'],
          'followup': ['view', 'create', 'complete'],
          'general_issue': ['view', 'create'],
          'misc': ['view', 'create'],
          'export_excel': ['view'],
        };

      case 'loan_staff':
        return {
          'customer': ['view'],
          'loan': ['view', 'edit'],
          'followup': ['view', 'create', 'complete'],
          'general_issue': ['view', 'create', 'edit'],
          'misc': ['view', 'create'],
        };

      case 'installation_staff':
        return {
          'customer': ['view'],
          'installation': ['view', 'edit'],
          'general_issue': ['view', 'create', 'edit'],
          'misc': ['view', 'create'],
        };

      case 'accounts':
        return {
          'customer': ['view'],
          'payment': ['view', 'create', 'edit'],
          'invoices': ['view', 'create', 'edit'],
          'customer_hishob': ['view', 'create', 'edit'],
          'sub_vendor': ['view', 'create', 'edit'],
          'commission': ['view', 'create', 'pay'],
          'subsidy': ['view', 'edit'],
          'export_excel': ['view'],
          'reports': ['view'],
        };

      case 'viewer':
        return {
          'customer': ['view'],
          'loan': ['view'],
          'installation': ['view'],
          'rts': ['view'],
          'subsidy': ['view'],
          'payment': ['view'],
          'invoices': ['view'],
          'customer_hishob': ['view'],
          'sub_vendor': ['view'],
          'commission': ['view'],
          'solar_quotation': ['view'],
          'solar_cost_calculator': ['view'],
          'leads': ['view'],
          'followup': ['view'],
          'general_issue': ['view'],
          'misc': ['view'],
          'reports': ['view'],
        };

      case 'sub_vendor':
        return {
          'sub_vendor': ['view', 'edit'],
          'vendor_dashboard': ['view'],
          'assigned_sites': ['view', 'update_status'],
          'materials': ['view'],
          'settlement': ['view', 'download_pdf'],
        };

      case 'staff':
      default:
        return {
          'customer': ['view', 'create', 'edit'],
          'followup': ['view', 'create', 'complete'],
          'general_issue': ['view', 'create'],
          'misc': ['view', 'create'],
        };
    }
  }
}

class UserProfile {
  final String id;
  final String email;
  final String? fullName;
  final String role; // 'admin', 'staff', 'super_admin', 'office_staff', etc.
  final String? mobile;
  final String? employeeId;
  final String? department;
  final String status; // 'Active', 'Inactive', 'Suspended'
  final bool isActive;
  final bool canDelete;
  final Map<String, List<String>> permissions;
  final String? remarks;
  final String? profilePhotoUrl;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  UserProfile({
    required this.id,
    required this.email,
    this.fullName,
    required this.role,
    this.mobile,
    this.employeeId,
    this.department,
    this.status = 'Active',
    this.isActive = true,
    this.canDelete = false,
    Map<String, List<String>>? permissions,
    this.remarks,
    this.profilePhotoUrl,
    this.createdAt,
    this.updatedAt,
  }) : permissions = permissions ?? UserRole.defaultPermissions(role);

  bool get isAdmin =>
      role == 'admin' || role == 'super_admin' || role == 'owner';
  bool get isSuperAdmin => role == 'super_admin' || role == 'owner';
  bool get isSubVendor => role.toLowerCase() == UserRole.subVendor;
  bool get isStaff => !isAdmin && !isSubVendor;

  bool get isSuspended => status.toUpperCase() == 'SUSPENDED';
  bool get isInactive => status.toUpperCase() == 'INACTIVE' || !isActive;

  /// Check if user has granular permission (e.g. module: 'customer', action: 'view' | 'edit' | 'delete')
  bool hasPermission(String module, String action) {
    if (isAdmin) return true;
    final mKey = module.toLowerCase();
    final act = action.toLowerCase();

    List<String>? actions = permissions[mKey];

    // Fallbacks for legacy keys or aliases
    if (actions == null) {
      if (mKey == 'sub_vendor' && permissions.containsKey('commission')) {
        actions = permissions['commission'];
      } else if (mKey == 'solar_quotation' && permissions.containsKey('customer')) {
        actions = permissions['customer'];
      } else if (mKey == 'solar_cost_calculator' && permissions.containsKey('customer')) {
        actions = permissions['customer'];
      } else if (mKey == 'customer_hishob' && permissions.containsKey('payment')) {
        actions = permissions['payment'];
      } else if (mKey == 'invoices' && permissions.containsKey('payment')) {
        actions = permissions['payment'];
      } else if (mKey == 'leads' && permissions.containsKey('customer')) {
        actions = permissions['customer'];
      } else if (mKey == 'whatsapp' && permissions.containsKey('customer')) {
        actions = permissions['customer'];
      }
    }

    if (actions == null) return false;
    if (actions.contains('*')) return true;

    // View action
    if (act == 'view') {
      return actions.contains('view') || actions.isNotEmpty;
    }

    // Edit action maps to edit, create, or update
    if (act == 'edit' || act == 'update' || act == 'create') {
      return actions.contains('edit') ||
          actions.contains('create') ||
          actions.contains('update');
    }

    // Delete action
    if (act == 'delete') {
      if (actions.contains('delete')) return true;
      // If legacy global canDelete is enabled and staff has view access to this module
      if (canDelete && actions.contains('view')) return true;
      return false;
    }

    return actions.contains(act);
  }

  bool canView(String module) => hasPermission(module, 'view');
  bool canEdit(String module) => hasPermission(module, 'edit');
  bool canDeleteFrom(String module) => hasPermission(module, 'delete');

  /// Total distinct modules where user has at least View access
  int get allowedModulesCount {
    if (isAdmin) return 20;
    return permissions.keys.where((k) {
      final acts = permissions[k];
      return acts != null && acts.isNotEmpty;
    }).length;
  }

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    final roleVal = json['role'] as String? ?? 'staff';

    // Parse permissions JSONB safely
    Map<String, List<String>> parsedPermissions = {};
    if (json['permissions'] != null && json['permissions'] is Map) {
      final rawMap = json['permissions'] as Map;
      rawMap.forEach((k, v) {
        if (v is List) {
          parsedPermissions[k.toString()] =
              v.map((e) => e.toString()).toList();
        }
      });
    } else {
      parsedPermissions = UserRole.defaultPermissions(roleVal);
    }

    final rawStatus = json['status'] as String? ??
        ((json['is_active'] as bool? ?? true) ? 'Active' : 'Inactive');

    return UserProfile(
      id: json['id'] as String,
      email: json['email'] as String? ?? '',
      fullName: json['full_name'] as String?,
      role: roleVal,
      mobile: json['mobile'] as String?,
      employeeId: json['employee_id'] as String?,
      department: json['department'] as String?,
      status: rawStatus,
      isActive: json['is_active'] as bool? ?? (rawStatus == 'Active'),
      canDelete: json['can_delete'] as bool? ?? false,
      permissions: parsedPermissions,
      remarks: json['remarks'] as String?,
      profilePhotoUrl: json['profile_photo_url'] as String?,
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'] as String)
          : null,
      updatedAt: json['updated_at'] != null
          ? DateTime.tryParse(json['updated_at'] as String)
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'email': email,
      'full_name': fullName,
      'role': role,
      'mobile': mobile,
      'employee_id': employeeId,
      'department': department,
      'status': status,
      'is_active': isActive && status == 'Active',
      'can_delete': canDelete,
      'permissions': permissions,
      'remarks': remarks,
      'profile_photo_url': profilePhotoUrl,
      if (createdAt != null) 'created_at': createdAt!.toIso8601String(),
      if (updatedAt != null) 'updated_at': updatedAt!.toIso8601String(),
    };
  }

  UserProfile copyWith({
    String? email,
    String? fullName,
    String? role,
    String? mobile,
    String? employeeId,
    String? department,
    String? status,
    bool? isActive,
    bool? canDelete,
    Map<String, List<String>>? permissions,
    String? remarks,
    String? profilePhotoUrl,
    DateTime? updatedAt,
  }) {
    return UserProfile(
      id: id,
      email: email ?? this.email,
      fullName: fullName ?? this.fullName,
      role: role ?? this.role,
      mobile: mobile ?? this.mobile,
      employeeId: employeeId ?? this.employeeId,
      department: department ?? this.department,
      status: status ?? this.status,
      isActive: isActive ?? this.isActive,
      canDelete: canDelete ?? this.canDelete,
      permissions: permissions ?? this.permissions,
      remarks: remarks ?? this.remarks,
      profilePhotoUrl: profilePhotoUrl ?? this.profilePhotoUrl,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  DateTime? get created_at => createdAt;
}
