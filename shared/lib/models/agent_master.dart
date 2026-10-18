/// Global Agent Master — Single Source of Truth for Commission Agents.
/// 
/// Reusable across Siya Data Management Software.
class AgentMaster {
  final String id;
  final String name;
  final String? mobile;
  final String? email;
  final String? agencyName;
  final String? address;
  final String? panNumber;
  final String? bankName;
  final String? accountNumber;
  final String? ifscCode;
  final String? upiId;
  final bool isActive;
  final bool deleted;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const AgentMaster({
    required this.id,
    required this.name,
    this.mobile,
    this.email,
    this.agencyName,
    this.address,
    this.panNumber,
    this.bankName,
    this.accountNumber,
    this.ifscCode,
    this.upiId,
    this.isActive = true,
    this.deleted = false,
    this.createdAt,
    this.updatedAt,
  });

  AgentMaster copyWith({
    String? id,
    String? name,
    String? mobile,
    String? email,
    String? agencyName,
    String? address,
    String? panNumber,
    String? bankName,
    String? accountNumber,
    String? ifscCode,
    String? upiId,
    bool? isActive,
    bool? deleted,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return AgentMaster(
      id: id ?? this.id,
      name: name ?? this.name,
      mobile: mobile ?? this.mobile,
      email: email ?? this.email,
      agencyName: agencyName ?? this.agencyName,
      address: address ?? this.address,
      panNumber: panNumber ?? this.panNumber,
      bankName: bankName ?? this.bankName,
      accountNumber: accountNumber ?? this.accountNumber,
      ifscCode: ifscCode ?? this.ifscCode,
      upiId: upiId ?? this.upiId,
      isActive: isActive ?? this.isActive,
      deleted: deleted ?? this.deleted,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'mobile': mobile,
      'email': email,
      'agency_name': agencyName,
      'address': address,
      'pan_number': panNumber,
      'bank_name': bankName,
      'account_number': accountNumber,
      'ifsc_code': ifscCode,
      'upi_id': upiId,
      'is_active': isActive,
      'deleted': deleted,
      'created_at': createdAt?.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
    };
  }

  factory AgentMaster.fromJson(Map<String, dynamic> json) {
    return AgentMaster(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? 'Unnamed Agent',
      mobile: json['mobile']?.toString(),
      email: json['email']?.toString(),
      agencyName: json['agency_name']?.toString() ?? json['agency']?.toString(),
      address: json['address']?.toString(),
      panNumber: json['pan_number']?.toString(),
      bankName: json['bank_name']?.toString(),
      accountNumber: json['account_number']?.toString(),
      ifscCode: json['ifsc_code']?.toString(),
      upiId: json['upi_id']?.toString(),
      isActive: json['is_active'] as bool? ?? true,
      deleted: json['deleted'] as bool? ?? false,
      createdAt: json['created_at'] != null ? DateTime.tryParse(json['created_at'].toString()) : null,
      updatedAt: json['updated_at'] != null ? DateTime.tryParse(json['updated_at'].toString()) : null,
    );
  }

  @override
  String toString() => name;
}
