/// Global Staff Master — Single Source of Truth for Staff profiles.
/// 
/// When any staff detail (Name, Mobile, Email, Role) is updated,
/// it reflects everywhere the staff member is assigned or referenced.
class StaffMaster {
  final String id;
  final String name;
  final String? email;
  final String? mobile;
  final String role; // 'admin', 'staff', 'technician', 'sales'
  final bool isActive;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const StaffMaster({
    required this.id,
    required this.name,
    this.email,
    this.mobile,
    this.role = 'staff',
    this.isActive = true,
    this.createdAt,
    this.updatedAt,
  });

  StaffMaster copyWith({
    String? id,
    String? name,
    String? email,
    String? mobile,
    String? role,
    bool? isActive,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return StaffMaster(
      id: id ?? this.id,
      name: name ?? this.name,
      email: email ?? this.email,
      mobile: mobile ?? this.mobile,
      role: role ?? this.role,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'email': email,
      'mobile': mobile,
      'role': role,
      'is_active': isActive,
      'created_at': createdAt?.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
    };
  }

  factory StaffMaster.fromJson(Map<String, dynamic> json) {
    return StaffMaster(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? json['full_name']?.toString() ?? 'Staff Member',
      email: json['email']?.toString(),
      mobile: json['mobile']?.toString() ?? json['phone']?.toString(),
      role: json['role']?.toString() ?? 'staff',
      isActive: json['is_active'] as bool? ?? json['active'] as bool? ?? true,
      createdAt: json['created_at'] != null ? DateTime.tryParse(json['created_at'].toString()) : null,
      updatedAt: json['updated_at'] != null ? DateTime.tryParse(json['updated_at'].toString()) : null,
    );
  }
}
