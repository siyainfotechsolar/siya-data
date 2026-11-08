/// Represents a Sub-Vendor (Solar Installation Contractor / Partner).
class SubVendor {
  final String id;
  final String vendorCode; // e.g. SIYA-VND-101
  final String name;
  final String? contactPerson;
  final String mobile;
  final String email;
  final String? authUserId;
  final String? address;
  final String? panNumber;
  final String? gstNumber;
  final String? bankName;
  final String? accountNumber;
  final String? ifscCode;
  final String? upiId;
  final double defaultRatePerKw; // Default: ₹1,000/kW
  final bool isActive;
  final String status; // 'Active', 'Inactive', 'Blocked'
  final String? notes;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final String? createdBy;
  final String? updatedBy;

  const SubVendor({
    required this.id,
    required this.vendorCode,
    required this.name,
    this.contactPerson,
    required this.mobile,
    required this.email,
    this.authUserId,
    this.address,
    this.panNumber,
    this.gstNumber,
    this.bankName,
    this.accountNumber,
    this.ifscCode,
    this.upiId,
    this.defaultRatePerKw = 1000.0,
    this.isActive = true,
    this.status = 'Active',
    this.notes,
    this.createdAt,
    this.updatedAt,
    this.createdBy,
    this.updatedBy,
  });

  bool get isBlocked => status.toLowerCase() == 'blocked' || !isActive;

  factory SubVendor.fromJson(Map<String, dynamic> json) {
    return SubVendor(
      id: json['id'] as String? ?? '',
      vendorCode: json['vendor_code'] as String? ?? '',
      name: json['name'] as String? ?? '',
      contactPerson: json['contact_person'] as String?,
      mobile: json['mobile'] as String? ?? '',
      email: json['email'] as String? ?? '',
      authUserId: json['auth_user_id'] as String?,
      address: json['address'] as String?,
      panNumber: json['pan_number'] as String?,
      gstNumber: json['gst_number'] as String?,
      bankName: json['bank_name'] as String?,
      accountNumber: json['account_number'] as String?,
      ifscCode: json['ifsc_code'] as String?,
      upiId: json['upi_id'] as String?,
      defaultRatePerKw: (json['default_rate_per_kw'] as num?)?.toDouble() ?? 1000.0,
      isActive: json['is_active'] as bool? ?? true,
      status: json['status'] as String? ?? 'Active',
      notes: json['notes'] as String?,
      createdAt: json['created_at'] != null ? DateTime.tryParse(json['created_at'] as String) : null,
      updatedAt: json['updated_at'] != null ? DateTime.tryParse(json['updated_at'] as String) : null,
      createdBy: json['created_by'] as String?,
      updatedBy: json['updated_by'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'vendor_code': vendorCode,
      'name': name,
      if (contactPerson != null) 'contact_person': contactPerson,
      'mobile': mobile,
      'email': email,
      if (authUserId != null) 'auth_user_id': authUserId,
      if (address != null) 'address': address,
      if (panNumber != null) 'pan_number': panNumber,
      if (gstNumber != null) 'gst_number': gstNumber,
      if (bankName != null) 'bank_name': bankName,
      if (accountNumber != null) 'account_number': accountNumber,
      if (ifscCode != null) 'ifsc_code': ifscCode,
      if (upiId != null) 'upi_id': upiId,
      'default_rate_per_kw': defaultRatePerKw,
      'is_active': isActive,
      'status': status,
      if (notes != null) 'notes': notes,
      if (createdAt != null) 'created_at': createdAt!.toIso8601String(),
      if (updatedAt != null) 'updated_at': updatedAt!.toIso8601String(),
      if (createdBy != null) 'created_by': createdBy,
      if (updatedBy != null) 'updated_by': updatedBy,
    };
  }

  SubVendor copyWith({
    String? id,
    String? vendorCode,
    String? name,
    String? contactPerson,
    String? mobile,
    String? email,
    String? authUserId,
    String? address,
    String? panNumber,
    String? gstNumber,
    String? bankName,
    String? accountNumber,
    String? ifscCode,
    String? upiId,
    double? defaultRatePerKw,
    bool? isActive,
    String? status,
    String? notes,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? createdBy,
    String? updatedBy,
  }) {
    return SubVendor(
      id: id ?? this.id,
      vendorCode: vendorCode ?? this.vendorCode,
      name: name ?? this.name,
      contactPerson: contactPerson ?? this.contactPerson,
      mobile: mobile ?? this.mobile,
      email: email ?? this.email,
      authUserId: authUserId ?? this.authUserId,
      address: address ?? this.address,
      panNumber: panNumber ?? this.panNumber,
      gstNumber: gstNumber ?? this.gstNumber,
      bankName: bankName ?? this.bankName,
      accountNumber: accountNumber ?? this.accountNumber,
      ifscCode: ifscCode ?? this.ifscCode,
      upiId: upiId ?? this.upiId,
      defaultRatePerKw: defaultRatePerKw ?? this.defaultRatePerKw,
      isActive: isActive ?? this.isActive,
      status: status ?? this.status,
      notes: notes ?? this.notes,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      createdBy: createdBy ?? this.createdBy,
      updatedBy: updatedBy ?? this.updatedBy,
    );
  }
}
